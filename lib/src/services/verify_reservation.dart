import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';
import 'one_shot_receipt.dart';
import 'one_shot_expiry_reminder.dart';

/// Fresh read-only server validation; never refreshes/writes a credential.
Future<VerifiedReservationState> verifyReservation(
  SupabaseClient client,
  String owner,
  int days,
) async {
  final token = client.auth.currentSession?.accessToken;
  bool current() =>
      token != null &&
      client.auth.currentSession?.accessToken == token &&
      client.auth.currentUser?.id == owner &&
      (client.auth.currentSession?.expiresAt ?? 0) >
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30;
  if (!current()) throw StateError('Session unavailable');
  Future<String> inventory() async {
    final rows = await client
        .from('ingredients')
        .select('id,user_id,name,quantity,expiry_date,storage_type,created_at')
        .eq('user_id', owner)
        .order('id')
        .limit(1001);
    if (rows.length > 1000 ||
        rows.any((r) => r['user_id'] != owner) ||
        rows.map((r) => r['id']).toSet().length != rows.length) {
      throw StateError('Inventory unavailable');
    }
    return reminderInventoryIdentity(rows.map(Ingredient.fromJson).toList());
  }

  if ((await client.auth.getUser()).user?.id != owner) {
    throw StateError('Account unavailable');
  }
  final first = await inventory();
  if ((await client.auth.getUser()).user?.id != owner || !current()) {
    throw StateError('Account changed');
  }
  final second = await inventory();
  if (first != second || !current()) throw StateError('Inventory changed');
  return VerifiedReservationState(owner, second, days);
}
