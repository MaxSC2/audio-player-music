import 'package:flutter_test/flutter_test.dart';
import 'package:audio_player/services/audio_handler.dart';

void main() {
  group('providerIndexFromMediaQueueIndex', () {
    test('maps valid local indices into the provider queue', () {
      expect(providerIndexFromMediaQueueIndex(0, 120, 81), 120);
      expect(providerIndexFromMediaQueueIndex(40, 120, 81), 160);
      expect(providerIndexFromMediaQueueIndex(80, 120, 81), 200);
    });

    test('rejects indices outside the published window', () {
      expect(providerIndexFromMediaQueueIndex(-1, 120, 81), isNull);
      expect(providerIndexFromMediaQueueIndex(81, 120, 81), isNull);
      expect(providerIndexFromMediaQueueIndex(10, 120, 0), isNull);
    });
  });
}
