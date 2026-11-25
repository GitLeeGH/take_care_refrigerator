import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

/// Public catalog only: never query or write an inventory row or expiry date.
final sourcedGuidanceProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
      final rows = await ref
          .watch(supabaseProvider)
          .from('shelf_life_data')
          .select('name,reference_guidance')
          .limit(200)
          .timeout(const Duration(seconds: 10));
      return parseSourcedGuidance(rows);
    });

Map<String, Map<String, dynamic>> parseSourcedGuidance(List<dynamic> rows) {
  final result = <String, Map<String, dynamic>>{};
  for (final row in rows) {
    if (row is! Map ||
        row['name'] is! String ||
        row['reference_guidance'] is! Map)
      continue;
    final data = Map<String, dynamic>.from(row['reference_guidance'] as Map);
    if (data['kind'] != 'quality_reference' ||
        data['storage_type'] != 'refrigerated')
      continue;
    const fields = [
      'period_text',
      'conditions',
      'uncertainty',
      'disclaimer',
      'source_publisher',
      'source_url',
      'checked_on',
    ];
    if (fields.any(
      (key) =>
          data[key] is! String ||
          (data[key] as String).isEmpty ||
          (data[key] as String).length > 2000,
    ))
      continue;
    final url = Uri.tryParse(data['source_url'] as String);
    if (url == null ||
        url.scheme != 'https' ||
        url.userInfo.isNotEmpty ||
        !['www.pubs.ext.vt.edu', 'www.canada.ca'].contains(url.host))
      continue;
    final min = data['min_days'], max = data['max_days'];
    if (!(min == null && max == null) &&
        !(min is int && max is int && min > 0 && max >= min && max <= 365))
      continue;
    result[row['name'] as String] = data;
  }
  return result;
}

class SourcedGuidanceButton extends StatelessWidget {
  const SourcedGuidanceButton({
    super.key,
    required this.name,
    required this.storageType,
  });
  final String name;
  final String? storageType;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.menu_book_outlined),
    label: const Text('출처가 있는 보관 참고 정보'),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => _SourcedDialog(name: name, storageType: storageType),
    ),
  );
}

class _SourcedDialog extends ConsumerWidget {
  const _SourcedDialog({required this.name, required this.storageType});
  final String name;
  final String? storageType;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AlertDialog(
    scrollable: true,
    title: const Text('보관 참고 · 소비기한과 별개'),
    content: storageType != 'refrigerated'
        ? const Text('현재 자료는 냉장 보관용입니다. 이 재료의 보관 방식에는 적용하지 않습니다.')
        : ref
              .watch(sourcedGuidanceProvider)
              .when(
                data: (catalog) {
                  // Exact name only. Do not apply raw-vegetable guidance to processed foods.
                  final guide = catalog[name.trim()];
                  if (guide == null)
                    return const Text(
                      '이 이름에 대해 확인된 자료가 없습니다. 다른 식품의 기간을 대신 적용하지 않습니다.',
                    );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name: ${guide['period_text']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(guide['conditions'] as String),
                      const SizedBox(height: 12),
                      Text(guide['uncertainty'] as String),
                      const SizedBox(height: 12),
                      Text(guide['disclaimer'] as String),
                      const SizedBox(height: 12),
                      Text(
                        '출처: ${guide['source_publisher']}\n자료 확인: ${guide['checked_on']}',
                      ),
                      SelectableText(guide['source_url'] as String),
                    ],
                  );
                },
                loading: () => const Text('참고 자료를 불러오는 중…'),
                error: (_, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('자료를 불러오지 못했습니다. 재료의 날짜는 변경되지 않았습니다.'),
                    TextButton(
                      onPressed: () => ref.invalidate(sourcedGuidanceProvider),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
    ],
  );
}
