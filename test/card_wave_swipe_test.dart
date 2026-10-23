import 'package:audio_player/features/now_playing/card_wave/card_wave_player_body.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cardWaveSwipeAction', () {
    test('short slow drag settles back', () {
      expect(cardWaveSwipeAction(12, 40), 0);
      expect(cardWaveSwipeAction(-20, -100), 0);
    });

    test('left drag deals the next card', () {
      expect(cardWaveSwipeAction(-32, -80), 1);
      expect(cardWaveSwipeAction(-40, 0), 1);
    });

    test('right drag brings the previous card back', () {
      expect(cardWaveSwipeAction(32, 80), -1);
      expect(cardWaveSwipeAction(40, 0), -1);
    });

    test('fast flick wins over short distance', () {
      expect(cardWaveSwipeAction(-8, -420), 1);
      expect(cardWaveSwipeAction(8, 420), -1);
    });
  });
}
