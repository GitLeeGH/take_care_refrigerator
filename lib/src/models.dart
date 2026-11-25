import 'services/reviewed_recipe_repairs.dart';
import 'dart:convert';
import 'ingredient_matching.dart';
import 'services/cooking_steps.dart';
import 'services/food_catalog_seed.dart';
import 'services/original_video.dart';

String _catalogKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
final Set<String> _referenceFoodNames = {
  for (final row in jsonDecode(foodCatalogSeed) as List)
    for (final name in [row['name'], ...(row['aliases'] as List)])
      _catalogKey(name as String),
};

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
  /// Structural checks only: a valid URL does not verify its contents or rights.
  Uri? get sourceUri {
    final raw = blogUrl?.trim() ?? '';
    if (raw.isEmpty || RegExp(r'\s').hasMatch(raw)) return null;
    final uri = Uri.tryParse(raw);
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  bool get hasMalformedSource =>
      blogUrl?.trim().isNotEmpty == true && sourceUri == null;

  // Local review holds: preserve database rows, likes and saved source text.
  // Remove only after a separate source review, never merely because names match.
  String? get browsingContentWarning =>
      id == '5b1493b3-552a-47e3-9db2-d9e7cca49c52'
      ? '제목·내용 불일치: 애플파이 제목에 만두전골 설명이 저장되어 있어요. 원문 확인이 필요해요.'
      : null;

  String? get recommendationHoldReason =>
      matchesReviewedRecipeRepair(
        id: id,
        name: name,
        description: description,
        blogUrl: blogUrl,
        requiredIngredients: requiredIngredients,
      )
      ? null
      : const <String, String>{
          'be5110bd-93f2-4c31-8ff8-c3dc0f5ab922':
              '원문의 물이 저장 목록에 없고 소고기다시다와 진간장이 하나의 재료로 합쳐져 추천을 보류했어요. 원문 확인이 필요해요.',
          'd411c5df-29c9-4a6b-b0b0-a6ab23dfc6a1':
              '원문의 물과 삶은 토란대·고사리의 준비 상태가 저장 재료 목록에 반영되지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '2e7b409e-188a-4708-b6f5-e37ef0bd5a50':
              '원문의 물이 저장 목록에 없고 라면의 분말·건더기 스프 구분이 모호해 추천을 보류했어요. 원문 확인이 필요해요.',
          '0e91baf5-96a3-469d-9f37-4f9594c7481a':
              '원문의 진간장이 저장된 재료 목록에서 빠지고 묶음 재료 표기가 갈라져 추천을 보류했어요. 원문 확인이 필요해요.',
          'efa14738-76bc-450e-904e-fc77a7a82c23':
              '소고기다시다·전분물·얼음과 조리 순서를 복구했지만 소고기 준비 상태와 최종 가열 조건 확인이 남아 추천을 보류했어요.',
          '22d41614-e517-4266-9f00-0628c4327233':
              '원문의 물이 저장된 재료 목록에 없고 후추·다시다 표기가 정확하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '306348e5-a019-42f0-9c33-1949a4c47793':
              '원문에서 확인한 물을 복구했지만 다짐육 종류와 조리 설명의 추가 확인이 필요해 추천 보류를 유지하고 있어요.',
          'b41d0e42-b0e9-4a0a-b8b1-c25a73c1ae7e':
              '당면·물·소고기다시다를 원문대로 복구했지만 돼지고기 만두의 최종 가열 조건 확인이 남아 추천을 보류했어요.',
          'b6e8e61b-dc37-442c-8421-ab9185e17b70':
              '원문의 조리 단계에 쓰는 식용유가 저장된 재료 목록에 없어 추천을 보류했어요. 익힌 로티세리 치킨을 사용하는 범위도 확인이 필요해요.',
          'cff9b01a-02da-462d-a03c-53c945cdf746':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          'ead2c67b-1ac8-40a7-a5c8-67b8ed494e3d':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '1d63c717-fcf9-4289-b2d0-d70c7938b0fd':
              '원문 기준 중화면·진간장·쥬키니호박 표기를 복구했지만 면·오이 분량과 조리 조건 확인이 남아 추천을 보류했어요.',
          '5143db0c-2793-4081-a104-3b9cc2381459':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '5726f3cb-0fb7-4011-ad3a-7fe3cb410590':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '5b1493b3-552a-47e3-9db2-d9e7cca49c52':
              '제목은 애플파이지만 저장된 재료와 설명은 만두전골입니다. 원문 확인 전 추천을 보류했어요.',
          '4e92d153-05b3-4642-b35e-d0cd080cba2f':
              '저장된 추가 메뉴·조리법과 재료 목록의 범위를 확인해야 해 추천을 보류했어요.',
          'd9c5ecda-6fb7-4132-8adb-a2e1a17b42ea':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          'eb1df20e-f8ab-43b6-945f-5026196a1fa4':
              '저장된 추가 메뉴·조리법과 재료 목록의 범위를 확인해야 해 추천을 보류했어요.',
          '16967470-8712-4276-9a22-4bf4e05e4690':
              '저장된 추가 메뉴·조리법과 재료 목록의 범위를 확인해야 해 추천을 보류했어요.',
          '1d59a887-5e58-4a80-9da7-e412cc900292':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '286fd588-2361-43f4-bf23-450ae8da4010':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '41780aaa-ccd9-4137-b1eb-ef5f5f9fe8f6':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '65efea49-1054-4e7a-9c04-a80746058029':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '764a7e11-1f0c-4db2-98a3-00b66d9004dd':
              '저장된 추가 메뉴·조리법과 재료 목록의 범위를 확인해야 해 추천을 보류했어요.',
          '7c49d2bd-9a92-4974-996a-c6e6131198bc':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '7d39e593-c42c-4063-83d5-db66e3471015':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '8fee8e70-b7d3-45d1-8546-ddede0024d60':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '9bcde790-90cc-4204-b776-76b11fddc605':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          'aba7d50b-292a-477b-92a1-953dc35b4808':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          'ad32f7eb-ddcc-4912-9545-e909c3ca2952':
              '저장된 추가 메뉴·조리법과 재료 목록의 범위를 확인해야 해 추천을 보류했어요.',
          'ba432d11-8c9b-44e7-a08d-786d7d8560dc':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          'bc87c1e4-400e-40e1-8344-b27dfe023390':
              '저장된 추가 메뉴·조리법과 재료 목록의 범위를 확인해야 해 추천을 보류했어요.',
          'c623046c-2942-47e7-85f2-65f976498ef5':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          'cf77157b-ac82-4df0-aec2-575edc49762c':
              '저장된 추가 메뉴·조리법과 재료 목록의 범위를 확인해야 해 추천을 보류했어요.',
          'd11302f3-90c6-423d-bd23-0430a6fea106':
              '저장된 추가 메뉴·조리법과 재료 목록의 범위를 확인해야 해 추천을 보류했어요.',
          'd862a02a-f56b-4aaa-923a-72f9407a0375':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          'e460bef7-0914-4afc-a2a0-dea7216bd778':
              '저장된 추가 메뉴·조리법과 재료 목록의 범위를 확인해야 해 추천을 보류했어요.',
          'e7ad8095-2759-4b78-9f70-b46a1bbe44bd':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          'f20d30fa-9541-4fcc-bd7e-337546fd1a9c':
              '저장된 조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          'f9381a81-5d25-44c0-9c3d-a2911686507e':
              '밥·계란프라이·참깨를 복구했지만 해당 분량·준비 과정과 돼지고기 익힘 확인이 남아 추천을 보류했어요.',
          '0276ab22-b134-4dc3-9990-d2dd844dcd42':
              '조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '16e3a332-5dbe-437c-bbe4-a47e9355985c':
              '조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '741b2897-4bde-4bac-a575-88baa2fd437e':
              '조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '8c24acd9-b104-4bad-a6ec-7e61a37417f1':
              '조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          'a7c85be2-86a0-4845-885d-43c98a7a4745':
              '조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          'aaba4f35-0a5a-40fd-ab8b-1f8f76887d8d':
              '밥·물과 구운 소시지 표기를 복구했지만 소시지·참치마요 분량·준비와 계란 익힘 확인이 남아 추천을 보류했어요.',
          'd4f79ea5-f936-46b8-a748-fb5a4c473333':
              '조리 설명과 재료 목록이 일치하지 않아 추천을 보류했어요. 원문 확인이 필요해요.',
          '032d9f6f-75de-5c03-8f11-e2afbbecd57d':
              '원문 재료 목록 복구 후 추가 검토 중으로 추천을 보류했어요.',
          '1ae0b6d9-9dd5-58f7-a340-d731e70178a8':
              '원문 재료 목록 복구 후 추가 검토 중으로 추천을 보류했어요.',
          '1e9c115d-ec14-514a-bcae-59c9a44760dc':
              '원문 재료 목록 복구 후 추가 검토 중으로 추천을 보류했어요.',
          '3d8da6ff-c052-5ab9-bd22-06e3f2a2347c':
              '원문 재료 목록 복구 후 추가 검토 중으로 추천을 보류했어요.',
          '637753ee-26e9-5ab5-b56c-ee723d21f715':
              '원문 재료 목록 복구 후 추가 검토 중으로 추천을 보류했어요.',
          'b5e98e1b-4d2b-570d-9663-91e397ac3ba8':
              '원문 재료 목록 복구 후 추가 검토 중으로 추천을 보류했어요.',
          'd2635645-1ab9-5a3c-9062-009e50dd324e':
              '원문 재료 목록 복구 후 추가 검토 중으로 추천을 보류했어요.',
          '7bac407a-7d54-526b-a6f1-0d04563d58f4':
              '익힘 확인 설명이 충분하지 않아 추천을 보류했어요.',
          '0e8c79fb-9281-5384-8bea-881f53f5b119':
              '익힘 확인 설명이 충분하지 않아 추천을 보류했어요.',
          'cb2c3f45-f809-5a4d-9954-eb350a48bf6a':
              '굽는 시간과 완료 기준을 확인해야 하므로 추천을 보류했어요.',
          '66097dc3-2bfb-54d6-9354-fb7e0f7c44a8':
              '굽는 시간과 완료 기준을 확인해야 하므로 추천을 보류했어요.',
          '646859de-721d-5aed-b3ab-f659bd09c204':
              '재료의 준비 상태와 시작 단계를 확인해야 하므로 추천을 보류했어요.',
        }[id];

  bool get eligibleForRecommendation =>
      recommendationHoldReason == null && eligibleForBrowsing;

  // Dictionary membership is not evidence that an ingredient is present or absent.
  bool get eligibleForBrowsing =>
      name.trim().isNotEmpty &&
      requiredIngredients.isNotEmpty &&
      requiredIngredients.every((name) => name.trim().isNotEmpty) &&
      !hasMalformedSource;

  List<String> get unlistedReferenceIngredients => requiredIngredients
      .where((name) => !_referenceFoodNames.contains(_catalogKey(name)))
      .toSet()
      .toList(growable: false);

  String? get ingredientMatchingNotice =>
      description?.contains('<!-- mfds-import:v1;') == true &&
          unlistedReferenceIngredients.isNotEmpty
      ? '사전 미등재 재료도 원문 그대로 표시합니다: ${unlistedReferenceIngredients.join(', ')}. '
            '재고 이름이 일치할 때만 보유로 표시하며, 다른 이름의 같은 재료인지는 미확인입니다. 분량은 직접 확인해 주세요.'
      : null;

  bool get hasNavigableSteps => savedCookingSteps(
    displayDescription,
    unverified: hasUnverifiedSteps,
  ).isNotEmpty;

  String get dataQualityNotice => recommendationHoldReason != null
      ? recommendationHoldReason!
      : !eligibleForRecommendation
      ? '등록 정보 확인 필요 · 추천에서 제외됩니다.'
      : !hasNavigableSteps
      ? '단계별 조리 안내 미확인 · 원문을 확인해 주세요.'
      : '저장된 조리 단계 있음 · 분량과 원문을 확인해 주세요.';

  /// Existing saved evidence records explicitly distinguish unknown steps.
  bool get hasUnverifiedSteps =>
      description?.contains('[아직 확인되지 않은 정보]') == true ||
      description?.contains('<!-- recipe-evidence:v1;steps=unverified -->') ==
          true;

  String get displayDescription => (description ?? '')
      // Keep provenance in the stored description, not in screen-reader copy.
      .replaceAll(
        RegExp(r'<!--\s*(?:recipe-evidence|mfds-import):[\s\S]*?-->'),
        '',
      )
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
  final String? servings;
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
    this.servings,
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
    servings: json['servings'],
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

/// Collapse identical content only in recommendations, never delete saved rows.
/// Names or URLs alone are insufficient: variants and different sources remain.
List<Recipe> uniqueRecommendationRecipes(Iterable<Recipe> recipes) {
  final ordered = recipes.where((r) => r.eligibleForRecommendation).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final seen = <String>{};
  return ordered
      .where(
        (r) => seen.add(
          jsonEncode([
            r.name,
            r.description,
            r.blogUrl,
            r.youtubeVideoId,
            r.imageUrl,
            r.totalTime,
            r.servings,
            r.cuisineType,
            r.videoSegments,
            r.requiredIngredients,
          ]),
        ),
      )
      .toList();
}
