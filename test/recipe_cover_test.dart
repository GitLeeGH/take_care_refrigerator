import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/services/original_video.dart';
import 'package:take_care_refrigerator/src/widgets/recipe_cover.dart';
import 'package:take_care_refrigerator/src/widgets/original_video_panel.dart';

void main() {
  const video = OriginalVideo(OriginalVideoKind.youtube, 'rLEyOHvGb1Y');
  test(
    'thumbnail is restricted to validated YouTube ID, uploaded image wins',
    () {
      expect(
        video.thumbnailUrl.toString(),
        'https://i.ytimg.com/vi/rLEyOHvGb1Y/hqdefault.jpg',
      );
      expect(
        const OriginalVideo(
          OriginalVideoKind.youtube,
          '../bad/id',
        ).thumbnailUrl,
        isNull,
      );
      expect(
        const OriginalVideo(
          OriginalVideoKind.instagram,
          'rLEyOHvGb1Y',
        ).thumbnailUrl,
        isNull,
      );
      expect(
        const RecipeCover(
          imageUrl: 'https://example.com/upload.jpg',
          video: video,
        ).sources.map((e) => e.toString()),
        ['https://example.com/upload.jpg', video.thumbnailUrl.toString()],
      );
      expect(
        const RecipeCover(
          imageUrl: 'javascript:alert(1)',
          video: video,
        ).sources,
        [video.thumbnailUrl],
      );
      expect(
        const RecipeCover(
          imageUrl: 'https://user:password@example.com/photo.jpg',
        ).sources,
        isEmpty,
      );
    },
  );
  testWidgets('missing image has a readable bounded fallback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 132, width: 150, child: RecipeCover()),
        ),
      ),
    );
    expect(find.text('등록된 이미지가 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed uploaded and thumbnail requests retain fallback without exceptions',
    (tester) async {
      // Flutter test HTTP returns 400; no external requests or real photos.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 180,
                child: RecipeCover(
                  imageUrl: 'https://example.com/unavailable.jpg',
                  video: video,
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      });
      expect(find.text('이미지를 불러올 수 없어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'hero exposes thumbnail before tap and keeps original launch usable',
    (tester) async {
      var launches = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OriginalVideoPanel(
              video: const OriginalVideo(
                OriginalVideoKind.instagram,
                'ABCdef123',
              ),
              hero: true,
              playOnEntry: true,
              posterImageUrl: 'https://example.com/upload.jpg',
              launcher: (_, _) async {
                launches++;
                return true;
              },
            ),
          ),
        ),
      );
      expect(find.byType(RecipeCover), findsOneWidget);
      expect(launches, 0);
      expect(find.bySemanticsLabel('원본 영상 재생'), findsOneWidget);
      await tester.tap(find.text('원본 영상 보기'));
      await tester.pumpAndSettle();
      expect(launches, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
