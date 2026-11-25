/// Admin-reviewed timing metadata. Missing/stale/malformed metadata fails closed.
class VideoSegment {
  const VideoSegment(this.start, this.end);
  final double start;
  final double end;
  String get label => '${start.round()}–${end.round()}초';
}

List<VideoSegment>? verifiedVideoSegments(
  Object? raw,
  String? videoId,
  List<String> steps,
) {
  if (raw is! Map ||
      raw['version'] != 1 ||
      raw['verified'] != true ||
      raw['video_id'] != videoId ||
      videoId == null ||
      steps.isEmpty ||
      !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId) ||
      !const ['excerpt', 'complete'].contains(raw['coverage']) ||
      raw['verified_at'] is! String ||
      DateTime.tryParse(raw['verified_at'] as String) == null) {
    return null;
  }
  final entries = raw['segments'];
  final duration = raw['duration_seconds'];
  if (entries is! List ||
      entries.length != steps.length ||
      duration is! num ||
      !duration.isFinite ||
      duration <= 0 ||
      duration > 86400) {
    return null;
  }
  final result = <VideoSegment>[];
  double previousEnd = 0;
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    if (entry is! Map || entry['step_text'] != steps[i]) return null;
    final start = entry['start_seconds'];
    final end = entry['end_seconds'];
    if (start is! num ||
        end is! num ||
        !start.isFinite ||
        !end.isFinite ||
        start < previousEnd ||
        end <= start ||
        end > duration) {
      return null;
    }
    result.add(VideoSegment(start.toDouble(), end.toDouble()));
    previousEnd = end.toDouble();
  }
  return List.unmodifiable(result);
}
