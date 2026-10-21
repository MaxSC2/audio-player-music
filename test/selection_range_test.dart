import 'package:audio_player/core/selection_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const order = [10, 20, 30, 40, 50];

  test('selects forward range and keeps base selection', () {
    expect(
      selectionRangeIds(order: order, anchor: 1, target: 3, base: {99}),
      {99, 20, 30, 40},
    );
  });

  test('selects backward range', () {
    expect(
      selectionRangeIds(order: order, anchor: 4, target: 2),
      {30, 40, 50},
    );
  });

  test('single item keeps anchor', () {
    expect(selectionRangeIds(order: order, anchor: 2, target: 2), {30});
  });

  test('clamps out-of-range indexes', () {
    expect(
      selectionRangeIds(order: order, anchor: -5, target: 99),
      order.toSet(),
    );
  });

  test('empty order returns base', () {
    expect(
      selectionRangeIds(order: const [], anchor: 0, target: 2, base: {1, 2}),
      {1, 2},
    );
  });
}
