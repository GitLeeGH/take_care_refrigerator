import 'package:flutter/material.dart';
import '../theme.dart';

/// Paint a Flutter frame before platform initialization, and never expose raw
/// configuration errors (which can contain URLs or credentials) in the UI.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    required this.initialize,
    required this.ready,
  });
  final Future<bool> Function() initialize;
  final Widget Function(bool) ready;
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<bool> startup;
  @override
  void initState() {
    super.initState();
    startup = Future(widget.initialize).timeout(const Duration(seconds: 30));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: startup,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return widget.ready(snapshot.data!);
      }
      return MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: snapshot.hasError
                  ? const Text(
                      '앱을 시작하지 못했어요.\n앱을 닫고 다시 실행해 주세요.\n계속되면 개발자에게 알려 주세요.',
                      textAlign: TextAlign.center,
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text('냉장고를 준비하고 있어요'),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
}
