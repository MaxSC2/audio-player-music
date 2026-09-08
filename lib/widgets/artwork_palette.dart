import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'cached_artwork.dart';

/// Dominant colors текущей обложки для ambient-фона.
/// Без новых зависимостей: даунскейл кодеком до ~32px + квантование HSV.
class ArtworkPalette {
  static const int _maxEntries = 60;
  static final LinkedHashMap<int, List<Color>> _cache = LinkedHashMap();

  /// Нейтральная палитра (нет арта / ч/б / ошибка).
  static const List<Color> fallback = [
    Color(0xFF3A4356),
    Color(0xFF232936),
  ];

  /// Синхронное чтение из кеша (null — ещё не загружено).
  static List<Color>? cached(int trackId) => _cache[trackId];

  static Future<List<Color>> forTrack(int trackId) async {
    final hit = _cache.remove(trackId);
    if (hit != null) {
      _cache[trackId] = hit;
      return hit;
    }
    try {
      final bytes = await ArtworkCache.load(trackId, size: 200);
      final colors = bytes == null ? fallback : await _extract(bytes);
      _cache[trackId] = colors;
      while (_cache.length > _maxEntries) {
        _cache.remove(_cache.keys.first);
      }
      return colors;
    } catch (_) {
      return fallback;
    }
  }

  static Future<List<Color>> _extract(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 32,
      targetHeight: 32,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    codec.dispose();
    if (data == null) return fallback;

    final px = data.buffer.asUint8List();
    // Ведра HSV: 12 hue x 3 sat x 3 val.
    final Map<int, double> buckets = {};
    final Map<int, List<int>> sums = {};
    final n = px.length ~/ 4;
    for (var i = 0; i < n; i++) {
      final r = px[i * 4] / 255.0;
      final g = px[i * 4 + 1] / 255.0;
      final b = px[i * 4 + 2] / 255.0;
      final hsv = HSVColor.fromColor(Color.fromRGBO(
        (r * 255).round(),
        (g * 255).round(),
        (b * 255).round(),
        1.0,
      ));
      final h = (hsv.hue / 30).floor().clamp(0, 11);
      final s = (hsv.saturation * 3).floor().clamp(0, 2);
      final v = (hsv.value * 3).floor().clamp(0, 2);
      final key = h * 9 + s * 3 + v;
      // Вес: насыщенные и средне-яркие цвета важнее; почти чёрное/белое — штраф.
      var w = 0.35 + 0.65 * hsv.saturation;
      if (hsv.value < 0.12 || hsv.value > 0.96) w *= 0.25;
      buckets[key] = (buckets[key] ?? 0) + w;
      final acc = sums.putIfAbsent(key, () => [0, 0, 0, 0]);
      acc[0] += px[i * 4];
      acc[1] += px[i * 4 + 1];
      acc[2] += px[i * 4 + 2];
      acc[3] += 1;
    }
    if (buckets.isEmpty) return fallback;
    final sorted = buckets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // Берём топ-ведро + самое далёкое по hue среди следующих (контраст).
    Color avg(int key) {
      final acc = sums[key]!;
      final c = acc[3];
      return Color.fromRGBO(
        acc[0] ~/ c,
        acc[1] ~/ c,
        acc[2] ~/ c,
        1.0,
      );
    }

    final first = avg(sorted.first.key);
    Color second = first;
    final firstHue = sorted.first.key ~/ 9;
    for (var i = 1; i < sorted.length && i < 6; i++) {
      final hue = sorted[i].key ~/ 9;
      var dh = (hue - firstHue).abs();
      if (dh > 6) dh = 12 - dh;
      if (dh >= 2) {
        second = avg(sorted[i].key);
        break;
      }
    }
    return [first, second];
  }
}
