import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/original_video.dart';
import 'youtube_metadata_header.dart';

typedef VideoReferenceLauncher = Future<bool> Function(Uri, LaunchMode);

/// Link-only reference. Never treats recipe fields as verified video metadata,
/// fetches thumbnails implicitly, or constructs a WebView/player.
class ExternalVideoReference extends StatefulWidget {
  const ExternalVideoReference({
    super.key,
    required this.video,
    this.launcher,
    this.metadataState = VideoMetadataState.unconfigured,
    this.metadata,
    this.retryMetadata,
  });
  final OriginalVideo video;
  final VideoMetadataState metadataState;
  final YouTubeMetadata? metadata;
  final VoidCallback? retryMetadata;
  final VideoReferenceLauncher? launcher;
  @override
  State<ExternalVideoReference> createState() => _ExternalVideoReferenceState();
}

class _ExternalVideoReferenceState extends State<ExternalVideoReference> {
  bool busy = false, failed = false;
  int _generation = 0;
  @override
  void didUpdateWidget(covariant ExternalVideoReference oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.kind != widget.video.kind ||
        oldWidget.video.id != widget.video.id) {
      ++_generation;
      busy = false;
      failed = false;
    }
  }

  bool get youtube => widget.video.kind == OriginalVideoKind.youtube;
  String get service => youtube ? 'YouTube' : 'Instagram';
  Uri? get target {
    final candidate = widget.video.url;
    final parsed = OriginalVideo.parse(candidate.toString());
    return parsed?.kind == widget.video.kind && parsed?.id == widget.video.id
        ? candidate
        : null;
  }

  Future<void> open() async {
    if (busy || target == null) return;
    final uri = target!;
    final generation = ++_generation;
    bool current() => mounted && generation == _generation;
    setState(() {
      busy = true;
      failed = false;
    });
    final launch = widget.launcher ?? (uri, mode) => launchUrl(uri, mode: mode);
    bool opened = false;
    for (final mode in [
      LaunchMode.externalNonBrowserApplication,
      LaunchMode.externalApplication,
    ]) {
      if (!mounted || !current()) return;
      if (ModalRoute.of(context)?.isCurrent == false) {
        setState(() {
          busy = false;
          failed = false;
        });
        return;
      }
      try {
        opened = await launch(uri, mode);
      } catch (_) {
        opened = false;
      }
      if (!mounted || !current()) return;
      if (opened) break;
    }
    if (current()) {
      setState(() {
        busy = false;
        failed = !opened;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$service 참고 영상', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (youtube)
            YouTubeMetadataHeader(
              videoId: widget.video.id,
              state: widget.metadataState,
              data: widget.metadata,
              retry: widget.retryMetadata,
            )
          else
            const Text('Instagram 원본에서 영상 정보를 확인해 주세요.'),
          const SizedBox(height: 8),
          const Text(
            '아래 재료·조리 정보는 앱에 저장된 별도 정보예요. 영상 링크만으로 내용의 일치나 이용 허가가 확인되는 것은 아니에요.',
          ),
          const SizedBox(height: 12),
          if (target == null)
            const Text('영상 주소를 확인할 수 없어요.')
          else ...[
            SelectableText(target.toString()),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy ? null : open,
              icon: const Icon(Icons.open_in_new),
              label: Text(busy ? '여는 중…' : '$service에서 보기'),
            ),
          ],
          if (failed)
            Semantics(
              liveRegion: true,
              child: Text('열지 못했어요. $service 앱 또는 브라우저를 확인한 뒤 다시 눌러 주세요.'),
            ),
        ],
      ),
    ),
  );
}
