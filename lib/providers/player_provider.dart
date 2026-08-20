import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_track.dart';
import '../models/custom_playlist.dart';
import '../models/queue_snapshot.dart';
import '../services/audio_handler.dart';

enum PlayerRepeatMode { off, all, one }
enum SortOrder { title, artist, dateAddedNew, dateAddedOld, duration }

enum ListeningContext { balanced, energy, calm, party, focus }

enum DiscoveryLevel { familiar, balanced, discovery, experimental }

extension DiscoveryLevelX on DiscoveryLevel {
  double get factor => switch (this) {
        DiscoveryLevel.familiar => 0.0,
        DiscoveryLevel.balanced => 0.35,
        DiscoveryLevel.discovery => 0.7,
        DiscoveryLevel.experimental => 1.0,
      };

  String get label => switch (this) {
        DiscoveryLevel.familiar => 'Привычное',
        DiscoveryLevel.balanced => 'Баланс',
        DiscoveryLevel.discovery => 'Открытия',
        DiscoveryLevel.experimental => 'Эксперимент',
      };
}

class PlayerProvider extends ChangeNotifier {
  late final AudioPlayer _audioPlayer;
  late final AndroidEqualizer _equalizer;
  late final AndroidLoudnessEnhancer _loudness;
  final OnAudioQuery _audioQuery;
  SharedPreferences? _prefs;

  List<AudioTrack> _allTracks = [];
  List<int> _favoriteIds = [];
  List<CustomPlaylist> _playlists = [];
  List<Map<String, int>> _historyRaw = [];
  List<Map<String, int>> _notNowRaw = [];
  Set<ListeningContext> _activeContexts = {ListeningContext.balanced};
  Map<int, int> _skipCount = {};
  bool _deepCuts = false;
  DiscoveryLevel _discoveryLevel = DiscoveryLevel.balanced;
  List<QueueSnapshot> _queueSnapshots = [];
  Map<int, List<int>> _bookmarks = {};

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
  bool _xBoost = false;
  Duration? _repeatA;
  Duration? _repeatB;

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
  bool get xBoost => _xBoost;
  Duration? get repeatA => _repeatA;
  Duration? get repeatB => _repeatB;
  bool get repeatABActive => _repeatA != null && _repeatB != null;
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

  PlayerProvider() : _audioQuery = OnAudioQuery() {
    _equalizer = AndroidEqualizer();
    _loudness = AndroidLoudnessEnhancer();
    _audioPlayer = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [_equalizer, _loudness],
      ),
    );
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavorites();
    _loadPlaylists();
    _loadSettings();

    _audioPlayer.positionStream.listen((pos) {
      _position = pos;
      if (_repeatA != null && _repeatB != null && pos >= _repeatB!) {
        _audioPlayer.seek(_repeatA!);
      }
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
      if (state == ProcessingState.ready) {
        _applyEqualizerPreset(_equalizerPreset);
      }
      if (state == ProcessingState.completed) {
        _onTrackComplete();
      }
    });

    _audioPlayer.playbackEventStream.listen((event) {
      if (event.currentIndex != null) {
        _currentIndex = event.currentIndex!;
        if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
          _recordHistory(_playlist[_currentIndex]);
        }
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

    final savedHistory = prefs.getString('history');
    if (savedHistory != null) {
      try {
        _historyRaw = (jsonDecode(savedHistory) as List)
            .whereType<Map>()
            .map((e) => e.cast<String, int>())
            .toList();
      } catch (_) {
        _historyRaw = [];
      }
    }

    final savedNotNow = prefs.getString('not_now');
    if (savedNotNow != null) {
      try {
        _notNowRaw = (jsonDecode(savedNotNow) as List)
            .whereType<Map>()
            .map((e) => e.cast<String, int>())
            .toList();
      } catch (_) {
        _notNowRaw = [];
      }
    }

    final savedContext = prefs.getString('listening_context');
    if (savedContext != null && savedContext.isNotEmpty) {
      final names = savedContext.split(',');
      final parsed = names
          .map((n) => ListeningContext.values.firstWhere(
                (c) => c.name == n,
                orElse: () => ListeningContext.balanced,
              ))
          .toSet();
      _activeContexts = parsed.isEmpty
          ? {ListeningContext.balanced}
          : parsed;
    }

    final savedSkips = prefs.getString('skip_counts');
    if (savedSkips != null) {
      try {
        final raw = jsonDecode(savedSkips) as Map;
        raw.forEach((k, v) {
          final id = int.tryParse(k.toString());
          if (id != null) {
            _skipCount[id] = v as int;
          }
        });
      } catch (_) {
        _skipCount = {};
      }
    }

    _deepCuts = prefs.getBool('dj_deep_cuts') ?? false;
    final savedDiscovery = prefs.getString('dj_discovery');
    if (savedDiscovery != null) {
      _discoveryLevel = DiscoveryLevel.values.firstWhere(
        (d) => d.name == savedDiscovery,
        orElse: () => DiscoveryLevel.balanced,
      );
    }

    final savedBookmarks = prefs.getString('bookmarks');
    if (savedBookmarks != null) {
      try {
        final raw = jsonDecode(savedBookmarks) as Map;
        raw.forEach((k, v) {
          final id = int.tryParse(k.toString());
          if (id != null) {
            _bookmarks[id] = (v as List).cast<int>();
          }
        });
      } catch (_) {
        _bookmarks = {};
      }
    }

    final savedSnapshots = prefs.getString('queue_snapshots');
    if (savedSnapshots != null) {
      try {
        _queueSnapshots = (jsonDecode(savedSnapshots) as List)
            .whereType<Map>()
            .map((e) => QueueSnapshot.fromJson(e.cast<String, dynamic>()))
            .toList();
      } catch (_) {
        _queueSnapshots = [];
      }
    }

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

  List<({AudioTrack track, DateTime time})> get historyEntries {
    final result = <({AudioTrack track, DateTime time})>[];
    if (_historyRaw.isEmpty) return result;
    for (final e in _historyRaw) {
      final id = e['id'];
      final ts = e['ts'];
      if (id == null || ts == null) continue;
      final index = _allTracks.indexWhere((t) => t.id == id);
      if (index < 0) continue;
      result.add((
        track: _allTracks[index],
        time: DateTime.fromMillisecondsSinceEpoch(ts),
      ));
    }
    return result;
  }

  void _recordHistory(AudioTrack track) {
    _historyRaw.insert(
      0,
      {'id': track.id, 'ts': DateTime.now().millisecondsSinceEpoch},
    );
    if (_historyRaw.length > 300) {
      _historyRaw.removeRange(300, _historyRaw.length);
    }
    _prefs?.setString('history', jsonEncode(_historyRaw));
  }

  Future<void> clearHistory() async {
    _historyRaw = [];
    await _prefs?.remove('history');
    notifyListeners();
  }

  // ─── "Не хочу сейчас" ──────────────────────────────────────────────
  static const int _notNowExpiryMs = 7 * 24 * 3600 * 1000;

  List<AudioTrack> get notNowTracks {
    _expireNotNow();
    final result = <AudioTrack>[];
    for (final e in _notNowRaw) {
      final id = e['id'];
      if (id == null) continue;
      final index = _allTracks.indexWhere((t) => t.id == id);
      if (index < 0) continue;
      result.add(_allTracks[index]);
    }
    return result;
  }

  bool isNotNow(int id) => _notNowRaw.any((e) => e['id'] == id);

  void _expireNotNow() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final before = _notNowRaw.length;
    _notNowRaw.removeWhere((e) => (now - (e['ts'] ?? 0)) > _notNowExpiryMs);
    if (_notNowRaw.length != before) {
      _prefs?.setString('not_now', jsonEncode(_notNowRaw));
    }
  }

  void toggleNotNow(AudioTrack track) {
    _expireNotNow();
    final index = _notNowRaw.indexWhere((e) => e['id'] == track.id);
    if (index >= 0) {
      _notNowRaw.removeAt(index);
    } else {
      _notNowRaw.insert(
        0,
        {'id': track.id, 'ts': DateTime.now().millisecondsSinceEpoch},
      );
      if (_notNowRaw.length > 200) {
        _notNowRaw.removeRange(200, _notNowRaw.length);
      }
    }
    _prefs?.setString('not_now', jsonEncode(_notNowRaw));
    notifyListeners();
  }

  // ─── Listening Context ─────────────────────────────────────────────
  Set<ListeningContext> get activeContexts => Set.unmodifiable(_activeContexts);

  bool isContextActive(ListeningContext c) => _activeContexts.contains(c);

  void toggleContext(ListeningContext value) {
    if (value == ListeningContext.balanced) {
      _activeContexts = {ListeningContext.balanced};
    } else {
      _activeContexts.remove(ListeningContext.balanced);
      if (!_activeContexts.remove(value)) {
        _activeContexts.add(value);
      }
      if (_activeContexts.isEmpty) {
        _activeContexts.add(ListeningContext.balanced);
      }
    }
    _prefs?.setString(
      'listening_context',
      _activeContexts.map((e) => e.name).join(','),
    );
    notifyListeners();
  }

  // ─── Skip learning ─────────────────────────────────────────────────
  int skipCountFor(int id) => _skipCount[id] ?? 0;

  void _recordSkip(int id) {
    _skipCount[id] = (_skipCount[id] ?? 0) + 1;
    _prefs?.setString(
      'skip_counts',
      jsonEncode(_skipCount.map((k, v) => MapEntry('$k', v))),
    );
  }

  // ─── DJ Options ────────────────────────────────────────────────────
  bool get deepCuts => _deepCuts;

  void setDeepCuts(bool value) {
    _deepCuts = value;
    _prefs?.setBool('dj_deep_cuts', value);
    notifyListeners();
  }

  DiscoveryLevel get discoveryLevel => _discoveryLevel;

  void setDiscoveryLevel(DiscoveryLevel value) {
    _discoveryLevel = value;
    _prefs?.setString('dj_discovery', value.name);
    notifyListeners();
  }

  // ─── Music Bookmarks (закладки внутри трека) ──────────────────────
  List<int> bookmarksFor(int trackId) {
    final list = _bookmarks[trackId];
    if (list == null) return const [];
    final copy = List<int>.from(list);
    copy.sort();
    return copy;
  }

  void toggleBookmark(int trackId, int positionMs) {
    final list = _bookmarks[trackId] ??= [];
    if (list.contains(positionMs)) {
      list.remove(positionMs);
    } else {
      list.add(positionMs);
    }
    if (list.isEmpty) {
      _bookmarks.remove(trackId);
    }
    _persistBookmarks();
    notifyListeners();
  }

  void removeBookmark(int trackId, int positionMs) {
    final list = _bookmarks[trackId];
    if (list == null) return;
    list.remove(positionMs);
    if (list.isEmpty) {
      _bookmarks.remove(trackId);
    }
    _persistBookmarks();
    notifyListeners();
  }

  void _persistBookmarks() {
    final map = <String, dynamic>{};
    _bookmarks.forEach((id, list) {
      map[id.toString()] = list;
    });
    _prefs?.setString('bookmarks', jsonEncode(map));
  }

  List<({AudioTrack track, int positionMs})> get allBookmarks {
    final result = <({AudioTrack track, int positionMs})>[];
    _bookmarks.forEach((id, list) {
      final index = _allTracks.indexWhere((t) => t.id == id);
      if (index < 0) return;
      final track = _allTracks[index];
      for (final ms in list) {
        result.add((track: track, positionMs: ms));
      }
    });
    result.sort((a, b) => b.positionMs - a.positionMs);
    return result;
  }

  // ─── Music DNA ─────────────────────────────────────────────────────
  List<({AudioTrack track, int plays})> topTracks({int limit = 5}) {
    final counts = <int, int>{};
    for (final e in _historyRaw) {
      final id = e['id'];
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = <({AudioTrack track, int plays})>[];
    for (final e in ranked) {
      final index = _allTracks.indexWhere((t) => t.id == e.key);
      if (index < 0) continue;
      result.add((track: _allTracks[index], plays: e.value));
      if (result.length >= limit) break;
    }
    return result;
  }

  List<({String artist, int plays})> topArtists({int limit = 5}) {
    final counts = <String, int>{};
    for (final e in _historyRaw) {
      final id = e['id'];
      if (id == null) continue;
      final index = _allTracks.indexWhere((t) => t.id == id);
      if (index < 0) continue;
      final artist = _allTracks[index].artist;
      counts[artist] = (counts[artist] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(limit).map((e) => (artist: e.key, plays: e.value)).toList();
  }

  int get totalPlays => _historyRaw.length;

  Duration get totalListeningTime {
    var ms = 0;
    for (final e in _historyRaw) {
      final id = e['id'];
      if (id == null) continue;
      final index = _allTracks.indexWhere((t) => t.id == id);
      if (index >= 0) ms += _allTracks[index].duration;
    }
    return Duration(milliseconds: ms);
  }

  int get uniqueTracksListened {
    final set = <int>{};
    for (final e in _historyRaw) {
      final id = e['id'];
      if (id != null) set.add(id);
    }
    return set.length;
  }

  ({int morning, int day, int evening}) listeningTimeProfile {
    var morning = 0, day = 0, evening = 0;
    for (final e in _historyRaw) {
      final ts = e['ts'];
      if (ts == null) continue;
      final h = DateTime.fromMillisecondsSinceEpoch(ts).hour;
      if (h < 12) {
        morning++;
      } else if (h < 18) {
        day++;
      } else {
        evening++;
      }
    }
    return (morning: morning, day: day, evening: evening);
  }

  // ─── Music Time Machine ────────────────────────────────────────────
  List<({AudioTrack track, DateTime time})> tracksForDay(DateTime day) {
    final result = <({AudioTrack track, DateTime time})>[];
    for (final e in _historyRaw) {
      final id = e['id'];
      final ts = e['ts'];
      if (id == null || ts == null) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      if (dt.year != day.year || dt.month != day.month || dt.day != day.day) {
        continue;
      }
      final index = _allTracks.indexWhere((t) => t.id == id);
      if (index < 0) continue;
      result.add((track: _allTracks[index], time: dt));
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  // ─── Explain Recommendation ────────────────────────────────────────
  Map<String, double> trackScoreBreakdown(AudioTrack t) {
    final out = <String, double>{};

    final hasEnergy = _activeContexts.any(
        (c) => c == ListeningContext.energy || c == ListeningContext.party);
    final hasCalm = _activeContexts
        .any((c) => c == ListeningContext.calm || c == ListeningContext.focus);
    final favWeight = hasEnergy ? 1.6 : (hasCalm ? 1.25 : 1.0);

    final n = _historyRaw.length;
    final favSet = _favoriteIds.toSet();

    if (favSet.contains(t.id)) {
      out['Избранное'] = 45 * favWeight;
    }

    if (t.artist == currentTrack?.artist) {
      out['Похоже на текущего'] = 18;
    }

    var affinity = 0.0;
    var lastSeen = -1;
    for (var i = 0; i < n; i++) {
      final id = _historyRaw[i]['id'];
      if (id == null) continue;
      if (id == t.id) lastSeen = i;
      final index = _allTracks.indexWhere((tt) => tt.id == id);
      if (index < 0) continue;
      final artist = _allTracks[index].artist;
      if (artist == t.artist) {
        affinity += math.pow(0.88, i).toDouble();
      }
    }
    if (affinity > 0) {
      out['Любимый исполнитель'] = math.min(16.0, affinity) * 1.3;
    }

    if (lastSeen >= 0) {
      final since = n - 1 - lastSeen;
      if (since < 10) {
        out['Играл недавно'] = -45 * math.exp(-since / 2.2);
      }
    }

    final skips = _skipCount[t.id] ?? 0;
    if (skips > 0) {
      out['Скипали'] = -math.min(30.0, skips * 12);
    }

    if (currentTrack != null &&
        t.album == currentTrack!.album &&
        t.id != currentTrack!.id) {
      out['С альбома текущего'] = 10;
    }

    var playCount = 0;
    for (final e in _historyRaw) {
      if (e['id'] == t.id) playCount++;
    }
    if (_deepCuts) {
      out['Deep Cuts'] = (1 - math.min(1.0, playCount / 8)) * 30;
    }

    var artistPlays = 0;
    for (final e in _historyRaw) {
      final id = e['id'];
      if (id == null) continue;
      final index = _allTracks.indexWhere((tt) => tt.id == id);
      if (index >= 0 && _allTracks[index].artist == t.artist) artistPlays++;
    }
    final known = math.min(1.0, artistPlays / 10);
    final discoveryF = _discoveryLevel.factor;
    if (discoveryF < 0.5) {
      if (known > 0) out['Знакомый стиль'] = known * (1 - discoveryF) * 20;
    } else {
      if (known < 1) out['Новый для тебя'] = (1 - known) * discoveryF * 20;
    }

    if (hasEnergy && t.duration > 0 && t.duration < 3 * 60 * 1000) {
      out['Короткий, под энергию'] = 12;
    }
    if (hasCalm && t.duration >= 3 * 60 * 1000) {
      out['Длинный, для спокойствия'] = 12;
    }

    out.removeWhere((_, v) => v == 0);
    return out;
  }

  // ─── Personal DJ / Smart Queue ─────────────────────────────────────
  List<AudioTrack> buildSmartQueue({int count = 60}) {
    _expireNotNow();
    final pool = visibleTracks
        .where((t) => !isNotNow(t.id))
        .toList();
    if (pool.isEmpty) return const [];

    final playCount = <int, int>{};
    final artistPlayCount = <String, int>{};
    for (final e in _historyRaw) {
      final id = e['id'];
      if (id == null) continue;
      playCount[id] = (playCount[id] ?? 0) + 1;
      final index = _allTracks.indexWhere((t) => t.id == id);
      if (index >= 0) {
        final artist = _allTracks[index].artist;
        artistPlayCount[artist] = (artistPlayCount[artist] ?? 0) + 1;
      }
    }

    final n = _historyRaw.length;
    final lastSeen = <int, int>{};
    final artistAffinity = <String, double>{};
    for (var i = 0; i < n; i++) {
      final id = _historyRaw[i]['id'];
      if (id == null) continue;
      lastSeen[id] = i;
      final index = _allTracks.indexWhere((t) => t.id == id);
      if (index < 0) continue;
      final artist = _allTracks[index].artist;
      final age = i; // 0 = самый свежий
      final w = math.pow(0.88, age).toDouble();
      artistAffinity[artist] = (artistAffinity[artist] ?? 0) + w;
    }

    final currentArtist = currentTrack?.artist;
    final favSet = _favoriteIds.toSet();
    final queue = <AudioTrack>[];
    final used = <int>{};
    final usedArtistCount = <String, int>{};
    int seed = DateTime.now().millisecondsSinceEpoch;

    final hasEnergy = _activeContexts.any(
        (c) => c == ListeningContext.energy || c == ListeningContext.party);
    final hasCalm = _activeContexts
        .any((c) => c == ListeningContext.calm || c == ListeningContext.focus);
    final favWeight = hasEnergy ? 1.6 : (hasCalm ? 1.25 : 1.0);

    final discoveryF = _discoveryLevel.factor;

    int _nextRand() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }

    while (queue.length < count && used.length < pool.length) {
      AudioTrack? best;
      double bestScore = -1e9;

      for (final t in pool) {
        if (used.contains(t.id)) continue;

        double score = 0;
        if (favSet.contains(t.id)) score += 45 * favWeight;
        if (t.artist == currentArtist) score += 18;

        final affinity = artistAffinity[t.artist] ?? 0;
        score += math.min(16.0, affinity) * 1.3;

        final lastI = lastSeen[t.id];
        if (lastI != null) {
          final since = n - 1 - lastI; // сколько треков назад играл
          if (since < 10) {
            score -= 45 * math.exp(-since / 2.2);
          }
        }

        score -= math.min(30.0, (_skipCount[t.id] ?? 0) * 12);

        final artistCount = usedArtistCount[t.artist] ?? 0;
        score -= artistCount * 34;

        final sameAlbum =
            currentTrack != null && t.album == currentTrack!.album && t.id != currentTrack!.id;
        if (sameAlbum) score += 10;

        if (queue.contains(t)) score -= 40;

        if (t.isFavorite) score += 8;
        if (t.id == currentTrack?.id) score -= 50;

        final pc = playCount[t.id] ?? 0;
        if (_deepCuts) {
          score += (1 - math.min(1.0, pc / 8)) * 30;
        }

        final apc = artistPlayCount[t.artist] ?? 0;
        final known = math.min(1.0, apc / 10);
        if (discoveryF < 0.5) {
          score += known * (1 - discoveryF) * 20;
        } else {
          score += (1 - known) * discoveryF * 20;
        }

        if (hasEnergy &&
            t.duration > 0 &&
            t.duration < 3 * 60 * 1000) {
          score += 12;
        }
        if (hasCalm && t.duration >= 3 * 60 * 1000) {
          score += 12;
        }

        score += (_nextRand() % 400) / 100.0;

        if (score > bestScore) {
          bestScore = score;
          best = t;
        }
      }

      if (best == null) break;
      used.add(best.id);
      queue.add(best);
      usedArtistCount[best.artist] = (usedArtistCount[best.artist] ?? 0) + 1;
    }

    return queue;
  }

  Future<void> launchPersonalDJ({int count = 60}) async {
    final queue = buildSmartQueue(count: count);
    if (queue.isEmpty) return;
    await playFromPlaylist(queue, 0);
  }

  // ─── Queue Snapshots ───────────────────────────────────────────────
  List<QueueSnapshot> get queueSnapshots =>
      List.unmodifiable(_queueSnapshots);

  void _persistSnapshots() {
    _prefs?.setString(
      'queue_snapshots',
      jsonEncode(_queueSnapshots.map((s) => s.toJson()).toList()),
    );
  }

  void saveQueueSnapshot(String name) {
    if (_playlist.isEmpty) return;
    _queueSnapshots.removeWhere((s) => s.name == name);
    _queueSnapshots.insert(
      0,
      QueueSnapshot(
        name: name,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        trackIds: _playlist.map((t) => t.id).toList(),
      ),
    );
    if (_queueSnapshots.length > 20) {
      _queueSnapshots.removeRange(20, _queueSnapshots.length);
    }
    _persistSnapshots();
    notifyListeners();
  }

  void deleteQueueSnapshot(String name) {
    _queueSnapshots.removeWhere((s) => s.name == name);
    _persistSnapshots();
    notifyListeners();
  }

  Future<void> applyQueueSnapshot(QueueSnapshot snapshot) async {
    final tracks = <AudioTrack>[];
    for (final id in snapshot.trackIds) {
      final index = _allTracks.indexWhere((t) => t.id == id);
      if (index >= 0) tracks.add(_allTracks[index]);
    }
    if (tracks.isEmpty) return;
    await playFromPlaylist(tracks, 0);
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

  String? _folderPathOf(AudioTrack t) {
    final d = t.data;
    if (d == null || d.isEmpty) return null;
    final idx = d.lastIndexOf('/');
    if (idx <= 0) return null;
    return d.substring(0, idx);
  }

  List<String> get folders {
    final set = <String>{};
    for (final t in visibleTracks) {
      final f = _folderPathOf(t);
      if (f != null) set.add(f);
    }
    return set.toList()..sort();
  }

  List<AudioTrack> tracksInFolder(String folder) =>
      visibleTracks.where((t) => _folderPathOf(t) == folder).toList();

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
    await _prepareInitialPlaylist();
  }

  Future<void> _prepareInitialPlaylist() async {
    if (_playlist.isNotEmpty) return;
    if (_allTracks.isEmpty) return;

    List<AudioTrack> initial;
    final firstAlbum = _allTracks.first.album;
    if (firstAlbum != null) {
      initial = _allTracks.where((t) => t.album == firstAlbum).toList();
    } else {
      initial = List<AudioTrack>.from(_allTracks);
    }
    if (initial.isEmpty) return;

    _playlist = initial;
    _currentIndex = 0;
    await _audioPlayer.setAudioSources(
      _playlist.map((t) => AudioSource.uri(Uri.parse(t.uri))).toList(),
    );
    await _audioPlayer.seek(Duration.zero, index: 0);
    _audioHandler?.setQueue(_playlist);
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

  int _urlCounter = 0;

  Future<void> playUrl(String url, {String? title}) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    _urlCounter += 1;
    final track = AudioTrack(
      id: -(_urlCounter),
      title: (title == null || title.isEmpty)
          ? trimmed.split('/').last
          : title,
      artist: 'Stream',
      uri: trimmed,
      duration: 0,
    );
    await playFromPlaylist([track], 0);
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

    final cur = currentTrack;
    if (cur != null && _isPlaying && _position.inMilliseconds < 25000) {
      _recordSkip(cur.id);
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

    final cur = currentTrack;
    if (cur != null && _isPlaying && _position.inMilliseconds < 25000) {
      _recordSkip(cur.id);
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

  static const Map<String, List<double>> _eqPresetGains = {
    'Flat (Стандарт)': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'X-Bass': [9, 7, 5, 3, 1, 0, 0, 0, 0, 0],
    'Bass Boost': [8, 7, 5, 3, 1, 0, 0, 0, 0, 0],
    'Treble Boost': [0, 0, 0, 0, 0, 1, 3, 5, 7, 8],
    'X-Wide': [2, 3, 4, 3, 0, 0, 3, 4, 3, 2],
    'Reverb': [2, 2, 1, 0, 0, 0, 0, 1, 1, 2],
    'Rock': [5, 4, 2, 1, 0, -1, 1, 2, 4, 5],
    'Pop': [-1, 1, 3, 4, 5, 4, 2, 0, -1, -2],
    'Jazz': [4, 3, 1, 1, 0, -1, 0, 1, 3, 4],
    'Classical': [5, 4, 3, 2, 1, 0, 0, 1, 2, 3],
    'Electronic': [6, 5, 2, 0, -1, 1, 3, 5, 6, 5],
    'Hip-Hop': [7, 6, 4, 2, 1, 0, 0, 1, 2, 3],
    'Acoustic': [3, 2, 1, 1, 0, 0, 1, 2, 2, 1],
    'Dance': [6, 5, 3, 2, 1, 0, 1, 2, 3, 4],
    'Bass & Treble': [8, 6, 4, 2, 0, -2, 0, 2, 4, 6],
    'Vocal Clarity': [0, -1, 0, 2, 4, 5, 4, 2, 1, 0],
    'Classic Rock': [6, 5, 4, 2, 1, 0, 1, 2, 3, 4],
    'Soft Rock': [3, 2, 1, 0, 0, 1, 2, 2, 1, 1],
    'Reggae': [3, 2, 0, 0, 2, 3, 2, 1, 1, 0],
    'Soul': [3, 2, 1, 0, 0, 1, 2, 3, 3, 2],
    'Country': [2, 2, 1, 1, 0, 0, 1, 2, 2, 1],
    'Lounge': [0, 0, 1, 2, 2, 1, 0, 0, 0, 0],
    'Piano': [4, 3, 2, 1, 0, 0, 1, 2, 2, 1],
    'Opera': [4, 3, 2, 0, -1, 0, 2, 3, 4, 5],
  };

  static List<double> eqGainsFor(String name) =>
      List.from(_eqPresetGains[name] ?? const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

  static List<double> _resampleGains(List<double> gains, int count) {
    if (count == gains.length) return List.from(gains);
    if (count <= 0) return const [];
    if (gains.isEmpty) return List.filled(count, 0);
    if (count == 1) return [gains[gains.length ~/ 2]];
    final result = <double>[];
    for (var i = 0; i < count; i++) {
      final pos = (gains.length - 1) * i / (count - 1);
      final low = pos.floor();
      final high = (low + 1).clamp(0, gains.length - 1);
      final frac = pos - low;
      result.add(gains[low] + (gains[high] - gains[low]) * frac);
    }
    return result;
  }

  Future<void> _applyEqualizerPreset(String name) async {
    try {
      final gains = _eqPresetGains[name] ??
          _eqPresetGains['Flat (Стандарт)'] ??
          const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      final params = await _equalizer.parameters;
      final bands = params.bands;
      final target = _resampleGains(gains, bands.length);
      for (var i = 0; i < bands.length; i++) {
        final clamped = target[i]
            .clamp(params.minDecibels, params.maxDecibels)
            .toDouble();
        await bands[i].setGain(clamped);
      }
      await _equalizer.setEnabled(true);
    } catch (_) {}
  }

  void setEqualizerPreset(String name) {
    _equalizerPreset = name;
    _prefs?.setString('eq_preset', name);
    _applyEqualizerPreset(name);
    notifyListeners();
  }

  void toggleXBoost() {
    _xBoost = !_xBoost;
    if (_xBoost) {
      _loudness.setEnabled(true);
      _loudness.setTargetGain(6.0);
    } else {
      _loudness.setEnabled(false);
    }
    notifyListeners();
  }

  void tapRepeatAB() {
    if (_repeatA == null) {
      _repeatA = _position;
      _repeatB = null;
    } else if (_repeatB == null) {
      if (_position > _repeatA!) {
        _repeatB = _position;
      } else {
        _repeatA = null;
      }
    } else {
      _repeatA = null;
      _repeatB = null;
    }
    notifyListeners();
  }

  void clearRepeatAB() {
    _repeatA = null;
    _repeatB = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}