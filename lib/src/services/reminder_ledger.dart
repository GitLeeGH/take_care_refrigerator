import 'package:flutter/services.dart';
import 'verified_expiry_delivery.dart';

/// Native atomic store, not SharedPreferences caches or isolate-local locks.
/// Not connected to production opt-in/logout until background engine registration
/// and native notification dispatch share the same invalidation boundary.
class ReminderLedger {
  const ReminderLedger({MethodChannel? channel})
    : channel =
          channel ?? const MethodChannel('refrigerator/reminder_ledger_v1');
  final MethodChannel channel;
  Map<String, Object> _args(ReminderLease lease) => {
    'owner': lease.owner,
    'generation': lease.generation,
    'days': lease.daysBefore,
  };
  Future<ReminderLease> activate(String owner, int days) async {
    if (owner.isEmpty || ![1, 3, 7].contains(days)) {
      throw ArgumentError('Invalid reminder consent');
    }
    final generation = await channel.invokeMethod<String>('activate', {
      'owner': owner,
      'days': days,
    });
    if (generation == null || generation.isEmpty) {
      throw StateError('Consent not persisted');
    }
    return ReminderLease(owner, generation, days);
  }

  Future<void> invalidate() => channel.invokeMethod<void>('invalidate');
  Future<bool> current(ReminderLease lease) async =>
      await channel.invokeMethod<bool>('current', _args(lease)) == true;
  Future<bool> claim(ReminderLease lease, DateTime localDay) async {
    if (localDay.isUtc) throw ArgumentError('Local calendar required');
    final day =
        '${localDay.year.toString().padLeft(4, '0')}-${localDay.month.toString().padLeft(2, '0')}-${localDay.day.toString().padLeft(2, '0')}';
    return await channel.invokeMethod<bool>('claim', {
          ..._args(lease),
          'day': day,
        }) ==
        true;
  }
}

/// Restores an already-existing credential only in memory. Never refreshes or
/// persists tokens from a worker. Expired credentials require foreground login/
/// refresh and therefore skip delivery. Token objects never stringify their value.
class BackgroundCredential {
  BackgroundCredential(this.owner, this.token, this.expiresAt);
  final String owner, token;
  final DateTime expiresAt;
  @override
  String toString() => 'BackgroundCredential(redacted)';
}

abstract interface class BackgroundCredentialReader {
  /// Must bypass preference caches. Integration must be serialized with the
  /// foreground auth writer; no production reader is enabled yet.
  Future<BackgroundCredential?> readFresh();
}

class BackgroundAuthGuard {
  BackgroundAuthGuard(this.ledger, this.credentials, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final ReminderLedger ledger;
  final BackgroundCredentialReader credentials;
  final DateTime Function() now;
  Future<BackgroundCredential?> restore(ReminderLease lease) async {
    if (!await ledger.current(lease)) return null;
    final first = await credentials.readFresh();
    if (first == null ||
        first.owner != lease.owner ||
        first.token.isEmpty ||
        !first.expiresAt.isAfter(now().add(const Duration(seconds: 30)))) {
      return null;
    }
    if (!await ledger.current(lease)) return null;
    final second = await credentials.readFresh();
    if (second == null ||
        second.owner != first.owner ||
        second.token != first.token ||
        second.expiresAt != first.expiresAt ||
        !await ledger.current(lease) ||
        !second.expiresAt.isAfter(now().add(const Duration(seconds: 30)))) {
      return null;
    }
    return second;
  }
}
