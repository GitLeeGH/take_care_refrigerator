// Presentation only: never change stored source text or matching requirements.
String recipePreviewText(String source) {
  return source
      .split('\n')
      .map((line) {
        var text = line.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');
        text = text.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '');
        text = text.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!);
        text = text.replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m[1]!);
        return text.trim();
      })
      .where((line) => line.isNotEmpty)
      .join('\n');
}
