import 'inventory_candidate_snapshot.dart';

/// Offline RPC request preparation only. No transport or production integration.
/// A future transport must validate context before dispatch AND before accepting
/// a response. An already dispatched server write cannot be undone by this check.
class UnknownInventoryCommand {
  UnknownInventoryCommand._(
    this.owner,
    this.sessionEpoch,
    this.rpc,
    Map<String, Object> values,
  ) : parameters = Map.unmodifiable(values);
  final String owner;
  final int sessionEpoch;
  final String rpc;
  final Map<String, Object> parameters;
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static void _owner(String owner, int epoch) {
    if (!_uuid.hasMatch(owner) || epoch < 0) {
      throw const FormatException('Invalid session');
    }
  }

  static String _text(String value, int maximum) {
    // SQL length(text) counts Unicode characters, not UTF-16 code units.
    final result = value.trim();
    if (result.isEmpty || result.runes.length > maximum) {
      throw const FormatException('Invalid field length');
    }
    return result;
  }

  factory UnknownInventoryCommand.create({
    required String owner,
    required int sessionEpoch,
    required String requestId,
    required String name,
    required String quantity,
    required String storage,
  }) {
    _owner(owner, sessionEpoch);
    if (!_uuid.hasMatch(requestId)) {
      throw const FormatException('Invalid request identity');
    }
    return UnknownInventoryCommand._(
      owner,
      sessionEpoch,
      'inventory_create_unknown_v2_candidate',
      {
        'p_request_id': requestId,
        'p_name': _text(name, 200),
        'p_quantity': _text(quantity, 100),
        'p_storage_type': _text(storage, 50),
      },
    );
  }
  static void _item(InventoryCandidateItem item, String owner, int epoch) {
    _owner(owner, epoch);
    if (item.value.owner != owner ||
        item.kind != 'unknown' ||
        item.value.expiry.actualDate != null ||
        !item.value.id.startsWith('unknown:') ||
        !_uuid.hasMatch(item.value.id.substring(8)) ||
        item.revision == null ||
        item.revision! < 1) {
      throw const FormatException('Invalid unknown target');
    }
  }

  factory UnknownInventoryCommand.edit({
    required InventoryCandidateItem item,
    required String owner,
    required int sessionEpoch,
    required String name,
    required String quantity,
    required String storage,
  }) {
    _item(item, owner, sessionEpoch);
    return UnknownInventoryCommand._(
      owner,
      sessionEpoch,
      'inventory_edit_unknown_v2_candidate',
      {
        'p_id': item.value.id,
        'p_revision': item.revision!,
        'p_name': _text(name, 200),
        'p_quantity': _text(quantity, 100),
        'p_storage_type': _text(storage, 50),
      },
    );
  }
  factory UnknownInventoryCommand.delete({
    required InventoryCandidateItem item,
    required String owner,
    required int sessionEpoch,
  }) {
    _item(item, owner, sessionEpoch);
    return UnknownInventoryCommand._(
      owner,
      sessionEpoch,
      'inventory_delete_unknown_v2_candidate',
      {'p_id': item.value.id, 'p_revision': item.revision!},
    );
  }
  void validateContext({
    required String? currentOwner,
    required int currentEpoch,
  }) {
    if (currentOwner != owner || currentEpoch != sessionEpoch) {
      throw StateError('Stale inventory command');
    }
  }

  void validateResult(
    Object? result, {
    required String? currentOwner,
    required int currentEpoch,
  }) {
    validateContext(currentOwner: currentOwner, currentEpoch: currentEpoch);
    final valid = rpc == 'inventory_create_unknown_v2_candidate'
        ? result is String &&
              result.startsWith('unknown:') &&
              _uuid.hasMatch(result.substring(8))
        : rpc == 'inventory_edit_unknown_v2_candidate'
        ? result is int && result == (parameters['p_revision'] as int) + 1
        : result == true;
    if (!valid) {
      throw const FormatException('Unexpected RPC result; reload required');
    }
  }
}
