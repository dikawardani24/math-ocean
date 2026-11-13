import 'dart:math' as dm;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'kecrekan_math.dart';

/// A bead on the physical frame. [node] is the imported glTF node; the spring
/// only ever moves it along local X.
class KecrekanBead {
  KecrekanBead({
    required this.node,
    required this.rod,
    required this.index,
    required this.x,
    required this.y,
    required this.z,
  });

  final Node node;
  final int rod;
  final int index;
  final double y;
  final double z;
  double x;
  double velocity = 0;
}

/// Owns the real 3D Kecrekan: the scene, the camera, the imported bead nodes
/// and the small spring solver that gives each bead weight.
class KecrekanController extends ChangeNotifier {
  KecrekanController({
    this.initialCount = 0,
    this.assetPath = 'assets/3d/kecrekan/kecrekan.glb',
  });

  static const String defaultAsset = 'assets/3d/kecrekan/kecrekan.glb';

  final int initialCount;
  final String assetPath;

  final Scene scene = Scene();
  final KecrekanMath math = KecrekanMath();
  final Map<String, KecrekanBead> _beadsByName = {};
  final List<KecrekanBead> beads = [];

  PerspectiveCamera? _camera;

  bool ready = false;
  String? error;

  int get total => math.total;
  PerspectiveCamera? get camera => _camera;

  /// Returns the new total when a tap moved a bead, otherwise null.
  Future<int?> load() async {
    try {
      await Scene.initializeStaticResources();
      final model = await loadScene(assetPath);
      _collectBeads(model);
      _applyInitial(initialCount);
      scene.add(model);
      scene.environmentIntensity = 0.7;
      scene.directionalLight = DirectionalLight(
        direction: vm.Vector3(0.35, -0.7, 1.0),
        color: vm.Vector3(1.0, 0.96, 0.9),
        intensity: 2.0,
      );
      final bounds = model.combinedWorldBounds;
      _camera = bounds == null
          ? PerspectiveCamera(
              position: vm.Vector3(0, 0.05, -7.4),
              target: vm.Vector3(0, 0.02, 0),
              fovRadiansY: 36 * dm.pi / 180,
            )
          : PerspectiveCamera.framing(
              bounds,
              direction: vm.Vector3(0, 0, -1),
              fovRadiansY: 34 * dm.pi / 180,
              margin: 0.9,
            );
      ready = true;
      notifyListeners();
    } catch (exception, stack) {
      error = '$exception';
      debugPrint('Kecrekan failed to load: $exception\n$stack');
      notifyListeners();
    }
    return null;
  }

  void _collectBeads(Node node) {
    final pattern = RegExp(r'^Bead_R(\d+)_(\d+)$');
    void walk(Node current) {
      final match = pattern.firstMatch(current.name);
      if (match != null) {
        final rod = int.parse(match.group(1)!);
        final index = int.parse(match.group(2)!);
        final p = current.position;
        final bead = KecrekanBead(
          node: current,
          rod: rod,
          index: index,
          x: p.x,
          y: p.y,
          z: p.z,
        );
        _beadsByName[current.name] = bead;
        beads.add(bead);
      }
      for (final child in current.children) {
        walk(child);
      }
    }

    walk(node);
    // Stable order: rod, then index.
    beads.sort((a, b) {
      final rod = a.rod.compareTo(b.rod);
      return rod != 0 ? rod : a.index.compareTo(b.index);
    });
  }

  void _applyInitial(int value) {
    math.setTotal(value);
    for (final bead in beads) {
      bead.x = KecrekanMath.beadX(bead.index, math.countFor(bead.rod));
      bead.node.position = vm.Vector3(bead.x, bead.y, bead.z);
    }
  }

  void resetTo(int value) {
    math.setTotal(value);
    notifyListeners();
  }

  /// Retry after a failed load, without rebuilding the widget.
  Future<void> retry() async {
    error = null;
    ready = false;
    notifyListeners();
    await load();
  }

  void reset() => resetTo(initialCount);

  /// How far, in logical pixels, a finger may be from a bead's centre and
  /// still grab it. The beads themselves are never enlarged.
  static double pickRadiusFor(Size size) {
    final shortest = size.isEmpty ? 360.0 : size.shortestSide;
    return (shortest * 0.05).clamp(22.0, 32.0);
  }

  /// The bead nearest [local] in screen space, within [radius].
  ///
  /// Screen-space picking is deliberately forgiving: the projected bead is a
  /// handful of pixels wide, and a child aiming at a bead should not have to
  /// land on its exact silhouette. When [rod] is supplied only beads on that
  /// rod are considered, which is how a drag stays on the row it started on.
  KecrekanBead? beadAt(Offset local, Size size, {int? rod, double? radius}) {
    final camera = _camera;
    if (!ready || camera == null || size.isEmpty) return null;
    final limit = radius ?? pickRadiusFor(size);
    KecrekanBead? best;
    var bestDistance = limit;
    for (final bead in beads) {
      if (rod != null && bead.rod != rod) continue;
      final screen = camera.worldToScreen(
        bead.node.globalTransform.getTranslation(),
        size,
      );
      if (screen == null) continue;
      final distance = (screen - local).distance;
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = bead;
      }
    }
    return best;
  }

  /// World X where the pointer ray crosses the plane at [z].
  double? planeX(Offset local, Size size, {double z = 0}) {
    final camera = _camera;
    if (!ready || camera == null) return null;
    final ray = camera.screenPointToRay(local, size);
    final dz = ray.direction.z;
    if (dz.abs() < 1e-5) return null;
    final t = (z - ray.origin.z) / dz;
    if (t < 0) return null;
    return ray.origin.x + ray.direction.x * t;
  }

  /// Taps the bead under the pointer. Counting is a tap on any bead of the
  /// right-hand group; tapping a counted bead sends one back.
  int? tapAt(Offset local, Size size) {
    final bead = beadAt(local, size);
    if (bead == null) return null;
    return toggleBead(bead);
  }

  /// Moves exactly one bead on [bead]'s row: counted beads go back, uncounted
  /// beads join the counted group.
  int toggleBead(KecrekanBead bead) {
    setRowCount(
      bead.rod,
      KecrekanMath.toggledCount(math.countFor(bead.rod), bead.index),
    );
    return math.countFor(bead.rod);
  }

  void setRowCount(int rod, int count) {
    final before = math.total;
    math.setCount(rod, count);
    if (math.total != before) notifyListeners();
  }

  void addToRow(int rod, int delta) {
    setRowCount(rod, math.countFor(rod) + delta);
  }

  /// Springs every bead toward the position its row's count implies.
  void tick(Duration elapsed, double deltaSeconds) {
    if (!ready) return;
    final dt = deltaSeconds.clamp(0.0, 0.05);
    if (dt <= 0) return;
    for (final bead in beads) {
      final target = KecrekanMath.beadX(bead.index, math.countFor(bead.rod));
      final dx = target - bead.x;
      if (dx.abs() < 0.0015 && bead.velocity.abs() < 0.02) {
        if (bead.x != target) {
          bead.x = target;
          bead.node.position = vm.Vector3(bead.x, bead.y, bead.z);
        }
        continue;
      }
      // Near-critical damping: the bead arrives without bouncing into its
      // neighbour, and the velocity ceiling keeps a fast flick from jumping
      // past a slot in one frame.
      bead.velocity += dx * 260 * dt;
      bead.velocity *= dm.exp(-31 * dt);
      bead.velocity = bead.velocity.clamp(-12.0, 12.0);
      bead.x += bead.velocity * dt;
      bead.node.position = vm.Vector3(bead.x, bead.y, bead.z);
    }
  }

  @override
  void dispose() {
    for (final bead in beads) {
      _beadsByName.remove(bead.node.name);
    }
    beads.clear();
    scene.dispose();
    super.dispose();
  }
}
