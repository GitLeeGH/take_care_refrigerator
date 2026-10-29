import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/services/recipe_draft.dart';
import 'package:take_care_refrigerator/src/pages/recipe_import_page.dart';

class FailedExtractor implements RecipeDraftExtractor {
  @override
  bool get available => true;
  @override
  Future<RecipeDraft> extract(
    YoutubeSource source,
    String text,
    RecipeSourceKind kind,
  ) async => throw StateError('test error');
}

Future<void> pressCheck(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('입력 확인'),
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('입력 확인'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('입력 확인'));
  await tester.pumpAndSettle();
}

Future<void> enterSource(WidgetTester tester, String key, String value) async {
  await tester.drag(find.byType(ListView), const Offset(0, 2000));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(find.byKey(Key(key)), value);
  await tester.pumpAndSettle();
}

void main() {
  test('accepts official URLs including sample Shorts', () {
    for (final url in [
      'https://www.youtube.com/shorts/rLEyOHvGb1Y',
      'https://youtube.com/watch?v=rLEyOHvGb1Y&t=10',
      'https://m.youtube.com/watch?v=rLEyOHvGb1Y',
      'https://youtu.be/rLEyOHvGb1Y?si=share',
    ]) {
      expect(YoutubeSource.parse(url)?.videoId, 'rLEyOHvGb1Y');
    }
  });
  test(
    'rejects spoofed hosts, credentials, invalid paths, IDs and duplicate IDs',
    () {
      for (final url in [
        '',
        'http://youtube.com/watch?v=rLEyOHvGb1Y',
        'https://youtube.com.evil.test/watch?v=rLEyOHvGb1Y',
        'https://evil.test/youtube.com/watch?v=rLEyOHvGb1Y',
        'https://user@youtube.com/watch?v=rLEyOHvGb1Y',
        'https://youtube.com:444/watch?v=rLEyOHvGb1Y',
        'https://youtu.be/short',
        'https://youtube.com/shorts/rLEyOHvGb1Y/extra',
        'https://youtube.com/watch?v=rLEyOHvGb1Y&v=rLEyOHvGb1Y',
      ]) {
        expect(YoutubeSource.parse(url), isNull, reason: url);
      }
    },
  );
  testWidgets(
    'input validates empty source and honestly reports unavailable extraction',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RecipeImportPage())),
      );
      await pressCheck(tester);
      await tester.pump();
      expect(find.textContaining('올바른 HTTPS'), findsOneWidget);
      await enterSource(
        tester,
        'recipe-source-url',
        'https://www.youtube.com/shorts/rLEyOHvGb1Y',
      );
      await pressCheck(tester);
      await tester.pump();
      expect(find.textContaining('링크만으로 내용을 추측'), findsOneWidget);
      await enterSource(tester, 'recipe-source-text', '사용자가 제공한 예시 텍스트');
      await pressCheck(tester);
      await tester.pump();
      expect(find.textContaining('자동 추출은 아직 연결되지'), findsOneWidget);
      expect(find.byType(RecipeDraftPreview), findsNothing);
    },
  );
  testWidgets(
    'extractor errors retain source and never create invented draft',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipeDraftExtractorProvider.overrideWithValue(FailedExtractor()),
          ],
          child: const MaterialApp(home: RecipeImportPage()),
        ),
      );
      await enterSource(
        tester,
        'recipe-source-url',
        'https://youtu.be/rLEyOHvGb1Y',
      );
      await enterSource(tester, 'recipe-source-text', '원문 그대로');
      await pressCheck(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('초안을 만들지 못했어요'), findsOneWidget);
      expect(find.text('원문 그대로'), findsOneWidget);
      expect(find.byType(RecipeDraftPreview), findsNothing);
    },
  );
  testWidgets('missing metadata remains explicitly unknown with provenance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipeDraftPreview(
              draft: RecipeDraft(
                source: YoutubeSource('rLEyOHvGb1Y'),
                sourceKind: RecipeSourceKind.userTranscript,
                ingredients: [
                  DraftIngredient(name: '예시 재료', evidence: '테스트 원문'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('제목 확인 필요'), findsOneWidget);
    expect(find.textContaining('분량 확인 필요'), findsOneWidget);
    expect(find.textContaining('조리 순서 없음'), findsOneWidget);
    expect(find.text('근거: 테스트 원문'), findsOneWidget);
  });
}
