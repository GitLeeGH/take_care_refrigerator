import 'reminder_auth_boundary.dart';
import '../app_variant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers.dart';

abstract class AuthGateway {
  String? get accountId;
  bool get sessionUsable;
  Stream<void> get changes;
  Future<void> restore();
  Future<void> signIn(String email, String password);
  Future<bool> signUp(String email, String password);
  Future<bool> oauth(OAuthProvider provider);
  Future<void> signOut();
}

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => SupabaseAuthGateway(ref.watch(supabaseProvider)),
);

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this.client);
  final SupabaseClient client;
  @override
  String? get accountId => client.auth.currentSession?.user.id;
  @override
  bool get sessionUsable {
    final expires = client.auth.currentSession?.expiresAt;
    return expires != null &&
        expires > DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  @override
  Stream<void> get changes => client.auth.onAuthStateChange.map((_) {});
  @override
  Future<void> restore() async {
    if (client.auth.currentSession != null && !sessionUsable) {
      await client.auth.refreshSession();
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    await withReminderSessionBoundary(
      invalidate: invalidateReminderSession,
      transition: () =>
          client.auth.signInWithPassword(email: email, password: password),
    );
  }

  @override
  Future<bool> signUp(String email, String password) async {
    final result = await withReminderSessionBoundary(
      invalidate: invalidateReminderSession,
      transition: () => client.auth.signUp(email: email, password: password),
    );
    return result.session != null;
  }

  @override
  Future<bool> oauth(OAuthProvider provider) => withReminderSessionBoundary(
    invalidate: invalidateReminderSession,
    transition: () => client.auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? null : '$mobileLoginRedirect/',
    ),
  );
  @override
  Future<void> signOut() => withReminderSessionBoundary(
    invalidate: invalidateReminderSession,
    transition: () => client.auth.signOut(),
  );
}
