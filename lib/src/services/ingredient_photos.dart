/// Curated real photographs, bundled for offline display.
/// Source metadata: assets/images/ingredients/sources.json.
/// This catalogue is visual only; never use it for dates, safety or recognition.
class IngredientReferencePhoto {
  const IngredientReferencePhoto({
    required this.id,
    required this.name,
    required this.aliases,
    required this.assetPath,
    required this.title,
    required this.author,
    required this.license,
    required this.licenseUrl,
    required this.sourceUrl,
  });
  final String id;
  final String name;
  final List<String> aliases;
  final String assetPath;
  final String title;
  final String author;
  final String license;
  final String licenseUrl;
  final String sourceUrl;
}

const ingredientReferencePhotos = <IngredientReferencePhoto>[
  IngredientReferencePhoto(
    id: "carrot",
    name: "당근",
    assetPath: "assets/images/ingredients/carrot.jpg",
    title: "Vegetable-Carrot-Bundle-wStalks.jpg",
    author: "Evan-Amos",
    license: "Public domain",
    licenseUrl: "",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Vegetable-Carrot-Bundle-wStalks.jpg",
    aliases: ["carrot", "carrots"],
  ),
  IngredientReferencePhoto(
    id: "onion",
    name: "양파",
    assetPath: "assets/images/ingredients/onion.jpg",
    title: "Onion on White.JPG",
    author: "Colin",
    license: "CC BY-SA 3.0",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/3.0",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Onion_on_White.JPG",
    aliases: ["onion", "onions"],
  ),
  IngredientReferencePhoto(
    id: "egg",
    name: "계란",
    assetPath: "assets/images/ingredients/egg.jpg",
    title: "6-Pack-Chicken-Eggs.jpg",
    author: "Evan-Amos",
    license: "Public domain",
    licenseUrl: "",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:6-Pack-Chicken-Eggs.jpg",
    aliases: ["달걀", "egg", "eggs"],
  ),
  IngredientReferencePhoto(
    id: "garlic",
    name: "마늘",
    assetPath: "assets/images/ingredients/garlic.jpg",
    title: "Garlic bulbs and cloves.jpg",
    author: "Ivar Leidus",
    license: "CC BY-SA 4.0",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Garlic_bulbs_and_cloves.jpg",
    aliases: ["통마늘", "깐마늘", "garlic"],
  ),
  IngredientReferencePhoto(
    id: "tomato",
    name: "토마토",
    assetPath: "assets/images/ingredients/tomato.jpg",
    title: "Tomato je.jpg",
    author: "Softeis",
    license: "CC BY-SA 3.0",
    licenseUrl: "http://creativecommons.org/licenses/by-sa/3.0/",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Tomato_je.jpg",
    aliases: ["tomato", "tomatoes"],
  ),
  IngredientReferencePhoto(
    id: "cherry_tomato",
    name: "방울토마토",
    assetPath: "assets/images/ingredients/cherry_tomato.jpg",
    title: "Cherry-Tomatoes-in-Pack.jpg",
    author: "Evan-Amos",
    license: "CC0",
    licenseUrl: "http://creativecommons.org/publicdomain/zero/1.0/deed.en",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Cherry-Tomatoes-in-Pack.jpg",
    aliases: ["cherry tomato", "cherry tomatoes"],
  ),
  IngredientReferencePhoto(
    id: "cucumber",
    name: "오이",
    assetPath: "assets/images/ingredients/cucumber.jpg",
    title: "CDC cuke2.jpg",
    author: "U.S. Centers for Disease Control and Prevention (CDC)",
    license: "Public domain",
    licenseUrl: "",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:CDC_cuke2.jpg",
    aliases: ["cucumber", "cucumbers"],
  ),
  IngredientReferencePhoto(
    id: "zucchini",
    name: "주키니",
    assetPath: "assets/images/ingredients/zucchini.jpg",
    title: "Zucchini-Whole.jpg",
    author: "Evan-Amos",
    license: "Public domain",
    licenseUrl: "",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Zucchini-Whole.jpg",
    aliases: ["주키니호박", "zucchini"],
  ),
  IngredientReferencePhoto(
    id: "cauliflower",
    name: "콜리플라워",
    assetPath: "assets/images/ingredients/cauliflower.jpg",
    title: "Chou-fleur 02.jpg",
    author: "Coyau",
    license: "CC BY-SA 3.0",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/3.0",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Chou-fleur_02.jpg",
    aliases: ["컬리플라워", "cauliflower"],
  ),
  IngredientReferencePhoto(
    id: "bell_pepper",
    name: "파프리카",
    assetPath: "assets/images/ingredients/bell_pepper.jpg",
    title: "Green-Yellow-Red-Pepper-2009.jpg",
    author: "Kham Tran - www.khamtran.com",
    license: "CC BY-SA 3.0",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/3.0",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Green-Yellow-Red-Pepper-2009.jpg",
    aliases: ["bell pepper", "bell peppers"],
  ),
  IngredientReferencePhoto(
    id: "potato_chips",
    name: "감자칩",
    assetPath: "assets/images/ingredients/potato_chips.jpg",
    title: "Potato-Chips.jpg",
    author: "Evan-Amos",
    license: "Public domain",
    licenseUrl: "",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Potato-Chips.jpg",
    aliases: ["포테이토칩", "potato chips"],
  ),
  IngredientReferencePhoto(
    id: "broccoli",
    name: "브로콜리",
    assetPath: "assets/images/ingredients/broccoli.jpg",
    title: "Broccolli 2.jpg",
    author: "JJ Harrison (https://www.jjharrison.com.au/)",
    license: "CC BY-SA 2.5",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/2.5",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Broccolli_2.jpg",
    aliases: ["broccoli"],
  ),
  IngredientReferencePhoto(
    id: "potato",
    name: "감자",
    assetPath: "assets/images/ingredients/potato.jpg",
    title: "Potato cv Dejima (cropped).jpg",
    author: "Fk",
    license: "CC BY-SA 4.0",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Potato_cv_Dejima_(cropped).jpg",
    aliases: ["potato", "potatoes"],
  ),
  IngredientReferencePhoto(
    id: "sweet_potato",
    name: "고구마",
    assetPath: "assets/images/ingredients/sweet_potato.jpg",
    title: "5aday sweet potato.jpg",
    author: "National Cancer Institute (5 A Day)",
    license: "Public domain",
    licenseUrl: "",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:5aday_sweet_potato.jpg",
    aliases: ["sweet potato", "sweet potatoes"],
  ),
  IngredientReferencePhoto(
    id: "scallion",
    name: "대파",
    assetPath: "assets/images/ingredients/scallion.jpg",
    title: "Spring Onion.jpg",
    author: "Donovan Govan.",
    license: "CC BY-SA 3.0",
    licenseUrl: "http://creativecommons.org/licenses/by-sa/3.0/",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Spring_Onion.jpg",
    aliases: ["scallion", "scallions", "green onion", "green onions"],
  ),
  IngredientReferencePhoto(
    id: "spinach",
    name: "시금치",
    assetPath: "assets/images/ingredients/spinach.jpg",
    title: "Spinach leaves.jpg",
    author: "Nillerdk",
    license: "CC BY 3.0",
    licenseUrl: "https://creativecommons.org/licenses/by/3.0",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Spinach_leaves.jpg",
    aliases: ["spinach"],
  ),
  IngredientReferencePhoto(
    id: "eggplant",
    name: "가지",
    assetPath: "assets/images/ingredients/eggplant.jpg",
    title: "Aubergine.jpg",
    author: "Horst Frank",
    license: "CC BY-SA 3.0",
    licenseUrl: "http://creativecommons.org/licenses/by-sa/3.0/",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Aubergine.jpg",
    aliases: ["eggplant", "aubergine"],
  ),
  IngredientReferencePhoto(
    id: "tofu",
    name: "두부",
    assetPath: "assets/images/ingredients/tofu.png",
    title: "Tofu 2.png",
    author: "Tiia Monto",
    license: "CC BY-SA 4.0",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Tofu_2.png",
    aliases: ["tofu", "firm tofu"],
  ),
  IngredientReferencePhoto(
    id: "soft_tofu",
    name: "연두부",
    assetPath: "assets/images/ingredients/soft_tofu.jpg",
    title: "Japanese SilkyTofu (Kinugoshi Tofu).JPG",
    author: "DryPot",
    license: "CC BY-SA 3.0",
    licenseUrl: "http://creativecommons.org/licenses/by-sa/3.0/",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Japanese_SilkyTofu_(Kinugoshi_Tofu).JPG",
    aliases: ["silken tofu"],
  ),
  IngredientReferencePhoto(
    id: "enoki",
    name: "팽이버섯",
    assetPath: "assets/images/ingredients/enoki.jpg",
    title: "EnokitakeJapaneseMushroom.jpg",
    author: "Chris 73",
    license: "CC BY-SA 3.0",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/3.0",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:EnokitakeJapaneseMushroom.jpg",
    aliases: ["팽이", "enoki", "enoki mushroom", "enoki mushrooms"],
  ),
  IngredientReferencePhoto(
    id: "soybean_sprouts",
    name: "콩나물",
    assetPath: "assets/images/ingredients/soybean_sprouts.jpg",
    title: "Kongnamul (soybean sprout) 2.jpg",
    author: "Hyeon-Jeong Suk",
    license: "CC BY 2.0",
    licenseUrl: "https://creativecommons.org/licenses/by/2.0",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Kongnamul_(soybean_sprout)_2.jpg",
    aliases: ["soybean sprouts"],
  ),
  IngredientReferencePhoto(
    id: "mung_sprouts",
    name: "숙주",
    assetPath: "assets/images/ingredients/mung_sprouts.jpg",
    title: "Mung bean sprouts 1.jpg",
    author: "chomjong",
    license: "CC BY 2.0",
    licenseUrl: "https://creativecommons.org/licenses/by/2.0",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Mung_bean_sprouts_1.jpg",
    aliases: ["숙주나물", "mung bean sprouts"],
  ),
  IngredientReferencePhoto(
    id: "apple",
    name: "사과",
    assetPath: "assets/images/ingredients/apple.jpg",
    title: "Wet apple isolated on white.jpg",
    author: "robin_24",
    license: "CC BY 2.0",
    licenseUrl: "https://creativecommons.org/licenses/by/2.0",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Wet_apple_isolated_on_white.jpg",
    aliases: ["apple", "apples"],
  ),
  IngredientReferencePhoto(
    id: "milk",
    name: "우유",
    assetPath: "assets/images/ingredients/milk.jpg",
    title: "Milk glass.jpg",
    author: "Stefan Kühn",
    license: "CC BY-SA 3.0",
    licenseUrl: "http://creativecommons.org/licenses/by-sa/3.0/",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Milk_glass.jpg",
    aliases: ["milk"],
  ),
  IngredientReferencePhoto(
    id: "rice",
    name: "쌀",
    assetPath: "assets/images/ingredients/rice.jpg",
    title: "White rice.jpg",
    author: "Lucy Gull",
    license: "CC BY-SA 3.0",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/3.0",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:White_rice.jpg",
    aliases: ["백미", "white rice"],
  ),
  IngredientReferencePhoto(
    id: "lettuce",
    name: "상추",
    assetPath: "assets/images/ingredients/lettuce.jpg",
    title: "Hydroponic lettuce leaves green.jpg",
    author: "Leon Brooks",
    license: "Public domain",
    licenseUrl: "",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Hydroponic_lettuce_leaves_green.jpg",
    aliases: ["leaf lettuce"],
  ),
  IngredientReferencePhoto(
    id: "red_bell_pepper",
    name: "빨강 파프리카",
    assetPath: "assets/images/ingredients/red_bell_pepper.jpg",
    title: "Red-Pepper.jpg",
    author: "Evan-Amos",
    license: "CC0",
    licenseUrl: "http://creativecommons.org/publicdomain/zero/1.0/deed.en",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Red-Pepper.jpg",
    aliases: ["빨간 파프리카", "홍파프리카", "홍피망", "red bell pepper"],
  ),
  IngredientReferencePhoto(
    id: "yellow_bell_pepper",
    name: "노랑 파프리카",
    assetPath: "assets/images/ingredients/yellow_bell_pepper.jpg",
    title: "Yellow bell pepper 2017 A1.jpg",
    author: "Fructibus",
    license: "CC0",
    licenseUrl: "http://creativecommons.org/publicdomain/zero/1.0/deed.en",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Yellow_bell_pepper_2017_A1.jpg",
    aliases: ["노란 파프리카", "yellow bell pepper"],
  ),
  IngredientReferencePhoto(
    id: "button_mushroom",
    name: "양송이버섯",
    assetPath: "assets/images/ingredients/button_mushroom.jpg",
    title: "Champignons Agaricus.jpg",
    author: "Darkone (talk · contribs)",
    license: "CC BY-SA 2.5",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/2.5",
    sourceUrl:
        "https://commons.wikimedia.org/wiki/File:Champignons_Agaricus.jpg",
    aliases: ["양송이", "button mushroom", "button mushrooms"],
  ),
  IngredientReferencePhoto(
    id: "aehobak",
    name: "애호박",
    assetPath: "assets/images/ingredients/aehobak.jpg",
    title: "Aehobak (cropped).jpg",
    author: "산체",
    license: "CC BY-SA 2.5",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/2.5",
    sourceUrl: "https://commons.wikimedia.org/wiki/File:Aehobak_(cropped).jpg",
    aliases: ["aehobak", "korean zucchini"],
  ),
];

String _photoKey(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'\s+'), '');

final _photosByName = <String, IngredientReferencePhoto>{
  for (final photo in ingredientReferencePhotos)
    for (final alias in [photo.name, ...photo.aliases]) _photoKey(alias): photo,
};

/// Exact names and reviewed aliases only. Removing a trailing pack quantity is
/// safe for display, but substring matching could show raw food for a sauce,
/// soup, mixed dish or a different species and is deliberately not used.
IngredientReferencePhoto? ingredientReferencePhotoFor(String name) {
  final key = _photoKey(
    name,
  ).replaceFirst(RegExp(r'\(?\d+(?:\.\d+)?(?:kg|g|ml|l|개|봉|팩|통|병|구)\)?$'), '');
  return _photosByName[key];
}
