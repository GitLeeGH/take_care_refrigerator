import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ingredient_photo.dart';
import 'receipt_layout.dart';

final receiptOcrProvider = Provider<Future<List<String>> Function(String)>(
  (ref) => (path) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Android only');
    }
    final result =
        await const MethodChannel(
          'refrigerator/receipt_ocr',
        ).invokeListMethod<dynamic>('recognizeLayout', {'path': path}) ??
        [];
    return ReceiptOcrLines(
      result.map((value) => ReceiptOcrLine.fromMap(value as Map)),
    );
  },
);

class ReceiptReviewLine {
  const ReceiptReviewLine(
    this.text,
    this.reason, {
    this.quantity,
    this.isCandidate = false,
    this.canRestore = true,
  });
  final String text;
  final String reason;
  final String? quantity;
  final bool isCandidate;
  final bool canRestore;
}

class ReceiptParseResult {
  const ReceiptParseResult(
    this.items,
    this.review, {
    this.notice,
    this.quantities = const {},
  });
  final List<String> items;
  final List<ReceiptReviewLine> review;
  final String? notice;
  final Map<int, String> quantities;
}

/// Heuristics suggest items; they never establish food identity, quantity or
/// expiry. Unselected lines remain recoverable instead of disappearing.
ReceiptParseResult parseReceipt(
  Iterable<String> lines, {
  List<String>? debugTrace,
}) {
  if (lines is ReceiptOcrLines) {
    return _parseLayoutReceipt(
      lines,
      debugTrace: kDebugMode ? debugTrace : null,
    );
  }
  final items = <String>[];
  final review = <ReceiptReviewLine>[];
  final trailingPrice = RegExp(
    r'\s+\d[\d,]*(?:\.\d+)?(?:\s*원)?(?:\s+\d[\d,]*(?:\.\d+)?(?:\s*원)?)*$',
  );
  final foods = RegExp(
    '숙주|나물|버섯|감자|고구마|양파|대파|쪽파|마늘|생강|당근|배추|양배추|시금치|상추|오이|호박|고추|토마토|브로콜리|콩나물|두부|달걀|계란|우유|치즈|요거트|버터|돼지|소고기|쇠고기|삼겹|목살|닭|오리|햄|소시지|부어스트|참치|고등어|연어|새우|오징어|멸치|어묵|김치|사과|바나나|딸기|포도|귤|오렌지|레몬|쌀|현미|잡곡|밀가루|전분|설탕|소금|간장|된장|고추장|식초|식용유|참기름|들기름|후추|깨|라면|국수|파스타|떡|빵|과자|감자칩',
  );
  for (final raw in lines.take(300)) {
    final original = raw.trim();
    if (original.isEmpty) continue;
    final compact = original.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final metadata =
        // Merchant/payment identifiers may resemble priced product rows.
        // Match labels, not food words containing similar syllables.
        RegExp(
          r'^(?:가맹점(?:명|번호|정보)?|가맹번호|단말기(?:번호)?|단말번호|매입사|카드사|승인번호)(?:[:：#\d]|$)',
        ).hasMatch(compact) ||
        RegExp(
          r'^(?:합계|총액|총금액|결제|카드|승인|부가세|면세|과세|사업자|전화|주소|영수증|포인트|거스름|현금|공급가|판매일|거래일|매장|고객|대표|계산원|매출금액|총매출|판매금액|지불금액|청구금액|내실금액|내실금|받을금액|받은금액|거래번호|할인금액|할인액|적립|잔액|신용(?:$|[:：\d])|tel[:.]?|fax[:.]?)',
        ).hasMatch(compact) ||
        RegExp(r'상품명.*(?:단가|수량|금액)').hasMatch(compact) ||
        RegExp(
          r'하나로마트|농협.*(?:점|마트)$|(?:마트|슈퍼|슈퍼마켓|편의점).{0,12}점$',
        ).hasMatch(compact) ||
        RegExp(
          r'이용바랍니다|감사합니다|방문해|운영중|화요장터|영업시간|교환.*환불|환불.*교환|^두배[!！]*$',
        ).hasMatch(compact) ||
        RegExp(
          r'(?:https?://|www\.|@.*\.[a-z]|\d{2,4}[-)]\d{3,4}-\d{4}|\d{3}-\d{2}-\d{5})',
        ).hasMatch(compact) ||
        RegExp(r'^\d{4}[-./]\d{1,2}[-./]\d{1,2}').hasMatch(compact);
    if (metadata) {
      review.add(
        ReceiptReviewLine(original, '매장·안내·결제 정보로 분류', canRestore: false),
      );
      continue;
    }
    var name = original.replaceFirst(RegExp(r'^\d{1,15}[\s.)]+'), '').trim();
    // Receipt item markers, not the first letter of English product names.
    final marked = RegExp(r'^[Pp](?:@|\s)*(?=[가-힣])').hasMatch(name);
    name = receiptProductName(name);
    final priced = trailingPrice.hasMatch(name);
    name = name.replaceFirst(trailingPrice, '').trim();
    // Packaging remains in the name; 400g is not interpreted as purchase count.
    if (name.length <= 80 &&
        RegExp(r'[가-힣A-Za-z]').hasMatch(name) &&
        (marked || priced || foods.hasMatch(name)) &&
        items.length < 50) {
      items.add(name);
    } else {
      review.add(ReceiptReviewLine(original, '품목 여부 확인 필요'));
    }
  }
  return ReceiptParseResult(
    List.unmodifiable(items),
    List.unmodifiable(review),
  );
}

List<String> receiptCandidates(Iterable<String> lines) =>
    parseReceipt(lines).items;

ReceiptParseResult _parseLayoutReceipt(
  ReceiptOcrLines input, {
  List<String>? debugTrace,
}) {
  final rows = receiptVisualRows(input);
  String compact(String line) => line.replaceAll(RegExp(r'\s+'), '');
  var header = -1;
  for (var i = 0; i < rows.length; i++) {
    final first = compact(rows[i]);
    if (!RegExp(r'상품명|품명|품목|메뉴명').hasMatch(first)) continue;
    var joined = first;
    for (var j = i; j < rows.length && j <= i + 2; j++) {
      if (j > i) {
        final next = compact(rows[j]);
        // Join only header labels, never the first product or its price row.
        if (!RegExp(r'^(?:상품코드|단가|수량|금액|가격)+$').hasMatch(next)) break;
        joined += next;
      }
      if (joined.contains('단가') &&
          joined.contains('수량') &&
          joined.contains('금액')) {
        header = j;
        break;
      }
    }
    if (header >= 0) break;
  }
  final end = header < 0
      ? -1
      : rows.indexWhere(
          (line) => RegExp(
            r'^(?:총합계|합계|소합계|총액|총금액|결제금액|받을금액|판매금액|과세물품|면세물품|부가세)',
          ).hasMatch(compact(line)),
          header + 1,
        );
  final restaurant = rows.any(
    (line) => RegExp(r'테이블|주문번호|매장식사').hasMatch(compact(line)),
  );
  debugTrace?.add(
    '원문 행 수 ${input.length} / 결합 행 수 ${rows.length} / 시작 ${header >= 0} / 끝 ${end >= 0}',
  );
  if (debugTrace != null) {
    final groups = receiptVisualGroups(input);
    for (var i = 0; i < groups.length; i++) {
      // Only geometry and indices: no OCR text, prices, account or identifiers.
      if (!RegExp(r'^\d{1,3}\s+[Pp]').hasMatch(rows[i].trim())) continue;
      for (var j = i; j <= i + 1 && j < groups.length; j++) {
        final parts = groups[j]
            .map((line) {
              final id = input.lines.indexOf(line) + 1;
              final box = line.positioned
                  ? [
                      line.left!,
                      line.top!,
                      line.right!,
                      line.bottom!,
                    ].map((v) => v.round()).join('/')
                  : '좌표 없음';
              return '#$id [$box]';
            })
            .join(', ');
        debugTrace.add('결합 행 ${j + 1}: $parts');
      }
    }
  }
  if (header < 0 || end < 0) {
    return _reviewUnboundedRows(rows, debugTrace: debugTrace);
  }
  final items = <String>[];
  final quantities = <int, String>{};
  final review = <ReceiptReviewLine>[];
  final numeric = RegExp(
    r'^(?:\*?\d{6,14}\s+)?([\d,]+)\s+(\d{1,3})\s+([\d,]+)(?:\s*원)?$',
  );
  final metadata = RegExp(
    r'^(?:테이블|전화|tel|승인|가맹|단말|카드|사업자|주문번호|할인|부가세|면세|과세|합계)',
    caseSensitive: false,
  );
  for (var i = 0; i < rows.length; i++) {
    final line = rows[i].trim();
    if (line.isEmpty) continue;
    if (i <= header ||
        i >= end ||
        metadata.hasMatch(compact(line)) ||
        (RegExp(r'\d').hasMatch(line) &&
            RegExp(r'^[0-9OoIl|,.\s-]+(?:원)?$').hasMatch(line)) ||
        !RegExp(r'[가-힣A-Za-z]').hasMatch(line)) {
      review.add(
        ReceiptReviewLine(line, '표 머리글·숫자·결제 정보 · 원문 보존', canRestore: false),
      );
      continue;
    }
    // Two-line receipt: title, then code/unit-price/count/total. No name dictionary.
    var name = line;
    RegExpMatch? prices = i + 1 < end
        ? numeric.firstMatch(rows[i + 1].trim())
        : null;
    var inline = false;
    if (prices == null) {
      final parts = RegExp(
        r'^(.*?)\s+((?:\*?\d{6,14}\s+)?[\d,]+\s+\d{1,3}\s+[\d,]+(?:\s*원)?)$',
      ).firstMatch(line);
      if (parts != null) {
        name = parts[1]!.trim();
        prices = numeric.firstMatch(parts[2]!);
        inline = true;
      }
    }
    name = receiptProductName(name);
    String? quantity;
    if (prices != null) {
      final unit = _receiptMoney(prices[1]!);
      final count = int.tryParse(prices[2]!);
      final total = _receiptMoney(prices[3]!);
      if (unit != null &&
          count != null &&
          total != null &&
          unit > 0 &&
          count > 0 &&
          unit * count == total) {
        quantity = '$count개';
      }
    }
    name = receiptProductName(name, allowOcrMarker: quantity != null);
    if (name.isEmpty) {
      review.add(ReceiptReviewLine(line, '품목명 확인 필요'));
      continue;
    }
    // Verified table/price evidence works without a known store-name dictionary.
    // Restaurant orders remain opt-in rather than silently becoming ingredients.
    if (!restaurant && quantity != null && name.length <= 80) {
      quantities[items.length] = quantity;
      items.add(name);
    } else {
      review.add(
        ReceiptReviewLine(
          name,
          prices == null
              ? '상품 영역의 이름 후보 · 가격 행 연결 미확인'
              : quantity == null
              ? '상품 행 후보 · 금액 계산 불일치, 수량 직접 확인'
              : '상품 행 확인 · 단가×수량=금액 일치. 등록할 항목만 선택',
          quantity: quantity,
          isCandidate: true,
        ),
      );
    }
    if (prices != null && !inline) {
      review.add(
        ReceiptReviewLine(rows[++i], '상품코드·단가·수량·금액 원문', canRestore: false),
      );
    }
  }
  return ReceiptParseResult(
    items,
    review,
    quantities: quantities,
    notice:
        '글자 인식과 품목 선별을 분리했습니다. ${items.length + review.where((r) => r.isCandidate).length}개 품목 후보를 찾았습니다. '
        '${restaurant ? '식당 주문은 테스트 결과로 표시하며 자동 등록 선택하지 않습니다. ' : ''}수량 제안도 원본과 확인하고, 날짜는 직접 입력해 주세요.',
  );
}

// Do not repair malformed OCR separators into apparently valid arithmetic.
int? _receiptMoney(String value) =>
    RegExp(r'^(?:\d+|\d{1,3}(?:,\d{3})+)$').hasMatch(value)
    ? int.tryParse(value.replaceAll(',', ''))
    : null;

List<String> receiptMissingFields({
  required String name,
  required String quantity,
  required String? storage,
  required DateTime? expiry,
}) => [
  if (name.trim().isEmpty) '이름',
  if (quantity.trim().isEmpty) '수량',
  if (storage == null) '보관 장소',
  if (expiry == null) '유통기한',
];

/// One immutable operation per row; confirmed rows are never submitted twice.
/// A lost response is reconciled by IngredientSaveOperation using stable IDs.
class ReceiptBatch {
  ReceiptBatch(List<IngredientSaveOperation> operations, {this.beforeSave})
    : operations = List.unmodifiable(operations);
  final void Function()? beforeSave;
  final List<IngredientSaveOperation> operations;
  int completed = 0;
  Future<void>? _pending;
  Future<void> save() =>
      _pending ??= _save().whenComplete(() => _pending = null);
  Future<void> _save() async {
    while (completed < operations.length) {
      beforeSave?.call();
      await operations[completed].save();
      completed++;
    }
  }
}

ReceiptParseResult _reviewUnboundedRows(
  List<String> rows, {
  List<String>? debugTrace,
}) {
  final review = <ReceiptReviewLine>[];
  final numeric = RegExp(
    r'^(?:\*?\d{6,14}\s+)?([\d,]+)\s+(\d{1,3})\s+([\d,]+)(?:\s*원)?$',
  );
  final stop = RegExp(r'^(?:총합계|합계|소합계|총액|총금액|결제금액|받을금액|판매금액|과세물품|면세물품|부가세)');
  var ended = false;
  for (var i = 0; i < rows.length; i++) {
    final line = rows[i].trim();
    final compact = line.replaceAll(RegExp(r'\s+'), '');
    if (stop.hasMatch(compact)) ended = true;
    final metadata = RegExp(
      r'상품명|상품코드|단가|수량|금액|품목|품명|메뉴명|전화|사업자|가맹|승인|카드|계좌|주소|고객|영수증|매장|점포|단말|포인트|결제|과세|면세|세금|합계|https?://|www\.|@|\d{2,4}[-)]\d{3,4}-\d{4}',
      caseSensitive: false,
    ).hasMatch(receiptProductName(line).replaceAll(RegExp(r'\s+'), ''));
    var prices = i + 1 < rows.length
        ? numeric.firstMatch(rows[i + 1].trim())
        : null;
    var rawName = line;
    var inline = false;
    // Without table bounds, inline recovery requires an explicit numbered
    // product marker as well as the same exact numeric validation.
    if (prices == null &&
        RegExp(r'^\d{1,3}\s+[Pp](?:@|e|\s)*(?=[가-힣])').hasMatch(line)) {
      final parts = RegExp(
        r'^(.*?)\s+((?:\*?\d{6,14}\s+)?[\d,]+\s+\d{1,3}\s+[\d,]+(?:\s*원)?)$',
      ).firstMatch(line);
      if (parts != null) {
        rawName = parts[1]!.trim();
        prices = numeric.firstMatch(parts[2]!);
        inline = true;
      }
    }
    final name = receiptProductName(rawName, allowOcrMarker: prices != null);
    // P@ is a product marker, so test metadata after stripping that marker.
    final unit = prices == null ? null : _receiptMoney(prices[1]!);
    final count = prices == null ? null : int.tryParse(prices[2]!);
    final total = prices == null ? null : _receiptMoney(prices[3]!);
    final plausible =
        !ended &&
        !metadata &&
        name.length >= 2 &&
        name.length <= 80 &&
        RegExp(r'[가-힣A-Za-z]').hasMatch(name) &&
        !RegExp(r'^[0-9OoIl|,.\s-]+$').hasMatch(name) &&
        unit != null &&
        count != null &&
        total != null &&
        unit > 0 &&
        count > 0 &&
        unit * count == total;
    if (debugTrace != null && RegExp(r'^\d{1,3}\s+[Pp]').hasMatch(line)) {
      final reasons = <String>[
        if (ended) '종료 경계 이후',
        if (metadata) '안내/결제 패턴',
        if (name.length < 2 || name.length > 80) '이름 길이',
        if (!RegExp(r'[가-힣A-Za-z]').hasMatch(name) ||
            RegExp(r'^[0-9OoIl|,.\s-]+$').hasMatch(name))
          '문자 조건',
        if (prices == null) '현재/다음 결합 행의 가격/수량 형식 불일치',
        if (prices != null && (unit == null || count == null || total == null))
          '숫자 형식 불일치',
        if (unit != null &&
            count != null &&
            total != null &&
            (unit <= 0 || count <= 0 || unit * count != total))
          '양수/산술 조건 불일치',
      ];
      debugTrace.add(
        '후보 행 ${i + 1}: ${plausible ? "수동 후보 통과" : reasons.join(" · ")}',
      );
    }
    if (plausible) {
      review.add(
        ReceiptReviewLine(
          name,
          '이름과 가격·수량 확인 — 표 경계 미확인, 직접 선택 필요',
          quantity: '$count개',
          isCandidate: true,
        ),
      );
      if (!inline) {
        review.add(
          ReceiptReviewLine(rows[++i], '가격·수량 행 — 원문에서 확인', canRestore: false),
        );
      }
    } else {
      review.add(
        ReceiptReviewLine(line, '상품 근거 부족 — 원문에서 확인', canRestore: false),
      );
    }
  }
  return ReceiptParseResult(
    [],
    review,
    notice:
        '상품 표의 시작과 합계를 함께 확인하지 못했습니다. 가격·수량이 연결된 품목 후보만 표시하며 자동 선택하지 않습니다. 후보가 없으면 원문을 확인해 품목을 직접 추가해 주세요.',
  );
}

// Strip an item index only before an explicit receipt product marker.
// Keep amounts, brand numbers and packaging (e.g. 100g or 365 milk) intact.
String receiptProductName(String line, {bool allowOcrMarker = false}) {
  var name = line.trim();
  // Observed P@ -> Pe OCR confusion is corrected only with both a row index
  // and an associated price row. Never rewrite unnumbered brand names.
  if (allowOcrMarker) {
    name = name.replaceFirst(RegExp(r'^\d{1,3}\s+[Pp]e(?=[가-힣])'), '');
  }
  return name
      .replaceFirst(RegExp(r'^\d{1,3}\s+(?=[Pp](?:@|\s)*(?=[가-힣]))'), '')
      .replaceFirst(RegExp(r'^[Pp](?:@|\s)*(?=[가-힣])'), '')
      .trim();
}
