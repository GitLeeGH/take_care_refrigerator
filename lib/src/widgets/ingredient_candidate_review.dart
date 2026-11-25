import 'package:flutter/material.dart';
import '../services/ingredient_recognition.dart';

class IngredientCandidateReview extends StatefulWidget {
  const IngredientCandidateReview({super.key, required this.candidates});
  final List<IngredientCandidate> candidates;
  @override
  State<IngredientCandidateReview> createState() =>
      _IngredientCandidateReviewState();
}

class _IngredientCandidateReviewState extends State<IngredientCandidateReview> {
  final name = TextEditingController();
  int? selected;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('인식 결과 확인'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '사진 인식은 틀릴 수 있어요. 재료 하나를 선택하고 이름을 확인해 주세요. 수량·소비기한은 직접 입력해야 합니다.',
        ),
        if (widget.candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('확실한 재료를 찾지 못했어요. 직접 입력하거나 다른 사진을 사용해 주세요.'),
          ),
        for (var i = 0; i < widget.candidates.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              selected == i
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(widget.candidates[i].name),
            subtitle: widget.candidates[i].category == null
                ? null
                : Text('분류 제안: ${widget.candidates[i].category}'),
            onTap: () => setState(() {
              selected = i;
              name.text = widget.candidates[i].name;
            }),
          ),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: '확인한 재료명'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        const Text('이름만 입력란에 반영합니다. 아직 저장하지 않습니다.'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('직접 입력'),
      ),
      FilledButton(
        onPressed: name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, name.text.trim()),
        child: const Text('이 이름 사용'),
      ),
    ],
  );
}
