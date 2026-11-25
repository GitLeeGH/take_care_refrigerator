import 'package:flutter/material.dart';
import '../services/meal_history.dart';
import '../services/curation_foundation.dart';

class MealHistoryCard extends StatelessWidget {
  const MealHistoryCard({super.key, required this.store, required this.today});
  final MealHistoryStore store;
  final MealDay today;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final records = _latestMeals(store);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('먹은 음식 기록', style: Theme.of(context).textTheme.titleLarge),
              const Text(
                '식사 기록은 이 기기에만 저장되며 다른 기기와 동기화되지 않아요. 앱을 삭제하거나 앱 데이터를 지우면 기록이 사라져요.',
              ),
              const Text('이번 주는 월요일부터 일요일까지예요.'),
              if (store.owner == null)
                const Text('로그인 후 기록할 수 있어요.')
              else if (store.busy)
                const LinearProgressIndicator()
              else if (store.failed)
                TextButton(
                  onPressed: store.load,
                  child: const Text('기록을 확인하지 못했어요 · 다시 불러오기'),
                )
              else if (records.isEmpty)
                const Text('아직 기록이 없어요. 먹은 메뉴를 직접 남겨 주세요.'),
              FilledButton.icon(
                onPressed:
                    store.owner == null ||
                        store.busy ||
                        store.failed ||
                        store.snapshot == null
                    ? null
                    : () => _edit(context),
                icon: const Icon(Icons.restaurant),
                label: const Text('먹었어요 · 기록 추가'),
              ),
              for (final record in records.take(7))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(record.name),
                  subtitle: Text(_date(record.day)),
                  trailing: IconButton(
                    tooltip: '${record.name} 기록 수정 또는 삭제',
                    onPressed: store.busy || store.failed
                        ? null
                        : () => _edit(context, record),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              if (records.length > 7)
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('전체 식사 기록'),
                      content: SizedBox(
                        width: 400,
                        height: 360,
                        child: ListenableBuilder(
                          listenable: store,
                          builder: (context, _) => ListView(
                            children: [
                              for (final r in _latestMeals(store))
                                ListTile(
                                  title: Text(r.name),
                                  subtitle: Text(_date(r.day)),
                                  onTap: store.busy || store.failed
                                      ? null
                                      : () => _edit(context, r),
                                ),
                            ],
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('닫기'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('전체 기록 · 수정 및 삭제'),
                ),
            ],
          ),
        ),
      );
    },
  );
  Future<void> _edit(BuildContext context, [MealRecord? record]) =>
      showDialog<void>(
        context: context,
        builder: (_) => _MealEditor(store: store, today: today, record: record),
      );
}

List<MealRecord> _latestMeals(MealHistoryStore store) =>
    (store.snapshot?.records.toList() ?? <MealRecord>[])
      ..sort((a, b) => b.day.compareTo(a.day));

String _date(MealDay d) =>
    '${d.value.year}-${d.value.month.toString().padLeft(2, '0')}-${d.value.day.toString().padLeft(2, '0')}';

class _MealEditor extends StatefulWidget {
  const _MealEditor({required this.store, required this.today, this.record});
  final MealHistoryStore store;
  final MealDay today;
  final MealRecord? record;
  @override
  State<_MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends State<_MealEditor> {
  late final String account;
  late final int epoch;
  late final int revision;
  late final controller = TextEditingController(
    text: widget.record?.name ?? '',
  );
  late MealDay day = widget.record?.day ?? widget.today;
  bool saving = false, confirmDelete = false;
  String? error;
  bool get current =>
      account == widget.store.owner && epoch == widget.store.generation;
  @override
  void initState() {
    super.initState();
    account = widget.store.owner!;
    epoch = widget.store.generation;
    revision = widget.store.snapshot!.revision;
    widget.store.addListener(_changed);
  }

  void _changed() {
    if (!current) {
      controller.clear();
      day = widget.today;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.store.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  Future<void> _save({bool delete = false}) async {
    if (saving || !current) return;
    if (!delete && controller.text.trim().isEmpty) {
      setState(() => error = '음식 이름을 입력해 주세요.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.store.save(
        account: account,
        epoch: epoch,
        revision: revision,
        name: controller.text,
        day: day,
        today: widget.today,
        id: widget.record?.id,
        delete: delete,
      );
      if (mounted && current) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => error = '저장 결과를 확인하지 못했어요. 닫은 뒤 기록을 다시 불러와 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.record == null ? '먹은 음식 기록' : '기록 수정'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!current)
            const Text('계정이 바뀌었어요. 닫고 다시 열어 주세요.')
          else ...[
            TextField(
              controller: controller,
              maxLength: 120,
              enabled: !saving,
              decoration: const InputDecoration(
                labelText: '음식 이름',
                hintText: '예: 김치볶음밥',
              ),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: day.compareTo(widget.today) > 0
                            ? widget.today.value
                            : day.value,
                        firstDate: DateTime(1900),
                        lastDate: widget.today.value,
                      );
                      if (mounted && current && selected != null) {
                        setState(
                          () => day = MealDay(
                            selected.year,
                            selected.month,
                            selected.day,
                          ),
                        );
                      }
                    },
              child: Text('먹은 날짜 ${_date(day)}'),
            ),
            if (confirmDelete)
              const Text('이 식사 기록을 삭제할까요? 냉장고 재료와 좋아요는 바뀌지 않아요.'),
            if (error != null) Semantics(liveRegion: true, child: Text(error!)),
            if (saving) const LinearProgressIndicator(),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
      if (current && widget.record != null)
        TextButton(
          onPressed: saving
              ? null
              : () {
                  if (confirmDelete) {
                    _save(delete: true);
                  } else {
                    setState(() => confirmDelete = true);
                  }
                },
          child: Text(confirmDelete ? '삭제 확인' : '삭제'),
        ),
      if (current)
        FilledButton(onPressed: saving ? null : _save, child: const Text('저장')),
    ],
  );
}
