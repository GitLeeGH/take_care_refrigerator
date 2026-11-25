/// Local, versioned planning references; NOT official use-by dates.
/// No writes to ingredient dates or the crowdsourced shelf_life_data table.
class StorageGuidance {
  const StorageGuidance(this.name, this.days, this.source, {this.note = ''});
  final String name, source, note;
  final int? days;
  DateTime referenceDay(DateTime purchased) {
    final period = days;
    if (period == null) throw StateError('No verified numeric period');
    return DateTime(purchased.year, purchased.month, purchased.day + period);
  }
}

const storageGuidanceVersion = '2026-11-02-v1';
// Stable identifiers for the proposed versioned catalogue, independent of labels.
const storageGuideIds = [
  'sprouts',
  'mushrooms',
  'leafy-greens',
  'brassica-florets',
  'cucumber-zucchini',
  'cabbage',
  'carrot',
];
const _vt =
    'https://www.pubs.ext.vt.edu/content/pubs_ext_vt_edu/en/348/348-960/348-960.html';
const _unl = 'https://food.unl.edu/free-resource/food-storage/';
const storageGuides = [
  StorageGuidance(
    '숙주·콩나물',
    null,
    'https://www.canada.ca/en/health-canada/services/food-safety-fruits-vegetables/sprouts.html',
    note:
        '출처는 비포장 새싹류를 며칠 이내 사용하도록 안내하며 특정 일수는 제시하지 않습니다. 숫자 기간은 미상이며 참고일을 계산하지 않습니다. 제품 표시를 우선하고 충분히 익혀 드세요.',
  ),
  StorageGuidance('생버섯', 3, _vt),
  StorageGuidance('시금치·잎상추', 3, _unl),
  StorageGuidance('브로콜리·콜리플라워', 3, _vt),
  StorageGuidance('오이·애호박', 4, _vt),
  StorageGuidance('양배추', 7, _vt),
  StorageGuidance('당근', 14, _vt),
];

/// Exact supported names only; no guesses for OCR fragments or prepared dishes.
int? storageGuideIndex(String name) => const {
  '숙주': 0,
  '숙주나물': 0,
  '콩나물': 0,
  '생버섯': 1,
  '버섯': 1,
  '새송이버섯': 1,
  '팽이버섯': 1,
  '표고버섯': 1,
  '시금치': 2,
  '잎상추': 2,
  '상추': 2,
  '브로콜리': 3,
  '콜리플라워': 3,
  '오이': 4,
  '애호박': 4,
  '양배추': 5,
  '당근': 6,
}[name.trim()];
