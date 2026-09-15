import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_player/providers/player_provider.dart';

void main() {
  group('buildShuffleOrder', () {
    test('пустая и одноэлементная очередь — пустой порядок', () {
      expect(buildShuffleOrder(0, 0), isEmpty);
      expect(buildShuffleOrder(1, 0), isEmpty);
      expect(buildShuffleOrder(1, -1), isEmpty);
    });

    test('содержит все индексы ровно по одному разу', () {
      const n = 50;
      final order = buildShuffleOrder(n, 0, random: math.Random(42));
      expect(order.length, n);
      expect(order.toSet().length, n, reason: 'дубликаты недопустимы');
      expect(order.reduce(math.max), n - 1);
      expect(order.reduce(math.min), 0);
    });

    test('текущий трек идёт первым — воспроизведение не переключается', () {
      const n = 30;
      for (var cur = 0; cur < n; cur++) {
        final order = buildShuffleOrder(n, cur, random: math.Random(cur));
        expect(order.first, cur, reason: 'current=$cur должен быть первым');
      }
    });

    test('детерминирован при одном seed', () {
      final a = buildShuffleOrder(20, 3, random: math.Random(7));
      final b = buildShuffleOrder(20, 3, random: math.Random(7));
      expect(a, b);
    });

    test('реально перемешивает (не тождественная перестановка)', () {
      const n = 40;
      final order = buildShuffleOrder(n, 0, random: math.Random(1));
      final identity = List<int>.generate(n, (i) => i);
      expect(order, isNot(equals(identity)));
    });
  });
}