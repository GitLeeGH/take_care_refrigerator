import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_gateway.dart';

class AuthSessionGate extends StatefulWidget {
  const AuthSessionGate({
    super.key,
    required this.gateway,
    required this.signedIn,
    required this.signedOut,
    this.onSessionBoundary,
    this.onAccountBoundary,
    this.onStartupBoundary,
  });
  final VoidCallback? onSessionBoundary;
  // Local snapshots survive token expiry, but never an actual owner change.
  final VoidCallback? onAccountBoundary;
  final VoidCallback? onStartupBoundary;
  final AuthGateway gateway;
  final Widget Function(String) signedIn;
  final WidgetBuilder signedOut;
  @override
  State<AuthSessionGate> createState() => _AuthSessionGateState();
}

class _AuthSessionGateState extends State<AuthSessionGate>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _subscription;
  bool _busy = true, _failed = false;
  int _generation = 0;
  String? _visibleAccount;
  @override
  void initState() {
    super.initState();
    _visibleAccount = widget.gateway.accountId;
    (widget.onStartupBoundary ?? widget.onSessionBoundary)?.call();
    WidgetsBinding.instance.addObserver(this);
    _subscription = widget.gateway.changes.listen(
      (_) {
        if (!mounted) return;
        if (_visibleAccount != widget.gateway.accountId ||
            !widget.gateway.sessionUsable) {
          widget.onSessionBoundary?.call();
        }
        ++_generation;
        if (_visibleAccount != widget.gateway.accountId) {
          widget.onAccountBoundary?.call();
          // Dialogs use the root Navigator by default; close those too.
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);
          _visibleAccount = widget.gateway.accountId;
        }
        setState(() {
          _busy = false;
          _failed =
              !widget.gateway.sessionUsable && widget.gateway.accountId != null;
        });
      },
      onError: (Object _, StackTrace _) {
        if (mounted) {
          widget.onSessionBoundary?.call();
          setState(() {
            ++_generation;
            _busy = false;
            _failed = true;
          });
        }
      },
    );
    _restore();
  }

  Future<void> _restore() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.gateway.restore().timeout(const Duration(seconds: 30));
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _failed =
              widget.gateway.accountId != null && !widget.gateway.sessionUsable;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        widget.onSessionBoundary?.call();
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _visibleAccount != widget.gateway.accountId) {
      widget.onAccountBoundary?.call();
    }
    if (state == AppLifecycleState.resumed &&
        (_visibleAccount != widget.gateway.accountId ||
            !widget.gateway.sessionUsable)) {
      widget.onSessionBoundary?.call();
    }
    if (state == AppLifecycleState.resumed &&
        !_busy &&
        !widget.gateway.sessionUsable) {
      _restore();
    }
  }

  @override
  void dispose() {
    ++_generation;
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_failed) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('로그인 상태를 확인하지 못했어요. 연결을 확인하고 다시 시도해 주세요.'),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _restore, child: const Text('다시 시도')),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final id = widget.gateway.accountId;
    _visibleAccount = id;
    return id != null && widget.gateway.sessionUsable
        ? widget.signedIn(id)
        : widget.signedOut(context);
  }
}

/// An independent provider container and Navigator are discarded together.
class AccountSessionScope extends StatefulWidget {
  const AccountSessionScope({
    super.key,
    required this.createContainer,
    required this.child,
    this.observers = const [],
  });
  final ProviderContainer Function() createContainer;
  final Widget child;
  final List<NavigatorObserver> observers;
  @override
  State<AccountSessionScope> createState() => _AccountSessionScopeState();
}

class _AccountSessionScopeState extends State<AccountSessionScope> {
  final navigatorKey = GlobalKey<NavigatorState>();
  late final ProviderContainer container = widget.createContainer();
  @override
  void dispose() {
    container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: container,
    child: NavigatorPopHandler<Object?>(
      onPopWithResult: (result) => navigatorKey.currentState!.pop(result),
      child: Navigator(
        key: navigatorKey,
        observers: widget.observers,
        onGenerateRoute: (_) =>
            MaterialPageRoute<void>(builder: (_) => widget.child),
      ),
    ),
  );
}
