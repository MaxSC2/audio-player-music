import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Живой аудио-визуализатор: получает РЕАЛЬНУЮ форму волны из нативного
/// `android.media.audiofx.Visualizer` (канал `neonwave/wave`) и публикует
/// сглаженные по полосам уровни.
///
/// Если доступ недоступен (нет разрешения RECORD_AUDIO или ром не отдаёт
/// Visualizer), [available] остаётся false — виджет переходит на
/// синтетическую, но органичную анимацию.
class AudioVisualizer {
  static const EventChannel _channel = EventChannel('neonwave/wave');

  /// Сколько полос отдаём наружу.
  static const int bands = 48;

  /// Сглаженные уровни 0..1 (по полосам).
  static final ValueNotifier<List<double>> levels =
      ValueNotifier<List<double>>(List<double>.filled(bands, 0));

  /// true — идут настоящие данные (эквалайзер живой).
  static final ValueNotifier<bool> available = ValueNotifier<bool>(false);

  /// Общая громкость 0..1 (для пульсации окружения/обложки).
  static final ValueNotifier<double> energy = ValueNotifier<double>(0);

  static StreamSubscription<dynamic>? _sub;
  static bool _requested = false;
  static final List<double> _smoothed = List<double>.filled(bands, 0);

  /// Запускает поток (лениво). Безопасно вызывать много раз.
  static Future<void> ensureStarted() async {
    if (_sub != null || _requested) return;
    _requested = true;
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        available.value = false;
        return;
      }
      _sub = _channel.receiveBroadcastStream().listen(
        _onData,
        onError: (Object _) {
          available.value = false;
        },
        cancelOnError: false,
      );
    } catch (_) {
      available.value = false;
    }
  }

  static void _onData(dynamic data) {
    if (data is! Uint8List || data.isEmpty) return;
    final n = data.length;
    final per = n / bands;
    var total = 0.0;
    final next = List<double>.filled(bands, 0);
    for (var b = 0; b < bands; b++) {
      final start = (b * per).floor();
      var end = ((b + 1) * per).ceil();
      if (end <= start) end = start + 1;
      if (end > n) end = n;
      var sum = 0.0;
      for (var i = start; i < end; i++) {
        // Волна приходит как 8-битный беззнаковый поток, 128 — центр.
        sum += (data[i] - 128).abs() / 128.0;
      }
      final v = (sum / (end - start)).clamp(0.0, 1.0);
      next[b] = v;
      total += v;
    }
    // Асимметричное сглаживание: быстрый подъём, плавный спад.
    for (var b = 0; b < bands; b++) {
      final prev = _smoothed[b];
      _smoothed[b] = next[b] > prev
          ? prev + (next[b] - prev) * 0.6
          : prev + (next[b] - prev) * 0.16;
    }
    levels.value = List<double>.from(_smoothed);
    energy.value = (total / bands).clamp(0.0, 1.0);
    if (!available.value) available.value = true;
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
