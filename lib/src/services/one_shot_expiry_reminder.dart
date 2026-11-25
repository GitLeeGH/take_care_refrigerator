import 'one_shot_receipt.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models.dart';
import 'calendar_day.dart';
import 'inventory_quantity.dart';

abstract class ExpiryReminderPlatform {
  Future<bool> permission();
  Future<void> cancelOwned();
  Future<void> schedule(DateTime at);
}

abstract interface class OwnedReservationProbe {
  Future<bool> hasOwnedPending({String? salt});
}

abstract interface class ReceiptSchedulePlatform {
  Future<void> scheduleWithProof(DateTime at, String salt);
}

enum OneShotStatus {
  idle,
  busy,
  cancelling,
  scheduled,
  denied,
  stale,
  empty,
  failed,
}

DateTime? nextExpiryReminder(
  List<Ingredient> items,
  DateTime now,
  int daysBefore,
) {
  if (now.isUtc || ![1, 3, 7].contains(daysBefore)) {
    throw ArgumentError('Local clock and supported window required');
  }
  final at = DateTime(now.year, now.month, now.day + 1, 9);
  final hasItem = items.any((item) {
    final days = calendarDayDifference(item.expiryDate, at);
    return !isExplicitlyEmptyQuantity(item.quantity) &&
        days >= 0 &&
        days <= daysBefore;
  });
  return hasItem ? at : null;
}

/// Value identity, independent of stream wrapper allocation and row ordering.
/// Kept in memory only; never persist/log inventory fields in notification data.
String reminderInventoryIdentity(List<Ingredient> items) {
  final rows =
      items
          .map(
            (item) => jsonEncode([
              item.id,
              item.name,
              item.quantity,
              item.expiryDate.year,
              item.expiryDate.month,
              item.expiryDate.day,
              item.storageType,
            ]),
          )
          .toList()
        ..sort();
  return jsonEncode(rows);
}

/// Explicit one-shot opt-in, no stored account, food names or repeating timer.
/// Invalidation increments synchronously; slow native work is cleaned in order.
class OneShotExpiryReminder {
  OneShotExpiryReminder(this.platform, {this.store, DateTime Function()? now})
    : now = now ?? DateTime.now;
  final ReservationStore? store;
  final DateTime Function() now;
  bool recoveryPending = false;
  ReceiptSnapshot? _recovery;
  static final instance = OneShotExpiryReminder(
    AndroidExpiryReminderPlatform(),
    store: const NativeReservationStore(),
  );
  final ExpiryReminderPlatform platform;
  final status = ValueNotifier(OneShotStatus.idle);
  Future<void> _tail = Future.value();
  int _epoch = 0;
  Future<void> _queue(Future<void> Function() action) {
    final job = _tail.then((_) => action());
    _tail = job.catchError((Object _) {});
    return job;
  }

  Future<void> cancel({bool needsRebooking = false}) {
    final hadReservation =
        recoveryPending ||
        status.value == OneShotStatus.scheduled ||
        status.value == OneShotStatus.busy ||
        status.value == OneShotStatus.stale;
    recoveryPending = false;
    _recovery = null;
    if (status.value == OneShotStatus.cancelling) return _tail;
    final epoch = ++_epoch;
    status.value = OneShotStatus.cancelling;
    return _queue(() async {
      try {
        try {
          await store?.clear();
        } finally {
          await platform.cancelOwned();
        }
        if (epoch == _epoch) {
          status.value = needsRebooking && hadReservation
              ? OneShotStatus.stale
              : OneShotStatus.idle;
        }
      } catch (_) {
        if (epoch == _epoch) status.value = OneShotStatus.failed;
      }
    });
  }

  Future<void> prepareStartup() {
    recoveryPending = true;
    return _queue(() async {
      var nativeRemoved = false;
      try {
        var hadPending = false;
        try {
          _recovery = await store?.read();
          if (platform is OwnedReservationProbe) {
            hadPending = await (platform as OwnedReservationProbe)
                .hasOwnedPending(salt: _recovery?.proof?.salt);
          }
        } finally {
          await platform
              .cancelOwned(); // Never wait for network while old static alarm remains.
          nativeRemoved = true;
        }
        if (_recovery?.proof == null || !hadPending) {
          if (_recovery?.proof != null || hadPending) {
            await store?.clear();
            status.value = OneShotStatus.stale;
          }
          recoveryPending = false;
          return;
        }
        if (!_recovery!.proof!.committed) {
          throw StateError('Uncommitted reservation');
        }
      } catch (_) {
        recoveryPending = false;
        _recovery = null;
        try {
          await store?.clear();
        } catch (_) {}
        status.value = nativeRemoved
            ? OneShotStatus.stale
            : OneShotStatus.failed;
      }
    });
  }

  Future<void> recover({
    required Future<VerifiedReservationState> Function() verify,
    required bool Function() stillValid,
  }) {
    final epoch = _epoch;
    return _queue(() async {
      if (!recoveryPending) return;
      final saved = _recovery;
      recoveryPending = false;
      _recovery = null;
      if (saved?.proof == null) return;
      final proof = saved!.proof!;
      status.value = OneShotStatus.busy;
      bool valid() => epoch == _epoch && stillValid();
      try {
        final fresh = await verify().timeout(const Duration(seconds: 15));
        if (!valid() ||
            !proof.matches(fresh.owner, fresh.inventory, fresh.days, now())) {
          throw StateError('Unverified reservation');
        }
        // CAS also rejects logout/OFF or a newer request from another engine.
        final stage = ReservationProof(
          proof.salt,
          proof.owner,
          proof.stock,
          proof.days,
          proof.due,
          proof.offset,
          false,
        );
        final revision = await store!.write(saved.revision, stage);
        if (!valid()) throw StateError('Reservation changed');
        await _schedule(
          proof.due,
          proof,
        ); // Existing permission only, no prompt.
        if (!valid()) throw StateError('Reservation changed');
        await store!.write(revision, proof);
        if (!valid()) throw StateError('Reservation changed');
        status.value = OneShotStatus.scheduled;
      } catch (_) {
        var removed = true;
        try {
          try {
            await store?.clear();
          } finally {
            await platform.cancelOwned();
          }
        } catch (_) {
          removed = false;
        }
        if (epoch == _epoch) {
          status.value = removed ? OneShotStatus.stale : OneShotStatus.failed;
        }
      }
    });
  }

  Future<void> _schedule(DateTime at, ReservationProof? proof) {
    if (store == null) return platform.schedule(at);
    if (proof == null || platform is! ReceiptSchedulePlatform) {
      throw StateError('Unbound reservation');
    }
    return (platform as ReceiptSchedulePlatform).scheduleWithProof(
      at,
      proof.salt,
    );
  }

  Future<void> request({
    required DateTime? at,
    required bool Function() stillValid,
    ReservationProof? proof,
  }) {
    if (status.value == OneShotStatus.busy ||
        status.value == OneShotStatus.cancelling) {
      return Future.value();
    }
    final epoch = ++_epoch;
    status.value = OneShotStatus.busy;
    bool valid() => epoch == _epoch && stillValid();
    return _queue(() async {
      try {
        await store?.clear();
        await platform.cancelOwned();
        if (!valid()) {
          if (epoch == _epoch) status.value = OneShotStatus.stale;
          return;
        }
        if (at == null) {
          status.value = OneShotStatus.empty;
          return;
        }
        final granted = await platform.permission(); // only after explicit tap
        if (!valid()) {
          if (epoch == _epoch) status.value = OneShotStatus.stale;
          return;
        }
        if (!granted) {
          status.value = OneShotStatus.denied;
          return;
        }
        String? revision;
        if (store != null) {
          if (proof == null || proof.due != at) {
            throw StateError('Missing reservation proof');
          }
          final snapshot = await store!.read();
          revision = await store!.write(snapshot.revision, proof);
          if (!valid()) throw StateError('Reservation changed');
        }
        await _schedule(at, proof);
        if (!valid()) {
          await platform.cancelOwned();
          if (epoch == _epoch) status.value = OneShotStatus.stale;
          return;
        }
        if (store != null) {
          await store!.write(revision!, proof!.commit());
          if (!valid()) throw StateError('Reservation changed');
        }
        status.value = OneShotStatus.scheduled;
      } catch (_) {
        // A failed native call may have committed. Best-effort owned cleanup.
        try {
          try {
            await store?.clear();
          } finally {
            await platform.cancelOwned();
          }
        } catch (_) {}
        if (epoch == _epoch) status.value = OneShotStatus.failed;
      }
    });
  }
}

class AndroidExpiryReminderPlatform
    implements
        ExpiryReminderPlatform,
        OwnedReservationProbe,
        ReceiptSchedulePlatform {
  @override
  Future<bool> hasOwnedPending({String? salt}) async {
    if (!supported) return false;
    await _init();
    await _checkOwnership();
    return (await plugin.pendingNotificationRequests()).any(
      (n) =>
          n.id == id &&
          (salt == null ? owns(n.payload) : n.payload == '$marker:$salt'),
    );
  }

  static const id = 730041;
  static const channelId = 'expiry_one_shot_v1';
  static const marker = 'tcf.expiry.one-shot.v1';
  static bool owns(String? payload) =>
      payload == marker ||
      (payload != null &&
          payload.startsWith('$marker:') &&
          RegExp(
            r'^[a-f0-9]{64}$',
          ).hasMatch(payload.substring(marker.length + 1)));
  final plugin = FlutterLocalNotificationsPlugin();
  bool get supported => !kIsWeb && Platform.isAndroid;
  Future<void> _init() async {
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  Future<void> _checkOwnership() async {
    final pending = await plugin.pendingNotificationRequests();
    if (pending.any((n) => n.id == id && !owns(n.payload))) {
      throw StateError('Reserved notification ID occupied');
    }
  }

  Future<bool> _channelAllowed(
    AndroidFlutterLocalNotificationsPlugin android,
  ) async {
    final channels = await android.getNotificationChannels();
    if (channels == null) throw StateError('Channel status unavailable');
    return !channels.any(
      (channel) =>
          channel.id == channelId && channel.importance == Importance.none,
    );
  }

  @override
  Future<bool> permission() async {
    if (!supported) return false;
    await _init();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    if (!await _channelAllowed(android)) return false;
    if (await android.areNotificationsEnabled() == true) return true;
    return await android.requestNotificationsPermission() == true &&
        await _channelAllowed(android);
  }

  @override
  Future<void> cancelOwned() async {
    if (!supported) return;
    await _init();
    await _checkOwnership();
    await plugin.cancel(id, tag: marker);
  }

  @override
  Future<void> schedule(DateTime at) => _scheduleNative(at);
  @override
  Future<void> scheduleWithProof(DateTime at, String salt) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(salt)) {
      throw ArgumentError('Invalid proof');
    }
    return _scheduleNative(at, salt: salt);
  }

  Future<void> _scheduleNative(DateTime at, {String? salt}) async {
    if (!supported || !at.isAfter(DateTime.now())) {
      throw StateError('Invalid schedule');
    }
    await _checkOwnership();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null ||
        await android.areNotificationsEnabled() != true ||
        !await _channelAllowed(android)) {
      throw StateError('Permission changed');
    }
    await plugin.zonedSchedule(
      id,
      '재료 기한을 확인해 주세요',
      '예약 당시 입력된 기한을 기준으로 한 알림입니다. 앱에서 현재 재고와 포장지 날짜를 확인해 주세요.',
      tz.TZDateTime.from(at.toUtc(), tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          '직접 예약한 기한 확인',
          channelDescription: '사용자가 예약한 한 번의 기한 확인 안내',
          tag: marker,
          visibility: NotificationVisibility.private,
          enableVibration: false,
          playSound: false,
          autoCancel: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: salt == null ? marker : '$marker:$salt',
    );
  }
}
