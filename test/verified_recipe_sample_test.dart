import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/services/recipe_draft.dart';
import 'package:take_care_refrigerator/src/services/verified_recipe_sample.dart';
import 'package:take_care_refrigerator/src/pages/recipe_import_page.dart';

void main() {
  test(
    'verified comment fixture preserves all facts and no inferred steps',
    () {
      final draft = verifiedRecipeSample(const YoutubeSource('rLEyOHvGb1Y'))!;
      expect(draft.ingredients.map((item) => item.name), [
        '돼지고기 목전지',
        '식용유',
        '설탕',
        '다진마늘',
        '고추장',
        '고춧가루',
        '진간장',
        '미림',
        '굴소스',
        '후추',
        '청양고추',
        '양파',
        '대파',
        '참기름',
        '통깨',
      ]);
      expect(draft.ingredients.map((item) => item.amount), [
        '600g',
        '3스푼',
        '2스푼',
        '1스푼',
        '1스푼',
        '4스푼',
        '3스푼',
        '2스푼',
        '1스푼',
        null,
        '2개 (20g)',
        '1/2개 (120g)',
        '1대 (100g)',
        '1스푼',
        '1스푼',
      ]);
      expect(draft.ingredients.first.evidence, contains('앞다리살 대체 가능'));
      expect(draft.measurementNote, contains('1스푼 = 10ml'));
      expect(draft.measurementNote, contains('1컵 = 180ml'));
      expect(draft.steps, isEmpty);
      expect(draft.confirmationNeeded, isTrue);
      expect(draft.creator, '추추의 한끼식사 @chuchu_cook');
      expect(draft.evidenceUrl, contains('lc=UgxVWWyxpcu9RC6RZ5V4AaABAg'));
      expect(draft.sourceKind, RecipeSourceKind.creatorComment);
    },
  );
  test('fixture cannot be applied to any other video or invalid link', () {
    expect(verifiedRecipeSample(null), isNull);
    expect(verifiedRecipeSample(const YoutubeSource('abcdefghijk')), isNull);
  });
  testWidgets('sample requires explicit choice and labels manual provenance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RecipeImportPage())),
    );
    expect(find.text('이 영상의 제작자 댓글 예시 보기'), findsNothing);
    await tester.enterText(
      find.byType(TextField).first,
      'https://www.youtube.com/shorts/rLEyOHvGb1Y',
    );
    await tester.pump();
    expect(find.byType(RecipeDraftPreview), findsNothing);
    await tester.scrollUntilVisible(
      find.text('이 영상의 제작자 댓글 예시 보기'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('이 영상의 제작자 댓글 예시 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 영상의 제작자 댓글 예시 보기'));
    await tester.pump();
    expect(find.byType(RecipeDraftPreview), findsOneWidget);
    expect(find.text('제작자 댓글에서 확인한 예시 · 자동 추출 결과가 아닙니다.'), findsOneWidget);
  });
}
