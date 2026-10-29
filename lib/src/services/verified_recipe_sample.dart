import 'recipe_draft.dart';

/// Manually verified creator-comment facts supplied by the review workflow.
/// This fixture is not an extractor, and applies only to this exact video.
RecipeDraft? verifiedRecipeSample(YoutubeSource? source) {
  if (source?.videoId != 'rLEyOHvGb1Y') return null;
  const facts = <(String, String?, String)>[
    ('돼지고기 목전지', '600g', '목전지 600g · 앞다리살 대체 가능'),
    ('식용유', '3스푼', '식용유 3스푼'),
    ('설탕', '2스푼', '설탕 2스푼'),
    ('다진마늘', '1스푼', '다진마늘 1스푼'),
    ('고추장', '1스푼', '고추장 1스푼'),
    ('고춧가루', '4스푼', '고춧가루 4스푼'),
    ('진간장', '3스푼', '진간장 3스푼'),
    ('미림', '2스푼', '미림 2스푼'),
    ('굴소스', '1스푼', '굴소스 1스푼'),
    ('후추', null, '후추 · 분량 미기재'),
    ('청양고추', '2개 (20g)', '청양고추 2개 20g'),
    ('양파', '1/2개 (120g)', '양파 1/2개 120g'),
    ('대파', '1대 (100g)', '대파 1대 100g'),
    ('참기름', '1스푼', '참기름 1스푼'),
    ('통깨', '1스푼', '통깨 1스푼'),
  ];
  return RecipeDraft(
    source: source!,
    sourceKind: RecipeSourceKind.creatorComment,
    title: "맛집 기사식당 느낌의 '제육볶음' 레시피!",
    creator: '추추의 한끼식사 @chuchu_cook',
    evidenceUrl:
        'https://www.youtube.com/watch?v=rLEyOHvGb1Y&lc=UgxVWWyxpcu9RC6RZ5V4AaABAg',
    measurementNote:
        '제작자 계량 기준: 1스푼 = 10ml · 1컵 = 180ml. 조리 순서·불 세기·시간은 확인되지 않았습니다.',
    ingredients: List.unmodifiable(
      facts.map(
        (fact) =>
            DraftIngredient(name: fact.$1, amount: fact.$2, evidence: fact.$3),
      ),
    ),
    steps: const [],
  );
}
