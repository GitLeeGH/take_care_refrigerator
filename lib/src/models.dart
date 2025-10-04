class Ingredient {
  final String id;
  final String name;
  final String quantity;
  final DateTime expiryDate;
  final String storageType;
  final DateTime createdAt;

  Ingredient({
    required this.id,
    required this.name,
    required this.quantity,
    required this.expiryDate,
    required this.storageType,
    required this.createdAt,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    id: json['id'],
    name: json['name'],
    quantity: json['quantity'],
    expiryDate: DateTime.parse(json['expiry_date']),
    storageType: json['storage_type'],
    createdAt: DateTime.parse(json['created_at']),
  );
}

class Recipe {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? youtubeVideoId; // Changed to nullable
  final String? blogUrl;
  final String? totalTime;
  final String? cuisineType;
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