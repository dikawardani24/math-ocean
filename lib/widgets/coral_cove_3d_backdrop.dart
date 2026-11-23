import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Static 3D Coral Cove environment. It is deliberately non-interactive so
/// the adventure's existing creature and collectible hit targets stay intact.
class CoralCove3DBackdrop extends StatefulWidget {
  const CoralCove3DBackdrop({super.key});

  @override
  State<CoralCove3DBackdrop> createState() => _CoralCove3DBackdropState();
}

class _CoralCove3DBackdropState extends State<CoralCove3DBackdrop> {
  final Scene _scene = Scene();
  Camera? _camera;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await Scene.initializeStaticResources();
      final model = await loadScene(
        'assets/3d/coral_cove/coral_cove_environment.glb',
      );
      _scene.add(model);
      _scene.environmentIntensity = 0.8;
      _scene.directionalLight = DirectionalLight(
        direction: vm.Vector3(-0.35, -0.7, 1),
        color: vm.Vector3(0.78, 0.92, 1),
        intensity: 1.25,
      );
      final bounds = model.combinedWorldBounds;
      if (bounds != null) {
        _camera = PerspectiveCamera.framing(
          bounds,
          direction: vm.Vector3(0, 0, -1),
          fovRadiansY: 42 * math.pi / 180,
          margin: 1.18,
        );
      }
      if (mounted) setState(() => _loaded = _camera != null);
    } catch (error, stack) {
      debugPrint('Coral Cove environment failed to load: $error\n$stack');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    if (!_loaded || camera == null) {
      // Keep a stable fallback if the generated asset has not been built yet.
      return const ColoredBox(
        color: Color(0xFF075363),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF087D91), Color(0xFF043746)],
            ),
          ),
        ),
      );
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: SceneView(
          _scene,
          camera: camera,
          maxFrameRate: 30,
        ),
      ),
    );
  }
}
