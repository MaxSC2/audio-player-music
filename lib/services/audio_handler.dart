import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audio_track.dart';

class PlayerAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;
  final VoidCallback onToggleRepeat;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleFavorite;
  List<AudioTrack> _queueTracks = [];
  bool _shuffleOn = false;
  bool _favoriteOn = false;
  int _repeat = 0;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final Map<int, String> _artPaths = {};

  PlayerAudioHandler(
    this.player, {
    required this.onToggleRepeat,
    required this.onToggleShuffle,
    required this.onToggleFavorite,
  }) {
    _listen();
  }

  PlaybackState get _state => playbackState.value;

  final List<String> debugLog = [];

  void _log(String msg) {
    final t = DateTime.now();
    final ts = '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.'
        '${t.millisecond.toString().padLeft(3, '0')}';
    debugLog.insert(0, '$ts $msg');
    if (debugLog.length > 60) debugLog.removeLast();
  }

  String _controlsSummary(List<MediaControl> c) => c
      .map((m) => '${m.label}(${m.action.name}'
          '${m.customAction != null ? '/c:${m.customAction!.name}' : ''})')
      .join(' ');

  String get diagnostics {
    try {
      final s = _state;
      return 'playing=${s.playing} processing=${s.processingState}\n'
          'controls=[${_controlsSummary(s.controls)}]\n'
          'systemActions=${s.systemActions?.map((a) => a.name).join(',')}\n'
          'repeat=${s.repeatMode} shuffle=${s.shuffleMode}\n'
          'compact=${s.androidCompactActionIndices}';
    } catch (e) {
      return 'ошибка диагностики: $e';
    }
  }

  String get _shuffleIcon => _shuffleOn
      ? 'drawable/ic_action_shuffle'
      : 'drawable/ic_action_shuffle_off';

  String get _repeatIcon {
    switch (_repeat) {
      case 1:
        return 'drawable/ic_action_repeat';
      case 2:
        return 'drawable/ic_action_repeat_one';
      default:
        return 'drawable/ic_action_repeat_off';
    }
  }

  String get _favoriteIcon => _favoriteOn
      ? 'drawable/ic_action_favorite'
      : 'drawable/ic_action_favorite_off';

  AudioServiceRepeatMode get _repeatServiceMode {
    switch (_repeat) {
      case 1:
        return AudioServiceRepeatMode.all;
      case 2:
        return AudioServiceRepeatMode.one;
      default:
        return AudioServiceRepeatMode.none;
    }
  }

  static const Set<MediaAction> _systemActions = {
    MediaAction.seek,
    MediaAction.setShuffleMode,
    MediaAction.setRepeatMode,
  };

  void setShuffleState(bool on) {
    _shuffleOn = on;
    final state = _state.copyWith(
      controls: _buildControls(_state.playing),
      systemActions: _systemActions,
      repeatMode: _repeatServiceMode,
      shuffleMode:
          on ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
    _log('SHUFFLE=$on controls=[${_controlsSummary(state.controls)}]');
    playbackState.add(state);
  }

  void setFavoriteState(bool on) {
    _favoriteOn = on;
    final state = _state.copyWith(
      controls: _buildControls(_state.playing),
    );
    _log('FAVORITE=$on controls=[${_controlsSummary(state.controls)}]');
    playbackState.add(state);
  }

  void setRepeatState(int mode) {
    _repeat = mode;
    final state = _state.copyWith(
      controls: _buildControls(_state.playing),
      systemActions: _systemActions,
      repeatMode: _repeatServiceMode,
      shuffleMode:
          _shuffleOn ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
    _log('REPEAT=$mode controls=[${_controlsSummary(state.controls)}]');
    playbackState.add(state);
  }

  List<MediaControl> _buildControls(bool playing) => [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ];

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'shuffle':
        onToggleShuffle();
      case 'favorite':
        onToggleFavorite();
      case 'repeat':
        onToggleRepeat();
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    onToggleShuffle();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    onToggleRepeat();
  }

  MediaItem _toMediaItem(AudioTrack track) {
    final artPath = _artPaths[track.id];
    return MediaItem(
      id: track.id.toString(),
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: Duration(milliseconds: track.duration),
      artUri: artPath != null ? Uri.file(artPath) : null,
    );
  }

  Future<void> _attachArt(AudioTrack track) async {
    if (_artPaths.containsKey(track.id)) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/neonwave_art_${track.id}.png');
      if (await file.exists()) {
        _artPaths[track.id] = file.path;
      } else {
        final bytes = await _audioQuery.queryArtwork(
          track.id,
          ArtworkType.AUDIO,
          format: ArtworkFormat.PNG,
          size: 512,
        );
        if (bytes == null) return;
        await file.writeAsBytes(bytes, flush: true);
        _artPaths[track.id] = file.path;
      }
      final idx = player.currentIndex;
      if (idx != null &&
          idx >= 0 &&
          idx < _queueTracks.length &&
          _queueTracks[idx].id == track.id) {
        mediaItem.add(_toMediaItem(track));
      }
    } catch (_) {}
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() => player.seekToNext();

  @override
  Future<void> skipToPrevious() => player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) =>
      player.seek(Duration.zero, index: index);

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  void setQueue(List<AudioTrack> tracks) {
    _queueTracks = List.of(tracks);
    queue.add(_queueTracks.map(_toMediaItem).toList());
    playbackState.add(_state.copyWith(queueIndex: player.currentIndex));
  }

  void _listen() {
    player.positionStream.listen((p) {
      playbackState.add(_state.copyWith(
        updatePosition: p,
        bufferedPosition: player.bufferedPosition,
      ));
    });

    player.playingStream.listen((playing) {
      final state = _state.copyWith(
        playing: playing,
        controls: _buildControls(playing),
        systemActions: _systemActions,
        androidCompactActionIndices: null,
        processingState: _mapProcessing(player.processingState),
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        repeatMode: _repeatServiceMode,
        shuffleMode: _shuffleOn
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        queueIndex: player.currentIndex,
      );
      _log('PUBLISH playing=$playing processing=${state.processingState} '
          'controls=[${_controlsSummary(state.controls)}] '
          'sys=${state.systemActions?.map((a) => a.name).join(',')} '
          'repeat=${state.repeatMode} shuffle=${state.shuffleMode} '
          'compact=${state.androidCompactActionIndices}');
      playbackState.add(state);
    });

    player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _queueTracks.length) {
        final track = _queueTracks[index];
        mediaItem.add(_toMediaItem(track));
        unawaited(_attachArt(track));
      }
      playbackState.add(_state.copyWith(queueIndex: index));
    });
  }

  AudioProcessingState _mapProcessing(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}