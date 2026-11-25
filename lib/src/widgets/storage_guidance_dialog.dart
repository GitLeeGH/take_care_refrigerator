import 'sourced_storage_guidance.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_guidance.dart';
import '../services/storage_reference.dart';

class StorageGuidanceButton extends StatelessWidget {
  const StorageGuidanceButton({
    super.key,
    required this.name,
    required this.storageType,
    this.ingredientId,
    this.onSave,
  });
  final String name;
  final String? storageType;
  final String? ingredientId;
  final Future<void> Function(StorageReferenceDraft)? onSave;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.info_outline),
    label: const Text('보관기간 참고 보기'),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => _GuideDialog(
        name: name,
        storageType: storageType,
        ingredientId: ingredientId,
        onSave: onSave,
      ),
    ),
  );
}

class _GuideDialog extends StatefulWidget {
  const _GuideDialog({
    required this.name,
    required this.storageType,
    this.ingredientId,
    this.onSave,
  });
  final String name;
  final String? storageType;
  final String? ingredientId;
  final Future<void> Function(StorageReferenceDraft)? onSave;
  @override
  State<_GuideDialog> createState() => _GuideState();
}

class _GuideState extends State<_GuideDialog> {
  int? selected;
  DateTime? purchased;
  bool confirmed = false;
  bool saving = false;
  String? error;
  DateTime? adjusted;
  @override
  void initState() {
    super.initState();
    selected = storageGuideIndex(widget.name);
  }

  @override
  Widget build(BuildContext context) {
    final guide = selected == null ? null : storageGuides[selected!];
    final eligible =
        widget.storageType == 'refrigerated' &&
        confirmed &&
        guide != null &&
        guide.days != null &&
        purchased != null;
    final persistable = widget.ingredientId != null && widget.onSave != null;
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: const Text('먼저 먹기 권장일 · 참고용'),
        content: SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SourcedGuidanceButton(
                name: widget.name,
                storageType: widget.storageType,
              ),
              const Text(
                '공식 소비기한이나 안전 보증이 아닙니다. 제품 표시일과 보관 지시를 우선하세요. 기존에 기록한 날짜는 변경하지 않습니다.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '실제 생재료 종류 확인'),
                hint: const Text('목록에 없으면 적용하지 않음'),
                items: [
                  for (var i = 0; i < storageGuides.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        storageGuides[i].name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() {
                  selected = v;
                  confirmed = false;
                  adjusted = null;
                }),
              ),
              if (guide != null) ...[
                const SizedBox(height: 12),
                Text(
                  guide.days == null
                      ? '숫자 보관기간 미상 · 참고 날짜를 계산하지 않습니다.'
                      : '구매 후 ${guide.days}일: 자료를 바탕으로 짧게 잡은 앱 참고값이며 식약처의 확정 기간이 아닙니다.',
                ),
                if (guide.note.isNotEmpty) Text(guide.note),
                TextButton(
                  onPressed: () async {
                    var opened = false;
                    try {
                      opened = await launchUrl(
                        Uri.parse(guide.source),
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {
                      /* Report failure without changing data. */
                    }
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('출처를 열지 못했습니다.')),
                      );
                    }
                  },
                  child: const Text('근거 자료 열기'),
                ),
              ],
              if (widget.storageType != 'refrigerated')
                const Text('현재 보관 장소가 냉장이 아니므로 참고일을 계산하지 않습니다.'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: confirmed,
                title: const Text('구매 당시 신선했고 4°C 이하로 계속 냉장한 생재료입니다.'),
                onChanged:
                    widget.storageType != 'refrigerated' ||
                        guide == null ||
                        guide.days == null
                    ? null
                    : (v) => setState(() => confirmed = v!),
              ),
              OutlinedButton(
                onPressed:
                    widget.storageType != 'refrigerated' ||
                        guide == null ||
                        guide.days == null
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          initialDate: purchased ?? now,
                          firstDate: DateTime(2000),
                          lastDate: now,
                        );
                        if (date != null && mounted) {
                          setState(() {
                            purchased = date;
                            adjusted = null;
                          });
                        }
                      },
                child: Text(
                  purchased == null
                      ? '구매일 직접 선택'
                      : '구매일 ${DateFormat('yyyy.MM.dd').format(purchased!)}',
                ),
              ),
              if (eligible)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '먼저 먹기 권장일 (참고)\n${DateFormat('yyyy.MM.dd').format(guide.referenceDay(purchased!))}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 8),
              if (eligible && persistable) ...[
                OutlinedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate:
                                adjusted ?? guide.referenceDay(purchased!),
                            firstDate: purchased!,
                            lastDate: DateTime(purchased!.year + 5),
                          );
                          if (date != null && mounted) {
                            setState(() => adjusted = date);
                          }
                        },
                  child: Text(
                    '참고 알림일 수정: ${referenceDateText(adjusted ?? guide.referenceDay(purchased!))}',
                  ),
                ),
                const Text(
                  '소비기한과 별도로 저장합니다. 알림일을 바꿔도 식품의 안전 기간이 늘어나지 않습니다. 앱 내 알림이며 백그라운드 전달은 지원하지 않습니다.',
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await widget.onSave!(
                              StorageReferenceDraft(
                                ingredientId: widget.ingredientId!,
                                guideId: storageGuideIds[selected!],
                                catalogVersion: storageGuidanceVersion,
                                purchasedOn: purchased!,
                                remindOn:
                                    adjusted ?? guide.referenceDay(purchased!),
                                conditionsConfirmed: confirmed,
                              ),
                            );
                            if (context.mounted) Navigator.pop(context);
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => error =
                                    '저장을 확인하지 못했습니다. 다시 시도하거나 닫고 저장 상태를 확인해 주세요. 기존 소비기한은 변경하지 않았습니다.',
                              );
                            }
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        },
                  child: Text(saving ? '참고일 저장 중…' : '참고 알림일만 저장'),
                ),
              ],
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const Text(
                '영수증 날짜를 소비기한으로 쓰지 않습니다. 변색·이취 등 이상이 있거나 냉장 상태가 불확실하면 이 참고값을 적용하지 마세요.',
              ),
              if (!persistable) const Text('이 화면은 날짜를 저장하거나 알림을 설정하지 않습니다.'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
