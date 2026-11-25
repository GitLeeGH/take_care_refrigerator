import 'dart:convert';
import 'calendar_day.dart';
import 'expiry_compatibility.dart';
import 'inventory_quantity.dart';
import 'inventory_v2_draft.dart';

/// Offline planning only: no plugin, permission prompt, persistence or delivery.
/// Rebuild from a fresh snapshot on resume, clock changes and reboot.
class ExpiryReminderIntent {
  const ExpiryReminderIntent(
    this.key,
    this.ingredientId,
    this.at,
    this.daysLeft,
  );
  final String key, ingredientId;
  final DateTime at;
  final int daysLeft;
}

List<ExpiryReminderIntent> planExpiryReminders({
  required String owner,
  required String? Function() currentOwner,
  required List<InventoryV2Draft> inventory,
  required bool freshSnapshot,
  required bool enabled,
  required bool permissionGranted,
  required DateTime now,
  required int localHour,
  required int daysBefore,
}) {
  if (owner.isEmpty || currentOwner() != owner) {
    throw StateError('Stale reminder session');
  }
  if (now.isUtc ||
      localHour < 0 ||
      localHour > 23 ||
      !const [1, 3, 7].contains(daysBefore)) {
    throw ArgumentError('Explicit local clock and supported settings required');
  }
  if (!enabled || !permissionGranted || !freshSnapshot) return const [];
  var at = DateTime(now.year, now.month, now.day, localHour);
  if (!at.isAfter(now)) {
    at = DateTime(now.year, now.month, now.day + 1, localHour);
  }
  final result = <ExpiryReminderIntent>[];
  final ids = <String>{};
  for (final item in inventory) {
    if (item.owner != owner) throw StateError('Foreign reminder inventory');
    if (!ids.add(item.id)) throw StateError('Duplicate reminder item');
    final actual = item.expiry.actualDate;
    if (actual == null || isExplicitlyEmptyQuantity(item.quantity)) continue;
    final days = calendarDayDifference(actual, at);
    if (days < 0 || days > daysBefore) continue;
    // Internal logical key contains owner ID; never log or send externally.
    final key = jsonEncode([
      owner,
      item.id,
      calendarDateText(actual),
      calendarDateText(at),
      at.toUtc().toIso8601String(),
      localHour,
      daysBefore,
    ]);
    result.add(ExpiryReminderIntent(key, item.id, at, days));
  }
  if (currentOwner() != owner) throw StateError('Stale reminder session');
  result.sort((a, b) => a.key.compareTo(b.key));
  return List.unmodifiable(result);
}

/// Only keys previously issued by this planner may be cancelled. Caller must
/// keep the native ID ownership map separately; this never touches OS state.
Set<String> obsoleteReminderKeys(
  Iterable<ExpiryReminderIntent> previous,
  Iterable<ExpiryReminderIntent> desired,
) {
  final keep = desired.map((e) => e.key).toSet();
  return previous.map((e) => e.key).where((key) => !keep.contains(key)).toSet();
}
