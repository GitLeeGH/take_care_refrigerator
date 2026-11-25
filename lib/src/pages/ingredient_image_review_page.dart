import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/app_presentation.dart';
import '../services/receipt_image_payload.dart';
import '../services/ingredient_ai_gateway.dart';

/// No network or persistence. Only explicit final confirmation returns bytes.
class IngredientImageReviewPage extends StatefulWidget {
  const IngredientImageReviewPage({
    super.key,
    required this.originalBytes,
    this.initialPreparedImage,
    this.isSessionCurrent,
    this.sessionChanges,
  });
  final Uint8List originalBytes;
  final PreparedReceiptImage? initialPreparedImage;
  final bool Function()? isSessionCurrent;
  final Listenable? sessionChanges;
  @override
  State<IngredientImageReviewPage> createState() =>
      _IngredientImageReviewPageState();
}

class _IngredientImageReviewPageState extends State<IngredientImageReviewPage>
    with WidgetsBindingObserver {
  PreparedReceiptImage? _source, _final;
  ReceiptImageRegion _crop = const ReceiptImageRegion(0, 0, 1, 1);
  final List<ReceiptImageRegion> _redactions = [];
  bool _busy = true, _confirmed = false, _returned = false;
  bool _foreground = true, _sessionInvalid = false;
  String? _error;
  Offset? _start, _end;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.sessionChanges?.addListener(_checkSession);
    _sessionInvalid = !(widget.isSessionCurrent?.call() ?? true);
    final prepared = widget.initialPreparedImage;
    if (prepared == null) {
      _load();
    } else {
      _source = prepared;
      _final = prepared;
      _busy = false;
    }
  }

  void _checkSession() {
    if (!mounted || (widget.isSessionCurrent?.call() ?? true)) return;
    setState(() {
      _sessionInvalid = true;
      _confirmed = false;
      _error = '로그인 상태가 바뀌어 전송을 중단했습니다. 사진은 이 화면에 유지됩니다. 취소 후 로그인 상태를 확인해 주세요.';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _returned) return;
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      // Retain the exact selected, cropped and masked photo, but never consent.
      _confirmed = false;
    });
    _checkSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.sessionChanges?.removeListener(_checkSession);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final image = await compute(
        prepareReceiptImage,
        ReceiptImagePreparation(
          originalBytes: widget.originalBytes,
          crop: _crop,
        ),
      );
      if (mounted) {
        setState(() {
          _source = image;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '사진을 준비하지 못했어요. 20MB 이하, 2,400만 화소 이하 사진을 선택해 주세요.';
        });
      }
    }
  }

  Future<void> _prepare() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final image = await compute(
        prepareReceiptImage,
        ReceiptImagePreparation(
          originalBytes: widget.originalBytes,
          crop: _crop,
          redactions: List.of(_redactions),
        ),
      );
      if (mounted) {
        setState(() {
          _final = image;
          _busy = false;
          _confirmed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '영역을 처리하지 못했어요. 더 작은 재료 영역을 선택해 주세요.';
        });
      }
    }
  }

  Widget _range(
    String label,
    RangeValues values,
    ValueChanged<RangeValues> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      RangeSlider(
        values: values,
        min: 0,
        max: 1,
        divisions: 100,
        labels: RangeLabels(
          '${(values.start * 100).round()}%',
          '${(values.end * 100).round()}%',
        ),
        semanticFormatterCallback: (v) => '${(v * 100).round()}퍼센트',
        onChanged: _busy
            ? null
            : (v) {
                if (v.end - v.start >= .02) setState(() => change(v));
              },
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: pageToolbarHeight(context),
      title: const Text('전송할 재료 사진 확인', maxLines: 2),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(pageGutter),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSectionHeading('보낼 사진을 확인해요'),
                  SizedBox(height: 8),
                  Text(
                    '원본 사진은 바뀌지 않아요. 자동으로 개인정보를 지우지 않으므로 직접 확인해 주세요.',
                    style: TextStyle(color: mediumGray, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_source != null && _final == null) ...[
            const SizedBox(height: 12),
            const Text('1. 아래 조절 막대로 재료 부분만 남겨 주세요. 코랄색 테두리 안쪽이 전송될 영역입니다.'),
            const Text('2. 사진 위에서 손가락으로 사각형을 그려 남은 개인정보를 검게 가려 주세요.'),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(
                  constraints.maxWidth,
                  480 * _source!.width / _source!.height,
                );
                final height = width * _source!.height / _source!.width;
                Offset point(Offset p) => Offset(
                  (p.dx / width).clamp(0, 1),
                  (p.dy / height).clamp(0, 1),
                );
                return Center(
                  child: GestureDetector(
                    onPanStart: _busy
                        ? null
                        : (d) => setState(() {
                            _start = point(d.localPosition);
                            _end = _start;
                          }),
                    onPanUpdate: _busy
                        ? null
                        : (d) => setState(() {
                            _end = point(d.localPosition);
                          }),
                    onPanEnd: _busy
                        ? null
                        : (_) => setState(() {
                            if (_start != null && _end != null) {
                              final r = Rect.fromPoints(_start!, _end!);
                              if (r.width > .002 && r.height > .002) {
                                _redactions.add(
                                  ReceiptImageRegion(
                                    r.left,
                                    r.top,
                                    r.right,
                                    r.bottom,
                                  ),
                                );
                              }
                            }
                            _start = null;
                            _end = null;
                          }),
                    onPanCancel: () => setState(() {
                      _start = null;
                      _end = null;
                    }),
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            _source!.bytes,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                            semanticLabel: '편집할 재료 사진',
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _RegionPainter(
                                _crop,
                                _redactions,
                                _start,
                                _end,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            _range(
              '남길 가로 범위 (왼쪽 / 오른쪽)',
              RangeValues(_crop.left, _crop.right),
              (v) => _crop = ReceiptImageRegion(
                v.start,
                _crop.top,
                v.end,
                _crop.bottom,
              ),
            ),
            _range(
              '남길 세로 범위 (위 / 아래)',
              RangeValues(_crop.top, _crop.bottom),
              (v) => _crop = ReceiptImageRegion(
                _crop.left,
                v.start,
                _crop.right,
                v.end,
              ),
            ),
            Text('검게 가린 영역: ${_redactions.length}개'),
            TextButton(
              onPressed: _busy || _redactions.isEmpty
                  ? null
                  : () => setState(() => _redactions.removeLast()),
              child: const Text('마지막 가림 취소'),
            ),
            FilledButton(
              onPressed: _busy ? null : _prepare,
              child: const Text('최종 전송 사진 만들기'),
            ),
          ],
          if (_final != null) ...[
            const SizedBox(height: 12),
            const Text('이 사진이 전송됩니다. 확대해 재료와 가릴 정보를 확인해 주세요.'),
            SizedBox(
              height: 360,
              child: InteractiveViewer(
                maxScale: 8,
                child: Image.memory(
                  _final!.bytes,
                  fit: BoxFit.contain,
                  semanticLabel: '최종 전송 사진',
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '요청 1회 최대 US\$0.60 예약 · 앱 전체 공유 월 US\$10 · 이 계정의 AI 기능 합산 하루 10회(UTC 기준)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '받는 곳: 앱 서버(Supabase)를 거쳐 OpenAI\n전달 정보: 위 사진에 보이는 식재료와 주변 이미지\n목적: 식재료 등록 후보 분석. 결과는 이름 후보만 보여주며 저장 전에 확인합니다. 수량·소비기한·신선도는 판단하지 않습니다.\n비용: 서버가 전송 직전 한도를 확인하고 최대 US\$0.60을 예약합니다. 실패하거나 응답을 확인하지 못해도 비용이 발생하거나 예약액이 유지될 수 있습니다. 이 한도는 앱의 사용 기록 기준이며 실제 OpenAI 청구액은 여기서 확인할 수 없습니다. 자동으로 재시도하지 않습니다. 같은 사진이라도 다시 선택해 보내면 새 유료 요청이 됩니다.\n보관: OpenAI의 API 데이터 정책에 따라 처리되며, 보안·오남용 감시 등을 위한 보관이 발생할 수 있습니다. 보관되지 않는다고 보장하지 않습니다.',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: _returned || !_foreground || _sessionInvalid
                  ? null
                  : (v) {
                      _checkSession();
                      if (!_sessionInvalid) {
                        setState(() => _confirmed = v ?? false);
                      }
                    },
              title: const Text(
                '식재료가 선명하게 보이고, 연락처·주소·결제/카드·계정 정보·QR/바코드·주변 배경을 제외했으며, 위 사진의 OpenAI 전송과 분석 비용을 확인했습니다.',
              ),
            ),
            FilledButton(
              onPressed:
                  !_confirmed || _returned || !_foreground || _sessionInvalid
                  ? null
                  : () {
                      _checkSession();
                      if (_sessionInvalid) return;
                      setState(() => _returned = true);
                      Navigator.of(
                        context,
                      ).pop(ReviewedIngredientImage(_final!));
                    },
              child: const Text('OpenAI로 보내 분석'),
            ),
            TextButton(
              onPressed: _returned
                  ? null
                  : () => setState(() {
                      _final = null;
                      _confirmed = false;
                    }),
              child: const Text('다시 편집'),
            ),
          ],
          TextButton(
            onPressed: _returned ? null : () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    ),
  );
}

class _RegionPainter extends CustomPainter {
  _RegionPainter(this.crop, this.redactions, this.start, this.end);
  final ReceiptImageRegion crop;
  final List<ReceiptImageRegion> redactions;
  final Offset? start, end;
  @override
  void paint(Canvas canvas, Size size) {
    Rect rect(ReceiptImageRegion r) => Rect.fromLTRB(
      r.left * size.width,
      r.top * size.height,
      r.right * size.width,
      r.bottom * size.height,
    );
    for (final r in redactions) {
      canvas.drawRect(rect(r), Paint()..color = Colors.black);
    }
    if (start != null && end != null) {
      canvas.drawRect(
        Rect.fromPoints(
          Offset(start!.dx * size.width, start!.dy * size.height),
          Offset(end!.dx * size.width, end!.dy * size.height),
        ),
        Paint()..color = Colors.black,
      );
    }
    final area = rect(crop);
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addRect(area)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(mask, Paint()..color = Colors.black54);
    canvas.drawRect(
      area,
      Paint()
        ..color = primaryGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _RegionPainter oldDelegate) => true;
}
