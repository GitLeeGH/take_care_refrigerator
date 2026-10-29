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

// No external provider or transport is configured. Only tests override this.
final ingredientRecognizerProvider = Provider<IngredientRecognizer>(
  (ref) => const UnconfiguredIngredientRecognizer(),
);
