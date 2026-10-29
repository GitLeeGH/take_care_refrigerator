import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/pages/recipe_import_page.dart';
import 'package:take_care_refrigerator/src/services/recipe_draft.dart';
import 'package:take_care_refrigerator/src/services/verified_recipe_sample.dart';
import 'package:take_care_refrigerator/src/theme.dart';

void main() {
  testWidgets('verified Shorts preview remains explicit and scrollable', (
    tester,
  ) async {
    const capture = bool.fromEnvironment('UI_CAPTURE');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (capture) {
      await tester.runAsync(() async {
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
    }
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                '확인된 댓글 예시 · 미리보기',
                style: TextStyle(fontFamily: 'Roboto', fontSize: 18),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: RecipeDraftPreview(
                draft: verifiedRecipeSample(
                  const YoutubeSource('rLEyOHvGb1Y'),
                )!,
              ),
            ),
          ),
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

    await save('shorts-verified-preview');
    await tester.ensureVisible(find.text('조리 순서 없음 · 원문 확인 필요'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await save('shorts-verified-preview-bottom');
  });
}
