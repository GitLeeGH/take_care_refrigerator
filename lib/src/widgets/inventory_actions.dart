import 'package:flutter/material.dart';
import '../theme.dart';

/// Two real registration paths; no recognition result is fabricated here.
class InventoryActions extends StatelessWidget {
  const InventoryActions({
    super.key,
    required this.onReceipt,
    required this.onManual,
  });
  final VoidCallback onReceipt;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final largeText =
        MediaQuery.sizeOf(context).width < 360 &&
        MediaQuery.textScalerOf(context).scale(18) > 32;
    const copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '장 본 재료, 한 번에',
          style: TextStyle(
            color: darkGray,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '사진 선택 → 품목 확인 → 일괄 등록',
          style: TextStyle(color: mediumGray, fontSize: 13, height: 1.5),
        ),
      ],
    );
    const receiptIcon = Icon(
      Icons.receipt_long_outlined,
      color: darkGray,
      size: 24,
    );
    const arrow = Icon(Icons.arrow_forward_rounded, color: primaryGreen);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onReceipt,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: largeText
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [receiptIcon, Spacer(), arrow]),
                        SizedBox(height: 12),
                        copy,
                      ],
                    )
                  : const Row(
                      children: [
                        receiptIcon,
                        SizedBox(width: 12),
                        Expanded(child: copy),
                        SizedBox(width: 12),
                        arrow,
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onManual,
          icon: const Icon(Icons.add),
          label: const Text('재료 직접 추가하기'),
        ),
      ],
    );
  }
}
