import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'unknown_inventory_command.dart';

/// Retains only unresolved owner-bound requests, never credentials. The shared
/// queue prevents a disposed controller from clearing a replacement's request.
class UnknownInventoryPendingStore {
  static final _queues = <String, Future<void>>{};
  String _key(String owner) => 'unknown_inventory_pending_v1:$owner';
  Future<T> _serial<T>(
    String owner,
    Future<T> Function(SharedPreferences) action,
  ) {
    final previous = _queues[owner] ?? Future<void>.value();
    final operation = previous.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      return action(preferences);
    });
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _queues[owner] = tail;
    tail.then((_) {
      if (identical(_queues[owner], tail)) _queues.remove(owner);
    });
    return operation;
  }

  Map<String, Object?> _data(UnknownInventoryCommand command) {
    final p = command.parameters;
    return {
      'version': 1,
      'owner': command.owner,
      'request_id': p['p_request_id'],
      'name': p['p_name'],
      'quantity': p['p_quantity'],
      'storage': p['p_storage_type'],
    };
  }

  Future<UnknownInventoryCommand?> read(String owner, int epoch) =>
      _serial(owner, (preferences) async {
        final raw = preferences.getString(_key(owner));
        if (raw == null) return null;
        final data = jsonDecode(raw);
        if (data is! Map || data['version'] != 1 || data['owner'] != owner) {
          throw const FormatException('Invalid pending request');
        }
        return UnknownInventoryCommand.create(
          owner: owner,
          sessionEpoch: epoch,
          requestId: data['request_id'] as String,
          name: data['name'] as String,
          quantity: data['quantity'] as String,
          storage: data['storage'] as String,
        );
      });
  Future<void> write(UnknownInventoryCommand command) =>
      _serial(command.owner, (preferences) async {
        if (command.rpc != 'inventory_create_unknown_v2_candidate') return;
        final raw = jsonEncode(_data(command));
        final old = preferences.getString(_key(command.owner));
        if (old != null && old != raw) {
          throw StateError('Different unresolved request');
        }
        if (!await preferences.setString(_key(command.owner), raw)) {
          throw StateError('Pending request could not be retained');
        }
      });
  Future<void> clear(UnknownInventoryCommand expected) =>
      _serial(expected.owner, (preferences) async {
        final old = preferences.getString(_key(expected.owner));
        if (old == null) return;
        if (old != jsonEncode(_data(expected))) {
          throw StateError('Refusing to clear a different unresolved request');
        }
        if (!await preferences.remove(_key(expected.owner))) {
          throw StateError('Pending request cleanup failed');
        }
      });
}
