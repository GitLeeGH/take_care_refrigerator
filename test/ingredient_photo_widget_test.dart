import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/widgets/ingredient_photo.dart';

void main() {
  testWidgets('stored private photo uses authenticated bytes and fits its card', (
    tester,
  ) async {
    const path = 'demo/ingredient/photo.png';
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ingredientPhotoBytesProvider(path).overrideWith((ref) async => bytes),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 140,
              height: 94,
              child: IngredientPhoto(path: path, fallback: Icon(Icons.kitchen)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing photo retains existing icon; failure offers retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: IngredientPhoto(path: null, fallback: Icon(Icons.kitchen)),
        ),
      ),
    );
    expect(find.byIcon(Icons.kitchen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    const path = 'demo/ingredient/photo.png';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ingredientPhotoBytesProvider(
            path,
          ).overrideWith((ref) async => throw StateError('offline')),
        ],
        child: const MaterialApp(
          home: IngredientPhoto(path: path, fallback: Icon(Icons.kitchen)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('사진 다시 불러오기'), findsOneWidget);
  });
}
