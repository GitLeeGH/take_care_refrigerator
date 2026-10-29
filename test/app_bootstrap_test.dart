import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/widgets/app_bootstrap.dart';

void main() {
  testWidgets('startup paints immediately then enters the app', (tester) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      AppBootstrap(
        initialize: () => pending.future,
        ready: (seen) => MaterialApp(home: Text(seen ? 'ready' : 'onboarding')),
      ),
    );
    expect(find.text('냉장고를 준비하고 있어요'), findsOneWidget);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('onboarding'), findsOneWidget);
  });
  testWidgets(
    'plugin failures show a safe error instead of leaving native splash',
    (tester) async {
      await tester.pumpWidget(
        AppBootstrap(
          initialize: () async =>
              throw MissingPluginException('private diagnostic'),
          ready: (_) => const SizedBox(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('앱을 시작하지 못했어요.'), findsOneWidget);
      expect(find.textContaining('private diagnostic'), findsNothing);
    },
  );
  testWidgets('stalled startup has a bounded wait', (tester) async {
    await tester.pumpWidget(
      AppBootstrap(
        initialize: () => Completer<bool>().future,
        ready: (_) => const SizedBox(),
      ),
    );
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.textContaining('앱을 시작하지 못했어요.'), findsOneWidget);
  });
}
