import 'package:audio_player/features/mini_player/neon/neon_mini_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('neon mini swipe', () {
    test('влево — следующий трек', () {
      expect(neonSwipeAction(dx: -30, velocity: 0), 1);
      expect(neonSwipeAction(dx: 0, velocity: -360), 1);
    });

    test('вправо — предыдущий трек', () {
      expect(neonSwipeAction(dx: 30, velocity: 0), -1);
      expect(neonSwipeAction(dx: 0, velocity: 360), -1);
    });

    test('короткое движение без скорости не переключает', () {
      expect(neonSwipeAction(dx: -12, velocity: 40), isNull);
      expect(neonSwipeAction(dx: 12, velocity: -40), isNull);
    });
  });
}
