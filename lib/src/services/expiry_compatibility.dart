import 'calendar_day.dart';

/// Preparation only. Do not enable until schema and old-client rollout agree.
/// Deliberately not configurable by dart-define or remote flags yet.
const unknownExpiryRegistrationEnabled = false;
// Reader remains available when a deployed writer is frozen for rollback.
const unknownExpiryReadEnabled = false;

DateTime? _calendarDate(Object? value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Expected a calendar date');
  }
  final date = DateTime.parse(value);
  if (calendarDateText(date) != value) {
    throw const FormatException('Invalid calendar date');
  }
  return date;
}

String calendarDateText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// Read-only local compatibility projection, NOT the production Ingredient.
/// No default date, date inference, persistence, or network access is allowed.
class IngredientExpiryDraft {
  const IngredientExpiryDraft({this.actualDate, this.referenceDate});
  final DateTime? actualDate;
  // A separate user-reviewed/reference date; never promoted to actualDate.
  final DateTime? referenceDate;

  factory IngredientExpiryDraft.fromLocalJson(Map<String, Object?> value) =>
      IngredientExpiryDraft(
        actualDate: _calendarDate(value['expiry_date']),
        referenceDate: _calendarDate(value['reference_date']),
      );

  int? actualDaysLeft(DateTime now) {
    final date = actualDate;
    if (date == null) return null;
    return calendarDayDifference(date, now);
  }

  bool isConfirmedUsable(DateTime now) {
    final days = actualDaysLeft(now);
    return days != null && days >= 0;
  }

  bool isConfirmedExpiring(DateTime now) {
    final days = actualDaysLeft(now);
    return days != null && days >= 0 && days <= 3;
  }

  // Null also means no actual-expiry notification, regardless of reference date.
  int? actualExpiryAlertDays(DateTime now) {
    final days = actualDaysLeft(now);
    return days != null && days <= 3 ? days : null;
  }

  /// Known dates sort first; unknown dates need their own group, never a sentinel.
  int compareByActualDate(IngredientExpiryDraft other) {
    final a = actualDate;
    final b = other.actualDate;
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return compareCalendarDates(a, b);
  }

  Map<String, String> toLegacyExpiryFields() {
    final date = actualDate;
    if (date == null) {
      throw StateError('Unknown expiry registration is disabled');
    }
    return {'expiry_date': calendarDateText(date)};
  }
}

/// Fail before a production request. Updating unrelated fields may omit expiry;
/// explicit NULL and new rows with no date must never reach the legacy schema.
void validateLegacyExpiryWrite(
  Map<String, dynamic> data, {
  required bool editing,
}) {
  if (!editing || data.containsKey('expiry_date')) {
    if (_calendarDate(data['expiry_date']) == null) {
      throw StateError(
        'An explicit expiry date is required by the current schema',
      );
    }
  }
}
