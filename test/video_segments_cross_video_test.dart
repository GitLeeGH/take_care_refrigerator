import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/services/video_segments.dart';

// Synthetic IDs and ranges only. Never uploaded or advertised as real recipes.
void main() {
  for (final id in ['fixture0001', 'fixture0002']) {
    test('isolates timing metadata for synthetic video $id', () {
      final data = {
        'version': 1,
        'verified': true,
        'coverage': 'excerpt',
        'verified_at': '2026-10-29',
        'video_id': id,
        'duration_seconds': 120,
        'segments': [
          {'step_text': 'test A', 'start_seconds': 0, 'end_seconds': 0.2},
          {'step_text': 'test B', 'start_seconds': 2.5, 'end_seconds': 119.5},
        ],
      };
      final result = verifiedVideoSegments(data, id, ['test A', 'test B'])!;
      expect(result.first.start, 0);
      expect(result.first.end, 0.2);
      expect(result.last.end, 119.5);
      expect(
        verifiedVideoSegments(data, 'rLEyOHvGb1Y', ['test A', 'test B']),
        isNull,
      );
      expect(verifiedVideoSegments(data, id, ['changed', 'test B']), isNull);
      expect(verifiedVideoSegments(null, id, ['test A', 'test B']), isNull);
    });
  }
}
