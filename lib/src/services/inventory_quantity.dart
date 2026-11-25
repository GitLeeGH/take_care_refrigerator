/// Recognize explicit zero only; unknown text does not establish sufficiency.
bool isExplicitlyEmptyQuantity(String value) => RegExp(
  r'^0+(?:\.0+)?\s*(?:개|봉|봉지|팩|병|캔|통|포|장|마리|알|묶음|단|g|kg|mg|ml|l)?$',
  caseSensitive: false,
).hasMatch(value.trim());
