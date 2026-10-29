import 'ingredient_matching.dart';
import 'services/original_video.dart';

class Ingredient {
  final String? imagePath;
  final String id;
  final String name;
  final String quantity;
  final DateTime expiryDate;
  final String storageType;
  final DateTime createdAt;

  Ingredient({
    this.imagePath,
    required this.id,
    required this.name,
    required this.quantity,
    required this.expiryDate,
    required this.storageType,
    required this.createdAt,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    imagePath: json['image_path'] as String?,
    id: json['id'],
    name: json['name'],
    quantity: json['quantity'],
    expiryDate: DateTime.parse(json['expiry_date']),
    storageType: json['storage_type'],
    createdAt: DateTime.parse(json['created_at']),
  );
}

class Recipe {
  /// Existing saved evidence records explicitly distinguish unknown steps.
  bool get hasUnverifiedSteps =>
      description?.contains('[아직 확인되지 않은 정보]') == true ||
      description?.contains('<!-- recipe-evidence:v1;steps=unverified -->') ==
          true;

  String get displayDescription => (description ?? '')
      .replaceAll('<!-- recipe-evidence:v1;steps=unverified -->', '')
      .trim();

  OriginalVideo? get originalVideo =>
      OriginalVideo.parse(
        'https://www.youtube.com/watch?v=${youtubeVideoId ?? ''}',
      ) ??
      OriginalVideo.parse(blogUrl ?? '');

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? youtubeVideoId; // Changed to nullable
  final String? blogUrl;
  final String? totalTime;
  final String? cuisineType;
  final Object? videoSegments;
  final List<String> requiredIngredients;
  final int likeCount;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.youtubeVideoId, // Changed to nullable
    this.blogUrl,
    this.totalTime,
    this.cuisineType,
    this.videoSegments,
    required this.requiredIngredients,
    required this.likeCount,
    required this.createdAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    imageUrl: json['image_url'],
    youtubeVideoId: json['youtube_video_id'], // Will now correctly handle null
    blogUrl: json['blog_url'],
    totalTime: json['total_time'],
    cuisineType: json['cuisine_type'],
    videoSegments: json['video_segments'],
    requiredIngredients: List<String>.from(json['required_ingredients'] ?? []),
    likeCount: json['like_count'] ?? 0,
    createdAt: DateTime.parse(json['created_at']),
  );
}

// A new class to hold combined recipe and ingredient availability info
class RecommendedRecipe {
  final Recipe recipe;
  final int ownedIngredientsCount;
  final int requiredIngredientsCount;
  final List<String> missingIngredients;

  factory RecommendedRecipe.fromInventory(
    Recipe recipe,
    Iterable<String> inventory,
  ) {
    final availability = IngredientAvailability(
      recipe.requiredIngredients,
      inventory,
    );
    return RecommendedRecipe(
      recipe: recipe,
      ownedIngredientsCount: availability.ownedIngredients.length,
      requiredIngredientsCount: availability.requiredIngredients.length,
      missingIngredients: availability.missingIngredients,
    );
  }

  RecommendedRecipe({
    required this.recipe,
    required this.ownedIngredientsCount,
    required this.requiredIngredientsCount,
    required this.missingIngredients,
  });
}

// Model for user profile data, including their role
class UserProfile {
  final String id;
  final String role;

  UserProfile({required this.id, required this.role});

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'],
    role: json['role'] ?? 'user', // Default to 'user' if role is null
  );
}
