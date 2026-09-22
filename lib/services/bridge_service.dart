import 'package:flutter/services.dart';

import '../models/audio_track.dart';
import '../providers/player_provider.dart';

/// Мост Mini-UNA → NeonWave: автовоспроизведение по внешней команде
/// с возвратом обратно в вызывающее приложение (SystemNavigator.pop).
class BridgeService {
  static const _channel = MethodChannel('neonwave/bridge');
  static bool _ready = false;

  static Future<void> init(PlayerProvider player) async {
    if (_ready) return;
    _ready = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'autoplay') {
        await _autoplay(player, _args(call.arguments));
      }
    });
    try {
      final pending =
          await _channel.invokeMapMethod<String, dynamic>('getPendingAutoplay');
      if (pending != null) await _autoplay(player, pending);
    } catch (_) {}
  }

  static Map<String, dynamic> _args(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static Future<void> _autoplay(
      PlayerProvider player, Map<String, dynamic> args) async {
    try {
      // Ждём библиотеку (холодный старт): до ~8 секунд.
      for (var i = 0; i < 16; i++) {
        if (player.visibleTracks.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final playlistName = (args['playlist'] as String?)?.trim() ?? '';
      var started = false;
      if (playlistName.isNotEmpty) {
        final match = player.playlists.where(
          (p) => p.name.toLowerCase().contains(playlistName.toLowerCase()),
        );
        if (match.isNotEmpty) {
          final byId = {for (final t in player.visibleTracks) t.id: t};
          final tracks = <AudioTrack>[];
          for (final id in match.first.trackIds) {
            final t = byId[id];
            if (t != null) tracks.add(t);
          }
          if (tracks.isNotEmpty) {
            await player.playFromPlaylist(tracks, 0);
            started = true;
          }
        }
      }
      if (!started) {
        if (player.smartRecentlyPlayed.isNotEmpty) {
          await player.playTrack(player.smartRecentlyPlayed.first);
        } else if (player.visibleTracks.isNotEmpty) {
          await player.playTrack(player.visibleTracks.first);
        } else {
          return; // Нечего играть — молча остаёмся.
        }
      }

      // Даём звуку стартовать и возвращаемся в Mini-UNA.
      await Future.delayed(const Duration(milliseconds: 900));
      await SystemNavigator.pop();
    } catch (_) {}
  }
}
