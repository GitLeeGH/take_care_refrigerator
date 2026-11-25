import 'dart:async';
import 'package:flutter/material.dart';

/// Supplied only by a future trusted official API adapter; never recipe fields.
/// Memory-only presentation contract, not evidence of API access or a cache.
enum VideoMetadataState { unconfigured, loading, available, unavailable, error }

class YouTubeMetadata {
  const YouTubeMetadata({
    required this.videoId,
    required this.title,
    required this.channel,
    required this.thumbnail,
    required this.checkedAt,
  });
  final String videoId, title, channel;
  final Uri thumbnail;
  final DateTime checkedAt;
  // Conservative display freshness; future provider must refresh/delete storage.
  DateTime get expiresAt => checkedAt.add(const Duration(hours: 24));
  bool validFor(String id, DateTime now) =>
      videoId == id &&
      RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) &&
      title.trim().isNotEmpty &&
      channel.trim().isNotEmpty &&
      !checkedAt.isAfter(now) &&
      now.isBefore(expiresAt) &&
      thumbnail.scheme == 'https' &&
      thumbnail.userInfo.isEmpty &&
      (!thumbnail.hasPort || thumbnail.port == 443) &&
      const {'i.ytimg.com', 'i9.ytimg.com'}.contains(thumbnail.host);
}

class YouTubeMetadataHeader extends StatefulWidget {
  const YouTubeMetadataHeader({
    super.key,
    required this.videoId,
    this.state = VideoMetadataState.unconfigured,
    this.data,
    this.retry,
    this.now,
  });
  final String videoId;
  final VideoMetadataState state;
  final YouTubeMetadata? data;
  final VoidCallback? retry;
  final DateTime Function()? now;
  @override
  State<YouTubeMetadataHeader> createState() => _YouTubeMetadataHeaderState();
}

class _YouTubeMetadataHeaderState extends State<YouTubeMetadataHeader>
    with WidgetsBindingObserver {
  Timer? timer;
  DateTime get now => (widget.now ?? DateTime.now)();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    arm();
  }

  @override
  void didUpdateWidget(covariant YouTubeMetadataHeader old) {
    super.didUpdateWidget(old);
    arm();
  }

  void arm() {
    timer?.cancel();
    final end = widget.data?.expiresAt;
    if (end != null && end.isAfter(now)) {
      timer = Timer(end.difference(now), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      arm();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final valid =
        widget.state == VideoMetadataState.available &&
        data != null &&
        data.validFor(widget.videoId, now);
    if (valid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              data.thumbnail.toString(),
              fit: BoxFit.contain,
              semanticLabel: 'YouTube 원본 썸네일',
              errorBuilder: (_, error, stack) =>
                  const Center(child: Text('썸네일을 불러오지 못했어요. 원본 링크에서 확인해 주세요.')),
            ),
          ),
          const SizedBox(height: 8),
          Text(data.title, style: Theme.of(context).textTheme.titleMedium),
          Text('YouTube · ${data.channel}'),
        ],
      );
    }
    final message = switch (widget.state) {
      VideoMetadataState.unconfigured =>
        '영상 제목·채널·썸네일 공급이 아직 연결되지 않았어요. 원본 링크에서 확인해 주세요.',
      VideoMetadataState.loading => 'YouTube 영상 정보를 확인하고 있어요.',
      VideoMetadataState.unavailable =>
        '공개된 영상 정보를 확인할 수 없어요. 비공개·삭제 여부는 YouTube에서 확인해 주세요.',
      VideoMetadataState.error => '영상 정보를 불러오지 못했어요. 이전 정보는 표시하지 않아요.',
      VideoMetadataState.available =>
        '영상 정보가 만료되었거나 확인되지 않았어요. 원본 링크에서 확인해 주세요.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(liveRegion: true, child: Text(message)),
        if (widget.retry != null &&
            widget.state != VideoMetadataState.loading &&
            widget.state != VideoMetadataState.unconfigured)
          TextButton(onPressed: widget.retry, child: const Text('영상 정보 다시 확인')),
      ],
    );
  }
}
