import 'dart:async';

import 'package:flutter/services.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

import '../models/audio_track.dart';
import '../providers/player_provider.dart';

/// Пушит состояние плеера в нативные виджеты рабочего стола
/// (small/large) через MethodChannel «neonwave/widgets».
class WidgetService {
  static const _channel = MethodChannel('neonwave/widgets');
  static final OnAudioQuery _query = OnAudioQuery();

  static int? _lastTrackId;
  static bool? _lastPlaying;
  static bool _busy = false;
  static Timer? _debounce;

  static void playerChanged(PlayerProvider p) {
    final track = p.currentTrack;
    final tid = track?.id;
    final playing = p.isPlaying;
    if (tid == _lastTrackId && playing == _lastPlaying) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _push(p, track, playing);
    });
  }

  static Future<void> _push(
      PlayerProvider p, AudioTrack? track, bool playing) async {
    if (_busy) return;
    _busy = true;
    try {
      List<int>? artBytes;
      if (track != null) {
        try {
          artBytes = await _query.queryArtwork(
            track.id,
            ArtworkType.AUDIO,
            format: ArtworkFormat.PNG,
            size: 256,
          );
        } catch (_) {}
      }
      await _channel.invokeMethod('update', {
        'title': track?.title ?? 'NeonWave',
        'artist': track?.artist ?? 'Откройте плеер',
        'playing': playing,
        'artBytes': artBytes,
      });
      _lastTrackId = track?.id;
      _lastPlaying = playing;
    } catch (_) {
      // виджетов нет / канал недоступен — молча пропускаем
    } finally {
      _busy = false;
    }
  }
}
