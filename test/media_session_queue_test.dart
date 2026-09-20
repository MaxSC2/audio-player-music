import 'package:flutter_test/flutter_test.dart';
import 'package:audio_player/services/audio_handler.dart';

void main() {
  group('calculateNativeWindowTrim', () {
    test('does not trim when the native queue is already bounded', () {
      expect(
        calculateNativeWindowTrim(
          currentLocalIndex: 40,
          nativeLength: 81,
          maxLength: 81,
        ),
        (removeStart: 0, removeEnd: 0),
      );
    });

    test('preserves the current item when trimming from the far side', () {
      final plan = calculateNativeWindowTrim(
        currentLocalIndex: 80,
        nativeLength: 82,
        maxLength: 81,
      );
      expect(plan.removeStart, 1);
      expect(plan.removeEnd, 0);
    });

    test('can trim both sides while keeping the current item', () {
      final plan = calculateNativeWindowTrim(
        currentLocalIndex: 40,
        nativeLength: 85,
        maxLength: 81,
      );
      expect(plan.removeStart + plan.removeEnd, 4);
      expect(plan.removeStart, greaterThanOrEqualTo(0));
      expect(plan.removeEnd, greaterThanOrEqualTo(0));
      expect(40 - plan.removeStart, greaterThanOrEqualTo(0));
      expect(
        85 - plan.removeStart - plan.removeEnd - 1 -
            (40 - plan.removeStart),
        greaterThanOrEqualTo(0),
      );
    });
  });

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


group('recommendation history recency', () {
  test('newest-first history uses the first matching entry', () {
    final history = <Map<String, int>>[
      {'id': 7, 'ts': 300},
      {'id': 8, 'ts': 200},
      {'id': 7, 'ts': 100},
    ];
    expect(latestHistoryIndex(history, 7), 0);
    expect(latestHistoryIndex(history, 8), 1);
    expect(latestHistoryIndex(history, 9), -1);
  });

  test('history index equals distance from newest', () {
    expect(historyDistanceFromNewest(0), 0);
    expect(historyDistanceFromNewest(9), 9);
    expect(historyDistanceFromNewest(10), 10);
    expect(historyDistanceFromNewest(-1), -1);
  });
});
