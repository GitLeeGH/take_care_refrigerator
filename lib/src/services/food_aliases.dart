// Reviewed exact synonyms from the food catalog, never substitutions.
const catalogIngredientAliases = <String, String>{
  // Same cooked form only, never interchangeable with a raw whole egg.
  '삶은계란': '삶은달걀',
  // Same explicit egg part only; never a whole egg substitution.
  '계란흰자': '달걀흰자',
  '계란노른자': '달걀노른자',
  // Exact spelling variants only; preserve preparation and meat cuts.
  '브로컬리': '브로콜리',
  '다진쇠고기': '다진소고기',
  // Same preparation/form only; never collapse minced/ground into whole foods.
  '마늘다진것': '다진마늘',
  '대파다진것': '다진대파',
  '후춧가루': '후추가루',
  '흰후춧가루': '흰후추가루',
  "달걀": "계란",
  "egg": "계란",
  "모짜렐라": "모차렐라",
  "샐러리": "셀러리",
  "쇠고기": "소고기",
  "salt": "소금",
  "소세지": "소시지",
  "숙주": "숙주나물",
  "cooking oil": "식용유",
  "올리브오일": "올리브유",
  "주키니호박": "주키니",
  "zucchini": "주키니",
  "주꾸미": "쭈꾸미",
  "sesame oil": "참기름",
  "케찹": "케첩",
  "컬리플라워": "콜리플라워",
  "black pepper": "후추",
};
