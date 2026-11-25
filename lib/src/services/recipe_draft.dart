import 'package:flutter_riverpod/flutter_riverpod.dart';

class YoutubeSource {
  const YoutubeSource(this.videoId);
  final String videoId;
  String get url => 'https://www.youtube.com/watch?v=$videoId';
  static YoutubeSource? parse(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443))
      return null;
    String? id;
    if (uri.host == 'youtu.be' && uri.pathSegments.length == 1) {
      id = uri.pathSegments.single;
    } else if (const {
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
    }.contains(uri.host)) {
      if (uri.path == '/watch' && uri.queryParametersAll['v']?.length == 1) {
        id = uri.queryParameters['v'];
      } else if (uri.pathSegments.length == 2 &&
          uri.pathSegments.first == 'shorts') {
        id = uri.pathSegments[1];
      }
    }
    return id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)
        ? YoutubeSource(id)
        : null;
  }
}

enum RecipeSourceKind { description, userTranscript, creatorComment }

class DraftIngredient {
  const DraftIngredient({
    required this.name,
    this.amount,
    required this.evidence,
  });
  final String name;
  final String? amount;
  final String evidence;
}

class DraftStep {
  const DraftStep({required this.instruction, required this.evidence});
  final String instruction;
  final String evidence;
}

/// Transient review data only; intentionally has no DB serialization/save API.
class RecipeDraft {
  const RecipeDraft({
    required this.source,
    required this.sourceKind,
    this.title,
    this.creator,
    this.evidenceUrl,
    this.measurementNote,
    this.ingredients = const [],
    this.steps = const [],
  });
  final YoutubeSource source;
  final RecipeSourceKind sourceKind;
  final String? title;
  final String? creator;
  final String? evidenceUrl;
  final String? measurementNote;
  final List<DraftIngredient> ingredients;
  final List<DraftStep> steps;
  bool get confirmationNeeded => true;
}

abstract interface class RecipeDraftExtractor {
  bool get available;
  Future<RecipeDraft> extract(
    YoutubeSource source,
    String text,
    RecipeSourceKind kind,
  );
}

class UnconfiguredRecipeDraftExtractor implements RecipeDraftExtractor {
  const UnconfiguredRecipeDraftExtractor();
  @override
  bool get available => false;
  @override
  Future<RecipeDraft> extract(
    YoutubeSource source,
    String text,
    RecipeSourceKind kind,
  ) => Future.error(StateError('Recipe extraction is not connected'));
}

final recipeDraftExtractorProvider = Provider<RecipeDraftExtractor>(
  (ref) => const UnconfiguredRecipeDraftExtractor(),
);
