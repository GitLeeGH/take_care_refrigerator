import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/app_variant.dart';
import 'package:take_care_refrigerator/src/pages/login_page.dart';

void main() {
  testWidgets('Android debug disables social login but keeps email entry', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(isDevelopmentApp, isTrue);
    expect(
      mobileLoginRedirect,
      'com.tcf.take_care_refrigerator.dev://login-callback',
    );
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );
    await tester.pumpAndSettle();
    for (final label in ['Google로 로그인', '카카오로 로그인']) {
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
    }
    expect(find.text('이메일로 로그인 또는 회원가입'), findsOneWidget);
    expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
  });

  test('other platforms keep their existing redirect', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(isDevelopmentApp, isFalse);
    expect(
      mobileLoginRedirect,
      'io.supabase.flutterquickstart://login-callback',
    );
  });
}
