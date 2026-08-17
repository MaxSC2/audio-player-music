import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_track.dart';

enum RepeatMode { off, all, one }
enum SortOrder { title, artist, dateAdded, duration }

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer;
  final OnAudioQuery _audioQuery;
  SharedPreferences? _prefs;

  List<AudioTrack> _allTracks = [];
  List<AudioTrack> _favoriteIds = [];

  List<AudioTrack> _playlist = [];
  int _currentIndex = -1;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  RepeatMode _repeatMode = RepeatMode.off;
  bool _shuffleMode = false;
  double _speed = 1.0;

  Timer? _sleepTimer;
  int _sleepTimerMinutes = 0;

  String _equalizerPreset = 'Flat (Стандарт)';

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
  RepeatMode get repeatMode => _repeatMode;
  bool get shuffleMode => _shuffleMode;
  double get speed => _speed;
  int get sleepTimerMinutes => _sleepTimerMinutes;
  String get equalizerPreset => _equalizerPreset;

  bool isFavorite(int id) => _favoriteIds.any((f) => f == id);

  PlayerProvider()
      : _audioPlayer = AudioPlayer(),
        _audioQuery = OnAudioQuery() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavorites();

    _audioPlayer.positionStream.listen((pos) {
      _position = pos;
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
    notifyListeners();
  }

  void _refreshTrackFavoriteFlags() {
    _allTracks = _allTracks
        .map((t) => t.copyWith(isFavorite: isFavorite(t.id)))
        .toList();
  }

  List<AudioTrack> get favoriteTracks {
    final fav = _allTracks.where((t) => isFavorite(t.id)).toList();
    return sortTracks(fav, _sortOrder);
  }

  SortOrder _sortOrder = SortOrder.title;
  SortOrder get sortOrder => _sortOrder;
  set sortOrder(SortOrder value) {
    _sortOrder = value;
    _allTracks = sortTracks(_allTracks, value);
    notifyListeners();
  }

  List<AudioTrack> sortTracks(List<AudioTrack> tracks, SortOrder order) {
    final list = List<AudioTrack>.from(tracks);
    switch (order) {
      case SortOrder.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SortOrder.artist:
        list.sort(
            (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
      case SortOrder.dateAdded:
        list.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
      case SortOrder.duration:
        list.sort((a, b) => b.duration.compareTo(a.duration));
    }
    return list;
  }

  List<AudioTrack> searchTracks(String query) {
    if (query.isEmpty) return _allTracks;
    final q = query.toLowerCase();
    return _allTracks.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          (t.album ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<String> get artists =>
      _allTracks.map((t) => t.artist).toSet().where((a) => a.isNotEmpty).toList()..sort();

  List<String> get albums =>
      _allTracks.where((t) => t.album != null && t.album!.isNotEmpty).map((t) => t.album!).toSet().toList()..sort();

  Future<void> requestPermission() async {
    final hasPermission = await _audioQuery.checkAndRequestPermissions();
    if (!hasPermission) return;
    await loadTracks();
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
              uri: song.uri,
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

    final uris = _playlist.map((t) => t.uri).toList();
    await _audioPlayer.setAudioSource(ConcatenatingAudioSource(
      children: uris.map((uri) => AudioSource.uri(Uri.parse(uri))).toList(),
      useLazyPreparation: true,
    ));

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
    if (_repeatMode == RepeatMode.one) {
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
      if (_repeatMode == RepeatMode.all) {
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
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffleMode = !_shuffleMode;
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
    final uris = _playlist.map((t) => t.uri).toList();
    await _audioPlayer.setAudioSource(ConcatenatingAudioSource(
      children: uris.map((uri) => AudioSource.uri(Uri.parse(uri))).toList(),
      useLazyPreparation: true,
    ));
    if (_currentIndex >= 0) {
      await _audioPlayer.seek(_position, index: _currentIndex);
      if (_isPlaying) await _audioPlayer.play();
    }
  }

  void setEqualizerPreset(String name) {
    _equalizerPreset = name;
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}