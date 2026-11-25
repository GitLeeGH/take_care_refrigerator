import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers.dart';
import 'meal_assistant.dart';
import 'meal_conversation.dart';
import 'meal_conversation_gateway.dart';

/// Approved conversation rollout follows the existing AI-enabled build unless
/// explicitly overridden. An unconfigured/default test build still stays OFF.
const mealConversationRolloutEnabled = bool.fromEnvironment(
  'MEAL_CONVERSATION_ENABLED',
  defaultValue: mealAssistantRolloutEnabled,
);
final mealConversationRolloutProvider = Provider<bool>(
  (ref) => mealConversationRolloutEnabled,
);

class MealConversationConnection {
  const MealConversationConnection({
    required this.baseUrl,
    required this.publishableKey,
    required this.readSession,
  });
  final String baseUrl, publishableKey;
  // Read afresh before each request, never cache an auth token in this provider.
  final Session? Function() readSession;
}

String? mealConversationSessionToken(Session? session) {
  if (session == null ||
      session.expiresAt == null ||
      session.isExpired ||
      session.user.isAnonymous ||
      session.user.id.isEmpty ||
      session.accessToken.isEmpty) {
    return null;
  }
  return session.accessToken;
}

final mealConversationConnectionProvider =
    Provider<MealConversationConnection?>((ref) {
      if (!dotenv.isInitialized) return null;
      final baseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final publishableKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      if (baseUrl.isEmpty || publishableKey.isEmpty) return null;
      final client = ref.watch(supabaseProvider);
      return MealConversationConnection(
        baseUrl: baseUrl,
        publishableKey: publishableKey,
        readSession: () => client.auth.currentSession,
      );
    });

/// Injection boundary for local tests. Merely reading the provider does not
/// create a client, fetch readiness, or transmit any question or recipe data.
final mealConversationHttpClientFactoryProvider =
    Provider<http.Client Function()>((ref) => http.Client.new);

final mealConversationGatewayProvider = Provider<MealConversationGateway>((
  ref,
) {
  if (!ref.watch(mealConversationRolloutProvider)) {
    return const DisabledMealConversationGateway();
  }
  final connection = ref.watch(mealConversationConnectionProvider);
  if (connection == null) return const DisabledMealConversationGateway();
  return configuredMealConversationGateway(
    rolloutEnabled: true,
    baseUrl: connection.baseUrl,
    publishableKey: connection.publishableKey,
    accessToken: () => mealConversationSessionToken(connection.readSession()),
    clientFactory: ref.watch(mealConversationHttpClientFactoryProvider),
  );
});
