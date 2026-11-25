import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../providers.dart';
import 'ingredient_ai_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ingredient_photo.dart';

/// Suggestions only. Quantity and expiry must never be inferred from a photo.
class IngredientCandidate {
  const IngredientCandidate({required this.name, this.category});
  final String name;
  final String? category;
}

abstract interface class IngredientRecognizer {
  bool get available;
  Future<List<IngredientCandidate>> recognize(IngredientPhotoDraft photo);
}

class UnconfiguredIngredientRecognizer implements IngredientRecognizer {
  const UnconfiguredIngredientRecognizer();
  @override
  bool get available => false;
  @override
  Future<List<IngredientCandidate>> recognize(IngredientPhotoDraft photo) =>
      Future.error(StateError('Recognition is not connected'));
}

// Explicit client rollout; the server remains the independent spend/auth gate.
final ingredientRecognizerProvider = Provider<IngredientRecognizer>((ref) {
  if (!const bool.fromEnvironment('INGREDIENT_AI_ENABLED'))
    return const UnconfiguredIngredientRecognizer();
  final client = ref.watch(supabaseProvider);
  final url = Uri.tryParse(dotenv.env['SUPABASE_URL'] ?? '');
  if (url == null ||
      url.scheme != 'https' ||
      url.host != 'brghwnwkfhbhamrrrqnr.supabase.co' ||
      url.hasQuery ||
      url.hasFragment)
    return const UnconfiguredIngredientRecognizer();
  return SupabaseIngredientRecognizer(
    endpoint: url.replace(path: '/functions/v1/ingredient-recognize'),
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    accessToken: () => client.auth.currentSession?.accessToken,
    currentOwner: () {
      final session = client.auth.currentSession;
      return session == null || session.isExpired || session.user.isAnonymous
          ? null
          : session.user.id;
    },
  );
});
