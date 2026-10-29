import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:io';
import '../lib/src/models.dart';
import '../lib/src/services/cooking_steps.dart';
import '../lib/src/services/video_segments.dart';

void main() { test('ten public recipes parse with actual application parsers', () {
  final rows = jsonDecode(File('../public_ten_recipe_checks.json').readAsStringSync()) as List;
  const expected = {'6YXFChdFCmo': 3, 'lFQFaGzGcYo': 5, 'An0q_mmi2Nw': 4,
    'fNUVMuKPfng': 4, 'ODi3tRXubE8': 6, 'gd3sB-0FpAg': 6,
    '9uB1K4NJ5tU': 3, 'dLilSkYc2yQ': 4, 'PlJ0k9MxdPM': 5, 'D9e5h3TWhHg': 5};
  const untimed = {'dLilSkYc2yQ', 'D9e5h3TWhHg'};
  final seen = <String>{};
  var failed = rows.length != expected.length;
  for (final raw in rows) {
    final recipe = Recipe.fromJson(Map<String,dynamic>.from(raw));
    final steps = savedCookingSteps(recipe.displayDescription, unverified: recipe.hasUnverifiedSteps);
    final segments = verifiedVideoSegments(recipe.videoSegments, recipe.youtubeVideoId, steps);
    final id = recipe.youtubeVideoId ?? '';
    final timingValid = untimed.contains(id)
      ? recipe.videoSegments == null && segments == null
      : segments != null && segments.length == steps.length;
    final valid = seen.add(id) && expected[id] == steps.length && timingValid
      && recipe.originalVideo != null && recipe.requiredIngredients.isNotEmpty;
    failed |= !valid;
    print(jsonEncode({'id': recipe.id, 'video_id': id, 'step_count': steps.length,
      'expected_step_count': expected[id], 'segment_count': segments?.length,
      'valid': valid, 'unverified_steps': recipe.hasUnverifiedSteps,
      'ranges': segments?.map((s) => [s.start,s.end]).toList(),
      'thumbnail': recipe.originalVideo?.thumbnailUrl.toString(),
      if (!valid) 'description': recipe.displayDescription}));
  }
  failed |= seen.length != expected.length;
  print('RESULT: ${failed ? "FAIL" : "PASS"}; ${rows.length} rows, ${seen.length} distinct videos');
  expect(failed, isFalse);
});
}
