import 'dart:collection';

/// In-memory OCR geometry only; never logged/uploaded. Unknown geometry retained.
class ReceiptOcrLine {
  const ReceiptOcrLine(
    this.text, {
    this.left,
    this.top,
    this.right,
    this.bottom,
  });
  final String text;
  final double? left, top, right, bottom;
  bool get positioned =>
      [left, top, right, bottom].every((v) => v != null && v.isFinite) &&
      right! > left! &&
      bottom! > top!;
  factory ReceiptOcrLine.fromMap(Map<dynamic, dynamic> value) => ReceiptOcrLine(
    value['text'] as String? ?? '',
    left: (value['left'] as num?)?.toDouble(),
    top: (value['top'] as num?)?.toDouble(),
    right: (value['right'] as num?)?.toDouble(),
    bottom: (value['bottom'] as num?)?.toDouble(),
  );
}

/// List compatibility keeps existing test OCR adapters usable.
class ReceiptOcrLines extends ListBase<String> {
  ReceiptOcrLines(Iterable<ReceiptOcrLine> values)
    : lines = List.unmodifiable(values);
  final List<ReceiptOcrLine> lines;
  @override
  int get length => lines.length;
  @override
  set length(int value) => throw UnsupportedError('Immutable OCR');
  @override
  String operator [](int index) => lines[index].text;
  @override
  void operator []=(int index, String value) =>
      throw UnsupportedError('Immutable OCR');
}

/// Reunite horizontally split OCR columns by vertical overlap, not food words.
List<List<ReceiptOcrLine>> receiptVisualGroups(ReceiptOcrLines input) {
  final positioned = input.lines.where((line) => line.positioned).toList()
    ..sort((a, b) {
      final top = a.top!.compareTo(b.top!);
      if (top != 0) return top;
      final left = a.left!.compareTo(b.left!);
      if (left != 0) return left;
      final bottom = a.bottom!.compareTo(b.bottom!);
      return bottom != 0 ? bottom : a.right!.compareTo(b.right!);
    });
  final groups = <List<ReceiptOcrLine>>[];
  for (final line in positioned) {
    List<ReceiptOcrLine>? best;
    var bestDistance = double.infinity;
    for (final group in groups) {
      // Require agreement with every column, preventing a tall box from
      // bridging two distinct rows. Never merge overlapping text boxes.
      final compatible = group.every((other) {
        if (line.left! < other.right! && line.right! > other.left!) {
          return false;
        }
        final overlap =
            (line.bottom! < other.bottom! ? line.bottom! : other.bottom!) -
            (line.top! > other.top! ? line.top! : other.top!);
        final height = (line.bottom! - line.top!) < (other.bottom! - other.top!)
            ? line.bottom! - line.top!
            : other.bottom! - other.top!;
        return overlap / height >= 0.6;
      });
      if (!compatible) continue;
      final center =
          group.fold<double>(
            0,
            (v, other) => v + (other.top! + other.bottom!) / 2,
          ) /
          group.length;
      final distance = ((line.top! + line.bottom!) / 2 - center).abs();
      if (distance < bestDistance) {
        best = group;
        bestDistance = distance;
      }
    }
    if (best == null) {
      groups.add([line]);
    } else {
      best.add(line);
    }
  }
  return [
    for (final group in groups)
      group..sort((a, b) => a.left!.compareTo(b.left!)),
    for (final line in input.lines.where((line) => !line.positioned)) [line],
  ];
}

List<String> receiptVisualRows(ReceiptOcrLines input) => [
  for (final group in receiptVisualGroups(input))
    group.map((line) => line.text).join(' '),
];
