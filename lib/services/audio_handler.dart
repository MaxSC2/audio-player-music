import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_track.dart';

class PlayerAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;
  List<AudioTrack> _queueTracks = [];

  PlayerAudioHandler(this.player) {
    _listen();
  }

  PlaybackState get _state => playbackState.value;

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
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
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