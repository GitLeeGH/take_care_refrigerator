import 'package:flutter/material.dart';
import '../theme.dart';

/// Serializes confirmation and the server request without popping other routes.
class AccountDeletionTile extends StatefulWidget {
  const AccountDeletionTile({super.key, required this.onDelete});
  final Future<void> Function() onDelete;

  @override
  State<AccountDeletionTile> createState() => _AccountDeletionTileState();
}

class _AccountDeletionTileState extends State<AccountDeletionTile> {
  bool _confirming = false;
  bool _busy = false;

  Future<void> _confirm() async {
    if (_confirming || _busy) return;
    setState(() => _confirming = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('계정 삭제'),
          content: const Text('정말로 계정을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: dangerInk),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      setState(() => _busy = true);
      await widget.onDelete();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '계정 삭제를 완료하지 못했어요. 일부 작업이 처리되었을 수 있습니다. 잠시 후 다시 시도해 주세요.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: _busy
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: dangerInk),
          )
        : const Icon(Icons.delete_outline, color: dangerInk),
    title: Semantics(
      liveRegion: true,
      child: Text(
        _busy ? '계정을 삭제하고 있습니다…' : '계정 삭제',
        style: const TextStyle(color: dangerInk, fontWeight: FontWeight.w600),
      ),
    ),
    subtitle: const Text(
      '계정과 모든 데이터가 영구적으로 삭제됩니다',
      style: TextStyle(fontSize: 12, color: mediumGray),
    ),
    enabled: !_confirming && !_busy,
    onTap: _confirming || _busy ? null : _confirm,
  );
}
