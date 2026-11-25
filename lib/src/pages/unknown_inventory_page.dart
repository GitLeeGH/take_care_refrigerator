import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../unknown_inventory_provider.dart';
import '../services/ingredient_photo.dart';
import '../services/inventory_candidate_snapshot.dart';
import '../services/unknown_inventory_command.dart';
import '../services/unknown_inventory_controller.dart';
import '../widgets/ingredient_thumbnail.dart';

const _storageLabels = {'refrigerated': '냉장', 'frozen': '냉동', 'ambient': '실온'};

/// Separate, visible inventory avoids sending null dates to installed old apps.
class UnknownInventoryEntry extends ConsumerWidget {
  const UnknownInventoryEntry({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(unknownInventoryEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final controller = ref.watch(unknownInventoryControllerProvider);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.event_busy_outlined),
          title: Text(
            controller.loaded
                ? '기한 미정 재료 · ${controller.items.length}개'
                : '기한 미정 재료',
          ),
          subtitle: Text(
            controller.error != null
                ? '목록 확인 필요 · 눌러서 다시 시도'
                : '날짜 없이 저장 · 소비기한 알림 제외',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const UnknownInventoryPage(),
            ),
          ),
        ),
      ),
    );
  }
}

class UnknownInventoryPage extends ConsumerStatefulWidget {
  const UnknownInventoryPage({super.key});
  @override
  ConsumerState<UnknownInventoryPage> createState() =>
      _UnknownInventoryPageState();
}

class _UnknownInventoryPageState extends ConsumerState<UnknownInventoryPage>
    with WidgetsBindingObserver {
  String query = '', storage = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(unknownInventoryEnabledProvider)) {
        unawaited(ref.read(unknownInventoryControllerProvider).reload());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(unknownInventoryEnabledProvider)) {
      unawaited(ref.read(unknownInventoryControllerProvider).reload());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> remove(
    UnknownInventoryController c,
    InventoryCandidateItem item,
  ) async {
    final actor = c.owner;
    final epoch = c.epoch;
    if (actor == null || c.busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('기한 미정 재료를 삭제할까요?'),
        content: Text(item.value.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !c.isCurrent(actor, epoch)) return;
    await c.submit(
      UnknownInventoryCommand.delete(
        item: item,
        owner: actor,
        sessionEpoch: epoch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(unknownInventoryEnabledProvider)) {
      return Scaffold(
        appBar: AppBar(title: const Text('기한 미정')),
        body: const Center(child: Text('서버 호환성 확인 후 사용할 수 있어요.')),
      );
    }
    final c = ref.watch(unknownInventoryControllerProvider);
    final writesEnabled = ref.watch(unknownInventoryWritesEnabledProvider);
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final visible = c.items
            .where(
              (row) =>
                  row.value.name.toLowerCase().contains(query) &&
                  (storage.isEmpty || row.storageType == storage),
            )
            .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('기한 미정 재료')),
          body: RefreshIndicator(
            onRefresh: () async {
              await c.reload();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '소비기한을 모르는 재료를 날짜 없이 저장해요. 소비기한 알림과 기한 기반 추천에서 제외됩니다.',
                ),
                const SizedBox(height: 8),
                const Text(
                  '기한 미정은 안전하다는 뜻이 아니에요. 재료 상태를 직접 확인해 주세요. 구형 앱에는 이 목록이 보이지 않습니다.',
                ),
                const SizedBox(height: 16),
                if (!writesEnabled)
                  const Text('새 저장과 수정은 잠시 중단됐어요. 기존 기한 미정 재료는 계속 확인할 수 있어요.'),
                TextField(
                  onChanged: (v) =>
                      setState(() => query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    labelText: '기한 미정 재료 검색',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in {'': '전체', ..._storageLabels}.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: storage == entry.key,
                        onSelected: (_) => setState(() => storage = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (c.busy) const LinearProgressIndicator(),
                if (c.error != null)
                  Semantics(liveRegion: true, child: Text(c.error!)),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: c.busy ? null : c.reload,
                      child: const Text('목록 새로고침'),
                    ),
                    if (c.pendingCreate != null)
                      OutlinedButton(
                        onPressed: !writesEnabled || c.busy
                            ? null
                            : () => c.submit(c.pendingCreate!),
                        child: const Text('같은 등록 요청 다시 확인'),
                      ),
                  ],
                ),
                if (c.loaded && visible.isEmpty)
                  Text(
                    c.items.isEmpty
                        ? '기한 미정으로 저장한 재료가 없어요.'
                        : '조건에 맞는 재료가 없어요.',
                  ),
                for (final row in visible)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IngredientThumbnail(
                                name: row.value.name,
                                width: 48,
                                height: 48,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  row.value.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${row.value.quantity} · ${_storageLabels[row.storageType] ?? row.storageType} · 기한 미정',
                          ),
                          Wrap(
                            children: [
                              TextButton(
                                onPressed:
                                    !writesEnabled ||
                                        c.busy ||
                                        !c.canWrite ||
                                        c.pendingCreate != null
                                    ? null
                                    : () => showUnknownIngredientEditor(
                                        context,
                                        ref,
                                        item: row,
                                      ),
                                child: const Text('수정'),
                              ),
                              TextButton(
                                onPressed:
                                    !writesEnabled ||
                                        c.busy ||
                                        !c.canWrite ||
                                        c.pendingCreate != null
                                    ? null
                                    : () => remove(c, row),
                                child: const Text('삭제'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      !writesEnabled ||
                          c.busy ||
                          !c.canWrite ||
                          c.owner == null ||
                          c.pendingCreate != null
                      ? null
                      : () => showUnknownIngredientEditor(
                          context,
                          ref,
                          initialStorage: storage.isEmpty
                              ? 'refrigerated'
                              : storage,
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('기한 미정 재료 추가'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<bool> showUnknownIngredientEditor(
  BuildContext context,
  WidgetRef ref, {
  InventoryCandidateItem? item,
  String initialName = '',
  String initialQuantity = '',
  String initialStorage = 'refrigerated',
}) async {
  if (!ref.read(unknownInventoryEnabledProvider) ||
      !ref.read(unknownInventoryWritesEnabledProvider)) {
    return false;
  }
  final c = ref.read(unknownInventoryControllerProvider);
  if (c.owner == null || !c.canWrite || c.busy || c.pendingCreate != null) {
    return false;
  }
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: false,
        builder: (_) => _UnknownEditor(
          controller: c,
          item: item,
          initialName: initialName,
          initialQuantity: initialQuantity,
          initialStorage: initialStorage,
        ),
      ) ??
      false;
}

class _UnknownEditor extends StatefulWidget {
  const _UnknownEditor({
    required this.controller,
    this.item,
    required this.initialName,
    required this.initialQuantity,
    required this.initialStorage,
  });
  final UnknownInventoryController controller;
  final InventoryCandidateItem? item;
  final String initialName, initialQuantity, initialStorage;
  @override
  State<_UnknownEditor> createState() => _UnknownEditorState();
}

class _UnknownEditorState extends State<_UnknownEditor> {
  late final name = TextEditingController(
    text: widget.item?.value.name ?? widget.initialName,
  );
  late final quantity = TextEditingController(
    text: widget.item?.value.quantity ?? widget.initialQuantity,
  );
  late String storage = widget.item?.storageType ?? widget.initialStorage;
  late final actor = widget.controller.owner;
  late final epoch = widget.controller.epoch;
  final requestId = newIngredientUuid();
  bool confirmed = false,
      busy = false,
      exitApproved = false,
      confirmingExit = false;
  String? error;
  UnknownInventoryCommand? operation;
  bool get current => widget.controller.isCurrent(actor, epoch);
  bool get locked => busy || operation != null || !current;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
  }

  void changed() {
    if (!current) {
      name.clear();
      quantity.clear();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    name.dispose();
    quantity.dispose();
    super.dispose();
  }

  Future<void> close() async {
    if (busy || confirmingExit) return;
    if (!current ||
        (name.text.isEmpty && quantity.text.isEmpty && operation == null)) {
      setState(() => exitApproved = true);
      Navigator.pop(context);
      return;
    }
    confirmingExit = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('입력을 종료할까요?'),
        content: Text(
          operation == null
              ? '저장하지 않은 변경은 사라져요.'
              : '저장됐을 수도 있어요. 재등록 전에 목록을 확인해 주세요. 확인되지 않은 등록 요청은 목록에서 다시 확인할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 입력'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    confirmingExit = false;
    if (mounted && leave == true) {
      setState(() => exitApproved = true);
      Navigator.pop(context);
    }
  }

  Future<void> save() async {
    if (busy || !current) return;
    try {
      if (!confirmed) throw const FormatException('기한 미정 확인이 필요해요.');
      operation ??= widget.item == null
          ? UnknownInventoryCommand.create(
              owner: actor!,
              sessionEpoch: epoch,
              requestId: requestId,
              name: name.text,
              quantity: quantity.text,
              storage: storage,
            )
          : UnknownInventoryCommand.edit(
              item: widget.item!,
              owner: actor!,
              sessionEpoch: epoch,
              name: name.text,
              quantity: quantity.text,
              storage: storage,
            );
    } catch (_) {
      setState(() => error = '재료명·수량을 입력하고 기한 미정에 체크해 주세요.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final saved = await widget.controller.submit(operation!);
      if (!mounted || !current) return;
      if (saved) {
        setState(() {
          busy = false;
          exitApproved = true;
        });
        Navigator.pop(context, true);
      } else {
        setState(
          () => error = widget.controller.error ?? '목록을 확인한 뒤 다시 시도해 주세요.',
        );
      }
    } catch (_) {
      if (mounted && current) {
        setState(() => error = '로그인 상태가 변경됐어요. 목록으로 돌아가 주세요.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: exitApproved,
    onPopInvokedWithResult: (popped, _) {
      if (!popped) close();
    },
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.item == null ? '기한 미정으로 저장' : '기한 미정 재료 수정',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!current)
              const Text('계정이 변경되어 입력을 취소했어요. 창을 닫아 주세요.')
            else ...[
              const Text('날짜를 만들지 않고 저장하며, 소비기한 알림에서 제외해요. 구형 앱에는 표시되지 않습니다.'),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                enabled: !locked,
                maxLength: 200,
                decoration: const InputDecoration(labelText: '재료명'),
              ),
              TextField(
                controller: quantity,
                enabled: !locked,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: '수량 (예: 1개, 200g)',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in _storageLabels.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: storage == e.key,
                      onSelected: locked
                          ? null
                          : (_) => setState(() => storage = e.key),
                    ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: confirmed,
                onChanged: locked
                    ? null
                    : (v) => setState(() => confirmed = v ?? false),
                title: const Text('소비기한을 몰라요 · 기한 미정으로 저장'),
              ),
              const Text(
                '현재 기한 미정 재료는 이름·수량·보관 장소를 저장해요. 사진 첨부와 날짜 있는 재료로의 전환은 아직 지원하지 않아요. 기한 미정은 안전하다는 뜻이 아닙니다.',
              ),
              if (error != null)
                Semantics(liveRegion: true, child: Text(error!)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed:
                    busy ||
                        (operation != null &&
                            !widget.controller.isPending(operation!))
                    ? null
                    : save,
                child: Text(
                  busy
                      ? '저장 확인 중…'
                      : operation == null
                      ? '저장'
                      : '같은 등록 요청 다시 확인',
                ),
              ),
            ],
            TextButton(onPressed: busy ? null : close, child: const Text('닫기')),
          ],
        ),
      ),
    ),
  );
}
