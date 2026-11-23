import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Reusable 3D baby green sea turtle. The GLB supplies the flipper/tail swim
/// cycle; this widget adds a gentle swimming path through its available space.
class Turtle3DCompanion extends StatefulWidget {
  const Turtle3DCompanion({
    super.key,
    this.size = 180,
    this.animation = 'Idle_Swim',
    this.loop = true,
  });

  final double size;
  final String animation;
  final bool loop;

  @override
  State<Turtle3DCompanion> createState() => _Turtle3DCompanionState();
}

class _Turtle3DCompanionState extends State<Turtle3DCompanion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swim;

  @override
  void initState() {
    super.initState();
    _swim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _swim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * .94,
      child: AnimatedBuilder(
        animation: _swim,
        child: _scene(),
        builder: (context, child) {
          final phase = _swim.value * math.pi * 2;
          // A slow oval path, not a nervous shake: Tala swims left/right,
          // rises and dips, and gently banks into each turn.
          final horizontal = math.sin(phase) * widget.size * .025;
          final vertical = math.sin(phase * 2) * widget.size * .012;
          final bank = math.sin(phase) * .018;
          return Transform.translate(
            offset: Offset(horizontal, vertical),
            child: Transform.rotate(
              angle: bank,
              child: Transform.scale(
                scale: 1,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _scene() {
    return SceneView.declarative(
      key: ValueKey(widget.animation),
      camera: PerspectiveCamera(
        // glTF is Y-up / -Z-forward. Keep the camera in front and zoom in
        // enough that the whole character reads clearly on a phone.
        position: vm.Vector3(0, 1.15, -4.75),
        target: vm.Vector3(0, .16, 0),
        fovRadiansY: 40 * math.pi / 180,
        fovNear: .05,
        fovFar: 30,
      ),
      environmentIntensity: 1.15,
      children: [
        SceneModel(
          'assets/3d/characters/tala_sea_turtle.glb',
          animations: [
            SceneAnimationSpec(
              widget.animation,
              loop: widget.loop,
            ),
          ],
        ),
      ],
    );
  }
}
