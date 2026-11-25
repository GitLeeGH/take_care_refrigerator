import '../models.dart';

/// Licensed, visually reviewed examples, not this recipe's actual result.
/// Provenance and exact-byte hashes: assets/images/recipe_examples/sources.json.
class RecipeExamplePhoto {
  const RecipeExamplePhoto({
    required this.id,
    required this.name,
    required this.originalTitle,
    required this.aliases,
    required this.assetPath,
    required this.author,
    required this.sourceUrl,
    required this.license,
    required this.licenseUrl,
  });
  final String id,
      name,
      originalTitle,
      assetPath,
      author,
      sourceUrl,
      license,
      licenseUrl;
  final List<String> aliases;
  static const usageNotice = '해당 레시피로 만든 실제 사진은 아니며 재료·모양이 다를 수 있어요.';
  static const changes = 'Commons 제공 축소본. 화면에 맞춰 크기·가장자리를 조절해 표시합니다.';
}

String _photoNameKey(String name) => name.replaceAll(RegExp(r'\s+'), '');

/// Allow-list only: no substring, ingredient, category or fuzzy matching.
RecipeExamplePhoto? recipeExamplePhotoFor(Recipe recipe) {
  if (recipe.browsingContentWarning != null) return null;
  final key = _photoNameKey(recipe.name);
  for (final photo in recipeExamplePhotos) {
    if (photo.aliases.any((name) => _photoNameKey(name) == key)) return photo;
  }
  return null;
}

const recipeExamplePhotos = <RecipeExamplePhoto>[
  RecipeExamplePhoto(
    id: "banana_smoothie",
    name: "바나나 스무디",
    originalTitle: "File:Banana Smoothie.jpg",
    assetPath: "assets/images/recipe_examples/banana_smoothie.jpg",
    author: "Ourlibrary",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Banana_Smoothie.jpg",
    license: "CC0",
    licenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/deed.en",
    aliases: ["바나나미숫가루쉐이크", "바나나쉐이크", "바나나스무디"],
  ),
  RecipeExamplePhoto(
    id: "pumpkin_soup",
    name: "호박 스프",
    originalTitle: "File:Autumn Soup (Unsplash) cropped.jpg",
    assetPath: "assets/images/recipe_examples/pumpkin_soup.jpg",
    author: "Cala cala_maffia",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Autumn_Soup_(Unsplash)_cropped.jpg",
    license: "CC0",
    licenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/deed.en",
    aliases: ["호박 고구마 스프", "단호박스프", "단호박수프", "호박스프"],
  ),
  RecipeExamplePhoto(
    id: "potato_salad",
    name: "감자 샐러드",
    originalTitle: "File:Potato salad-2.jpg",
    assetPath: "assets/images/recipe_examples/potato_salad.jpg",
    author: "jules",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Potato_salad-2.jpg",
    license: "CC BY 2.0",
    licenseUrl: "https://creativecommons.org/licenses/by/2.0",
    aliases: ["완두콩과 당근을 넣은 감자요거트 샐러드", "감자샐러드"],
  ),
  RecipeExamplePhoto(
    id: "miso_soup",
    name: "미소국",
    originalTitle: "File:Miso Soup 001.jpg",
    assetPath: "assets/images/recipe_examples/miso_soup.jpg",
    author: "Ocdp",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Miso_Soup_001.jpg",
    license: "CC0",
    licenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/deed.en",
    aliases: ["미역 미소국", "미소국", "미소된장국"],
  ),
  RecipeExamplePhoto(
    id: "watermelon_punch",
    name: "수박 화채",
    originalTitle: "File:Subak-hwachae.jpg",
    assetPath: "assets/images/recipe_examples/watermelon_punch.jpg",
    author: "Dr 방원장",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Subak-hwachae.jpg",
    license: "CC BY 4.0",
    licenseUrl: "https://creativecommons.org/licenses/by/4.0",
    aliases: ["수박 화채", "수박화채"],
  ),
  RecipeExamplePhoto(
    id: "strawberry_salad",
    name: "딸기 샐러드",
    originalTitle: "File:Strawberry salad.jpg",
    assetPath: "assets/images/recipe_examples/strawberry_salad.jpg",
    author: "E4024",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Strawberry_salad.jpg",
    license: "CC BY-SA 4.0",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
    aliases: ["스트로베리 샐러드", "딸기샐러드"],
  ),
  RecipeExamplePhoto(
    id: "grilled_banana",
    name: "구운 바나나",
    originalTitle: "File:Ginanggang (Philippines) 01.jpg",
    assetPath: "assets/images/recipe_examples/grilled_banana.jpg",
    author: "Obsidian Soul",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Ginanggang_(Philippines)_01.jpg",
    license: "CC0",
    licenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/deed.en",
    aliases: ["구운 바나나", "바나나구이"],
  ),
  RecipeExamplePhoto(
    id: "pumpkin_pudding",
    name: "호박 푸딩",
    originalTitle: "File:Vegan Pumpkin Custard (4320833119).jpg",
    assetPath: "assets/images/recipe_examples/pumpkin_pudding.jpg",
    author: "Vegan Feast Catering",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Vegan_Pumpkin_Custard_(4320833119).jpg",
    license: "CC BY 2.0",
    licenseUrl: "https://creativecommons.org/licenses/by/2.0",
    aliases: ["단호박푸딩", "호박푸딩"],
  ),
  RecipeExamplePhoto(
    id: "broccoli_stirfry",
    name: "브로콜리 볶음",
    originalTitle: "File:Stir-fried broccoli.jpg",
    assetPath: "assets/images/recipe_examples/broccoli_stirfry.jpg",
    author: "Fumikas Sagisavas",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Stir-fried_broccoli.jpg",
    license: "CC0",
    licenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/deed.en",
    aliases: ["브로콜리견과류복음", "브로콜리견과류볶음", "브로콜리볶음"],
  ),
  RecipeExamplePhoto(
    id: "yogurt_parfait",
    name: "요거트 파르페",
    originalTitle:
        "File:Parfaits at Harvest Table - February 2023 - Sarah Stierch.jpg",
    assetPath: "assets/images/recipe_examples/yogurt_parfait.jpg",
    author: "Missvain",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Parfaits_at_Harvest_Table_-_February_2023_-_Sarah_Stierch.jpg",
    license: "CC BY 4.0",
    licenseUrl: "https://creativecommons.org/licenses/by/4.0",
    aliases: ["누룽지 요거트 파르페", "요거트파르페"],
  ),
];
