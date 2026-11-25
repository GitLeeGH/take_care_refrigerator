import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/app_presentation.dart';
import '../services/receipt_image_payload.dart';

/// No network or persistence. Only explicit final confirmation returns bytes.
class ReceiptImageReviewPage extends StatefulWidget {
  const ReceiptImageReviewPage({
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
  State<ReceiptImageReviewPage> createState() => _ReceiptImageReviewPageState();
}

class _ReceiptImageReviewPageState extends State<ReceiptImageReviewPage>
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

  Future<void> _prepare({bool send = false}) async {
    if (_busy ||
        _returned ||
        !_foreground ||
        _sessionInvalid ||
        (send && !_confirmed))
      return;
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
          if (!send) _confirmed = false;
        });
        if (send) _send();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '영역을 처리하지 못했어요. 더 작은 품목 영역을 선택해 주세요.';
        });
      }
    }
  }

  void _send() {
    _checkSession();
    if (_busy ||
        _returned ||
        !_foreground ||
        _sessionInvalid ||
        !_confirmed ||
        _final == null)
      return;
    setState(() => _returned = true);
    Navigator.of(context).pop(ReviewedReceiptImage(_final!));
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
                if (v.end - v.start >= .02)
                  setState(() {
                    change(v);
                    _confirmed = false;
                  });
              },
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: pageToolbarHeight(context),
      title: const Text('전송할 품목 사진 확인', maxLines: 2),
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
            const Text('1. 아래 조절 막대로 품목 부분만 남겨 주세요. 코랄색 테두리 안쪽이 전송될 영역입니다.'),
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
                            _confirmed = false;
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
                            semanticLabel: '편집할 영수증 사진',
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
                  : () => setState(() {
                      _redactions.removeLast();
                      _confirmed = false;
                    }),
              child: const Text('마지막 가림 취소'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _prepare(),
              child: const Text('미리보기'),
            ),
          ],
          if (_final != null) ...[
            const SizedBox(height: 12),
            const Text('이 사진이 전송됩니다. 확대해 품목 이름과 가릴 정보를 확인해 주세요.'),
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
          ],
          if (_source != null) ...[
            const SizedBox(height: 12),
            const Text(
              '선택한 영역의 사진을 앱 서버(Supabase)를 거쳐 OpenAI로 보내 식재료를 분석해요. 연락처·주소·결제 정보는 먼저 가려 주세요.',
            ),
            const ExpansionTile(
              title: Text('개인정보 안내'),
              children: [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '사진은 OpenAI API 정책에 따라 처리되며 보안·오남용 감시 목적으로 보관될 수 있습니다.',
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: _busy || _returned || !_foreground || _sessionInvalid
                  ? null
                  : (v) {
                      _checkSession();
                      if (!_sessionInvalid) {
                        setState(() => _confirmed = v ?? false);
                      }
                    },
              title: const Text('개인정보를 가렸으며, 이 사진의 OpenAI 전송과 분석에 동의합니다.'),
            ),
            FilledButton(
              onPressed:
                  _busy ||
                      !_confirmed ||
                      _returned ||
                      !_foreground ||
                      _sessionInvalid
                  ? null
                  : () {
                      if (_final == null) {
                        _prepare(send: true);
                      } else {
                        _send();
                      }
                    },
              child: Text(_busy ? '사진 준비 중…' : 'AI로 분석하기'),
            ),
            if (_final != null)
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
