/// Only explicit numbered instructions are eligible for step navigation.
/// Free prose, ingredient lists and evidence-only records stay unparsed.
List<String> savedCookingSteps(String description, {required bool unverified}) {
  if (unverified) return const [];
  final lines = description.split('\n');
  final heading = RegExp(
    r'^\s*#{0,6}\s*(?:조리 방법|조리 순서|요리 과정|만드는 법|만드는 방법)\s*[:：]?\s*$',
  );
  final numbered = RegExp(r'^\s*([0-9]+)[.)]\s+(.+)$');
  final start = lines.indexWhere((line) => heading.hasMatch(line));
  if (start < 0) return const [];
  final result = <String>[];
  for (final line in lines.skip(start + 1)) {
    if (line.trim().isEmpty) continue;
    final match = numbered.firstMatch(line);
    if (match == null) {
      if (RegExp(r'^\s*#{1,6}\s+').hasMatch(line)) break;
      // Do not silently truncate a multi-line instruction or a prose section.
      return const [];
    }
    if (int.parse(match.group(1)!) != result.length + 1) return const [];
    result.add(match.group(2)!.trim());
  }
  return List.unmodifiable(result);
}
