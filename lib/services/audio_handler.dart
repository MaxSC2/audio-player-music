import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../models/audio_track.dart';

class PlayerAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;
  final VoidCallback onToggleRepeat;
  final VoidCallback onToggleShuffle;
  List<AudioTrack> _queueTracks = [];
  bool _shuffleOn = false;
  RepeatMode _repeat = RepeatMode.off;

  PlayerAudioHandler(
    this.player, {
    required this.onToggleRepeat,
    required this.onToggleShuffle,
  }) {
    _listen();
  }

  PlaybackState get _state => playbackState.value;

  String get _shuffleIcon => _shuffleOn
      ? 'drawable/ic_action_shuffle'
      : 'drawable/ic_action_shuffle_off';

  String get _repeatIcon {
    switch (_repeat) {
      case RepeatMode.all:
        return 'drawable/ic_action_repeat';
      case RepeatMode.one:
        return 'drawable/ic_action_repeat_one';
      case RepeatMode.off:
        return 'drawable/ic_action_repeat_off';
    }
  }

  void setShuffleState(bool on) {
    _shuffleOn = on;
    playbackState.add(_state.copyWith(
      controls: _buildControls(_state.playing),
    ));
  }

  void setRepeatState(RepeatMode mode) {
    _repeat = mode;
    playbackState.add(_state.copyWith(
      controls: _buildControls(_state.playing),
    ));
  }

  List<MediaControl> _buildControls(bool playing) => [
        MediaControl.custom(
          androidIcon: _shuffleIcon,
          label: 'Перемешать',
          name: 'shuffle',
        ),
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.custom(
          androidIcon: _repeatIcon,
          label: 'Повтор',
          name: 'repeat',
        ),
      ];

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'shuffle':
        onToggleShuffle();
      case 'repeat':
        onToggleRepeat();
    }
  }

  MediaItem _toMediaItem(AudioTrack track) {
    return MediaItem(
      id: track.id.toString(),
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: Duration(milliseconds: track.duration),
    );
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
      playbackState.add(_state.copyWith(
        playing: playing,
        controls: _buildControls(playing),
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [1, 2, 3],
        processingState: _mapProcessing(player.processingState),
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: player.currentIndex,
      ));
    });

    player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _queueTracks.length) {
        mediaItem.add(_toMediaItem(_queueTracks[index]));
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