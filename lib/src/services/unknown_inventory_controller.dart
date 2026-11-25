import 'package:flutter/foundation.dart';
import 'candidate_rpc_gateway.dart';
import 'inventory_candidate_snapshot.dart';
import 'unknown_inventory_command.dart';

/// Separate from dated inventory: no unknown record reaches an expiry reader.
/// The transport is authenticated RPC, never local-only storage or a fake date.
class UnknownInventoryController extends ChangeNotifier {
  UnknownInventoryController({
    required Future<List<InventoryCandidateItem>> Function() read,
    required Future<void> Function(UnknownInventoryCommand) write,
    required String? Function() owner,
    required int Function() epoch,
    this.restorePending,
    this.retainPending,
    this.clearPending,
  }) : _read = read,
       _write = write,
       _owner = owner,
       _epoch = epoch;

  final Future<List<InventoryCandidateItem>> Function() _read;
  final Future<void> Function(UnknownInventoryCommand) _write;
  final String? Function() _owner;
  final int Function() _epoch;
  final Future<UnknownInventoryCommand?> Function(String, int)? restorePending;
  final Future<void> Function(UnknownInventoryCommand)? retainPending;
  final Future<void> Function(UnknownInventoryCommand)? clearPending;
  bool _restored = false;
  bool get canWrite => restorePending == null || _restored;
  String? get owner => _owner();
  int get epoch => _epoch();
  List<InventoryCandidateItem> items = const [];
  bool loading = false, saving = false, loaded = false, _disposed = false;
  String? error;
  UnknownInventoryCommand? pendingCreate;
  int _generation = 0;
  bool get busy => loading || saving;
  bool isPending(UnknownInventoryCommand command) =>
      pendingCreate != null &&
      pendingCreate!.owner == command.owner &&
      pendingCreate!.sessionEpoch == command.sessionEpoch &&
      pendingCreate!.rpc == command.rpc &&
      mapEquals(pendingCreate!.parameters, command.parameters);
  bool isCurrent(String? actor, int session) =>
      !_disposed && actor != null && owner == actor && epoch == session;

  void sessionChanged() {
    ++_generation;
    items = const [];
    _restored = false;
    loading = saving = loaded = false;
    pendingCreate = null;
    error = null;
    if (!_disposed) notifyListeners();
  }

  Future<bool> reload() async {
    if (_disposed || busy || owner == null) return false;
    final actor = owner!;
    final session = epoch;
    final generation = ++_generation;
    loading = true;
    loaded = false;
    items = const [];
    _restored = false;
    error = null;
    notifyListeners();
    try {
      String? recoveryError;
      if (!_restored && restorePending != null) {
        try {
          final recovered = await restorePending!(actor, session);
          if (!isCurrent(actor, session) || generation != _generation) {
            return false;
          }
          recovered?.validateContext(currentOwner: owner, currentEpoch: epoch);
          pendingCreate = recovered;
          _restored = true;
        } catch (_) {
          if (!isCurrent(actor, session) || generation != _generation) {
            return false;
          }
          recoveryError = '이전 등록 확인정보를 복구하지 못해 새 저장을 막았어요. 기존 재료는 확인할 수 있어요.';
        }
      }
      final result = await _read();
      if (!isCurrent(actor, session) || generation != _generation) return false;
      if (result.any((row) => row.value.owner != actor)) {
        throw StateError('Inventory owner changed');
      }
      items = List.unmodifiable(result.where((row) => row.kind == 'unknown'));
      loaded = true;
      error = recoveryError;
      return true;
    } catch (_) {
      if (isCurrent(actor, session) && generation == _generation) {
        error = '기한 미정 재료를 불러오지 못했어요. 다시 확인해 주세요.';
      }
      return false;
    } finally {
      if (isCurrent(actor, session) && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> submit(UnknownInventoryCommand command) async {
    if (_disposed || busy || !canWrite) return false;
    command.validateContext(currentOwner: owner, currentEpoch: epoch);
    if (pendingCreate != null && !isPending(command)) {
      return false;
    }
    final actor = owner!;
    final session = epoch;
    final retryingUncertain = pendingCreate != null;
    final generation = ++_generation;
    saving = true;
    error = null;
    notifyListeners();
    var committed = false;
    String? failure;
    try {
      if (command.rpc == 'inventory_create_unknown_v2_candidate') {
        await retainPending?.call(command);
        if (!isCurrent(actor, session) || generation != _generation) {
          return false;
        }
      }
      await _write(command);
      if (!isCurrent(actor, session) || generation != _generation) return false;
      if (command.rpc == 'inventory_create_unknown_v2_candidate') {
        await clearPending?.call(command);
        if (!isCurrent(actor, session) || generation != _generation) {
          return false;
        }
      }
      committed = true;
      pendingCreate = null;
    } catch (e) {
      if (!isCurrent(actor, session) || generation != _generation) return false;
      final definite =
          e is CandidateRpcFailure &&
          (e.kind == CandidateRpcFailureKind.conflict ||
              e.kind == CandidateRpcFailureKind.blocked);
      failure = definite
          ? '다른 변경과 충돌했거나 저장이 허용되지 않았어요. 목록을 확인해 주세요.'
          : '저장 결과를 확인하지 못했어요. 이미 저장됐을 수 있으니 목록을 확인해 주세요.';
      if (command.rpc == 'inventory_create_unknown_v2_candidate' &&
          (!definite || retryingUncertain)) {
        pendingCreate = command;
      } else {
        pendingCreate = null;
        if (command.rpc == 'inventory_create_unknown_v2_candidate') {
          try {
            await clearPending?.call(command);
          } catch (_) {
            pendingCreate = command;
          }
          if (!isCurrent(actor, session)) return false;
        }
      }
    } finally {
      if (isCurrent(actor, session) && generation == _generation) {
        saving = false;
      }
    }
    if (!isCurrent(actor, session) || generation != _generation) return false;
    final readBack = await reload();
    if (!isCurrent(actor, session)) return false;
    // A lost create reply is resolved only by the exact same ID and payload.
    if (!committed && readBack && pendingCreate != null) {
      final p = command.parameters;
      committed = items.any(
        (row) =>
            row.value.id == 'unknown:${p['p_request_id']}' &&
            row.value.name == p['p_name'] &&
            row.value.quantity == p['p_quantity'] &&
            row.storageType == p['p_storage_type'],
      );
      if (committed) {
        try {
          await clearPending?.call(command);
          if (!isCurrent(actor, session)) return false;
          pendingCreate = null;
        } catch (_) {
          if (!isCurrent(actor, session)) return false;
          error = '재료는 저장됐지만 등록 확인정보 정리가 필요해요. 같은 요청 다시 확인을 눌러 주세요.';
        }
      }
    }
    if (!committed && failure != null) error = failure;
    notifyListeners();
    return committed;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    items = const [];
    _restored = false;
    pendingCreate = null;
    super.dispose();
  }
}
