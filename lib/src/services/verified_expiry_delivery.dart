import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'calendar_day.dart';
import 'inventory_quantity.dart';

// Remains OFF until durable cross-isolate opt-in/session/claim storage and
// Android reboot integration have been verified. Never restore cached content.
const recurringExpiryDeliveryEnabled = false;

class ReminderLease {
  const ReminderLease(this.owner, this.generation, this.daysBefore);
  final String owner, generation;
  final int daysBefore;
}

abstract interface class VerifiedExpirySource {
  Future<String?> verifiedOwner();
  Future<List<Map<String, dynamic>>> currentRows(String owner);
}

/// Network-only reads using the caller's authenticated client; no session
/// restoration, token refresh, credential persistence or privileged API.
class SupabaseVerifiedExpirySource implements VerifiedExpirySource {
  SupabaseVerifiedExpirySource(this.client);
  final SupabaseClient client;
  @override
  Future<String?> verifiedOwner() async =>
      (await client.auth.getUser()).user?.id;
  @override
  Future<List<Map<String, dynamic>>> currentRows(String owner) async =>
      await client
          .from('ingredients')
          .select('id,user_id,expiry_date,quantity')
          .eq('user_id', owner)
          .order('id')
          .limit(501);
}

abstract interface class VerifiedExpiryDestination {
  /// Must reload durable consent/session generation, including logout and OFF.
  Future<bool> leaseCurrent(ReminderLease lease);

  /// Read only: must not request OS permission from a background worker.
  Future<bool> permissionGranted();

  /// Must atomically persist the account/day claim across workers and reboots.
  /// A failed/uncertain delivery retains its claim (at-most-one attempt).
  Future<bool> claimDay(ReminderLease lease, String localDay);

  /// Must check lease again at the native boundary and display generic text
  /// without ingredient names, quantities or account information.
  Future<void> showGeneric(ReminderLease lease);
}

enum VerifiedDeliveryResult { sent, skipped, unavailable }

/// A scheduled wake-up is only a request to revalidate, never permission to send.
/// This coordinator is executable with adapters but is not registered as an
/// Android callback while the durable destination contract remains unverified.
class VerifiedExpiryDelivery {
  VerifiedExpiryDelivery(
    this.source,
    this.destination, {
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final VerifiedExpirySource source;
  final VerifiedExpiryDestination destination;
  final DateTime Function() now;
  Future<VerifiedDeliveryResult>? _pending;
  Future<VerifiedDeliveryResult> run(ReminderLease lease) =>
      _pending ??= _run(lease).whenComplete(() => _pending = null);

  Future<VerifiedDeliveryResult> _run(ReminderLease lease) async {
    final watch = Stopwatch()..start();
    Future<T> read<T>(Future<T> future) =>
        future.timeout(const Duration(seconds: 5));
    final start = now();
    bool timeValid() {
      final time = now();
      return !time.isUtc &&
          time.hour >= 9 &&
          time.hour < 12 &&
          time.year == start.year &&
          time.month == start.month &&
          time.day == start.day &&
          time.timeZoneOffset == start.timeZoneOffset &&
          !time.isBefore(start) &&
          time.difference(start).inSeconds <= 15 &&
          watch.elapsed <= const Duration(seconds: 15);
    }

    Future<bool> valid() async =>
        timeValid() &&
        await read(destination.leaseCurrent(lease)) &&
        await read(destination.permissionGranted()) &&
        timeValid();
    try {
      if (lease.owner.isEmpty ||
          lease.generation.isEmpty ||
          ![1, 3, 7].contains(lease.daysBefore) ||
          !await valid()) {
        return VerifiedDeliveryResult.skipped;
      }
      if (await read(source.verifiedOwner()) != lease.owner) {
        return VerifiedDeliveryResult.skipped;
      }
      final first = _snapshot(
        await read(source.currentRows(lease.owner)),
        lease,
        start,
      );
      if (!first.$2 || !await valid()) return VerifiedDeliveryResult.skipped;
      // Verify auth and refetch after initial query: deletion, edits and remote
      // changes observed between reads suppress the notification.
      if (await read(source.verifiedOwner()) != lease.owner) {
        return VerifiedDeliveryResult.skipped;
      }
      final second = _snapshot(
        await read(source.currentRows(lease.owner)),
        lease,
        start,
      );
      if (first.$1 != second.$1 || !second.$2 || !await valid()) {
        return VerifiedDeliveryResult.skipped;
      }
      final day = '${start.year}-${start.month}-${start.day}';
      if (!await read(destination.claimDay(lease, day)) || !await valid()) {
        return VerifiedDeliveryResult.skipped;
      }
      await destination.showGeneric(lease);
      return VerifiedDeliveryResult.sent;
    } catch (_) {
      // No raw exception, inventory or authentication data in logs.
      return VerifiedDeliveryResult.unavailable;
    }
  }

  (String, bool) _snapshot(
    List<Map<String, dynamic>> rows,
    ReminderLease lease,
    DateTime at,
  ) {
    if (rows.length > 500) throw const FormatException('Snapshot incomplete');
    final ids = <String>{};
    final values = <String>[];
    var eligible = false;
    for (final row in rows) {
      final id = row['id'],
          date = row['expiry_date'],
          quantity = row['quantity'];
      if (id is! String ||
          id.isEmpty ||
          !ids.add(id) ||
          row['user_id'] != lease.owner ||
          quantity is! String ||
          quantity.trim().isEmpty ||
          !row.containsKey('expiry_date')) {
        throw const FormatException('Invalid snapshot');
      }
      if (date != null) {
        if (date is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
          throw const FormatException('Invalid calendar date');
        }
        final parts = date.split('-').map(int.parse).toList();
        final parsed = DateTime(parts[0], parts[1], parts[2]);
        if (parsed.year != parts[0] ||
            parsed.month != parts[1] ||
            parsed.day != parts[2]) {
          throw const FormatException('Invalid calendar date');
        }
        final days = calendarDayDifference(parsed, at);
        eligible |=
            days >= 0 &&
            days <= lease.daysBefore &&
            !isExplicitlyEmptyQuantity(quantity);
      }
      values.add(jsonEncode([id, date, quantity]));
    }
    values.sort();
    return (jsonEncode(values), eligible);
  }
}
