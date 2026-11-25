import 'package:flutter/foundation.dart';
import '../widgets/app_presentation.dart';
import '../theme.dart';
import '../widgets/storage_guidance_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers.dart';
import '../services/ingredient_photo.dart';
import '../services/receipt_import.dart';
import '../services/receipt_analysis.dart';
import '../services/receipt_ai_gateway.dart';
import '../services/receipt_image_payload.dart';
import 'receipt_image_review_page.dart';
import '../widgets/ingredient_thumbnail.dart';

final receiptImagePickerProvider =
    Provider<Future<XFile?> Function(ImageSource)>(
      (ref) =>
          (source) => ImagePicker().pickImage(
            source: source,
            maxWidth: 2200,
            maxHeight: 2200,
            imageQuality: 90,
          ),
    );

final receiptAiPhotoLoaderProvider =
    Provider<Future<Uint8List> Function(XFile)>(
      (ref) => (file) async {
        if (await file.length() > 20 * 1024 * 1024) {
          throw const ReceiptAiFailure('invalid_image');
        }
        return file.readAsBytes();
      },
    );
final receiptAiImageReviewProvider =
    Provider<Future<ReviewedReceiptImage?> Function(BuildContext, Uint8List)>(
      (ref) => (context, bytes) {
        final guard = ref.read(receiptAiSessionProvider);
        final review = guard.capture(
          inputRevision: 'local-preview',
          requestId: 'local-preview',
        );
        return Navigator.of(context).push<ReviewedReceiptImage>(
          MaterialPageRoute(
            builder: (_) => ReceiptImageReviewPage(
              originalBytes: bytes,
              sessionChanges: guard,
              isSessionCurrent: () => review.matches(guard.current(review)),
            ),
          ),
        );
      },
    );

class ReceiptImportPage extends ConsumerStatefulWidget {
  const ReceiptImportPage({super.key, this.initialSource});
  final ImageSource? initialSource;
  @override
  ConsumerState<ReceiptImportPage> createState() => _ReceiptImportPageState();
}

class _RowDraft {
  _RowDraft(String value) : name = TextEditingController(text: value);
  final TextEditingController name;
  final quantity = TextEditingController();
  final anchor = GlobalKey();
  DateTime? expiry;
  String? storage;
  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class _ReceiptImportPageState extends ConsumerState<ReceiptImportPage>
    with WidgetsBindingObserver {
  final _rows = <_RowDraft>[];
  final _reviewLines = <ReceiptReviewLine>[];
  final _selectedReview = <ReceiptReviewLine>{};
  final _rawLines = <String>[];

  final _aiReviewGuards = <bool Function()>[];
  final _form = GlobalKey<FormState>();
  bool _busy = false, _reviewed = false;
  bool _picking = false, _foreground = true;
  int _foregroundRevision = 0;
  bool _validationAttempted = false;
  String? _message, _owner;
  ReceiptBatch? _batch;
  PreparedReceiptImage? _pendingAiImage;
  ReceiptAiReviewContext? _pendingAiStart;
  bool _pendingAiReplace = false;
  bool get _locked => _busy || _batch != null;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final source = widget.initialSource;
    if (source != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pick(source, useAi: true);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _foregroundRevision++;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final row in _rows) {
      row.dispose();
    }

    _aiReviewGuards.clear();
    _rawLines.clear();
    _reviewLines.clear();
    _selectedReview.clear();
    _pendingAiImage = null;
    _pendingAiStart = null;
    super.dispose();
  }

  Future<void> _pick(
    ImageSource source, {
    bool useAi = false,
    bool resumeAi = false,
  }) async {
    if (_locked || _picking) return;
    _picking = true;
    try {
      await _pickOnce(source, useAi: useAi, resumeAi: resumeAi);
    } finally {
      _picking = false;
    }
  }

  Future<void> _pickOnce(
    ImageSource source, {
    required bool useAi,
    required bool resumeAi,
  }) async {
    var replace = resumeAi && _pendingAiReplace;
    if (_rows.isNotEmpty || _reviewLines.isNotEmpty) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('다른 영수증을 읽을까요?'),
          content: const Text(
            '교체하면 현재 미저장 입력을 새 결과로 바꿉니다. 이어 붙이기는 여러 영수증을 함께 등록할 때만 선택하세요. 같은 영수증을 다시 붙이면 중복 품목이 생길 수 있습니다. 선택 취소·인식 실패 시 현재 입력은 유지됩니다. AI로 다시 보내면 같은 사진도 새 유료 요청이 됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('이어 붙이기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('새 결과로 교체'),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      replace = choice;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      ReceiptAiReviewContext? aiRequest;
      if (useAi) {
        if (!ref.read(receiptAiEnabledProvider)) {
          throw const ReceiptAiFailure('not_ready');
        }
        final guard = ref.read(receiptAiSessionProvider);
        final pendingStart = _pendingAiStart;
        if (resumeAi &&
            (pendingStart == null ||
                _pendingAiImage == null ||
                !pendingStart.matches(guard.current(pendingStart)))) {
          throw const ReceiptAnalysisDiscarded();
        }
        aiRequest = guard.capture(
          inputRevision: 'pending-review',
          requestId: newIngredientUuid(),
        );
        await ref.read(receiptAiGatewayProvider).checkReady();
        if (!mounted) return;
        if (!aiRequest.matches(guard.current(aiRequest))) {
          throw const ReceiptAnalysisDiscarded();
        }
      }
      final photo = resumeAi
          ? null
          : await ref.read(receiptImagePickerProvider)(source);
      if ((!resumeAi && photo == null) || !mounted) return;
      if (useAi) _pendingAiReplace = replace;
      final analysis = useAi
          ? await _analyzeWithAi(
              photo,
              aiRequest!,
              prepared: resumeAi ? _pendingAiImage : null,
            )
          : await ref
                .read(receiptAnalysisProvider)(photo!.path)
                .timeout(const Duration(seconds: 45));
      if (!mounted || analysis == null) return;
      if (!analysis.isCurrent) throw const ReceiptAnalysisDiscarded();
      if (useAi) {
        _pendingAiImage = null;
        _pendingAiStart = null;
      }
      if (!analysis.hasRecognizedContent) {
        setState(
          () => _message = '읽힌 글자가 없어 기존 입력을 유지했습니다. 다른 사진을 선택하거나 직접 입력해 주세요.',
        );
        return;
      }
      final parsed = analysis.parsed;
      final candidates = parsed.items;
      setState(() {
        if (replace) {
          for (final row in _rows) {
            row.dispose();
          }
          _rows.clear();
          _reviewLines.clear();
          _selectedReview.clear();
          _rawLines.clear();
          _aiReviewGuards.clear();
          _owner = null;
        }
        if (analysis.context != null) {
          _owner = analysis.context!.owner;
          _aiReviewGuards.add(() => analysis.isSessionCurrent);
        }
        for (var i = 0; i < candidates.length; i++) {
          final row = _RowDraft(candidates[i]);
          row.quantity.text = parsed.quantities[i] ?? '';
          _rows.add(row);
        }
        _rawLines.addAll(analysis.rawLines);
        _reviewLines.addAll(parsed.review);
        _reviewed = false;
        _message =
            parsed.notice ??
            (candidates.isEmpty
                ? '자동 선택한 품목이 없습니다. 확인 필요 목록에서 실제 상품을 추가하거나 직접 입력해 주세요.'
                : '품목 후보 ${candidates.length}개를 찾고 안내·결제 문구 등 ${parsed.review.length}줄을 분리했습니다. 빠진 상품은 확인 필요 목록에서 추가해 주세요.');
      });
    } on ReceiptAiFailure catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on ReceiptAnalysisDiscarded {
      if (mounted) {
        setState(
          () => _message =
              '계정, 사진 또는 앱 사용 상태가 바뀌어 전송을 중단하거나 AI 결과를 적용하지 않았습니다. 기존 입력은 유지했습니다. 이미 전송했다면 비용이나 예약액이 남을 수 있으며 자동 재시도하지 않습니다.',
        );
      }
    } on UnsupportedError {
      if (mounted) {
        setState(
          () => _message = '사진 인식은 Android에서 지원합니다. 아래에서 품목을 직접 추가할 수 있습니다.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = '사진을 읽지 못했습니다. 다른 사진을 선택하거나 직접 입력해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<ReceiptAnalysis?> _analyzeWithAi(
    XFile? photo,
    ReceiptAiReviewContext start, {
    PreparedReceiptImage? prepared,
  }) async {
    final guard = ref.read(receiptAiSessionProvider);
    final bytes =
        prepared?.bytes ?? await ref.read(receiptAiPhotoLoaderProvider)(photo!);
    if (!mounted) return null;
    if (!start.matches(guard.current(start))) {
      throw const ReceiptAnalysisDiscarded();
    }
    final reviewed = prepared == null
        ? await ref.read(receiptAiImageReviewProvider)(context, bytes)
        : await Navigator.of(context).push<ReviewedReceiptImage>(
            MaterialPageRoute(
              builder: (_) => ReceiptImageReviewPage(
                originalBytes: bytes,
                initialPreparedImage: prepared,
                sessionChanges: guard,
                isSessionCurrent: () => start.matches(guard.current(start)),
              ),
            ),
          );
    if (!mounted || reviewed == null) return null;
    if (!start.matches(guard.current(start))) {
      throw const ReceiptAnalysisDiscarded();
    }
    // Retain sanitized pixels only, never consent. If preflight or response is
    // interrupted, a manual action can reopen this exact preview unchecked.
    _pendingAiImage = PreparedReceiptImage(
      reviewed.bytes,
      reviewed.width,
      reviewed.height,
    );
    _pendingAiStart = start;
    final request = ReceiptAiReviewContext(
      owner: start.owner,
      sessionRevision: start.sessionRevision,
      inputRevision: reviewed.sha256Hex,
      requestId: start.requestId,
    );
    final foregroundRevision = _foregroundRevision;
    var pending = true;
    try {
      return await ref
          .read(receiptAiGatewayProvider)
          .analyze(
            image: reviewed,
            context: request,
            currentContext: () =>
                !mounted ||
                    (pending &&
                        (!_foreground ||
                            _foregroundRevision != foregroundRevision))
                ? null
                : guard.current(request),
          );
    } finally {
      // A later background transition must not invalidate accepted draft items.
      pending = false;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_aiReviewGuards.any((isCurrent) => !isCurrent())) {
      setState(
        () => _message =
            'AI 결과를 확인한 계정이나 요청이 바뀌었습니다. 새 영수증 결과로 교체한 뒤 다시 확인해 주세요.',
      );
      return;
    }
    if (_batch == null) {
      final issues = <String>[];
      final targets = <GlobalKey?>[];
      for (var i = 0; i < _rows.length; i++) {
        final row = _rows[i];
        final missing = receiptMissingFields(
          name: row.name.text,
          quantity: row.quantity.text,
          storage: row.storage,
          expiry: row.expiry,
        );
        if (missing.isNotEmpty) {
          issues.add(
            '품목 ${i + 1} · ${row.name.text.trim().isEmpty ? '이름 미입력' : row.name.text.trim()}\n${missing.join(' · ')} 입력 필요',
          );
          targets.add(row.anchor);
        }
      }
      if (_rows.isEmpty) {
        issues.add('등록할 품목을 추가해 주세요.');
        targets.add(null);
      }
      if (!_reviewed) {
        issues.add('목록 아래의 직접 확인란을 선택해 주세요.');
        targets.add(null);
      }
      final formValid = _form.currentState!.validate();
      if (issues.isNotEmpty || !formValid) {
        setState(() {
          _validationAttempted = true;
          _message = '저장 전 확인이 필요합니다. 이번 시도에서는 저장하지 않았습니다.';
        });
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('저장 전 입력을 확인해 주세요'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('필수 항목을 입력해 주세요. 입력한 내용은 그대로 유지됩니다.'),
                const SizedBox(height: 12),
                for (var i = 0; i < issues.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: targets[i] == null
                        ? Text(issues[i])
                        : TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final target = targets[i]?.currentContext;
                                if (mounted && target != null) {
                                  Scrollable.ensureVisible(
                                    target,
                                    alignment: 0,
                                    duration: const Duration(milliseconds: 250),
                                  );
                                }
                              });
                            },
                            child: Text('${issues[i]}\n이 품목으로 이동'),
                          ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('입력 계속하기'),
              ),
            ],
          ),
        );
        return;
      }
    }
    final client = ref.read(supabaseProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null || (_owner != null && _owner != uid)) {
      setState(() => _message = '등록을 시작한 계정으로 로그인되어 있는지 확인해 주세요.');
      return;
    }
    _owner = uid;
    _batch ??= ReceiptBatch(
      _rows
          .map(
            (row) => IngredientSaveOperation(
              gateway: SupabaseIngredientPhotoGateway(client),
              editing: false,
              data: {
                'id': newIngredientUuid(),
                'user_id': uid,
                'name': row.name.text.trim(),
                'quantity': row.quantity.text.trim(),
                'storage_type': row.storage,
                'expiry_date': row.expiry!.toIso8601String().split('T').first,
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'image_path': null,
              },
            ),
          )
          .toList(),
      beforeSave: () {
        if (client.auth.currentUser?.id != _owner ||
            _aiReviewGuards.any((isCurrent) => !isCurrent())) {
          throw StateError('Account changed');
        }
      },
    );
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _batch!.save();
      ref.invalidate(ingredientsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_batch!.completed}개 재료를 등록했습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      ref.invalidate(ingredientsProvider);
      if (mounted) {
        setState(
          () => _message =
              '${_batch!.completed}/${_rows.length}개 저장 확인. 나머지는 저장 여부 확인이 필요합니다. 재시도하면 같은 항목을 확인한 뒤 이어서 저장합니다.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _restoreReview(Iterable<ReceiptReviewLine> chosen) {
    if (_locked) return;
    final selected = chosen.where((line) => line.canRestore).toList();
    setState(() {
      for (final line in selected) {
        if (!_reviewLines.contains(line)) continue;
        final row = _RowDraft(line.text);
        row.quantity.text = line.quantity ?? '';
        _rows.add(row);
        _reviewLines.remove(line);
        _selectedReview.remove(line);
      }
      _reviewed = false;
    });
  }

  Future<void> _leave() async {
    if (_busy) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('등록 화면을 나갈까요?'),
        content: Text(
          _batch == null
              ? '입력한 품목은 저장되지 않습니다.'
              : '일부 항목은 이미 저장되었을 수 있습니다. 냉장고 목록을 확인한 뒤 다시 등록해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 입력'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && _rows.isEmpty && _reviewLines.isEmpty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: pageToolbarHeight(context),
        title: const Text('영수증 등록', maxLines: 2),
      ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(pageGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.privacy_tip_outlined, size: 20),
                  title: const Text(
                    '사진 처리 안내',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(
                      '사진은 앱 서버를 거쳐 OpenAI로 전송돼 품목을 분석합니다. 전송 전에 개인정보를 가리고 동의해 주세요.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (ref.watch(receiptAiEnabledProvider)) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [coralSurface, Color(0xFFF7B5A5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppSectionHeading('AI로 영수증 등록'),
                      const SizedBox(height: 8),
                      const Text(
                        '영수증을 찍고, 찾은 품목을 확인해요.',
                        style: TextStyle(color: darkGray, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _locked
                                ? null
                                : () => _pick(ImageSource.gallery, useAi: true),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('AI로 사진 선택'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _locked
                                ? null
                                : () => _pick(ImageSource.camera, useAi: true),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: primaryGreen),
                            ),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('AI로 직접 촬영'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '사진을 확인하고 AI로 분석해요.',
                        style: TextStyle(fontSize: 12, color: darkGray),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_pendingAiImage != null) ...[
                  OutlinedButton(
                    onPressed: _locked
                        ? null
                        : () => _pick(
                            ImageSource.gallery,
                            useAi: true,
                            resumeAi: true,
                          ),
                    child: const Text('전송 사진 다시 확인'),
                  ),
                  const Text(
                    '사진은 이 화면에만 유지됩니다. 다시 확인해 보내면 새 유료 요청이며 이전 요청의 비용이나 예약액이 남아 있을 수 있습니다.',
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              if (_busy) const LinearProgressIndicator(),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_message!, semanticsLabel: _message),
                ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppSectionHeading('등록 전 확인'),
                      const SizedBox(height: 8),
                      const Text('품목·수량을 확인하고 유통기한은 포장에 적힌 날짜를 입력해 주세요.'),
                      const SizedBox(height: 8),
                      const Text('포장 중량(400g 등)과 구매 수량은 다릅니다.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_rawLines.isNotEmpty)
                ExpansionTile(
                  title: Text('OCR 원문 ${_rawLines.length}줄 · 품목 선별 전'),
                  subtitle: const Text(
                    '전화·결제 정보가 포함될 수 있어요. 원문은 이 화면의 확인용이며 자동 전송하지 않아요. 펼칠 때 주변 노출에 주의해 주세요.',
                  ),
                  children: [
                    for (var i = 0; i < _rawLines.length; i++)
                      ListTile(title: Text('${i + 1}. ${_rawLines[i]}')),
                  ],
                ),
              for (final candidateGroup in [true, false])
                if (_reviewLines.any(
                  (line) =>
                      line.canRestore && line.isCandidate == candidateGroup,
                ))
                  ExpansionTile(
                    title: Text(
                      candidateGroup
                          ? '찾은 품목 · 선택해서 추가 ${_reviewLines.where((r) => r.isCandidate).length}개'
                          : '확인 필요 · 자동 선택 제외 ${_reviewLines.where((r) => !r.isCandidate && r.canRestore).length}줄',
                    ),
                    subtitle: const Text(
                      '실제 상품만 선택해 주세요. 복원한 줄은 재료 이름 칸에 복사됩니다. 전화·결제 정보는 삭제한 뒤 저장해 주세요.',
                    ),
                    children: [
                      if (candidateGroup)
                        TextButton.icon(
                          onPressed: _locked
                              ? null
                              : () => _restoreReview(
                                  _reviewLines.where(
                                    (line) => line.isCandidate,
                                  ),
                                ),
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('품목 후보 모두 한 번에 추가'),
                        ),
                      if (_selectedReview.any(
                        (line) =>
                            line.canRestore &&
                            line.isCandidate == candidateGroup,
                      ))
                        TextButton(
                          onPressed: _locked
                              ? null
                              : () => _restoreReview(
                                  _selectedReview.where(
                                    (line) =>
                                        line.canRestore &&
                                        line.isCandidate == candidateGroup,
                                  ),
                                ),
                          child: const Text('선택한 줄 한 번에 복원'),
                        ),
                      for (final line
                          in _reviewLines
                              .where(
                                (line) =>
                                    line.canRestore &&
                                    line.isCandidate == candidateGroup,
                              )
                              .toList())
                        ListTile(
                          leading: Checkbox(
                            semanticLabel: '${line.text} 품목 선택',
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            visualDensity: VisualDensity.standard,
                            value: _selectedReview.contains(line),
                            onChanged: _locked
                                ? null
                                : (selected) => setState(() {
                                    if (selected == true) {
                                      _selectedReview.add(line);
                                    } else {
                                      _selectedReview.remove(line);
                                    }
                                  }),
                          ),
                          title: Text(line.text),
                          subtitle: Text(line.reason),
                          trailing: IconButton(
                            tooltip: '${line.text} 품목으로 복원',
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _locked
                                ? null
                                : () => _restoreReview([line]),
                          ),
                        ),
                    ],
                  ),
              for (var i = 0; i < _rows.length; i++) _row(_rows[i], i),
              TextButton.icon(
                onPressed: _locked
                    ? null
                    : () => setState(() {
                        _rows.add(_RowDraft(''));
                        _reviewed = false;
                      }),
                icon: const Icon(Icons.add),
                label: const Text('품목 직접 추가'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _reviewed,
                onChanged: _locked
                    ? null
                    : (v) => setState(() => _reviewed = v!),
                title: const Text('품목·수량·유통기한을 직접 확인했습니다.'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(
          onPressed: _busy || _rows.isEmpty ? null : _save,
          child: Text(
            _busy
                ? '처리 중…'
                : _batch == null
                ? '${_rows.length}개 재료 저장'
                : '남은 항목 저장 재시도',
          ),
        ),
      ),
    ),
  );

  Widget _row(_RowDraft row, int index) => Card(
    key: row.anchor,
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IngredientThumbnail(name: row.name.text),
              Expanded(child: Text('품목 ${index + 1}')),
              IconButton(
                tooltip: '품목 제외',
                onPressed: _locked
                    ? null
                    : () => setState(() {
                        _rows.remove(row);
                        row.dispose();
                        _reviewed = false;
                      }),
                icon: Icon(Icons.close, semanticLabel: '${index + 1}번 품목 제외'),
              ),
            ],
          ),
          TextFormField(
            controller: row.name,
            enabled: !_locked,
            maxLength: 80,
            decoration: const InputDecoration(labelText: '재료 이름'),
            validator: (v) => v!.trim().isEmpty ? '이름을 입력해 주세요' : null,
            onChanged: (_) => setState(() => _reviewed = false),
          ),
          TextFormField(
            controller: row.quantity,
            enabled: !_locked,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: '수량',
              helperText: '예: 2개, 500g',
              helperMaxLines: 2,
            ),
            validator: (v) => v!.trim().isEmpty ? '수량을 입력해 주세요' : null,
            onChanged: (_) => setState(() => _reviewed = false),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: row.storage,
            decoration: const InputDecoration(labelText: '보관 장소 (필수)'),
            hint: const Text('선택해 주세요', overflow: TextOverflow.ellipsis),
            validator: (value) => value == null ? '보관 장소를 선택해 주세요' : null,
            items: const [
              DropdownMenuItem(value: 'refrigerated', child: Text('냉장')),
              DropdownMenuItem(value: 'frozen', child: Text('냉동')),
              DropdownMenuItem(value: 'ambient', child: Text('실온')),
            ],
            onChanged: _locked
                ? null
                : (v) => setState(() {
                    row.storage = v!;
                    _reviewed = false;
                  }),
          ),
          StorageGuidanceButton(name: row.name.text, storageType: row.storage),
          if (_validationAttempted && row.expiry == null)
            Text(
              '품목 ${index + 1}: 유통기한을 선택해 주세요. 모르는 날짜는 추정하지 마세요.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          OutlinedButton.icon(
            onPressed: _locked
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: row.expiry ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null && mounted) {
                      setState(() {
                        row.expiry = date;
                        _reviewed = false;
                      });
                    }
                  },
            icon: const Icon(Icons.calendar_month),
            label: Text(
              row.expiry == null
                  ? '유통기한 (필수)'
                  : '유통기한 ${row.expiry!.toIso8601String().split('T').first}',
            ),
          ),
        ],
      ),
    ),
  );
}
