import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Full-bleed, non-interactive 3D environment behind Coral Cove gameplay.
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
        model = await loadScene(
          'assets/3d/coral_cove/coral_cove_environment.glb',
        );
      } catch (error) {
        debugPrint(
          'Coral Cove cooked scene unavailable; trying runtime GLB import: $error',
        );
        model = await Node.fromGlbAsset(
          'assets/3d/coral_cove/coral_cove_environment.glb',
        );
      }

      _scene.add(model);
      _scene.environmentIntensity = 0.8;
      _scene.skybox = Skybox(
        GradientSkySource(
          zenithColor: vm.Vector3(0.015, 0.20, 0.31),
          horizonColor: vm.Vector3(0.025, 0.48, 0.57),
          groundColor: vm.Vector3(0.012, 0.12, 0.17),
          sunDirection: vm.Vector3(-0.4, 0.8, -0.3),
          sunColor: vm.Vector3(0.45, 0.78, 0.82),
          sunSharpness: 24,
        ),
        intensity: 0.9,
      );
      _scene.directionalLight = DirectionalLight(
        direction: vm.Vector3(-0.35, -0.7, 1),
        color: vm.Vector3(0.78, 0.92, 1),
        intensity: 1.25,
      );

      // Keep the known-visible GLB orientation. The fixed portrait camera
      // guessed the exported coordinate axes incorrectly and looked away
      // from the reef. Frame the imported model first; portrait viewport
      // projection is then applied by SceneView itself.
      final bounds = model.combinedWorldBounds;
      if (bounds != null) {
        _camera = PerspectiveCamera.framing(
          bounds,
          direction: vm.Vector3(0, -0.16, -1),
          fovRadiansY: 54 * math.pi / 180,
          margin: 0.78,
        );
      } else {
        // This fallback preserves the GLB's known viewing direction.
        _camera = PerspectiveCamera(
          position: vm.Vector3(0, 7, -18),
          target: vm.Vector3(0, 1, 0),
          fovRadiansY: 54 * math.pi / 180,
        );
      }

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

    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: SceneView(
            _scene,
            camera: camera,
            maxFrameRate: 30,
          ),
        ),
      ),
    );
  }
}
