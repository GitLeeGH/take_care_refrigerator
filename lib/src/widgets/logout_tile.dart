import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_gateway.dart';
import '../providers.dart';

class LogoutTile extends ConsumerStatefulWidget {
  const LogoutTile({super.key});
  @override
  ConsumerState<LogoutTile> createState() => _LogoutTileState();
}

class _LogoutTileState extends ConsumerState<LogoutTile> {
  bool busy = false;
  Future<void> logout() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      ref.read(notificationCleanupProvider)();
      await ref.read(authGatewayProvider).signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그아웃을 완료하지 못했어요. 연결을 확인하고 다시 시도해 주세요.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.logout),
    title: Text(busy ? '로그아웃 중…' : '로그아웃'),
    enabled: !busy,
    onTap: busy ? null : logout,
  );
}
