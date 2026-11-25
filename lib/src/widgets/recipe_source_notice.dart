import 'package:flutter/material.dart';
import '../models.dart';
import 'package:url_launcher/url_launcher.dart';

typedef SourceLauncher = Future<bool> Function(Uri, LaunchMode);

/// Describes saved link evidence only; never infers permission or verification.
class RecipeSourceNotice extends StatefulWidget {
  const RecipeSourceNotice({super.key, required this.recipe, this.launcher});
  final Recipe recipe;
  final SourceLauncher? launcher;
  @override
  State<RecipeSourceNotice> createState() => _RecipeSourceNoticeState();
}

class _RecipeSourceNoticeState extends State<RecipeSourceNotice> {
  bool busy = false, failed = false;
  int generation = 0;
  @override
  void didUpdateWidget(covariant RecipeSourceNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipe.id != widget.recipe.id ||
        oldWidget.recipe.sourceUri != widget.recipe.sourceUri) {
      ++generation;
      busy = false;
      failed = false;
    }
  }

  Future<void> open() async {
    final uri = widget.recipe.sourceUri;
    if (busy || uri == null) return;
    final request = ++generation;
    setState(() {
      busy = true;
      failed = false;
    });
    var opened = false;
    try {
      opened =
          await (widget.launcher ?? (uri, mode) => launchUrl(uri, mode: mode))(
            uri,
            LaunchMode.externalApplication,
          );
    } catch (_) {}
    if (!mounted || request != generation) return;
    setState(() {
      busy = false;
      failed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final source = recipe.sourceUri;
    final mfds =
        source?.toString() ==
            'https://www.foodsafetykorea.go.kr/api/newDatasetDetail.do?svc_no=COOKRCP01' &&
        recipe.description?.contains('<!-- mfds-import:v1;') == true;
    final label = source != null
        ? '저장된 출처 링크: ${source.host}'
        : recipe.hasMalformedSource
        ? '출처 주소 확인 필요: 현재 저장된 주소로 원문을 열 수 없습니다.'
        : '출처 링크 없음: 앱에서 원문을 확인할 수 없습니다.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mfds) ...[
          const Text('출처: 식품의약품안전처'),
          const Text('데이터명: 조리식품의 레시피 DB (COOKRCP01)'),
          const Text('아래 원본 링크는 개별 요리가 아닌 공식 데이터셋 안내입니다.'),
          const Text('출처 표시는 제3자 권리나 조리 정보의 정확성·안전을 보장하지 않습니다.'),
          const SizedBox(height: 6),
        ],
        Text(label),
        if (source != null)
          TextButton.icon(
            onPressed: busy ? null : open,
            icon: const Icon(Icons.open_in_new),
            label: Text(busy ? '출처 여는 중' : '원본 출처 열기'),
          ),
        if (failed)
          Semantics(
            liveRegion: true,
            child: const Text('출처를 열지 못했습니다. 연결 상태를 확인한 뒤 다시 눌러 주세요.'),
          ),
        const SizedBox(height: 6),
        const Text('출처 링크와 참고 영상은 별개이며, 재료 정보의 완전성을 보장하지 않습니다.'),
      ],
    );
  }
}
