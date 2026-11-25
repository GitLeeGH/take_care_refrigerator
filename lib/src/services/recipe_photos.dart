import '../models.dart';

/// Visually reviewed completed-dish photos bound to exact source records.
/// Offline display lookup only; never changes recipes or recommendations.
class RecipePhoto {
  const RecipePhoto({
    required this.recipeId,
    required this.name,
    required this.sourceId,
    required this.assetPath,
    this.focalY = 0,
  });
  // Null only for explicitly reviewed source-record mappings below.
  final String? recipeId;
  final String name, sourceId, assetPath;
  final double focalY;
  static const author = '식품의약품안전처';
  static const license = '이용허락범위 제한 없음';
  static const sourceUrl =
      'https://www.foodsafetykorea.go.kr/api/newDatasetDetail.do?svc_no=COOKRCP01';
  static const licenseUrl = 'https://www.data.go.kr/data/15060073/openapi.do';
}

RecipePhoto? recipePhotoFor(Recipe recipe) {
  if (recipe.sourceUri?.toString() != RecipePhoto.sourceUrl) return null;
  final marker = RegExp(
    r'<!-- mfds-import:v1;[^>]*;id=(\d+);',
  ).firstMatch(recipe.description ?? '');
  if (marker == null) return null;
  for (final photo in recipePhotos) {
    if (recipe.id == photo.recipeId &&
        recipe.name == photo.name &&
        marker.group(1) == photo.sourceId) {
      return photo;
    }
  }
  // These public source records were verified independently of app UUIDs.
  // Still require exact official URI, marker number and dish name above/below.
  for (final photo in sourceRecordRecipePhotos) {
    if (recipe.name == photo.name && marker.group(1) == photo.sourceId) {
      return photo;
    }
  }
  return null;
}

const recipePhotos = <RecipePhoto>[
  RecipePhoto(
    recipeId: '66097dc3-2bfb-54d6-9354-fb7e0f7c44a8',
    name: '야채칩',
    sourceId: '1002',
    assetPath: 'assets/images/recipes/mfds_1002.jpg',
  ),
  RecipePhoto(
    recipeId: '5aa208d0-2f68-58e4-8f02-2d3322c7108c',
    name: '가지볶음',
    sourceId: '1034',
    assetPath: 'assets/images/recipes/mfds_1034.jpg',
  ),
  RecipePhoto(
    recipeId: '0e8c79fb-9281-5384-8bea-881f53f5b119',
    name: '새우채소꼬치구이',
    sourceId: '1081',
    assetPath: 'assets/images/recipes/mfds_1081.png',
  ),
  RecipePhoto(
    recipeId: '6422e24b-1b16-5d9a-bde1-3c8954785c68',
    name: '비트두유',
    sourceId: '1133',
    assetPath: 'assets/images/recipes/mfds_1133.png',
  ),
  RecipePhoto(
    recipeId: '32596758-9385-55c0-a75b-19802a2d722a',
    name: '광어스테이크',
    sourceId: '501',
    assetPath: 'assets/images/recipes/mfds_501.png',
  ),
  RecipePhoto(
    recipeId: '5a3ee737-727c-5bc7-a02e-df543342eeb8',
    name: '코코넛밀크카레',
    sourceId: '503',
    assetPath: 'assets/images/recipes/mfds_503.png',
  ),
  RecipePhoto(
    recipeId: '1e9c115d-ec14-514a-bcae-59c9a44760dc',
    name: '수삼매운닭찜',
    sourceId: '679',
    assetPath: 'assets/images/recipes/mfds_679.jpg',
  ),
  RecipePhoto(
    recipeId: '4811e932-50f1-5f94-a390-2a3399f9ce21',
    name: '수박껍질풋고추볶음',
    sourceId: '685',
    assetPath: 'assets/images/recipes/mfds_685.jpg',
  ),
  RecipePhoto(
    recipeId: '646859de-721d-5aed-b3ab-f659bd09c204',
    name: '포도호두스무디',
    sourceId: '688',
    assetPath: 'assets/images/recipes/mfds_688.jpg',
  ),
];

/// Exact public source records with no retained app-row UUID snapshot.
/// Never match a source number without the exact source URI and dish name.
const sourceRecordRecipePhotos = <RecipePhoto>[
  RecipePhoto(
    recipeId: null,
    name: '쑥호두달걀말이',
    sourceId: '700',
    assetPath: 'assets/images/recipes/mfds_700.jpg',
  ),
  RecipePhoto(
    recipeId: null,
    name: '아욱 된장무침',
    sourceId: '3009',
    assetPath: 'assets/images/recipes/mfds_3009.jpg',
    focalY: 1,
  ),
];

const allRecipePhotos = <RecipePhoto>[
  ...recipePhotos,
  ...sourceRecordRecipePhotos,
];
