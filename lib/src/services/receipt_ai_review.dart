import 'receipt_import.dart';

/// Validates model output only. No transport, credentials or inventory writes.
/// Shape/identifier checks do not establish accuracy or complete redaction.
ReceiptParseResult reviewAiReceiptResponse(Object? response) {
  Never invalid() =>
      throw const FormatException('AI receipt response is invalid');
  if (response is! Map ||
      response.length != 1 ||
      !response.containsKey('items')) {
    invalid();
  }
  final items = response['items'];
  if (items is! List || items.length > 50) invalid();
  const fields = {
    'name',
    'purchase_quantity',
    'package_amount',
    'package_unit',
    'uncertain',
  };
  final review = <ReceiptReviewLine>[];
  for (final item in items) {
    if (item is! Map ||
        item.length != fields.length ||
        !item.keys.every(fields.contains)) {
      invalid();
    }
    final name = item['name'];
    final quantity = item['purchase_quantity'];
    final amount = item['package_amount'];
    final unit = item['package_unit'];
    final uncertain = item['uncertain'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.runes.length > 120 ||
        RegExp(
          r'[\x00-\x1f\x7f]|https?://|www\.|@',
          caseSensitive: false,
        ).hasMatch(name) ||
        RegExp(
          r'\d{2,4}[-) ]\d{3,4}[- ]\d{4}|(?:\d[ -]?){12,}',
        ).hasMatch(name) ||
        RegExp(
          r'^(?:전화|주소|승인번호|카드번호|사업자번호|계좌번호)\s*[:：]',
        ).hasMatch(name.trim())) {
      invalid();
    }
    if (quantity != null &&
        (quantity is! int || quantity < 1 || quantity > 999)) {
      invalid();
    }
    if (amount != null &&
        (amount is! num ||
            !amount.isFinite ||
            amount <= 0 ||
            amount > 100000)) {
      invalid();
    }
    if (!{null, 'g', 'kg', 'ml', 'L'}.contains(unit) ||
        (amount == null) != (unit == null) ||
        uncertain is! bool) {
      invalid();
    }
    final package = amount == null
        ? null
        : '${amount == amount.roundToDouble() ? amount.toInt() : amount}$unit';
    // Package information remains visible after restoring a candidate, without
    // converting grams or millilitres into the purchase count.
    final normalizedName = name.trim();
    final compactName = normalizedName.replaceAll(RegExp(r'\s+'), '');
    final displayName = package == null || compactName.contains(package)
        ? normalizedName
        : '$normalizedName ($package)';
    review.add(
      ReceiptReviewLine(
        displayName,
        [
          uncertain ? 'AI가 확신하지 못한 품목 · 직접 확인 필요' : 'AI 품목 후보 · 직접 확인 필요',
          if (package != null) '포장량 $package',
          quantity == null ? '구매 수량 확인 필요' : '구매 수량 $quantity개 · 확인 필요',
        ].join(' · '),
        quantity: quantity == null ? null : '$quantity개',
        isCandidate: true,
      ),
    );
  }
  // Never auto-select, infer expiry/storage, or save inventory from a response.
  return ReceiptParseResult(
    const [],
    List.unmodifiable(review),
    notice: review.isEmpty
        ? 'AI가 품목을 찾지 못했습니다. 기존 입력을 유지하고 사진을 다시 확인하거나 직접 추가해 주세요.'
        : 'AI 품목 후보 ${review.length}개입니다. 실제 상품만 선택하고 이름·구매 수량·유통기한을 직접 확인해 주세요.',
  );
}
