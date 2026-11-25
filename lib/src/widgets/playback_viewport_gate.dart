import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

double visiblePlaybackFraction(Rect player, Iterable<Rect> clips) {
  if (player.width < 200 || player.height < 200) return 0;
  var visible = player;
  for (final clip in clips) {
    visible = visible.intersect(clip);
    if (visible.isEmpty) return 0;
  }
  return (visible.width * visible.height / (player.width * player.height))
      .clamp(0, 1);
}

/// Observes scroll/layout visibility without intercepting player touch events.
/// Route/lifecycle blocking remains the player's responsibility.
class PlaybackViewportGate extends StatefulWidget {
  const PlaybackViewportGate({
    super.key,
    required this.child,
    required this.onChanged,
  });
  final Widget child;
  final ValueChanged<bool> onChanged;
  @override
  State<PlaybackViewportGate> createState() => _PlaybackViewportGateState();
}

class _PlaybackViewportGateState extends State<PlaybackViewportGate>
    with WidgetsBindingObserver {
  final anchor = GlobalKey();
  final positions = <ScrollPosition>[];
  bool scheduled = false;
  bool? previous;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scheduleMeasure();
  }

  void scheduleMeasure() {
    if (scheduled || !mounted) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      measure();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final position in positions) {
      position.removeListener(scheduleMeasure);
    }
    positions.clear();
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        if (!positions.contains(position)) {
          positions.add(position);
          position.addListener(scheduleMeasure);
        }
      }
      return true;
    });
    scheduleMeasure();
  }

  @override
  void didChangeMetrics() => scheduleMeasure();

  @override
  void didUpdateWidget(covariant PlaybackViewportGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    scheduleMeasure();
  }

  void measure() {
    if (!mounted) return;
    final box = anchor.currentContext?.findRenderObject();
    var allowed = false;
    if (box is RenderBox && box.attached && box.hasSize) {
      final bounds = box.localToGlobal(Offset.zero) & box.size;
      final clips = <Rect>[Offset.zero & MediaQuery.sizeOf(context)];
      RenderObject? ancestor = box.parent;
      while (ancestor != null) {
        if (ancestor is RenderOffstage && ancestor.offstage) {
          clips.add(Rect.zero);
        }
        if (ancestor is RenderOpacity && ancestor.opacity == 0) {
          clips.add(Rect.zero);
        }
        if (ancestor is RenderAbstractViewport) {
          final viewportBox = ancestor as RenderObject;
          if (viewportBox is RenderBox && viewportBox.hasSize) {
            clips.add(
              viewportBox.localToGlobal(Offset.zero) & viewportBox.size,
            );
          }
        }
        ancestor = ancestor.parent;
      }
      allowed = visiblePlaybackFraction(bounds, clips) > .5;
    }
    if (allowed != previous) {
      previous = allowed;
      widget.onChanged(allowed);
    }
  }

  @override
  void dispose() {
    for (final position in positions) {
      position.removeListener(scheduleMeasure);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      scheduleMeasure();
      return SizedBox(
        key: anchor,
        child: constraints.maxWidth < 200
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: Text('플레이어를 표시할 공간이 부족해요. 원본 앱 / 브라우저에서 재생해 주세요.'),
              )
            : widget.child,
      );
    },
  );
}
