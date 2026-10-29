import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/models.dart';
import 'package:take_care_refrigerator/src/pages/recipe_detail_page.dart';
import 'package:take_care_refrigerator/src/services/video_segments.dart';
import 'package:take_care_refrigerator/src/widgets/original_video_panel.dart';

Map<String, dynamic> timings() => {
  'version': 1,
  'verified': true,
  'coverage': 'excerpt',
  'verified_at': '2026-10-29T00:00:00Z',
  'video_id': 'rLEyOHvGb1Y',
  'duration_seconds': 61.461,
  'segments': [
    {'step_text': '첫 단계', 'start_seconds': 20, 'end_seconds': 25},
    {'step_text': '둘째 단계', 'start_seconds': 30, 'end_seconds': 35},
  ],
};

void main() {
  const steps = ['첫 단계', '둘째 단계'];
  test(
    'only verified metadata matching video and exact current steps is usable',
    () {
      expect(verifiedVideoSegments(timings(), 'rLEyOHvGb1Y', steps)!.length, 2);
      expect(verifiedVideoSegments(null, 'rLEyOHvGb1Y', steps), isNull);
      expect(verifiedVideoSegments(timings(), 'other123456', steps), isNull);
      expect(
        verifiedVideoSegments(timings(), 'rLEyOHvGb1Y', ['수정됨', steps[1]]),
        isNull,
      );
      expect(verifiedVideoSegments(timings(), 'rLEyOHvGb1Y', []), isNull);
      for (final field in [
        'verified',
        'verified_at',
        'coverage',
        'duration_seconds',
        'version',
      ]) {
        expect(
          verifiedVideoSegments(timings()..remove(field), 'rLEyOHvGb1Y', steps),
          isNull,
        );
      }
    },
  );
  test('invalid numeric ranges, overlaps and mismatched count fail closed', () {
    for (final range in [
      [-1, 25],
      [20, 20],
      [30, 20],
      [20, 90],
      [double.nan, 25],
      [20, double.infinity],
      ['20', 25],
      [20, 31],
    ]) {
      final data = timings();
      data['segments'][0]['start_seconds'] = range[0];
      data['segments'][0]['end_seconds'] = range[1];
      expect(verifiedVideoSegments(data, 'rLEyOHvGb1Y', steps), isNull);
    }
    expect(
      verifiedVideoSegments(timings()..['segments'] = [], 'rLEyOHvGb1Y', steps),
      isNull,
    );
  });
  testWidgets(
    'step navigation selects timings, opt out clears repeat, completion stops playback',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: CookingPage(
            recipe: Recipe(
              id: 'test',
              name: '테스트 전용',
              description: '## 조리 방법\n1. 첫 단계\n2. 둘째 단계',
              youtubeVideoId: 'rLEyOHvGb1Y',
              requiredIngredients: [],
              likeCount: 0,
              createdAt: DateTime(2026),
              videoSegments: timings(),
            ),
          ),
        ),
      );
      OriginalVideoPanel panel() =>
          tester.widget(find.byType(OriginalVideoPanel));
      expect(panel().segment!.start, 20);
      expect(panel().playOnEntry, isTrue);
      expect(find.text('단계 영상 · 약 20–25초'), findsOneWidget);
      expect(find.textContaining('초 단위의 대략적인 구간'), findsOneWidget);
      await tester.ensureVisible(find.text('이 구간 반복'));
      await tester.tap(find.text('이 구간 반복'));
      await tester.pumpAndSettle();
      expect(panel().repeatSegment, isTrue);
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(panel().segment!.start, 30);
      await tester.ensureVisible(find.text('단계에 맞춰 영상 이동'));
      await tester.tap(find.text('단계에 맞춰 영상 이동'));
      await tester.pumpAndSettle();
      expect(panel().segment, isNull);
      expect(panel().repeatSegment, isFalse);
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();
      expect(panel().playbackEnabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
