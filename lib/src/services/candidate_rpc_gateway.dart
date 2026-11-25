import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'expiry_compatibility.dart';
import 'inventory_candidate_snapshot.dart';
import 'unknown_inventory_command.dart';

typedef CandidateRpcCall =
    Future<Object?> Function(String, Map<String, Object>);

enum CandidateRpcFailureKind {
  readFailed,
  conflict,
  blocked,
  writeUncertain,
  invalidResponse,
  busy,
}

class CandidateRpcFailure implements Exception {
  const CandidateRpcFailure(this.kind);
  final CandidateRpcFailureKind kind;
  // Never retain or print remote error payload, row contents, URL or tokens.
  @override
  String toString() => 'CandidateRpcFailure(${kind.name})';
}

class CandidateRpcGateway {
  CandidateRpcGateway._(
    this._call,
    this._owner,
    this._epoch,
    this.timeout, {
    this.production = false,
  });
  final bool production;
  final CandidateRpcCall _call;
  final String? Function() _owner;
  final int Function() _epoch;
  final Duration timeout;
  bool _writing = false;
  int _readSequence = 0;
  factory CandidateRpcGateway.forApp({
    required SupabaseClient client,
    required int Function() sessionEpoch,
  }) {
    if (!unknownExpiryReadEnabled) {
      throw StateError('Unknown expiry RPC disabled');
    }
    return CandidateRpcGateway._(
      (name, params) async => await client.rpc(name, params: params),
      () => client.auth.currentUser?.id,
      sessionEpoch,
      const Duration(seconds: 20),
      production: true,
    );
  }

  /// Test-only injection; never registered in live providers or routes.
  @visibleForTesting
  factory CandidateRpcGateway.isolated({
    required CandidateRpcCall call,
    required String? Function() owner,
    required int Function() epoch,
    Duration timeout = const Duration(seconds: 20),
  }) => CandidateRpcGateway._(call, owner, epoch, timeout);
  void _session(String owner, int epoch) {
    if (owner.isEmpty || _owner() != owner || _epoch() != epoch) {
      throw StateError('Stale candidate session');
    }
  }

  Future<List<InventoryCandidateItem>> read() async {
    final actor = _owner();
    final epoch = _epoch();
    final sequence = ++_readSequence;
    if (actor == null) {
      throw StateError('No candidate session');
    }
    try {
      _session(actor, epoch);
      final result = await _call(
        'inventory_read_v2_candidate',
        const {},
      ).timeout(timeout);
      _session(actor, epoch);
      if (sequence != _readSequence) {
        throw StateError('Superseded candidate read');
      }
      if (result is! Map<String, dynamic>) {
        throw const CandidateRpcFailure(
          CandidateRpcFailureKind.invalidResponse,
        );
      }
      return InventoryCandidateSnapshot.decode(
        result,
        requestedOwner: actor,
        currentOwner: _owner,
      );
    } catch (err) {
      _session(actor, epoch);
      if (sequence != _readSequence) {
        throw StateError('Superseded candidate read');
      }
      if (err is CandidateRpcFailure) {
        rethrow;
      }
      throw const CandidateRpcFailure(CandidateRpcFailureKind.readFailed);
    }
  }

  Future<void> write(UnknownInventoryCommand command) async {
    if (production && !unknownExpiryRegistrationEnabled) {
      throw const CandidateRpcFailure(CandidateRpcFailureKind.blocked);
    }
    command.validateContext(currentOwner: _owner(), currentEpoch: _epoch());
    if (_writing) {
      throw const CandidateRpcFailure(CandidateRpcFailureKind.busy);
    }
    _writing = true;
    ++_readSequence;
    try {
      final result = await _call(
        command.rpc,
        command.parameters,
      ).timeout(timeout);
      command.validateContext(currentOwner: _owner(), currentEpoch: _epoch());
      command.validateResult(
        result,
        currentOwner: _owner(),
        currentEpoch: _epoch(),
      );
    } catch (err) {
      command.validateContext(currentOwner: _owner(), currentEpoch: _epoch());
      if (err is PostgrestException && err.code == '40001') {
        throw const CandidateRpcFailure(CandidateRpcFailureKind.conflict);
      }
      if (err is PostgrestException && err.code == '42501') {
        throw const CandidateRpcFailure(CandidateRpcFailureKind.blocked);
      }
      // Timeout, malformed reply and transport failure may follow a committed write.
      // Never retry automatically or infer rollback. Caller must reload/reconcile.
      throw const CandidateRpcFailure(CandidateRpcFailureKind.writeUncertain);
    } finally {
      _writing = false;
    }
  }
}
