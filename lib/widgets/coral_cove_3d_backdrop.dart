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
  PerspectiveCamera? _camera;
  bool _loaded = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await Scene.initializeStaticResources();

      Node model;
      try {
        // Preferred path: load the build-hook-preprocessed .fsceneb asset.
        model = await loadScene(
          'assets/3d/coral_cove/coral_cove_environment.glb',
        );
      } catch (error) {
        // The generator creates this GLB after checkout. If the Flutter Scene
        // build hook has not cooked it yet, import the bundled GLB directly.
        debugPrint(
          'Coral Cove cooked scene unavailable; trying runtime GLB import: $error',
        );
        model = await Node.fromGlbAsset(
          'assets/3d/coral_cove/coral_cove_environment.glb',
        );
      }

      _scene.add(model);
      _scene.environmentIntensity = 0.8;
      _scene.directionalLight = DirectionalLight(
        direction: vm.Vector3(-0.35, -0.7, 1),
        color: vm.Vector3(0.78, 0.92, 1),
        intensity: 1.25,
      );

      final bounds = model.combinedWorldBounds;
      _camera = bounds == null
          ? PerspectiveCamera(
              position: vm.Vector3(0, 5, -22),
              target: vm.Vector3(0, 1, 0),
              fovRadiansY: 42 * math.pi / 180,
            )
          : PerspectiveCamera.framing(
              bounds,
              direction: vm.Vector3(0, 0, -1),
              fovRadiansY: 42 * math.pi / 180,
              margin: 1.18,
            );

      if (mounted) setState(() => _loaded = true);
    } catch (error, stack) {
      _loadError = error.toString();
      debugPrint('Coral Cove environment failed to load: $error\n$stack');
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    if (!_loaded || camera == null) {
      // Keep a stable fallback if the generated asset has not been built yet.
      return ColoredBox(
        color: const Color(0xFF075363),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF087D91), Color(0xFF043746)],
            ),
          ),
          child: _loadError == null
              ? const SizedBox.expand()
              : Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '3D reef failed to load: $_loadError',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
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
