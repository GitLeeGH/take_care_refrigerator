import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:take_care_refrigerator/src/services/original_video.dart';
import 'package:take_care_refrigerator/src/widgets/original_video_panel.dart';

void main() {
  testWidgets(
    'cooking entry attempts playback without another poster tap and keeps failure fallback',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OriginalVideoPanel(
              video: OriginalVideo(OriginalVideoKind.youtube, 'rLEyOHvGb1Y'),
              hero: true,
              playOnEntry: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // No WebView platform is installed in widget tests; automatic initialization
      // must fail visibly, not hang, launch another app or create a second player.
      expect(find.textContaining('재생을 시작하지 못했어요'), findsOneWidget);
      expect(find.text('원본 앱 / 브라우저 열기'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 21));
      expect(tester.takeException(), isNull);
    },
  );
  test('accepts only canonical supported original video URLs', () {
    expect(
      OriginalVideo.parse('https://www.youtube.com/shorts/rLEyOHvGb1Y')?.kind,
      OriginalVideoKind.youtube,
    );
    expect(
      OriginalVideo.parse(
        'https://www.instagram.com/reel/ABCdef_123/?igsh=share',
      )?.url.toString(),
      'https://www.instagram.com/reel/ABCdef_123/',
    );
    for (final input in [
      'http://instagram.com/reel/ABCDE/',
      'https://instagram.com.evil.test/reel/ABCDE/',
      'https://user@instagram.com/reel/ABCDE/',
      'https://instagram.com:444/reel/ABCDE/',
      'https://instagram.com/p/ABCDE/',
      'https://instagram.com/reel/ABCDE/extra',
      'https://instagram.com//reel/ABCDE/',
      'javascript:alert(1)',
      'intent://instagram.com/reel/ABCDE/',
    ]) {
      expect(OriginalVideo.parse(input), isNull, reason: input);
    }
  });
  test('player HTML cannot interpolate untrusted IDs or origins', () {
    expect(
      () => youtubePlayerHtml(
        "x'</script>",
        'https://com.tcf.take_care_refrigerator',
      ),
      throwsArgumentError,
    );
    expect(
      () => youtubePlayerHtml('rLEyOHvGb1Y', 'https://evil.test'),
      throwsArgumentError,
    );
    expect(youtubePlayerError(150), contains('허용하지 않았어요'));
    expect(youtubePlayerError(100), contains('비공개'));
    expect(youtubePlayerError(153), contains('확인하지 못했어요'));
  });
  testWidgets(
    'Reel launch falls back to browser and retains a copyable URL on failure',
    (tester) async {
      final modes = <LaunchMode>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OriginalVideoPanel(
              video: const OriginalVideo(
                OriginalVideoKind.instagram,
                'ABCdef_123',
              ),
              launcher: (url, mode) async {
                modes.add(mode);
                return false;
              },
            ),
          ),
        ),
      );
      expect(find.text('여기서 영상 보기'), findsNothing);
      expect(find.textContaining('로그인·공개 범위'), findsOneWidget);
      await tester.tap(find.text('원본 앱 / 브라우저 열기'));
      await tester.pumpAndSettle();
      expect(modes, [
        LaunchMode.externalApplication,
        LaunchMode.inAppBrowserView,
      ]);
      expect(find.textContaining('주소를 복사해'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    },
  );
  testWidgets(
    'YouTube starts only on request and unavailable WebView keeps fallback',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OriginalVideoPanel(
              video: OriginalVideo(OriginalVideoKind.youtube, 'rLEyOHvGb1Y'),
            ),
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.tap(find.text('여기서 영상 보기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('재생을 시작하지 못했어요'), findsOneWidget);
      expect(find.text('원본 앱 / 브라우저 열기'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 21));
      expect(tester.takeException(), isNull);
    },
  );
}
