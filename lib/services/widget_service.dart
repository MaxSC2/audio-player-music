import 'dart:async';

import 'package:flutter/services.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

import '../models/audio_track.dart';
import '../providers/player_provider.dart';

/// Пушит состояние плеера в нативные виджеты рабочего стола
/// (small/large) через MethodChannel «neonwave/widgets».
/// Также принимает от виджетов команды favorite/shuffle/repeat,
/// если приложение живо (иначе нативная сторона открывает приложение).
class WidgetService {
  static const _channel = MethodChannel('neonwave/widgets');
  static final OnAudioQuery _query = OnAudioQuery();

  static final Map<int, List<int>> _artCache = {};

  static int? _lastTrackId;
  static bool? _lastPlaying;
  static bool? _lastFav;
  static bool? _lastShuffle;
  static int? _lastRepeat;
  static bool _busy = false;
  static Timer? _debounce;

  static PlayerProvider? _player;

  /// Регистрирует обработчик команд от виджетов. Вызывать один раз в main().
  static void bind(PlayerProvider player) {
    _player = player;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'widgetAction') {
        final action = call.arguments as String?;
        switch (action) {
          case 'neonwave.widget.FAVORITE':
            player.toggleFavoriteCurrent();
          case 'neonwave.widget.SHUFFLE':
            await player.toggleShuffle();
          case 'neonwave.widget.REPEAT':
            player.toggleRepeat();
        }
        push(player, force: true);
      }
    });
    // Первичное заполнение виджетов текущим состоянием
    Future.microtask(() => push(player, force: true));
  }

  static void playerChanged(PlayerProvider p) => push(p);

  static void push(PlayerProvider p, {bool force = false}) {
    final track = p.currentTrack;
    final tid = track?.id;
    final playing = p.isPlaying;
    final fav = track != null && p.isFavorite(track.id);
    final shuffle = p.shuffleMode;
    final repeat = p.repeatMode.index;

    if (!force &&
        tid == _lastTrackId &&
        playing == _lastPlaying &&
        fav == _lastFav &&
        shuffle == _lastShuffle &&
        repeat == _lastRepeat) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      _push(p, track, playing, fav, shuffle, repeat);
    });
  }

  static Future<void> _push(
    PlayerProvider p,
    AudioTrack? track,
    bool playing,
    bool fav,
    bool shuffle,
    int repeat,
  ) async {
    if (_busy) return;
    _busy = true;
    try {
      List<int>? artBytes;
      final tid = track?.id;
      if (tid != null) {
        if (_artCache.containsKey(tid)) {
          artBytes = _artCache[tid];
        } else {
          try {
            artBytes = await _query.queryArtwork(
              tid,
              ArtworkType.AUDIO,
              format: ArtworkFormat.PNG,
              size: 256,
            );
            if (artBytes != null) _artCache[tid] = artBytes;
          } catch (_) {}
        }
      }
      await _channel.invokeMethod('update', {
        'title': track?.title ?? 'NeonWave',
        'artist': track?.artist ?? 'Откройте плеер',
        'playing': playing,
        'favorite': fav,
        'shuffle': shuffle,
        'repeat': repeat,
        'artBytes': artBytes,
      });
      _lastTrackId = tid;
      _lastPlaying = playing;
      _lastFav = fav;
      _lastShuffle = shuffle;
      _lastRepeat = repeat;
    } catch (_) {
      // виджетов нет / канал недоступен — молча пропускаем
    } finally {
      _busy = false;
    }
  }

  static void invalidateArt(int trackId) => _artCache.remove(trackId);
}
