import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'receipt_ai_review.dart';
import 'receipt_import.dart';
import 'receipt_layout.dart';

/// The production implementation stays local. This seam lets an independently
/// authorized future AI flow reuse the same review UI without a new save path.
/// Nothing here sends images/text, stores credentials or enables external AI.
final receiptAnalysisProvider =
    Provider<Future<ReceiptAnalysis> Function(String)>((ref) {
      final recognize = ref.watch(receiptOcrProvider);
      return (path) async {
        final lines = await recognize(path);
        final trace = kDebugMode ? <String>[] : null;
        return ReceiptAnalysis._(
          parsed: parseReceipt(lines, debugTrace: trace),
          rawLines: lines is ReceiptOcrLines
              ? List.unmodifiable(lines)
              : const [],
          debugTrace: List.unmodifiable(trace ?? const <String>[]),
          hasRecognizedContent: lines.any((line) => line.trim().isNotEmpty),
        );
      };
    });

/// Opaque request/session versions, never access tokens or receipt contents.
/// A future caller must change sessionRevision on every auth transition, even
/// an A -> B -> A switch; account equality alone is not sufficient.
class ReceiptAiReviewContext {
  const ReceiptAiReviewContext({
    required this.owner,
    required this.sessionRevision,
    required this.inputRevision,
    required this.requestId,
  });
  final String owner, sessionRevision, inputRevision, requestId;

  bool matches(ReceiptAiReviewContext? other) =>
      owner.isNotEmpty &&
      sessionRevision.isNotEmpty &&
      inputRevision.isNotEmpty &&
      requestId.isNotEmpty &&
      other != null &&
      owner == other.owner &&
      sessionRevision == other.sessionRevision &&
      inputRevision == other.inputRevision &&
      requestId == other.requestId;
}

class ReceiptAnalysisDiscarded implements Exception {
  const ReceiptAnalysisDiscarded();
}

class ReceiptAnalysis {
  ReceiptAnalysis._({
    required this.parsed,
    required this.hasRecognizedContent,
    this.rawLines = const [],
    this.debugTrace = const [],
    this.context,
    ReceiptAiReviewContext? Function()? currentContext,
  }) : _currentContext = currentContext;

  /// Accepts an already-obtained response, not a network callback. Auth, consent,
  /// image/text minimization, budget and provider calls are outside this adapter
  /// and are NOT implemented or authorized by calling it.
  factory ReceiptAnalysis.aiReview({
    required Object? response,
    required ReceiptAiReviewContext context,
    required ReceiptAiReviewContext? Function() currentContext,
  }) {
    if (!context.matches(currentContext())) {
      throw const ReceiptAnalysisDiscarded();
    }
    final parsed = reviewAiReceiptResponse(response);
    return ReceiptAnalysis._(
      parsed: parsed,
      hasRecognizedContent: parsed.review.isNotEmpty,
      context: context,
      currentContext: currentContext,
    );
  }

  final ReceiptParseResult parsed;
  final bool hasRecognizedContent;
  final List<String> rawLines, debugTrace;
  final ReceiptAiReviewContext? context;
  final ReceiptAiReviewContext? Function()? _currentContext;
  bool _discarded = false;
  bool _sessionInvalidated = false;

  /// Sticky invalidation: once observed stale, this result cannot be reused.
  bool get isCurrent {
    if (_discarded) return false;
    if (context != null && !context!.matches(_currentContext!())) {
      _discarded = true;
    }
    return !_discarded;
  }

  /// Once candidates are accepted into the draft, a later receipt request or
  /// user edit must not invalidate them. Only the captured account/session
  /// remains binding for save. Null/revoked session stays invalid thereafter.
  bool get isSessionCurrent {
    if (_sessionInvalidated) return false;
    if (context != null) {
      final current = _currentContext!();
      if (current == null ||
          context!.owner != current.owner ||
          context!.sessionRevision != current.sessionRevision) {
        _sessionInvalidated = true;
      }
    }
    return !_sessionInvalidated;
  }
}
