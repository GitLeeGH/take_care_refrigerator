import '../ingredient_matching.dart';
import '../models.dart';
import '../services/expiry_compatibility.dart';
import '../services/receipt_import.dart';

/// Offline rollout rehearsal. No database client, file persistence or user data.
class NullableInventoryDraft {
  const NullableInventoryDraft({
    required this.id,
    required this.name,
    required this.quantity,
    required this.storage,
    required this.expiry,
    this.explicitlyUnknown = false,
    this.referenceReminder = false,
  });
  final String id, name, quantity, storage;
  final IngredientExpiryDraft expiry;
  final bool explicitlyUnknown, referenceReminder;

  List<String> get errors => [
    if (name.trim().isEmpty) '재료명',
    if (quantity.trim().isEmpty) '수량',
    if (!['refrigerated', 'frozen', 'ambient'].contains(storage)) '보관 방식',
    if (expiry.actualDate == null && !explicitlyUnknown) '날짜 선택 또는 기한 미상 확인',
    if (expiry.actualDate != null && explicitlyUnknown) '날짜와 미상 상태 충돌',
    if (referenceReminder && expiry.referenceDate == null) '참고 알림 날짜',
  ];
  String get actualLabel => expiry.actualDate == null
      ? '소비기한 미상 · 상태 확인 필요'
      : '표시된 날짜 ${calendarDateText(expiry.actualDate!)}';
}

class NullableInventoryMemory {
  final _rows = <String, NullableInventoryDraft>{};
  List<NullableInventoryDraft> get sorted {
    final result = _rows.values.toList();
    result.sort((a, b) {
      final date = a.expiry.compareByActualDate(b.expiry);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    return List.unmodifiable(result);
  }

  // Validate the whole batch first: no partial rows, no placeholder dates.
  void acceptLocalBatch(Iterable<NullableInventoryDraft> drafts) {
    final values = List<NullableInventoryDraft>.of(drafts);
    if (values.map((e) => e.id).toSet().length != values.length ||
        values.any((e) => e.id.isEmpty || e.errors.isNotEmpty)) {
      throw StateError('Review every local draft before accepting the batch');
    }
    for (final row in values) {
      _rows[row.id] = row;
    }
  }

  void clear() => _rows.clear();
}

class NullableRecipeCheck {
  NullableRecipeCheck(
    this.recipe,
    List<NullableInventoryDraft> rows,
    DateTime now,
  ) : dated = IngredientAvailability(
        recipe.requiredIngredients,
        rows.where((r) => r.expiry.isConfirmedUsable(now)).map((r) => r.name),
      ),
      unknown = IngredientAvailability(
        recipe.requiredIngredients,
        rows.where((r) => r.expiry.actualDate == null).map((r) => r.name),
      ).ownedIngredients;
  final Recipe recipe;
  // This describes only name/date matching, never edible/safe status.
  final IngredientAvailability dated;
  final List<String> unknown;
}

List<NullableRecipeCheck> checkNullableRecipes(
  List<Recipe> recipes,
  List<NullableInventoryDraft> rows,
  DateTime now,
) {
  final result = recipes.map((r) => NullableRecipeCheck(r, rows, now)).toList();
  result.sort((a, b) {
    final availability = compareIngredientAvailability(a.dated, b.dated);
    return availability != 0
        ? availability
        : a.recipe.id.compareTo(b.recipe.id);
  });
  return result;
}

enum PreviewReminderKind { actualExpiry, reference }

class PreviewReminder {
  const PreviewReminder(this.itemId, this.kind, this.message);
  final String itemId, message;
  final PreviewReminderKind kind;
}

List<PreviewReminder> previewNullableReminders(
  List<NullableInventoryDraft> rows,
  DateTime now,
) => [
  for (final row in rows) ...[
    if (row.expiry.actualExpiryAlertDays(now) != null)
      PreviewReminder(
        row.id,
        PreviewReminderKind.actualExpiry,
        '${row.name} · 표시된 날짜 ${calendarDateText(row.expiry.actualDate!)} · 상태를 확인하세요.',
      ),
    if (row.referenceReminder &&
        row.expiry.referenceDate != null &&
        IngredientExpiryDraft(
              actualDate: row.expiry.referenceDate,
            ).actualDaysLeft(now)! <=
            0)
      PreviewReminder(
        row.id,
        PreviewReminderKind.reference,
        '${row.name} · 참고 권장일 ${calendarDateText(row.expiry.referenceDate!)} · 실제 소비기한이나 안전 보증이 아닙니다.',
      ),
  ],
];

class NullableReceiptCandidate {
  const NullableReceiptCandidate(this.name, this.quantity);
  final String name;
  final String? quantity;
}

/// Actual parser output only. Candidates still require explicit user review;
/// OCR provides neither an actual expiry nor a reference date.
List<NullableReceiptCandidate> nullableReceiptCandidates(
  ReceiptParseResult parsed,
) => [
  for (var i = 0; i < parsed.items.length; i++)
    NullableReceiptCandidate(parsed.items[i], parsed.quantities[i]),
  for (final row in parsed.review.where((r) => r.isCandidate))
    NullableReceiptCandidate(row.text, row.quantity),
];
