import 'inventory_v2_draft.dart';

/// Offline candidate contract only. No provider, network call or write API.
class InventoryCandidateItem {
  const InventoryCandidateItem(
    this.value,
    this.kind,
    this.revision,
    this.storageType,
  );
  final InventoryV2Draft value;
  final String kind;
  final String storageType;
  final int? revision;
}

class InventoryCandidateSnapshot {
  static List<InventoryCandidateItem> decode(
    Map<String, dynamic> envelope, {
    required String requestedOwner,
    required String? Function() currentOwner,
  }) {
    if (requestedOwner.isEmpty || currentOwner() != requestedOwner) {
      throw StateError('Stale inventory session');
    }
    final raw = envelope['items'];
    if (envelope['version'] != 2 || raw is! List) {
      throw const FormatException('Unsupported candidate contract');
    }
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    );
    final metadata = <String, ({String kind, int? revision})>{};
    for (final item in raw) {
      if (item is! Map<String, dynamic> || item['id'] is! String) {
        throw const FormatException('Invalid candidate row');
      }
      final id = item['id'] as String;
      final kind = item['record_kind'];
      final revision = item['revision'];
      if (!item.containsKey('revision') ||
          !item.containsKey('reference_date') ||
          item['reference_date'] != null) {
        throw const FormatException('Unsupported candidate reference');
      }
      if (kind == 'known') {
        if (!uuid.hasMatch(id) ||
            item['expiry_date'] == null ||
            revision != null) {
          throw const FormatException('Invalid known identity');
        }
      } else if (kind == 'unknown') {
        if (!id.startsWith('unknown:') ||
            !uuid.hasMatch(id.substring(8)) ||
            item['expiry_date'] != null ||
            revision is! int ||
            revision < 1 ||
            !item.containsKey('image_path') ||
            item['image_path'] != null) {
          throw const FormatException('Invalid unknown identity');
        }
      } else {
        throw const FormatException('Unsupported record kind');
      }
      if (metadata.containsKey(id)) {
        throw const FormatException('Duplicate candidate identity');
      }
      metadata[id] = (kind: kind as String, revision: revision as int?);
    }
    final values = InventoryV2Draft.decode(
      envelope,
      requestedOwner: requestedOwner,
      currentOwner: currentOwner,
    );
    return List.unmodifiable(
      values.map((value) {
        final m = metadata[value.id]!;
        return InventoryCandidateItem(
          value,
          m.kind,
          m.revision,
          (raw.firstWhere((r) => r['id'] == value.id)
                  as Map<String, dynamic>)['storage_type']
              as String,
        );
      }),
    );
  }
}
