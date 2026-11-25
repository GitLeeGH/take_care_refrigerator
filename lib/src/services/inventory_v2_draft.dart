import '../models.dart';
import 'expiry_compatibility.dart';

/// Offline contract prototype only. No production provider calls this adapter.
/// Unknown rows remain visible to a future dedicated list, but never become
/// legacy Ingredient objects, expiry recommendations, or actual-date alerts.
class InventoryV2Draft {
  InventoryV2Draft._(
    this.id,
    this.owner,
    this.name,
    this.quantity,
    this.expiry,
    this.known,
  );
  final String id;
  final String owner;
  final String name;
  final String quantity;
  final IngredientExpiryDraft expiry;
  final Ingredient? known;
  String get expiryLabel => expiry.actualDate == null
      ? '소비기한 미정'
      : calendarDateText(expiry.actualDate!);

  static List<InventoryV2Draft> decode(
    Map<String, dynamic> envelope, {
    required String requestedOwner,
    required String? Function() currentOwner,
  }) {
    if (requestedOwner.isEmpty || currentOwner() != requestedOwner) {
      throw StateError('Stale inventory session');
    }
    if (envelope['version'] != 2 || envelope['items'] is! List) {
      throw const FormatException('Unsupported inventory contract');
    }
    final ids = <String>{};
    final items = <InventoryV2Draft>[];
    for (final value in envelope['items'] as List) {
      if (value is! Map<String, dynamic> ||
          value['user_id'] != requestedOwner ||
          value['id'] is! String ||
          (value['id'] as String).isEmpty ||
          value['name'] is! String ||
          value['quantity'] is! String ||
          (value['name'] as String).trim().isEmpty ||
          (value['quantity'] as String).trim().isEmpty ||
          value['storage_type'] is! String ||
          (value['storage_type'] as String).trim().isEmpty ||
          value['created_at'] is! String ||
          DateTime.tryParse(value['created_at'] as String) == null ||
          !value.containsKey('expiry_date')) {
        throw const FormatException('Invalid inventory row');
      }
      final id = value['id'] as String;
      if (!ids.add(id)) throw const FormatException('Duplicate inventory ID');
      final expiry = IngredientExpiryDraft.fromLocalJson(value);
      items.add(
        InventoryV2Draft._(
          id,
          requestedOwner,
          value['name'] as String,
          value['quantity'] as String,
          expiry,
          expiry.actualDate == null ? null : Ingredient.fromJson(value),
        ),
      );
    }
    if (currentOwner() != requestedOwner) {
      throw StateError('Stale inventory session');
    }
    items.sort((a, b) {
      final date = a.expiry.compareByActualDate(b.expiry);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    return List.unmodifiable(items);
  }
}
