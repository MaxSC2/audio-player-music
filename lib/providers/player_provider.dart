import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_track.dart';
import '../models/custom_playlist.dart';
import '../services/audio_handler.dart';

enum PlayerRepeatMode { off, all, one }
enum SortOrder { title, artist, dateAddedNew, dateAddedOld, duration }

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer;
  final OnAudioQuery _audioQuery;
  SharedPreferences? _prefs;

  List<AudioTrack> _allTracks = [];
  List<int> _favoriteIds = [];
  List<CustomPlaylist> _playlists = [];

  double _defaultSpeed = 1.0;
  bool _hideUnknownArtist = false;

  List<AudioTrack> _playlist = [];
  int _currentIndex = -1;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  PlayerRepeatMode _repeatMode = PlayerRepeatMode.off;
  bool _shuffleMode = false;
  double _speed = 1.0;

  Timer? _sleepTimer;
  int _sleepTimerMinutes = 0;

  String _equalizerPreset = 'Flat (Стандарт)';

  bool _resumePlayback = false;
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);
  PlayerAudioHandler? _audioHandler;
  String? _mediaServiceError;

  AudioPlayer get player => _audioPlayer;

  List<AudioTrack> get allTracks => _allTracks;
  List<AudioTrack> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  AudioTrack? get currentTrack =>
      (_currentIndex >= 0 && _currentIndex < _playlist.length)
          ? _playlist[_currentIndex]
          : null;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  PlayerRepeatMode get repeatMode => _repeatMode;
  bool get shuffleMode => _shuffleMode;
  double get speed => _speed;
  int get sleepTimerMinutes => _sleepTimerMinutes;
  String get equalizerPreset => _equalizerPreset;
  List<CustomPlaylist> get playlists => _playlists;
  double get defaultSpeed => _defaultSpeed;
  bool get hideUnknownArtist => _hideUnknownArtist;
  bool get resumePlayback => _resumePlayback;
  bool get mediaServiceReady => _audioHandler != null;
  String? get mediaServiceError => _mediaServiceError;
  List<String> get mediaDebugLog {
    try {
      return _audioHandler?.debugLog ?? const [];
    } catch (_) {
      return const [];
    }
  }
  String get mediaDiagnostics {
    try {
      return _audioHandler?.diagnostics ?? 'Обработчик не подключён';
    } catch (e) {
      return 'ошибка: $e';
    }
  }

  void setMediaServiceError(String message) {
    _mediaServiceError = message;
    notifyListeners();
  }

  static const MethodChannel _deleteChannel =
      MethodChannel('neonwave/deletion');

  Future<bool> deleteTrack(AudioTrack track) async {
    try {
      final path = track.data ?? track.uri;
      if (path.isEmpty) return false;
      final ok = await _deleteChannel.invokeMethod<bool>(
            'deleteTrack',
            {'path': path},
          ) ??
          false;
      if (!ok) return false;

      final deletedId = track.id;
      _allTracks.removeWhere((t) => t.id == deletedId);
      _favoriteIds.removeWhere((id) => id == deletedId);
      for (var i = 0; i < _playlists.length; i++) {
        final ids = _playlists[i].trackIds
            .where((id) => id != deletedId)
            .toList();
        if (ids.length != _playlists[i].trackIds.length) {
          _playlists[i] = _playlists[i].copyWith(trackIds: ids);
        }
      }

      final queueIndex = _playlist.indexWhere((t) => t.id == deletedId);
      if (queueIndex >= 0) {
        if (queueIndex == _currentIndex) {
          await _audioPlayer.stop();
          _isPlaying = false;
          _position = Duration.zero;
          _duration = Duration.zero;
          _currentIndex = -1;
        } else if (queueIndex < _currentIndex) {
          _currentIndex -= 1;
        }
        _playlist.removeAt(queueIndex);
      }

      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void attachAudioHandler(PlayerAudioHandler handler) {
    _audioHandler = handler;
    handler.setShuffleState(_shuffleMode);
    handler.setRepeatState(_repeatMode.index);
    final track = currentTrack;
    if (track != null) handler.setFavoriteState(isFavorite(track.id));
    notifyListeners();
  }

  bool isFavorite(int id) => _favoriteIds.any((f) => f == id);

  PlayerProvider()
      : _audioPlayer = AudioPlayer(),
        _audioQuery = OnAudioQuery() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavorites();
    _loadPlaylists();
    _loadSettings();

    _audioPlayer.positionStream.listen((pos) {
      _position = pos;
      _maybePersistPosition();
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });

    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onTrackComplete();
      }
    });

    _audioPlayer.playbackEventStream.listen((event) {
      if (event.currentIndex != null) {
        _currentIndex = event.currentIndex!;
        notifyListeners();
      }
    });

    _audioPlayer.setSpeed(_speed);
  }

  Future<void> _loadSettings() async {
    final prefs = _prefs;
    if (prefs == null) return;

    _defaultSpeed = prefs.getDouble('default_speed') ?? 1.0;
    _hideUnknownArtist = prefs.getBool('hide_unknown') ?? false;
    _resumePlayback = prefs.getBool('resume_playback') ?? false;
    _speed = _defaultSpeed;

    final savedSort = prefs.getString('sort_order');
    if (savedSort != null) {
      final migrated = savedSort == 'dateAdded' ? 'dateAddedNew' : savedSort;
      _sortOrder = SortOrder.values.firstWhere(
        (s) => s.name == migrated,
        orElse: () => SortOrder.title,
      );
    }

    final savedEq = prefs.getString('eq_preset');
    if (savedEq != null) {
      _equalizerPreset = savedEq;
    }

    await _audioPlayer.setSpeed(_speed);
    notifyListeners();
  }

  Future<void> _loadPlaylists() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final raw = prefs.getString('playlists');
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => CustomPlaylist.fromJson(e as Map<String, dynamic>))
          .toList();
      _playlists = list;
      notifyListeners();
    } catch (_) {
      _playlists = [];
    }
  }

  Future<void> _savePlaylists() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      'playlists',
      jsonEncode(_playlists.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _playlists.add(CustomPlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmed,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final index = _playlists.indexWhere((p) => p.id == id);
    if (index < 0) return;
    _playlists[index] = _playlists[index].copyWith(name: trimmed);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> addToPlaylist(String playlistId, AudioTrack track) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index < 0) return;
    if (_playlists[index].trackIds.contains(track.id)) return;
    _playlists[index] = _playlists[index].copyWith(
      trackIds: [..._playlists[index].trackIds, track.id],
    );
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> removeFromPlaylist(String playlistId, int trackId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index < 0) return;
    _playlists[index] = _playlists[index].copyWith(
      trackIds: _playlists[index].trackIds.where((t) => t != trackId).toList(),
    );
    await _savePlaylists();
    notifyListeners();
  }

  List<AudioTrack> tracksOfPlaylist(CustomPlaylist playlist) {
    final tracks = <AudioTrack>[];
    for (final id in playlist.trackIds) {
      for (final t in _allTracks) {
        if (t.id == id) {
          tracks.add(t);
          break;
        }
      }
    }
    return tracks;
  }

  Future<void> setDefaultSpeed(double speed) async {
    _defaultSpeed = speed;
    _speed = speed;
    await _prefs?.setDouble('default_speed', speed);
    await _audioPlayer.setSpeed(speed);
    notifyListeners();
  }

  Future<void> setHideUnknownArtist(bool value) async {
    _hideUnknownArtist = value;
    await _prefs?.setBool('hide_unknown', value);
    notifyListeners();
  }

  Future<void> setResumePlayback(bool value) async {
    _resumePlayback = value;
    await _prefs?.setBool('resume_playback', value);
    notifyListeners();
  }

  void _maybePersistPosition() {
    if (!_resumePlayback) return;
    final now = DateTime.now();
    if (now.difference(_lastPersist).inSeconds < 5) return;
    _lastPersist = now;
    _prefs?.setStringList(
      'last_playlist_ids',
      _playlist.map((t) => t.id.toString()).toList(),
    );
    _prefs?.setInt('last_index', _currentIndex);
    _prefs?.setInt('last_position_ms', _position.inMilliseconds);
  }

  Future<void> _maybeResume() async {
    if (!_resumePlayback) return;
    final prefs = _prefs;
    if (prefs == null) return;

    final ids = prefs.getStringList('last_playlist_ids');
    final index = prefs.getInt('last_index') ?? -1;
    final positionMs = prefs.getInt('last_position_ms') ?? 0;
    if (ids == null || ids.isEmpty) return;

    final tracks = <AudioTrack>[];
    for (final idStr in ids) {
      final id = int.tryParse(idStr);
      if (id == null) continue;
      for (final t in _allTracks) {
        if (t.id == id) {
          tracks.add(t);
          break;
        }
      }
    }
    if (tracks.isEmpty || index < 0 || index >= tracks.length) return;

    _playlist = tracks;
    await _audioPlayer.setAudioSources(
      _playlist.map((t) => AudioSource.uri(Uri.parse(t.uri))).toList(),
    );
    _currentIndex = index;
    await _audioPlayer.seek(Duration(milliseconds: positionMs), index: index);
    _audioHandler?.setQueue(_playlist);
    notifyListeners();
  }

  List<AudioTrack> get visibleTracks {
    if (!_hideUnknownArtist) return _allTracks;
    return _allTracks
        .where((t) => t.artist.toLowerCase() != 'unknown artist')
        .toList();
  }

  Future<void> _loadFavorites() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final saved = prefs.getStringList('favorite_ids');
    if (saved != null) {
      _favoriteIds = saved.map((s) => int.tryParse(s) ?? 0).toList();
      notifyListeners();
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setStringList(
      'favorite_ids',
      _favoriteIds.map((id) => id.toString()).toList(),
    );
  }

  void toggleFavorite(AudioTrack track) {
    if (isFavorite(track.id)) {
      _favoriteIds.removeWhere((f) => f == track.id);
    } else {
      _favoriteIds.add(track.id);
    }
    _saveFavorites();
    _refreshTrackFavoriteFlags();
    _audioHandler?.setFavoriteState(isFavorite(track.id));
    notifyListeners();
  }

  void toggleFavoriteCurrent() {
    final track = currentTrack;
    if (track == null) return;
    toggleFavorite(track);
  }

  void _refreshTrackFavoriteFlags() {
    _allTracks = _allTracks
        .map((t) => t.copyWith(isFavorite: isFavorite(t.id)))
        .toList();
    _playlist = _playlist
        .map((t) => t.copyWith(isFavorite: isFavorite(t.id)))
        .toList();
  }

  List<AudioTrack> get favoriteTracks {
    final fav = visibleTracks.where((t) => isFavorite(t.id)).toList();
    return sortTracks(fav, _sortOrder);
  }

  SortOrder _sortOrder = SortOrder.title;
  SortOrder get sortOrder => _sortOrder;
  set sortOrder(SortOrder value) {
    _sortOrder = value;
    _allTracks = sortTracks(_allTracks, value);
    _prefs?.setString('sort_order', value.name);
    notifyListeners();
  }

  List<AudioTrack> sortTracks(List<AudioTrack> tracks, SortOrder order) {
    final list = List<AudioTrack>.from(tracks);
    switch (order) {
      case SortOrder.title:
        list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOrder.artist:
        list.sort(
            (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case SortOrder.dateAddedNew:
        list.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
        break;
      case SortOrder.dateAddedOld:
        list.sort((a, b) => (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0));
        break;
      case SortOrder.duration:
        list.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }
    return list;
  }

  List<AudioTrack> searchTracks(String query) {
    final base = visibleTracks;
    if (query.isEmpty) return base;
    final q = query.toLowerCase();
    return base.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          (t.album ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<String> get artists =>
      visibleTracks.map((t) => t.artist).toSet().where((a) => a.isNotEmpty).toList()..sort();

  List<String> get albums =>
      visibleTracks.where((t) => t.album != null && t.album!.isNotEmpty).map((t) => t.album!).toSet().toList()..sort();

  Future<void> requestPermission() async {
    try {
      final status = await Permission.audio.request();
      if (!status.isGranted) return;
    } catch (_) {
      return;
    }
    await _requestNotificationPermission();
    try {
      await loadTracks();
    } catch (_) {}
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await Permission.notification.request();
    } catch (_) {}
  }

  Future<void> loadTracks() async {
    final tracks = await _audioQuery.querySongs(
      sortType: null,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    _allTracks = tracks
        .where((song) => song.isMusic != null ? song.isMusic! : true)
        .where((song) => song.duration != null && song.duration! > 5000)
        .map((song) => AudioTrack(
              id: song.id,
              title: song.title,
              artist: song.artist ?? 'Unknown Artist',
              album: song.album,
              uri: song.uri ?? '',
              duration: song.duration ?? 0,
              size: song.size,
              dateAdded: song.dateAdded,
              data: song.data,
              albumId: song.albumId,
              isFavorite: isFavorite(song.id),
            ))
        .toList();

    _allTracks = sortTracks(_allTracks, _sortOrder);
    notifyListeners();
    await _maybeResume();
  }

  Future<void> playTrack(AudioTrack track) async {
    final index = _playlist.indexWhere((t) => t.id == track.id);
    if (index >= 0) {
      await playAt(index);
    } else {
      await playFromPlaylist([track], 0);
    }
  }

  Future<void> playFromPlaylist(List<AudioTrack> tracks, int startIndex) async {
    _playlist = List<AudioTrack>.from(tracks);
    if (_playlist.isEmpty) return;

    _prefs?.setStringList(
      'last_playlist_ids',
      _playlist.map((t) => t.id.toString()).toList(),
    );
    _prefs?.setInt('last_index', startIndex);

    await _audioPlayer.setAudioSources(
      _playlist.map((t) => AudioSource.uri(Uri.parse(t.uri))).toList(),
    );

    _audioHandler?.setQueue(_playlist);
    await playAt(startIndex);
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    await _audioPlayer.seek(Duration.zero, index: index);
    await _audioPlayer.play();
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (currentTrack == null) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    _isPlaying = _audioPlayer.playing;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;
    if (_repeatMode == PlayerRepeatMode.one) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      return;
    }

    if (_shuffleMode) {
      await _playRandom();
      return;
    }

    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _playlist.length) {
      if (_repeatMode == PlayerRepeatMode.all) {
        await playAt(0);
      } else {
        await _audioPlayer.pause();
        await _audioPlayer.seek(Duration.zero);
      }
    } else {
      await playAt(nextIndex);
    }
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;
    if (_position.inSeconds > 3) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }

    final prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      await _audioPlayer.seek(Duration.zero);
    } else {
      await playAt(prevIndex);
    }
  }

  Future<void> _playRandom() async {
    if (_playlist.length < 2) return;
    var index = _currentIndex;
    while (index == _currentIndex) {
      index = (DateTime.now().microsecondsSinceEpoch) % _playlist.length;
    }
    await playAt(index);
  }

  Future<void> _onTrackComplete() async {
    await next();
  }

  void toggleRepeat() {
    switch (_repeatMode) {
      case PlayerRepeatMode.off:
        _repeatMode = PlayerRepeatMode.all;
      case PlayerRepeatMode.all:
        _repeatMode = PlayerRepeatMode.one;
      case PlayerRepeatMode.one:
        _repeatMode = PlayerRepeatMode.off;
    }
    _audioHandler?.setRepeatState(_repeatMode.index);
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffleMode = !_shuffleMode;
    _audioHandler?.setShuffleState(_shuffleMode);
    notifyListeners();
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _audioPlayer.setSpeed(speed);
    notifyListeners();
  }

  void cycleSpeed() {
    const speeds = [1.0, 1.25, 1.5, 1.75, 2.0, 0.75, 0.5];
    final idx = speeds.indexOf(_speed);
    setSpeed(speeds[(idx + 1) % speeds.length]);
  }

  void setSleepTimer(int minutes) {
    _sleepTimerMinutes = minutes;
    _sleepTimer?.cancel();
    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      await _audioPlayer.pause();
      _sleepTimerMinutes = 0;
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerMinutes = 0;
    notifyListeners();
  }

  void addToQueueNext(AudioTrack track) {
    final insertIndex = _currentIndex + 1;
    _playlist.insert(insertIndex, track);
    _rebuildPlaylist();
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _playlist.length) return;
    _playlist.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex -= 1;
    } else if (index == _currentIndex) {
      if (_playlist.isEmpty) {
        _currentIndex = -1;
      } else if (_currentIndex >= _playlist.length) {
        _currentIndex = 0;
      }
      _rebuildPlaylist();
      playAt(_currentIndex);
      return;
    }
    _rebuildPlaylist();
    notifyListeners();
  }

  Future<void> _rebuildPlaylist() async {
    if (_playlist.isEmpty) {
      await _audioPlayer.stop();
      return;
    }
    _audioHandler?.setQueue(_playlist);
    await _audioPlayer.setAudioSources(
      _playlist.map((t) => AudioSource.uri(Uri.parse(t.uri))).toList(),
    );
    if (_currentIndex >= 0) {
      await _audioPlayer.seek(_position, index: _currentIndex);
      if (_isPlaying) await _audioPlayer.play();
    }
  }

  void setEqualizerPreset(String name) {
    _equalizerPreset = name;
    _prefs?.setString('eq_preset', name);
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}