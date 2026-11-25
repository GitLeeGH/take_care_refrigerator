import 'dart:math';
import 'package:flutter/material.dart';
import '../services/inventory_candidate_snapshot.dart';
import '../services/unknown_inventory_command.dart';
import 'unknown_preview_store.dart';

/// Test harness only. Never registered in the production router.
class UnknownInventoryPreviewPage extends StatelessWidget {
  const UnknownInventoryPreviewPage({super.key, required this.controller});
  final UnknownPreviewController controller;
  String _requestId() {
    final r = Random.secure();
    final b = List.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> edit(
    BuildContext context, [
    InventoryCandidateItem? item,
  ]) async {
    final actor = controller.owner;
    final epoch = controller.epoch;
    if (actor == null || controller.busy) {
      return;
    }
    final command = await showModalBottomSheet<UnknownInventoryCommand>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _Editor(
        controller: controller,
        owner: actor,
        epoch: epoch,
        requestId: _requestId(),
        item: item,
      ),
    );
    if (command != null && !controller.disposed) {
      await controller.submit(command);
    }
  }

  Future<void> remove(BuildContext context, InventoryCandidateItem item) async {
    final actor = controller.owner;
    final epoch = controller.epoch;
    if (actor == null) {
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모의 재료 삭제'),
        content: const Text('이 미리보기 목록에서 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제 확인'),
          ),
        ],
      ),
    );
    if (yes == true && !controller.disposed) {
      await controller.submit(
        UnknownInventoryCommand.delete(
          item: item,
          owner: actor,
          sessionEpoch: epoch,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('기한 미정 · 격리 미리보기')),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('모의 저장만 사용합니다. 운영 기능 OFF · 앱 종료 후 보존되지 않습니다.'),
            const Text('기한 미정 재료는 새 버전에서만 표시됩니다. 구형 앱에서는 보이지 않습니다.'),
            const Text('기한 미상은 안전하다는 뜻이 아닙니다. 재료 상태를 직접 확인해 주세요.'),
            if (controller.owner == null) const Text('테스트 계정을 선택해 주세요.'),
            if (controller.busy) const Text('처리 중'),
            if (controller.error != null)
              Semantics(liveRegion: true, child: Text(controller.error!)),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: controller.busy || controller.owner == null
                      ? null
                      : controller.reload,
                  child: const Text('목록 다시 확인'),
                ),
                FilledButton(
                  onPressed:
                      controller.busy ||
                          controller.owner == null ||
                          controller.retryCreate != null
                      ? null
                      : () => edit(context),
                  child: const Text('미정 재료 추가'),
                ),
                if (controller.retryCreate != null)
                  OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () => controller.submit(controller.retryCreate!),
                    child: const Text('같은 등록 요청 재확인'),
                  ),
              ],
            ),
            if (!controller.busy &&
                controller.error == null &&
                controller.owner != null &&
                controller.items.isEmpty)
              const Text('등록된 모의 재료가 없습니다.'),
            for (final row in controller.items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.value.name),
                      Text('${row.value.quantity} · ${row.value.expiryLabel}'),
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: controller.busy
                                ? null
                                : () => edit(context, row),
                            child: const Text('수정'),
                          ),
                          TextButton(
                            onPressed: controller.busy
                                ? null
                                : () => remove(context, row),
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Editor extends StatefulWidget {
  const _Editor({
    required this.controller,
    required this.owner,
    required this.epoch,
    required this.requestId,
    this.item,
  });
  final UnknownPreviewController controller;
  final String owner, requestId;
  final int epoch;
  final InventoryCandidateItem? item;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final TextEditingController name = TextEditingController(
    text: widget.item?.value.name ?? '',
  );
  late final TextEditingController quantity = TextEditingController(
    text: widget.item?.value.quantity ?? '',
  );
  late String storage = widget.item?.storageType ?? 'refrigerated';
  bool confirmed = false;
  String? error;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
  }

  void changed() {
    if (widget.controller.epoch != widget.epoch) {
      name.clear();
      quantity.clear();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    name.dispose();
    quantity.dispose();
    super.dispose();
  }

  void save() {
    try {
      if (!confirmed) {
        throw StateError('Confirm unknown');
      }
      final c = widget.item == null
          ? UnknownInventoryCommand.create(
              owner: widget.owner,
              sessionEpoch: widget.epoch,
              requestId: widget.requestId,
              name: name.text,
              quantity: quantity.text,
              storage: storage,
            )
          : UnknownInventoryCommand.edit(
              item: widget.item!,
              owner: widget.owner,
              sessionEpoch: widget.epoch,
              name: name.text,
              quantity: quantity.text,
              storage: storage,
            );
      c.validateContext(
        currentOwner: widget.controller.owner,
        currentEpoch: widget.controller.epoch,
      );
      Navigator.pop(context, c);
    } catch (_) {
      setState(() => error = '이름·수량과 기한 미상 확인을 입력해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      16,
      16,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => widget.controller.epoch != widget.epoch
            ? const Text('계정이 변경되어 입력을 취소했습니다. 창을 닫아 주세요.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: '재료 이름'),
                  ),
                  TextField(
                    controller: quantity,
                    decoration: const InputDecoration(labelText: '수량'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: storage,
                    items: [
                      if (![
                        'refrigerated',
                        'frozen',
                        'ambient',
                      ].contains(storage))
                        DropdownMenuItem(value: storage, child: Text(storage)),
                      const DropdownMenuItem(
                        value: 'refrigerated',
                        child: Text('냉장'),
                      ),
                      const DropdownMenuItem(
                        value: 'frozen',
                        child: Text('냉동'),
                      ),
                      const DropdownMenuItem(
                        value: 'ambient',
                        child: Text('실온'),
                      ),
                    ],
                    onChanged: (v) => setState(() => storage = v!),
                    decoration: const InputDecoration(labelText: '보관 장소'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: confirmed,
                    onChanged: (v) => setState(() => confirmed = v ?? false),
                    title: const Text('실제 소비기한을 모릅니다'),
                  ),
                  if (error != null) Text(error!),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('취소'),
                      ),
                      FilledButton(onPressed: save, child: const Text('모의 저장')),
                    ],
                  ),
                ],
              ),
      ),
    ),
  );
}
