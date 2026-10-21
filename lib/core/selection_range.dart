Set<int> selectionRangeIds({
  required List<int> order,
  required int anchor,
  required int target,
  Set<int> base = const <int>{},
}) {
  if (order.isEmpty) return Set<int>.of(base);
  final a = anchor.clamp(0, order.length - 1);
  final b = target.clamp(0, order.length - 1);
  final lo = a < b ? a : b;
  final hi = a < b ? b : a;
  return <int>{...base, ...order.sublist(lo, hi + 1)};
}
