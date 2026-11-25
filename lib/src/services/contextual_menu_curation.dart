import '../models.dart';

/// Context is supplied explicitly. Missing weather/location never implies rain
/// or a hemisphere. Age alone is intentionally not a ranking input.
enum MenuMoment { everyday, winter, rainy }

class ContextMenu {
  const ContextMenu(this.recipe, this.reason);
  final Recipe recipe;
  final String reason;
}

List<ContextMenu> contextualMenus(
  Iterable<Recipe> reviewedCandidates, {
  MenuMoment moment = MenuMoment.everyday,
  Set<String> preferredIngredients = const {},
}) {
  final rows = <({Recipe recipe, int score, int index, String reason})>[];
  var index = 0;
  for (final recipe in reviewedCandidates) {
    final order = index++;
    if (!recipe.eligibleForRecommendation) continue;
    final text = '${recipe.name} ${recipe.requiredIngredients.join(' ')}';
    // Adult eligibility is not collected, so alcohol pairings are never added.
    if (RegExp('막걸리|소주|맥주|와인|칵테일|위스키').hasMatch(text)) continue;
    var score = 0;
    var reason = '기존 추천 순서로 골랐어요.';
    if (moment == MenuMoment.rainy &&
        RegExp('파전|부침개|김치전|감자전').hasMatch(recipe.name)) {
      score += 1;
      reason = '선택한 비 오는 날 테마에 어울리는 전 메뉴예요.';
    }
    final preferred = recipe.requiredIngredients
        .where(preferredIngredients.contains)
        .toList();
    if (preferred.isNotEmpty) {
      score += 1;
      reason = '좋아한다고 선택한 ${preferred.join(', ')}를 활용해요.';
    }
    rows.add((recipe: recipe, score: score, index: order, reason: reason));
  }
  rows.sort((a, b) {
    final score = b.score.compareTo(a.score);
    return score != 0 ? score : a.index.compareTo(b.index);
  });
  return [for (final row in rows) ContextMenu(row.recipe, row.reason)];
}

/// Korean public monthly recommendations, not exclusive harvest windows.
/// Verified foodnuri monthly pages, 2026-11-11. Exact ingredient names only:
/// do not infer varieties, preserved foods, prices, or local availability.
const officialMonthlyIngredients = <int, Set<String>>{
  1: {'우엉', '감귤', '레드향', '방울양배추'},
  2: {'봄동', '유채나물', '딸기', '천혜향', '한라봉', '연근', '시금치'},
  3: {'세발나물', '돌나물', '미나리', '달래'},
  4: {'산마늘', '완두콩', '아스파라거스', '씀바귀', '쑥', '머위'},
  5: {'곰취', '상추', '오이', '호박잎', '취나물'},
  6: {'보리수열매', '체리', '보리', '살구', '앵두'},
  7: {'토마토', '아욱', '블루베리', '강낭콩', '깻잎'},
  8: {'청귤', '홍고추', '포도', '참나물', '여주'},
  9: {'기장', '조', '찹쌀', '흑미', '토란대', '능이버섯'},
  10: {'청경채', '수수', '쌀', '대두', '대파'},
  11: {'섬초', '총각무', '잣', '유자', '얼갈이배추', '배추', '마', '무', '단호박', '늙은호박', '감'},
  12: {'돼지감자', '당근', '브로콜리', '콜라비', '콜리플라워', '키위'},
};

String? officialSeasonalSource(int month) =>
    officialMonthlyIngredients.containsKey(month)
    ? 'https://www.foodnuri.go.kr/portal/bbs/B0000283/list.do?menuNo=300063&searchCnd=&searchWrd=&selectMonth=$month'
    : null;

// Retained for callers of the initial November-only API.
const novemberSeasonalSource =
    'https://www.foodnuri.go.kr/portal/bbs/B0000283/list.do?menuNo=300063&searchCnd=&searchWrd=&selectMonth=11';
final novemberSeasonalIngredients = officialMonthlyIngredients[11]!;

/// Match reviewed recipes against the supplied Korean calendar month.
/// Missing/invalid month does not infer weather, location, or a season.
List<ContextMenu> officialSeasonalMenus(
  Iterable<Recipe> candidates,
  int month,
) {
  final seasonal = officialMonthlyIngredients[month];
  if (seasonal == null) return [];
  return [
    for (final row in contextualMenus(candidates))
      if (row.recipe.requiredIngredients.any(
        (name) => seasonal.contains(name.trim()),
      ))
        ContextMenu(
          row.recipe,
          '${row.recipe.requiredIngredients.map((name) => name.trim()).where(seasonal.contains).toSet().join(', ')}: 농식품정보누리 $month월 추천 식재료',
        ),
  ];
}
