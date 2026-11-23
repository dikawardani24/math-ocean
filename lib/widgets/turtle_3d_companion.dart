import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Reusable animated 3D baby green sea turtle used throughout Coral Cove.
class Turtle3DCompanion extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * .88,
      child: SceneView.declarative(
        key: ValueKey(animation),
        camera: PerspectiveCamera(
          // glTF uses Y-up and -Z-forward. The Blender source is Z-up,
          // so using a negative Y camera position looked underneath Tala.
          position: vm.Vector3(0, 1.65, -5.1),
          target: vm.Vector3(0, .18, 0),
          fovRadiansY: 39 * 3.141592653589793 / 180,
          fovNear: .05,
          fovFar: 30,
        ),
        environmentIntensity: 1.15,
        children: [
          SceneModel(
            'assets/3d/characters/tala_sea_turtle.glb',
            animations: [
              SceneAnimationSpec(
                animation,
                loop: loop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
