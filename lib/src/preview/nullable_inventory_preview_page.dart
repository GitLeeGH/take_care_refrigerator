import 'package:flutter/material.dart';
import '../models.dart';
import '../services/expiry_compatibility.dart';
import '../services/receipt_import.dart';
import '../widgets/expiry_compatibility_card.dart';
import 'nullable_inventory_preview.dart';

/// Not registered in the app router. Local test harnesses instantiate this page.
class NullableInventoryPreviewPage extends StatefulWidget {
  const NullableInventoryPreviewPage({
    super.key,
    required this.memory,
    required this.now,
    this.recipes = const [],
    this.receipt,
  });
  final NullableInventoryMemory memory;
  final DateTime now;
  final List<Recipe> recipes;
  final ReceiptParseResult? receipt;
  @override
  State<NullableInventoryPreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<NullableInventoryPreviewPage> {
  int _nextId = 0;
  Future<void> _edit({
    NullableInventoryDraft? row,
    NullableReceiptCandidate? candidate,
  }) async {
    var draftId = row?.id;
    if (draftId == null) {
      do {
        draftId = 'local-${++_nextId}';
      } while (widget.memory.sorted.any((item) => item.id == draftId));
    }
    final draft = await showModalBottomSheet<NullableInventoryDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PreviewEditor(
        id: draftId!,
        row: row,
        candidate: candidate,
        now: widget.now,
      ),
    );
    if (!mounted || draft == null) return;
    setState(() => widget.memory.acceptLocalBatch([draft]));
  }

  Future<void> _receipt() async {
    final candidates = nullableReceiptCandidates(widget.receipt!);
    final selected = await showModalBottomSheet<NullableReceiptCandidate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('OCR 이후 후보 · 직접 선택하여 검토하세요. 날짜는 추정하지 않아요.'),
            ),
            for (final candidate in candidates)
              ListTile(
                title: Text(candidate.name),
                subtitle: Text(candidate.quantity ?? '수량 미확인'),
                onTap: () => Navigator.pop(context, candidate),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    await _edit(candidate: selected);
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.memory.sorted;
    final checks = checkNullableRecipes(widget.recipes, rows, widget.now);
    final reminders = previewNullableReminders(rows, widget.now);
    return Scaffold(
      appBar: AppBar(title: const Text('기한 미상 · 로컬 미리보기')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '테스트 전용 · 메모리에서만 동작합니다. 운영 등록 OFF · 서버·파일 저장 및 실제 알림 발송 없음.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _edit(),
                  child: const Text('수동 초안'),
                ),
                if (widget.receipt != null)
                  OutlinedButton(
                    onPressed: _receipt,
                    child: const Text('영수증 후보 검토'),
                  ),
                TextButton(
                  onPressed: () => setState(widget.memory.clear),
                  child: const Text('로컬 초안 비우기'),
                ),
              ],
            ),
            Text(
              '총 ${rows.length}개 · 기한 미상 ${rows.where((r) => r.expiry.actualDate == null).length}개',
            ),
            for (final row in rows)
              Card(
                child: ListTile(
                  title: Text(row.name),
                  subtitle: Text('${row.quantity}\n${row.actualLabel}'),
                  isThreeLine: true,
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      scrollable: true,
                      title: Text(row.name),
                      content: ExpiryCompatibilityCard(draft: row.expiry),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('닫기'),
                        ),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: '초안 수정',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(row: row),
                  ),
                ),
              ),
            const Text('추천 검토 · 날짜와 이름의 일치만 비교하며 섭취 안전을 판단하지 않아요.'),
            for (final check in checks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${check.recipe.name}\n날짜가 확인된 재료 일치 ${check.dated.ownedIngredients.length}/${check.dated.requiredIngredients.length}'
                  '${check.unknown.isEmpty ? '' : '\n기한 미상 확인 필요: ${check.unknown.join(', ')}'}',
                ),
              ),
            const Text('알림 미리보기 · 발송되지 않아요.'),
            if (reminders.isEmpty) const Text('표시할 알림 없음'),
            for (final reminder in reminders) Text(reminder.message),
          ],
        ),
      ),
    );
  }
}

class _PreviewEditor extends StatefulWidget {
  const _PreviewEditor({
    required this.id,
    required this.now,
    this.row,
    this.candidate,
  });
  final String id;
  final DateTime now;
  final NullableInventoryDraft? row;
  final NullableReceiptCandidate? candidate;
  @override
  State<_PreviewEditor> createState() => _PreviewEditorState();
}

class _PreviewEditorState extends State<_PreviewEditor> {
  late final TextEditingController name, quantity;
  DateTime? actual, reference;
  bool unknown = false, remind = false;
  String storage = '';
  String? error;
  @override
  void initState() {
    super.initState();
    final row = widget.row;
    name = TextEditingController(text: row?.name ?? widget.candidate?.name);
    quantity = TextEditingController(
      text: row?.quantity ?? widget.candidate?.quantity,
    );
    actual = row?.expiry.actualDate;
    reference = row?.expiry.referenceDate;
    unknown = row?.explicitlyUnknown ?? false;
    remind = row?.referenceReminder ?? false;
    storage = row?.storage ?? '';
  }

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isReference) async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: (isReference ? reference : actual) ?? widget.now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (isReference) {
        reference = chosen;
      } else {
        actual = chosen;
        unknown = false;
      }
    });
  }

  void _submit() {
    final draft = NullableInventoryDraft(
      id: widget.id,
      name: name.text,
      quantity: quantity.text,
      storage: storage,
      expiry: IngredientExpiryDraft(
        actualDate: actual,
        referenceDate: reference,
      ),
      explicitlyUnknown: unknown,
      referenceReminder: remind,
    );
    if (draft.errors.isNotEmpty) {
      setState(() => error = '확인 필요: ${draft.errors.join(', ')}');
      return;
    }
    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('로컬 초안 · 실제 등록 불가'),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: '재료명'),
          ),
          TextField(
            controller: quantity,
            decoration: const InputDecoration(labelText: '수량'),
          ),
          DropdownButtonFormField<String>(
            initialValue: storage.isEmpty ? null : storage,
            decoration: const InputDecoration(labelText: '보관 방식'),
            items: const [
              DropdownMenuItem(value: 'refrigerated', child: Text('냉장')),
              DropdownMenuItem(value: 'frozen', child: Text('냉동')),
              DropdownMenuItem(value: 'ambient', child: Text('실온')),
            ],
            onChanged: (value) => setState(() => storage = value ?? ''),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('실제 기한 미상으로 확인'),
            value: unknown,
            onChanged: (value) => setState(() {
              unknown = value ?? false;
              if (unknown) actual = null;
            }),
          ),
          OutlinedButton(
            onPressed: () => _pick(false),
            child: Text(
              actual == null ? '표시된 날짜 선택' : calendarDateText(actual!),
            ),
          ),
          OutlinedButton(
            onPressed: () => _pick(true),
            child: Text(
              reference == null
                  ? '참고 권장일 선택 (별도)'
                  : '참고 ${calendarDateText(reference!)}',
            ),
          ),
          const Text('참고 권장일을 선택해도 실제 날짜는 바뀌지 않아요. 안전 보증이 아닙니다.'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('참고 알림 미리보기 동의'),
            value: remind,
            onChanged: (value) => setState(() => remind = value),
          ),
          if (error != null) Text(error!),
          FilledButton(onPressed: _submit, child: const Text('로컬 모의 등록')),
        ],
      ),
    ),
  );
}
