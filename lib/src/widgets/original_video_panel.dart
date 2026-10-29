import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../app_variant.dart';
import '../services/original_video.dart';
import '../services/video_segments.dart';
import 'recipe_cover.dart';

final videoRouteObserver = RouteObserver<ModalRoute<dynamic>>();
typedef OriginalVideoLauncher = Future<bool> Function(Uri url, LaunchMode mode);

class OriginalVideoPanel extends StatefulWidget {
  const OriginalVideoPanel({
    super.key,
    required this.video,
    this.launcher,
    this.hero = false,
    this.segment,
    this.repeatSegment = false,
    this.playbackEnabled = true,
    this.posterImageUrl,
    this.playOnEntry = false,
  });
  final bool hero;

  /// Only cooking entry, reached by the user's explicit "요리 시작" tap.
  final bool playOnEntry;
  final String? posterImageUrl;
  final VideoSegment? segment;
  final bool repeatSegment;
  final bool playbackEnabled;
  final OriginalVideo video;
  final OriginalVideoLauncher? launcher;
  @override
  State<OriginalVideoPanel> createState() => _OriginalVideoPanelState();
}

class _OriginalVideoPanelState extends State<OriginalVideoPanel>
    with WidgetsBindingObserver, RouteAware {
  WebViewController? controller;
  ModalRoute<dynamic>? route;
  Timer? timeout;
  Timer? playHintTimer;
  String? playHint;
  bool isPlaying = false, requestingPlay = false;
  bool hasEnded = false;
  String? error;
  bool loading = false, opening = false;
  bool playerReady = false;
  bool get canEmbed =>
      widget.video.kind == OriginalVideoKind.youtube &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.playOnEntry &&
          widget.playbackEnabled &&
          canEmbed &&
          route?.isCurrent != false) {
        unawaited(start());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context);
    if (route != next) {
      videoRouteObserver.unsubscribe(this);
      route = next;
      if (next != null) videoRouteObserver.subscribe(this, next);
    }
  }

  Future<void> pause() async {
    playHintTimer?.cancel();
    try {
      await controller?.runJavaScript('if(window.pauseVideo)pauseVideo();');
    } catch (_) {}
  }

  bool get active =>
      mounted &&
      widget.playbackEnabled &&
      route?.isCurrent != false &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  Future<void> requestPlay({bool fromStart = false}) async {
    if (!playerReady || !active || requestingPlay || error != null) return;
    requestingPlay = true;
    playHintTimer?.cancel();
    playHintTimer = Timer(const Duration(seconds: 6), () {
      if (active && !isPlaying)
        setState(() => playHint = '재생이 지연되고 있어요. 재생 버튼을 누르거나 원본을 열어 주세요.');
    });
    try {
      await resume();
      if (!active) return;
      await controller?.runJavaScript(
        'if(window.playRecipeVideo)playRecipeVideo($fromStart);',
      );
    } catch (_) {
      if (mounted)
        setState(
          () => playHint = '재생을 시작하지 못했어요. 플레이어의 재생 버튼이나 원본 열기를 이용해 주세요.',
        );
    } finally {
      requestingPlay = false;
    }
  }

  Future<void> ready() async {
    if (playerReady) return;
    playerReady = true;
    timeout?.cancel();
    setState(() => loading = false);
    // Loading a range atomically avoids issuing play while cue is still pending.
    await syncSegment(seek: !widget.playOnEntry);
    if (!active) {
      await pause();
      return;
    }
    if (widget.playOnEntry) await requestPlay(fromStart: true);
  }

  Future<void> resume() async {
    if (!widget.playbackEnabled ||
        route?.isCurrent == false ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    try {
      await controller?.runJavaScript(
        'if(window.resumeRecipePlayback)resumeRecipePlayback();',
      );
    } catch (_) {}
  }

  Future<void> syncSegment({bool seek = true}) async {
    if (!playerReady) return;
    final segment = widget.segment;
    try {
      await controller?.runJavaScript(
        'if(window.setRecipeSegment)setRecipeSegment(${segment?.start ?? 'null'},${segment?.end ?? 'null'},${widget.repeatSegment},$seek);',
      );
    } catch (_) {
      fail('영상 구간을 이동하지 못했어요. 원본에서 확인해 주세요.');
    }
  }

  @override
  void didUpdateWidget(covariant OriginalVideoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.playbackEnabled) {
      unawaited(pause());
      return;
    }
    if (!oldWidget.playbackEnabled) unawaited(resume());
    final changed =
        oldWidget.segment?.start != widget.segment?.start ||
        oldWidget.segment?.end != widget.segment?.end;
    if (changed || oldWidget.repeatSegment != widget.repeatSegment) {
      if (changed) {
        hasEnded = false;
        playHint = null;
      }
      if (changed && widget.segment != null && widget.playOnEntry) {
        // Previous/next is an explicit request to watch the selected step,
        // even when the preceding range ended or was manually paused.
        unawaited(playSelectedStep());
      } else {
        unawaited(syncSegment(seek: changed));
      }
    }
  }

  Future<void> playSelectedStep() async {
    // Set bounds without cueing first: cue followed immediately by play races
    // the iframe. requestPlay loads the bounded range atomically instead.
    await syncSegment(seek: false);
    if (!active) return;
    isPlaying = false;
    await requestPlay(fromStart: true);
  }

  Future<void> closePlayer(WebViewController old) async {
    try {
      await old.runJavaScript(
        'if(window.destroyRecipePlayer)destroyRecipePlayer();',
      );
    } catch (_) {}
    try {
      await old.loadHtmlString('<!doctype html><html><body></body></html>');
    } catch (_) {}
  }

  @override
  void didPushNext() {
    unawaited(pause());
  }

  @override
  void didPopNext() {
    unawaited(resume());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(pause());
    } else {
      unawaited(resume());
    }
  }

  @override
  void dispose() {
    timeout?.cancel();
    playHintTimer?.cancel();
    videoRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    final old = controller;
    if (old != null) unawaited(closePlayer(old));
    super.dispose();
  }

  void fail(String message) {
    timeout?.cancel();
    unawaited(pause());
    if (mounted)
      setState(() {
        error = message;
        loading = false;
      });
  }

  Future<void> start() async {
    if (!canEmbed || loading || controller != null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final origin = isDevelopmentApp
          ? 'https://com.tcf.take_care_refrigerator.dev'
          : 'https://com.tcf.take_care_refrigerator';
      final next = WebViewController();
      controller = next;
      if (widget.playOnEntry && next.platform is AndroidWebViewController) {
        // App-local media behavior after an explicit cooking-start tap.
        // YouTube/browser autoplay rejection is still handled below.
        await (next.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }
      await next.setJavaScriptMode(JavaScriptMode.unrestricted);
      await next.addJavaScriptChannel(
        'PlayerStatus',
        onMessageReceived: (message) {
          if (!mounted) return;
          if (message.message == 'ready') {
            unawaited(ready());
          } else if (message.message == 'blocked') {
            playHintTimer?.cancel();
            setState(() {
              isPlaying = false;
              playHint = '자동 재생이 제한됐어요. 재생 버튼을 누르거나 원본을 열어 주세요.';
            });
          } else if (message.message == 'segment-ended') {
            playHintTimer?.cancel();
            setState(() {
              hasEnded = true;
              isPlaying = false;
              playHint = null;
            });
          } else if (message.message.startsWith('state:')) {
            final playing = message.message == 'state:1';
            final ended =
                message.message == 'state:0' ||
                (message.message == 'state:2' && hasEnded);
            if (playing || ended) playHintTimer?.cancel();
            setState(() {
              isPlaying = playing;
              hasEnded = ended;
              if (playing || ended) playHint = null;
            });
          } else if (message.message.startsWith('error:')) {
            fail(
              youtubePlayerError(
                int.tryParse(message.message.substring(6)) ?? 0,
              ),
            );
          }
        },
      );
      await next.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (request.url == 'about:blank' || request.url == '$origin/')
              return NavigationDecision.navigate;
            if (!request.isMainFrame &&
                uri?.scheme == 'https' &&
                const {
                  'www.youtube.com',
                  'www.youtube-nocookie.com',
                }.contains(uri?.host))
              return NavigationDecision.navigate;
            // Never execute intent:/javascript:/file: links or navigate to login pages.
            if (request.isMainFrame) fail('이 링크는 원본 앱 또는 브라우저에서 열어 주세요.');
            return NavigationDecision.prevent;
          },
          onWebResourceError: (event) {
            if (event.isForMainFrame == true)
              fail('영상을 불러오지 못했어요. 연결을 확인하거나 원본을 열어 주세요.');
          },
        ),
      );
      if (!mounted) {
        await closePlayer(next);
        return;
      }
      timeout = Timer(
        const Duration(seconds: 20),
        () => fail('영상 로딩이 지연되고 있어요. 원본에서 확인해 주세요.'),
      );
      await next.loadHtmlString(
        youtubePlayerHtml(widget.video.id, origin),
        baseUrl: '$origin/',
      );
      if (!mounted) {
        await closePlayer(next);
        return;
      }
      if (mounted) setState(() {});
    } catch (_) {
      fail('이 기기에서 앱 안 재생을 시작하지 못했어요. 원본에서 확인해 주세요.');
    }
  }

  Future<void> openOriginal() async {
    if (opening) return;
    setState(() => opening = true);
    await pause();
    final launch =
        widget.launcher ??
        (Uri url, LaunchMode mode) => launchUrl(url, mode: mode);
    var opened = false;
    try {
      opened = await launch(widget.video.url, LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened) {
      try {
        opened = await launch(widget.video.url, LaunchMode.inAppBrowserView);
      } catch (_) {}
    }
    if (mounted)
      setState(() {
        opening = false;
        if (!opened) error = '원본을 열지 못했어요. 아래 주소를 복사해 브라우저에서 열어 주세요.';
      });
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.hero)
            Text(
              widget.video.kind == OriginalVideoKind.youtube
                  ? '원본 YouTube 영상'
                  : '원본 Instagram 릴스',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          if (widget.hero && controller == null)
            SizedBox(
              height: 230,
              child: Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                label: '원본 영상 재생',
                onTap: canEmbed ? start : openOriginal,
                child: InkWell(
                  onTap: canEmbed ? start : openOriginal,
                  child: ExcludeSemantics(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RecipeCover(
                          imageUrl: widget.posterImageUrl,
                          video: widget.video,
                        ),
                        const Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFFCC0000),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        const Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(6),
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Text(
                                  '원본 영상 보기',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!widget.hero && canEmbed && controller == null)
            OutlinedButton.icon(
              onPressed: start,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('여기서 영상 보기'),
            ),
          if (canEmbed && controller != null && error == null)
            SizedBox(
              height: 240,
              child: WebViewWidget(controller: controller!),
            ),
          if (loading) const LinearProgressIndicator(),
          if (widget.playOnEntry &&
              playerReady &&
              error == null &&
              widget.playbackEnabled &&
              !isPlaying) ...[
            if (hasEnded && !widget.repeatSegment)
              Semantics(
                liveRegion: true,
                child: Text(
                  widget.segment != null
                      ? '이 단계의 영상 구간이 끝났어요. 다시 보거나 다음 단계로 이동하세요.'
                      : '영상 재생이 끝났어요. 다시 재생할 수 있어요.',
                ),
              ),
            if (playHint != null) Text(playHint!),
            OutlinedButton.icon(
              onPressed: () => requestPlay(fromStart: hasEnded),
              icon: Icon(hasEnded ? Icons.replay : Icons.play_arrow),
              label: Text(
                hasEnded
                    ? (widget.segment != null ? '이 구간 다시 재생' : '다시 재생')
                    : '재생하기',
              ),
            ),
          ],
          if (error != null) Text(error!),
          if (widget.video.kind == OriginalVideoKind.instagram)
            const Text(
              '릴스는 원본 앱 또는 브라우저에서 열립니다. 로그인·공개 범위·제작자의 임베드 설정에 따라 보이지 않을 수 있어요.',
            ),
          if (!canEmbed && widget.video.kind == OriginalVideoKind.youtube)
            const Text('이 환경에서는 원본 앱 또는 브라우저에서 재생합니다.'),
          TextButton.icon(
            onPressed: opening ? null : openOriginal,
            icon: const Icon(Icons.open_in_new),
            label: Text(opening ? '여는 중…' : '원본 앱 / 브라우저 열기'),
          ),
          if (!widget.hero || error != null)
            SelectableText(
              widget.video.url.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    ),
  );
}
