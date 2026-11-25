import 'services/food_aliases.dart';

/// Conservative identity matching only. Never a quantity or allergy check.
const _ingredientAliases = <String, String>{'숙주나물': '숙주', '달걀': '계란'};
final _packageSpec = RegExp(
  r'^\d+(?:\.\d+)?\s*(?:kg|g|ml|l|개|입|봉|팩)(?:\s*[x×*]\s*\d+\s*(?:개|입|봉|팩)?)?$',
);
final _packageSuffix = RegExp(
  r'\s*\d+(?:\.\d+)?\s*(?:kg|g|ml|l|개|입|봉|팩)(?:\s*[x×*]\s*\d+\s*(?:개|입|봉|팩)?)?$',
);
String _cleanIngredientName(String name) {
  var value = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  // Only a whole numeric packaging annotation can be discarded.
  value = value.replaceAllMapped(RegExp(r'\(([^()]*)\)|\[([^\[\]]*)\]'), (
    match,
  ) {
    final text = (match[1] ?? match[2]!).trim();
    return _packageSpec.hasMatch(text) ? ' ' : match[0]!;
  }).trim();
  value = value.replaceFirst(_packageSuffix, '').trim();
  // Ignore spaces between Korean syllables, not arbitrary English boundaries.
  value = value.replaceAll(RegExp(r'(?<=[가-힣])\s+(?=[가-힣])'), '');
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String normalizeIngredientName(String name) {
  final value = _cleanIngredientName(name);
  final catalogName = catalogIngredientAliases[value] ?? value;
  final canonical = _cleanIngredientName(catalogName);
  return _ingredientAliases[canonical] ?? canonical;
}

// Interpret explicit width variants only at ambiguity/exclusion boundaries.
// Do not rewrite stored names or broaden possession aliases/packaging cleanup.
String _canonicalIngredientPunctuation(String value) {
  const punctuation = {
    '（': '(',
    '）': ')',
    '［': '[',
    '］': ']',
    '／': '/',
    '，': ',',
    '＋': '+',
    '？': '?',
  };
  return value.replaceAllMapped(
    RegExp(r'[（）［］／，＋？]'),
    (match) => punctuation[match[0]]!,
  );
}

bool _ambiguousIngredientName(String name) =>
    normalizeIngredientName(name).isEmpty ||
    RegExp(
      r'[()\[\]/,·+?]|또는|혹은',
    ).hasMatch(_canonicalIngredientPunctuation(normalizeIngredientName(name)));
String _tentativeIngredientBase(String name) => normalizeIngredientName(
  _canonicalIngredientPunctuation(
    _cleanIngredientName(name),
  ).replaceAll(RegExp(r'\([^()]*\)|\[[^\[\]]*\]'), ''),
);

/// Complete coverage first, then owned proportion, then fewer missing names.
/// Counts use unique conservative name matches, never assumed pantry staples.
/// This is pantry relevance, not nutrition, allergy safety or a quantity check.
int compareIngredientAvailability(
  IngredientAvailability a,
  IngredientAvailability b,
) {
  if (a.canMake != b.canMake) return a.canMake ? -1 : 1;
  // Cross multiplication avoids rounding ties (e.g. 2/3 versus 3/5).
  // Unknown requirements have zero coverage, never 100% coverage.
  final aTotal = a.requiredIngredients.isEmpty
      ? 1
      : a.requiredIngredients.length;
  final bTotal = b.requiredIngredients.isEmpty
      ? 1
      : b.requiredIngredients.length;
  final coverage = (b.ownedIngredients.length * aTotal).compareTo(
    a.ownedIngredients.length * bTotal,
  );
  if (coverage != 0) return coverage;
  return a.missingIngredients.length.compareTo(b.missingIngredients.length);
}

class IngredientAvailability {
  IngredientAvailability(
    Iterable<String> required,
    Iterable<String> inventory,
  ) {
    final inventoryNames = inventory.toList();
    final owned =
        inventoryNames
            .where((name) => !_ambiguousIngredientName(name))
            .map(normalizeIngredientName)
            .toSet()
          ..remove('');
    final uncertainBases =
        inventoryNames
            .where(_ambiguousIngredientName)
            .map(_tentativeIngredientBase)
            .toSet()
          ..remove('');
    final unique = <String, String>{};
    for (final name in required) {
      final key = normalizeIngredientName(name);
      if (name.trim().isNotEmpty) {
        unique.putIfAbsent(
          key.isEmpty ? '?${name.trim()}' : key,
          () => name.trim(),
        );
      }
    }
    uncertainIngredients = List.unmodifiable([
      for (final entry in unique.entries)
        if (_ambiguousIngredientName(entry.value) ||
            (!owned.contains(entry.key) && uncertainBases.contains(entry.key)))
          entry.value,
    ]);
    requiredIngredients = List.unmodifiable(unique.values);
    ownedIngredients = List.unmodifiable([
      for (final entry in unique.entries)
        if (!_ambiguousIngredientName(entry.value) && owned.contains(entry.key))
          entry.value,
    ]);
    missingIngredients = List.unmodifiable([
      for (final entry in unique.entries)
        if (_ambiguousIngredientName(entry.value) || !owned.contains(entry.key))
          entry.value,
    ]);
  }

  late final List<String> requiredIngredients;
  late final List<String> ownedIngredients;

  /// Unmatched names, including uncertain names, retained for ranking compatibility.
  late final List<String> missingIngredients;
  late final List<String> uncertainIngredients;
  bool isUncertain(String name) => uncertainIngredients.any(
    (item) => normalizeIngredientName(item) == normalizeIngredientName(name),
  );

  // Unknown/empty requirements must not be advertised as ready to cook.
  bool get canMake =>
      requiredIngredients.isNotEmpty && missingIngredients.isEmpty;
  bool owns(String name) => ownedIngredients.any(
    (owned) => normalizeIngredientName(owned) == normalizeIngredientName(name),
  );
}

/// Preference exclusion is deliberately separate from possession evidence.
/// Explicit alternatives/annotations can trigger exclusion, never ownership.
/// Match whole components, not arbitrary substrings (간장 != 진간장).
// Explicit preparation/spelling aliases for preference exclusion only.
// These are not evidence of pantry equivalence or an allergy safety screen.
const _avoidanceAliases = <String, String>{
  '다진마늘': '마늘',
  '마늘다진것': '마늘',
  '후춧가루': '후추',
  '후추가루': '후추',
  '브로컬리': '브로콜리',
  '닭고기가슴살': '닭가슴살',
  '토막낸닭': '닭고기',
  '닭': '닭고기',
  '물오징어': '오징어',
};
// A broad avoided food excludes known subtypes, never the reverse.
const _avoidanceParents = <String, Set<String>>{
  '구운호두': {'호두'},
  '들깨가루': {'들깨'},
  '항정살': {'돼지고기'},
  '계란프라이': {'계란'},
  '계란후라이': {'계란'},
  '달걀프라이': {'계란'},
  '달걀후라이': {'계란'},
  '차돌박이': {'소고기'},
  '로티세리치킨가슴살': {'닭고기', '닭가슴살'},
  '소고기다시다': {'소고기'},
  '고등어통조림': {'고등어'},
  '다진소고기': {'소고기'},
  '쇠고기등심': {'소고기'},
  '다진돼지고기': {'돼지고기'},
  '돼지등심': {'돼지고기'},
  '다진호두': {'호두'},
  '아몬드가루': {'아몬드'},
  '아몬드슬라이스': {'아몬드'},
  '땅콩가루': {'땅콩'},
  '건새우': {'새우'},
  '새우살': {'새우'},
  '잔새우살다진것': {'새우'},
  '달걀흰자': {'계란'},
  '달걀노른자': {'계란'},
  // Unqualified parts trigger broad preference exclusion only.
  '흰자': {'계란'},
  '노른자': {'계란'},
  '삶은달걀': {'계란'},
  '건표고버섯': {'표고버섯'},
  '건미역': {'미역'},
  '마른미역': {'미역'},
  '불린미역': {'미역'},
  '생강즙': {'생강'},
  '다진생강': {'생강'},
  '마늘가루': {'마늘'},
  '마늘즙': {'마늘'},
  '통마늘': {'마늘'},
  '편마늘': {'마늘'},
  '녹인버터': {'버터'},
  '생강가루': {'생강'},
  '다진대파': {'대파', '파'},
  '다진파': {'파'},
  '파다진것': {'파'},
  '닭가슴살': {'닭고기'},
  '닭다리살': {'닭고기'},
  '닭안심': {'닭고기'},
  '갑오징어': {'오징어'},
};

// Preference-only measure cleanup. Possession matching remains unchanged.
final _avoidanceMeasureSuffix = RegExp(
  r'\s*\d+(?:\.\d+)?(?:/\d+)?\s*(?:숟가락|큰술|작은술|tbsp|tsp|컵)$',
  caseSensitive: false,
);

// Preserve spaced fractions only when followed by a known cooking measure.
// A slash between food names is still an alternative, not possession evidence.
final _avoidanceSpacedFraction = RegExp(
  r'(\d+)\s*/\s*(\d+)(?=\s*(?:숟가락|큰술|작은술|tbsp|tsp|컵)(?:\s|$|[()\[\],·+?/]))',
  caseSensitive: false,
);

bool matchesAvoidedIngredient(String required, Iterable<String> avoided) {
  String key(String value) {
    final normalized = normalizeIngredientName(
      value.trim().replaceFirst(_avoidanceMeasureSuffix, ''),
    );
    return _avoidanceAliases[normalized] ?? normalized;
  }

  // Preserve numeric fractions until each annotated component has its measure
  // removed. A slash between food alternatives remains a component boundary.
  Set<String> components(String value) => {
    for (final part
        in _canonicalIngredientPunctuation(value)
            .replaceAllMapped(
              _avoidanceSpacedFraction,
              (match) => '${match[1]}/${match[2]}',
            )
            .toLowerCase()
            .trim()
            .replaceFirst(_avoidanceMeasureSuffix, '')
            .split(RegExp(r'[()\[\],·+?]|(?<!\d)/|/(?!\d)|또는|혹은')))
      if (key(part).isNotEmpty) key(part),
  };
  final requiredComponents = components(required);
  final avoidedComponents = avoided.expand(components).toSet();
  return requiredComponents.any(
    (food) =>
        avoidedComponents.contains(food) ||
        (_avoidanceParents[food] ?? const <String>{}).any(
          avoidedComponents.contains,
        ),
  );
}
