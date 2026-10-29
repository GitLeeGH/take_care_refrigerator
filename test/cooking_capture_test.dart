import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/models.dart';
import 'package:take_care_refrigerator/src/providers.dart';
import 'package:take_care_refrigerator/src/pages/recipe_detail_page.dart';

void main() {
  testWidgets('detail tabs and cooking preview render from saved data', (
    tester,
  ) async {
    const capture = bool.fromEnvironment('UI_CAPTURE');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (capture)
      await tester.runAsync(() async {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(
                ByteData.sublistView(
                  await File(
                    r'C:\Users\User\develop\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
                  ).readAsBytes(),
                ),
              ),
            ))
            .load();
        for (final name in ['Roboto', 'Ahem']) {
          await (FontLoader(name)..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File(r'C:\Windows\Fonts\malgun.ttf').readAsBytes(),
                  ),
                ),
              ))
              .load();
        }
      });
    final recipe = Recipe(
      id: 'preview-only',
      youtubeVideoId: 'rLEyOHvGb1Y',
      name: '[미리보기] 저장된 요리 순서',
      description: '## 조리 방법\n1. 재료를 씻습니다.\n2. 재료를 썹니다.',
      requiredIngredients: ['양파', '대파'],
      likeCount: 0,
      createdAt: DateTime(2026),
    );
    final boundary = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ingredientsProvider.overrideWith(
            (ref) => Stream.value(<Ingredient>[]),
          ),
          userProfileProvider.overrideWith((ref) async => null),
          likedRecipeIdsProvider.overrideWith(
            (ref) => Stream.value(<String>{}),
          ),
        ],
        child: MaterialApp(
          builder: (_, child) => RepaintBoundary(key: boundary, child: child!),
          home: RecipeDetailPage(recipe: recipe),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> save(String name) async {
      if (!capture) return;
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/ui-preview/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await save('cooking-detail');
    await tester.tap(find.text('재료'));
    await tester.pumpAndSettle();
    expect(find.text('양파'), findsOneWidget);
    await tester.tap(find.text('레시피'));
    await tester.pumpAndSettle();
    expect(find.text('저장된 레시피'), findsOneWidget);
    await tester.tap(find.text('요리 시작'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 단계'), findsOneWidget);
    await save('cooking-progress');
    expect(tester.takeException(), isNull);
  });
}
