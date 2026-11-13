import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() => runApp(const MaterialApp(home: Smoke()));

class Smoke extends StatefulWidget {
  const Smoke({super.key});
  @override
  State<Smoke> createState() => _SmokeState();
}

class _SmokeState extends State<Smoke> {
  final Scene scene = Scene();
  Node? model;
  String status = 'loading…';
  int beadCount = 0;
  PerspectiveCamera? camera;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await Scene.initializeStaticResources();
      final node = await loadScene('assets/3d/kecrekan/kecrekan.glb');
      int beads = 0;
      void walk(Node n) {
        if (n.name.startsWith('Bead_')) beads++;
        for (final child in n.children) {
          walk(child);
        }
      }

      walk(node);
      scene.add(node);
      final bounds = node.combinedWorldBounds ??
          vm.Aabb3.minMax(
            vm.Vector3(-1.8, -1.8, -0.5),
            vm.Vector3(1.8, 1.8, 0.5),
          );
      final cam = PerspectiveCamera.framing(
        bounds,
        direction: vm.Vector3(0, 0, 1),
        margin: 1.12,
      );
      setState(() {
        model = node;
        beadCount = beads;
        camera = cam;
        status =
            'ok • $beads beads • center ${bounds.center.x.toStringAsFixed(2)},'
            '${bounds.center.y.toStringAsFixed(2)},${bounds.center.z.toStringAsFixed(2)}'
            ' • size ${(bounds.max.x - bounds.min.x).toStringAsFixed(2)}x'
            '${(bounds.max.y - bounds.min.y).toStringAsFixed(2)}x'
            '${(bounds.max.z - bounds.min.z).toStringAsFixed(2)}';
      });
    } catch (e, st) {
      debugPrint('$e\n$st');
      setState(() => status = 'ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff022b3a), Color(0xff0b6070)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          if (camera != null) SceneView(scene, camera: camera!),
          Positioned(
            left: 12,
            right: 12,
            bottom: 24,
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
