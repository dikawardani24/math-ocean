import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';

import '../core/audio_service.dart';
import '../core/feedback.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';
import 'kecrekan_controller.dart';

/// The playable 3D counting frame.
///
/// The imported GLB is the only thing drawn here: up to 25 independently
/// addressable bead nodes, a real camera, raycast picking and contact-based
/// movement. No painted beads, no flattened fake.
class KecrekanStage extends StatefulWidget {
  const KecrekanStage({
    super.key,
    required this.controller,
    this.hint = 'Grab a bead and push its neighbours',
    this.interactive = true,
    this.onInteraction,
    this.showTotal = true,
    this.showResetButton = true,
    this.showHintOverlay = true,
    this.height,
  });

  final KecrekanController controller;
  final String hint;
  final bool interactive;
  final VoidCallback? onInteraction;
  final bool showTotal;
  final bool showResetButton;
  final bool showHintOverlay;
  final double? height;

  @override
  State<KecrekanStage> createState() => _KecrekanStageState();
}

class _KecrekanStageState extends State<KecrekanStage> {
  Size _size = Size.zero;
  KecrekanBead? _downBead;
  bool _touched = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _ensureLoaded();
  }

  void _ensureLoaded() {
    if (_started) return;
    _started = true;
    widget.controller.load();
  }

  void _notifyTouched() {
    if (_touched) return;
    setState(() => _touched = true);
    widget.onInteraction?.call();
  }

  void _tap(TapUpDetails details) {
    if (!widget.interactive) return;
    // Always use the bead that was under the finger when it went down, not the
    // one under it when it lifted: a tap that wobbles must not toggle a
    // neighbour.
    final bead =
        _downBead ?? widget.controller.beadAt(details.localPosition, _size);
    _downBead = null;
    if (bead == null) return;
    final before = widget.controller.total;
    final row = widget.controller.toggleBead(bead);
    if (widget.controller.total != before) {
      _playForRow(row);
      Feel.snap();
      _notifyTouched();
    }
  }

  /// Grab the bead under the initial pointer-down position and keep the drag
  /// constrained to that rod.
  void _panDown(DragDownDetails details) {
    if (!widget.interactive) return;
    final bead = widget.controller.beadAt(details.localPosition, _size);
    _downBead = bead;
  }

  /// Keep the identity of the initially grabbed bead for the entire gesture.
  void _panStart(DragStartDetails details) {
    final bead = _downBead;
    if (bead == null) return;
    final worldX = widget.controller.planeX(
      details.localPosition,
      _size,
      z: bead.z,
    );
    if (worldX == null) return;
    widget.controller.beginBeadDrag(bead, worldX);
    // Collapse the mission details as soon as the child grabs a bead,
    // not only after the bead crosses the counting threshold.
    _notifyTouched();
  }

  void _panUpdate(DragUpdateDetails details) {
    if (!widget.interactive) return;
    final bead = _downBead;
    if (bead == null) return;
    final worldX = widget.controller.planeX(
      details.localPosition,
      _size,
      z: bead.z,
    );
    if (worldX == null) return;
    final before = widget.controller.total;
    final rowCount = widget.controller.dragBeadTo(worldX);
    if (rowCount == null) return;
    if (widget.controller.total != before) {
      _playForRow(rowCount);
      Feel.snap();
      _notifyTouched();
    }
  }

  void _panEnd(DragEndDetails details) {
    widget.controller.endBeadDrag();
    _downBead = null;
  }

  void _panCancel() {
    widget.controller.endBeadDrag();
    _downBead = null;
  }

  void _playForRow(int count) {
    if (count > 0 && count % 5 == 0) {
      AudioService.instance.groupFive();
    } else {
      AudioService.instance.bead();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        widget.controller.updateCameraForViewport(_size);
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final controller = widget.controller;
            return ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(0.1, -0.35),
                    radius: 1.25,
                    colors: [
                      Color(0xFF127A85),
                      Color(0xFF075363),
                      Color(0xFF032B3B),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Soft light behind the toy.
                    Positioned(
                      left: -60,
                      right: -60,
                      top: -30,
                      height: 220,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              OceanColors.aqua.withValues(alpha: 0.32),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (controller.error != null)
                      _ErrorState(
                        message: controller.error!,
                        onRetry: controller.retry,
                      )
                    else if (!controller.ready || controller.camera == null)
                      const _LoadingState()
                    else
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Anchor the pan where the finger went down, not where
                        // the gesture recogniser finally accepted it. Otherwise
                        // the touch slop swallows most of the first bead's
                        // travel and a four-bead drag only counts three.
                        dragStartBehavior: DragStartBehavior.down,
                        onTapUp: _tap,
                        onPanDown: _panDown,
                        onPanStart: _panStart,
                        onPanUpdate: _panUpdate,
                        onPanEnd: _panEnd,
                        onPanCancel: _panCancel,
                        child: SceneView(
                          controller.scene,
                          camera: controller.camera!,
                          onTick: controller.tick,
                          maxFrameRate: 60,
                        ),
                      ),
                    if (widget.showTotal)
                      Positioned(
                        left: 14,
                        top: 14,
                        child: _TotalBadge(total: controller.total),
                      ),
                    if (widget.showResetButton)
                      Positioned(
                      right: 12,
                      top: 12,
                      child: RoundIconButton(
                        icon: Icons.refresh_rounded,
                        size: 40,
                        color: Colors.white.withValues(alpha: 0.16),
                        iconColor: OceanColors.foam,
                        tooltip: 'Reset the beads',
                        onTap: () {
                          AudioService.instance.sfx('reset');
                          Feel.tap();
                          controller.reset();
                          _notifyTouched();
                        },
                      ),
                    ),
                    if (widget.showHintOverlay && controller.ready)
                      Positioned(
                        left: 14,
                        right: 64,
                        bottom: 12,
                        child: AnimatedOpacity(
                          opacity: _touched ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 500),
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: OceanColors.abyss.withValues(
                                    alpha: 0.55,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.touch_app_rounded,
                                      size: 16,
                                      color: OceanColors.mint,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        widget.hint,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: OceanColors.foam,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Baloo2',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TotalBadge extends StatelessWidget {
  const _TotalBadge({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 15, 7),
      decoration: BoxDecoration(
        color: OceanColors.shell.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: oceanShadow(blur: 12, y: 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💧', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR BEADS',
                style: TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: OceanColors.inkSoft,
                  fontFamily: 'Baloo2',
                ),
              ),
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 22,
                  height: 0.95,
                  fontWeight: FontWeight.w800,
                  color: OceanColors.ink,
                  fontFamily: 'Baloo2',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: OceanColors.aqua,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Polishing the kecrekan…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OceanColors.mint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💧', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 8),
            Text(
              'The beads are hiding',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: OceanColors.foam,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to try again.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: OceanColors.mint.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
            if (message.length < 120)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
