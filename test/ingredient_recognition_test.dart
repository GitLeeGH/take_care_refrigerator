import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/services/ingredient_recognition.dart';
import 'package:take_care_refrigerator/src/widgets/ingredient_candidate_review.dart';

void main() {
  test('production recognizer remains disconnected', () {
    expect(const UnconfiguredIngredientRecognizer().available, isFalse);
  });
  testWidgets('review requires confirmation and returns only editable name', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const IngredientCandidateReview(
                    candidates: [
                      IngredientCandidate(name: '두부', category: '콩 가공품'),
                    ],
                  ),
                );
              },
              child: const Text('검토'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('검토'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('두부'));
    await tester.enterText(find.byType(TextField), '연두부');
    await tester.pump();
    expect(result, isNull);
    await tester.tap(find.text('이 이름 사용'));
    await tester.pumpAndSettle();
    expect(result, '연두부');
  });
  testWidgets('empty results explain manual fallback at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: IngredientCandidateReview(candidates: []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('확실한 재료를 찾지 못했어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
