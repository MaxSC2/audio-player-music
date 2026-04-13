import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_track.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<AudioTrack> _playlist = [];
  int _currentIndex = -1;
  bool _isLoading = false;
  String? _error;

  AudioPlayer get audioPlayer => _audioPlayer;
  List<AudioTrack> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AudioTrack? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;

  bool get isPlaying => _audioPlayer.playing;

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  PlayerProvider() {
    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && index != _currentIndex) {
        _currentIndex = index;
        notifyListeners();
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playNext();
      }
    });
  }

  void setPlaylist(List<AudioTrack> tracks, {int startIndex = 0}) {
    _playlist = tracks;
    _currentIndex = startIndex;
    notifyListeners();
  }

  Future<void> playTrack(AudioTrack track) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final index = _playlist.indexWhere((t) => t.id == track.id);
      if (index != -1) {
        _currentIndex = index;
      }

      await _audioPlayer.setUrl(track.uri);
      await _audioPlayer.play();
    } catch (e) {
      _error = 'Не удалось воспроизвести: ${track.title}';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> play() async {
    await _audioPlayer.play();
    notifyListeners();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> _playNext() async {
    if (_playlist.isEmpty) return;
    final nextIndex = (_currentIndex + 1) % _playlist.length;
    await playTrack(_playlist[nextIndex]);
  }

  Future<void> _playPrev() async {
    if (_playlist.isEmpty) return;
    final prevIndex =
        (_currentIndex - 1 + _playlist.length) % _playlist.length;
    await playTrack(_playlist[prevIndex]);
  }

  Future<void> next() async {
    await _playNext();
  }

  Future<void> previous() async {
    await _playPrev();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
