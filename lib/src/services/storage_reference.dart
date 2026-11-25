import 'storage_guidance.dart';
import 'calendar_day.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String referenceDateText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
DateTime _date(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid reference date');
  }
  final parsed = DateTime.parse(value);
  if (referenceDateText(parsed) != value) {
    throw const FormatException('Invalid reference date');
  }
  return parsed;
}

class StoredStorageReference {
  const StoredStorageReference({
    required this.ingredientId,
    required this.userId,
    required this.guideId,
    required this.catalogVersion,
    required this.guideLabel,
    required this.purchasedOn,
    required this.suggestedOn,
    required this.remindOn,
    required this.sourceUrls,
    required this.active,
  });
  final String ingredientId, userId, guideId, catalogVersion, guideLabel;
  final DateTime purchasedOn, suggestedOn, remindOn;
  final List<String> sourceUrls;
  final bool active;
  bool get manuallyAdjusted =>
      referenceDateText(suggestedOn) != referenceDateText(remindOn);
  int daysLeft(DateTime now) => calendarDayDifference(remindOn, now);
  String get notificationId =>
      'reference:$ingredientId:${referenceDateText(remindOn)}:$catalogVersion';
  String notificationBody(String name) =>
      '$name · 먼저 먹기 권장일(참고) ${referenceDateText(remindOn)}'
      '${manuallyAdjusted ? ' (직접 수정)' : ''}\n구매일 ${referenceDateText(purchasedOn)} · $guideLabel 참고자료 기준. 실제 소비기한이나 안전 보증이 아닙니다.';
  factory StoredStorageReference.fromJson(Map<String, dynamic> row) {
    final purchased = _date(row['purchased_on']),
        suggested = _date(row['suggested_on']),
        remind = _date(row['remind_on']);
    if (suggested.isBefore(purchased) || remind.isBefore(purchased)) {
      throw const FormatException('Reference predates purchase');
    }
    return StoredStorageReference(
      ingredientId: row['ingredient_id'] as String,
      userId: row['user_id'] as String,
      guideId: row['guide_id'] as String,
      catalogVersion: row['catalog_version'] as String,
      guideLabel: row['guide_label'] as String,
      purchasedOn: purchased,
      suggestedOn: suggested,
      remindOn: remind,
      sourceUrls: List<String>.unmodifiable(
        (row['source_urls'] as List).cast<String>(),
      ),
      active: row['is_active'] == true,
    );
  }
}

class StorageReferenceDraft {
  const StorageReferenceDraft({
    required this.ingredientId,
    required this.guideId,
    required this.catalogVersion,
    required this.purchasedOn,
    required this.remindOn,
    required this.conditionsConfirmed,
  });
  final String ingredientId, guideId, catalogVersion;
  final DateTime purchasedOn, remindOn;
  final bool conditionsConfirmed;
  Map<String, dynamic> toWrite(String userId) {
    final index = storageGuideIds.indexOf(guideId);
    if (index < 0 || storageGuides[index].days == null) {
      throw StateError('No verified numeric period');
    }
    if (!conditionsConfirmed || remindOn.isBefore(purchasedOn)) {
      throw StateError('Reference conditions not confirmed');
    }
    // Server derives source, suggested date and guide label from immutable catalogue.
    // Never includes expiry_date, image_path or any ingredient mutation.
    return {
      'ingredient_id': ingredientId,
      'user_id': userId,
      'guide_id': guideId,
      'catalog_version': catalogVersion,
      'purchased_on': referenceDateText(purchasedOn),
      'remind_on': referenceDateText(remindOn),
      'conditions_confirmed': true,
      'is_active': true,
    };
  }
}

abstract interface class StorageReferenceGateway {
  Future<List<StoredStorageReference>> read();
  Future<StoredStorageReference> save(StorageReferenceDraft draft);
}

class SupabaseStorageReferenceGateway implements StorageReferenceGateway {
  SupabaseStorageReferenceGateway(this.client);
  final SupabaseClient client;
  String get _uid =>
      client.auth.currentUser?.id ?? (throw StateError('Sign in required'));
  @override
  Future<List<StoredStorageReference>> read() async {
    final owner = _uid;
    final rows = await client
        .from('ingredient_storage_references')
        .select()
        .eq('user_id', owner);
    if (_uid != owner) throw StateError('Account changed');
    return rows
        .map(StoredStorageReference.fromJson)
        .where((row) => row.userId == owner)
        .toList();
  }

  @override
  Future<StoredStorageReference> save(StorageReferenceDraft draft) async {
    final owner = _uid;
    final row = await client
        .from('ingredient_storage_references')
        .upsert(draft.toWrite(owner), onConflict: 'ingredient_id')
        .select()
        .single();
    if (_uid != owner) throw StateError('Account changed');
    return StoredStorageReference.fromJson(row);
  }
}
