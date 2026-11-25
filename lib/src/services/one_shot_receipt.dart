import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

String _digest(String salt, String value) =>
    sha256.convert(utf8.encode('$salt:$value')).toString();

class ReservationProof {
  ReservationProof(
    this.salt,
    this.owner,
    this.stock,
    this.days,
    this.due,
    this.offset,
    this.committed,
  );
  final String salt, owner, stock;
  final int days, offset;
  final DateTime due;
  final bool committed;
  factory ReservationProof.create(
    String owner,
    String inventory,
    int days,
    DateTime due,
  ) {
    final rng = Random.secure();
    final salt = List.generate(
      32,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return ReservationProof(
      salt,
      _digest(salt, owner),
      _digest(salt, inventory),
      days,
      due,
      due.timeZoneOffset.inMinutes,
      false,
    );
  }
  bool matches(String account, String inventory, int window, DateTime now) =>
      committed &&
      owner == _digest(salt, account) &&
      stock == _digest(salt, inventory) &&
      days == window &&
      due.isAfter(now.add(const Duration(seconds: 30))) &&
      due.difference(now) < const Duration(days: 2) &&
      offset == now.timeZoneOffset.inMinutes;
  ReservationProof commit() =>
      ReservationProof(salt, owner, stock, days, due, offset, true);
  String encode() => jsonEncode({
    'version': 1,
    'salt': salt,
    'owner': owner,
    'stock': stock,
    'days': days,
    'due': due.millisecondsSinceEpoch,
    'offset': offset,
    'committed': committed,
  });
  static ReservationProof decode(String raw) {
    if (raw.length > 2048) throw const FormatException('Invalid receipt');
    final v = jsonDecode(raw) as Map<String, dynamic>;
    if (v.length != 8 ||
        v['version'] != 1 ||
        ![1, 3, 7].contains(v['days']) ||
        v['due'] is! int ||
        v['offset'] is! int ||
        (v['offset'] as int).abs() > 840 ||
        v['committed'] is! bool) {
      throw const FormatException('Invalid receipt');
    }
    for (final key in ['salt', 'owner', 'stock']) {
      if (v[key] is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(v[key])) {
        throw const FormatException('Invalid receipt');
      }
    }
    return ReservationProof(
      v['salt'],
      v['owner'],
      v['stock'],
      v['days'],
      DateTime.fromMillisecondsSinceEpoch(v['due']),
      v['offset'],
      v['committed'],
    );
  }
}

class ReceiptSnapshot {
  ReceiptSnapshot(this.revision, this.proof);
  final String revision;
  final ReservationProof? proof;
}

abstract class ReservationStore {
  Future<ReceiptSnapshot> read();
  Future<String> write(String expected, ReservationProof proof);
  Future<void> clear();
}

class NativeReservationStore implements ReservationStore {
  const NativeReservationStore();
  static const channel = MethodChannel('refrigerator/one_shot_receipt_v1');
  @override
  Future<ReceiptSnapshot> read() async {
    final value = (await channel.invokeMapMethod<String, dynamic>('read'))!;
    return ReceiptSnapshot(
      value['revision'] as String,
      value['receipt'] == null
          ? null
          : ReservationProof.decode(value['receipt'] as String),
    );
  }

  @override
  Future<String> write(String expected, ReservationProof proof) async =>
      (await channel.invokeMethod<String>('write', {
        'expected': expected,
        'receipt': proof.encode(),
      }))!;
  @override
  Future<void> clear() => channel.invokeMethod<void>('clear');
}

class VerifiedReservationState {
  VerifiedReservationState(this.owner, this.inventory, this.days);
  final String owner, inventory;
  final int days;
}
