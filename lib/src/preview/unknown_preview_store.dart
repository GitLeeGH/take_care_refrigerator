import 'package:flutter/foundation.dart';
import '../services/inventory_candidate_snapshot.dart';
import '../services/unknown_inventory_command.dart';

class PreviewConflict implements Exception {}

/// Synthetic memory only: no file, network, auth client or production fallback.
class UnknownPreviewMemory {
  final _rows = <String, Map<String, dynamic>>{};
  final _requests = <String, Map<String, Object>>{};
  Future<void> Function()? beforeWrite;
  bool failRead = false, loseNextReply = false;
  Future<Map<String, dynamic>> read(String owner) async {
    if (failRead) {
      throw StateError('synthetic offline');
    }
    return {
      'version': 2,
      'items': _rows.values
          .where((r) => r['user_id'] == owner)
          .map((r) => Map<String, dynamic>.from(r))
          .toList(),
    };
  }

  Future<Object> write(UnknownInventoryCommand c) async {
    await beforeWrite?.call();
    final p = c.parameters;
    Object result;
    if (c.rpc == 'inventory_create_unknown_v2_candidate') {
      final key = '${c.owner}/${p['p_request_id']}';
      final id = 'unknown:${p['p_request_id']}';
      if (_requests.containsKey(key)) {
        if (!mapEquals(_requests[key], p)) {
          throw PreviewConflict();
        }
        final existing = _rows['${c.owner}/$id'];
        if (existing == null ||
            existing['name'] != p['p_name'] ||
            existing['quantity'] != p['p_quantity'] ||
            existing['storage_type'] != p['p_storage_type']) {
          throw PreviewConflict();
        }
      } else {
        _requests[key] = Map.of(p);
        _rows['${c.owner}/$id'] = {
          'id': id,
          'user_id': c.owner,
          'name': p['p_name'],
          'quantity': p['p_quantity'],
          'storage_type': p['p_storage_type'],
          'created_at': '2026-11-05T00:00:00Z',
          'record_kind': 'unknown',
          'revision': 1,
          'expiry_date': null,
          'reference_date': null,
          'image_path': null,
        };
      }
      result = id;
    } else {
      final key = '${c.owner}/${p['p_id']}';
      final row = _rows[key];
      if (row == null || row['revision'] != p['p_revision']) {
        throw PreviewConflict();
      }
      if (c.rpc == 'inventory_edit_unknown_v2_candidate') {
        row.addAll({
          'name': p['p_name'],
          'quantity': p['p_quantity'],
          'storage_type': p['p_storage_type'],
          'revision': (row['revision'] as int) + 1,
        });
        result = row['revision'] as int;
      } else if (c.rpc == 'inventory_delete_unknown_v2_candidate') {
        _rows.remove(key);
        result = true;
      } else {
        throw StateError('Unsupported preview command');
      }
    }
    if (loseNextReply) {
      loseNextReply = false;
      throw StateError('synthetic reply lost');
    }
    return result;
  }
}

class UnknownPreviewController extends ChangeNotifier {
  UnknownPreviewController(this.memory);
  final UnknownPreviewMemory memory;
  String? owner;
  int epoch = 0;
  bool busy = false, disposed = false;
  String? error;
  UnknownInventoryCommand? retryCreate;
  List<InventoryCandidateItem> items = [];
  bool _current(int e) => !disposed && e == epoch;
  Future<void> activate(String? value) async {
    ++epoch;
    owner = value;
    items = [];
    retryCreate = null;
    error = null;
    busy = false;
    notifyListeners();
    await reload();
  }

  Future<void> reload() async {
    if (disposed || busy || owner == null) {
      return;
    }
    final e = epoch;
    final actor = owner!;
    busy = true;
    items = [];
    error = null;
    notifyListeners();
    try {
      final data = await memory.read(actor);
      if (!_current(e)) {
        return;
      }
      items = InventoryCandidateSnapshot.decode(
        data,
        requestedOwner: actor,
        currentOwner: () => owner,
      );
    } catch (_) {
      if (_current(e)) {
        error = '목록을 불러오지 못했습니다. 다시 확인해 주세요.';
      }
    } finally {
      if (_current(e)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> submit(UnknownInventoryCommand command) async {
    if (disposed || busy) {
      return false;
    }
    try {
      command.validateContext(currentOwner: owner, currentEpoch: epoch);
    } catch (_) {
      return false;
    }
    final e = epoch;
    busy = true;
    error = null;
    retryCreate = null;
    notifyListeners();
    var success = false;
    try {
      final result = await memory.write(command);
      if (!_current(e)) {
        return false;
      }
      command.validateResult(result, currentOwner: owner, currentEpoch: epoch);
      success = true;
    } catch (err) {
      if (!_current(e)) {
        return false;
      }
      error = err is PreviewConflict
          ? '다른 변경과 충돌했습니다. 목록을 다시 확인하고 수정해 주세요.'
          : '저장 결과를 확인하지 못했습니다. 목록을 다시 확인해 주세요.';
      if (command.rpc == 'inventory_create_unknown_v2_candidate' &&
          err is! PreviewConflict) {
        retryCreate = command;
      }
    }
    if (!_current(e)) {
      return false;
    }
    final failure = error;
    busy = false;
    await reload();
    if (_current(e) && failure != null) {
      error = failure;
      notifyListeners();
    }
    return success;
  }

  @override
  void dispose() {
    disposed = true;
    ++epoch;
    items = [];
    retryCreate = null;
    super.dispose();
  }
}
