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
  double y;
  final double z;
  double x;
  double velocity = 0;
}

/// Owns the real 3D Kecrekan: the scene, the camera, the imported bead nodes
/// and the 1D contact solver that prevents bead overlap and propagates pushes.
class KecrekanController extends ChangeNotifier {
  KecrekanController({
    this.initialCount = 0,
    this.activeRowCount = 1,
    this.assetPath = 'assets/3d/kecrekan/kecrekan.glb',
  });

  static const String defaultAsset = 'assets/3d/kecrekan/kecrekan.glb';

  final int initialCount;
  final String assetPath;
  int activeRowCount;

  final Scene scene = Scene();
  final KecrekanMath math = KecrekanMath();
  final Map<String, KecrekanBead> _beadsByName = {};
  final List<KecrekanBead> _allBeads = [];
  final List<KecrekanBead> beads = [];
  final Map<String, Node> _frameNodes = {};
  final Map<int, List<Node>> _rowNodes = {};

  PerspectiveCamera? _camera;
  KecrekanBead? _draggedBead;
  double _dragOffset = 0;

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
      setActiveRowCount(activeRowCount, notify: false);
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
              // The default framing left too much empty space around the
              // toy. A tighter fit makes the frame and individual beads
              // substantially easier for small hands and young eyes to see.
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
    final beadPattern = RegExp(r'^Bead_R(\d+)_(\d+)$');
    final rowPattern = RegExp(
      r'^(?:Rod_(\d+)|RodCap_(\d+)_|FiveMarker_(\d+)|Bead_R(\d+)_)',
    );

    void walk(Node current) {
      if (current.name.startsWith('Frame_')) {
        _frameNodes[current.name] = current;
      }

      final rowMatch = rowPattern.firstMatch(current.name);
      if (rowMatch != null) {
        final row = int.parse(
          rowMatch.group(1) ??
              rowMatch.group(2) ??
              rowMatch.group(3) ??
              rowMatch.group(4)!,
        );
        _rowNodes.putIfAbsent(row, () => []).add(current);
      }

      final match = beadPattern.firstMatch(current.name);
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
        _allBeads.add(bead);
      }

      for (final child in current.children) {
        walk(child);
      }
    }

    walk(node);
    _allBeads.sort((a, b) {
      final rod = a.rod.compareTo(b.rod);
      return rod != 0 ? rod : a.index.compareTo(b.index);
    });
  }

  /// Show only the rows needed for this challenge and compact the frame around
  /// them. The bead diameter and horizontal spacing never change.
  void setActiveRowCount(int count, {bool notify = true}) {
    activeRowCount = count.clamp(1, KecrekanMath.rodCount).toInt();

    for (final entry in _rowNodes.entries) {
      final visible = entry.key < activeRowCount;
      for (final node in entry.value) {
        node.visible = visible;
      }
    }

    const rowSpacing = 0.52;
    for (final bead in _allBeads) {
      final rowY = bead.rod < activeRowCount
          ? (bead.rod - (activeRowCount - 1) / 2) * rowSpacing
          : 0.0;
      bead.y = rowY;
      bead.node.position = vm.Vector3(bead.x, rowY, bead.z);
    }

    for (final entry in _rowNodes.entries) {
      final rowY = entry.key < activeRowCount
          ? (entry.key - (activeRowCount - 1) / 2) * rowSpacing
          : 0.0;
      for (final node in entry.value) {
        if (node.name.startsWith('Bead_R')) continue;
        final p = node.position;
        node.position = vm.Vector3(p.x, rowY, p.z);
      }
    }

    final frameHalfHeight = (activeRowCount - 1) * rowSpacing / 2 + 0.35;
    final top = _frameNodes['Frame_TopRail'];
    if (top != null) {
      final p = top.position;
      top.position = vm.Vector3(p.x, frameHalfHeight, p.z);
    }
    final bottom = _frameNodes['Frame_BottomRail'];
    if (bottom != null) {
      final p = bottom.position;
      bottom.position = vm.Vector3(p.x, -frameHalfHeight, p.z);
    }
    final topAccent = _frameNodes['Frame_TopAccent'];
    if (topAccent != null) {
      final p = topAccent.position;
      topAccent.position = vm.Vector3(p.x, frameHalfHeight - 0.125, p.z);
    }
    final bottomAccent = _frameNodes['Frame_BottomAccent'];
    if (bottomAccent != null) {
      final p = bottomAccent.position;
      bottomAccent.position = vm.Vector3(p.x, -frameHalfHeight + 0.125, p.z);
    }

    final postScaleY = (frameHalfHeight * 2) / 3.20;
    for (final name in ['Frame_LeftPost', 'Frame_RightPost']) {
      final post = _frameNodes[name];
      if (post == null) continue;
      final scale = post.scale;
      post.scale = vm.Vector3(scale.x, postScaleY, scale.z);
    }

    beads
      ..clear()
      ..addAll(_allBeads.where((bead) => bead.rod < activeRowCount));

    if (notify) notifyListeners();
  }

  void _applyInitial(int value) {
    math.setTotal(value);
    for (final bead in beads) {
      bead.x = KecrekanMath.beadX(bead.index, math.countFor(bead.rod));
      bead.velocity = 0;
      bead.node.position = vm.Vector3(bead.x, bead.y, bead.z);
    }
  }

  void resetTo(int value) {
    _draggedBead = null;
    math.setTotal(value);
    for (final bead in beads) {
      bead.x = KecrekanMath.beadX(bead.index, math.countFor(bead.rod));
      bead.velocity = 0;
      bead.node.position = vm.Vector3(bead.x, bead.y, bead.z);
    }
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
  /// still grab it. The beads themselves are never enlarged. The wider radius helps small fingers land on a bead without requiring precision.
  static double pickRadiusFor(Size size) {
    final shortest = size.isEmpty ? 360.0 : size.shortestSide;
    return (shortest * 0.065).clamp(26.0, 38.0);
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

  /// Begin a physical grab on one bead. Preserve the finger-to-centre offset
  /// so grabbing an edge does not snap the bead under the pointer.
  void beginBeadDrag(KecrekanBead bead, double pointerWorldX) {
    _draggedBead = bead;
    _dragOffset = bead.x - pointerWorldX;
    bead.velocity = 0;
  }

  /// Move only the grabbed bead until it contacts a neighbour. Contact then
  /// pushes the contiguous chain; an empty gap prevents movement propagating.
  int? dragBeadTo(double pointerWorldX) {
    final bead = _draggedBead;
    if (bead == null) return null;
    final oldTotal = total;
    final target = (pointerWorldX + _dragOffset)
        .clamp(KecrekanMath.leftX, KecrekanMath.rightX)
        .toDouble();
    _moveWithContact(bead, target);
    _syncRowCount(bead.rod);
    _writeRodNodes(bead.rod);
    if (total != oldTotal) notifyListeners();
    return math.countFor(bead.rod);
  }

  void endBeadDrag() => _draggedBead = null;

  /// A tap sends the selected bead to the opposite side of the counting
  /// boundary. Neighbours move only if the selected bead physically contacts
  /// them while travelling there.
  int toggleBead(KecrekanBead bead) {
    final threshold = _countingThreshold(bead);
    final destination = threshold + (_isCounted(bead) ? 0.01 : -0.01);
    _moveWithContact(bead, destination);
    _syncRowCount(bead.rod);
    _writeRodNodes(bead.rod);
    notifyListeners();
    return math.countFor(bead.rod);
  }

  void _moveWithContact(KecrekanBead selected, double requestedX) {
    final row = beads.where((bead) => bead.rod == selected.rod).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final selectedIndex = row.indexOf(selected);
    if (selectedIndex < 0) return;

    final oldX = selected.x;
    selected.x = requestedX
        .clamp(KecrekanMath.leftX, KecrekanMath.rightX)
        .toDouble();
    selected.velocity = 0;

    if (selected.x < oldX) {
      // Higher indices are physically to the left (smaller world X).
      for (var i = selectedIndex + 1; i < row.length; i++) {
        final neighbour = row[i];
        final contactLimit = row[i - 1].x - KecrekanMath.spacing;
        if (neighbour.x > contactLimit) {
          neighbour.x = contactLimit;
          neighbour.velocity = 0;
        } else {
          break; // Preserve the empty gap; beads beyond it stay still.
        }
      }
      final overflow = KecrekanMath.leftX - row.last.x;
      if (overflow > 0) {
        for (var i = selectedIndex; i < row.length; i++) {
          row[i].x += overflow;
        }
      }
    } else if (selected.x > oldX) {
      // Lower indices are physically to the right (larger world X).
      for (var i = selectedIndex - 1; i >= 0; i--) {
        final neighbour = row[i];
        final contactLimit = row[i + 1].x + KecrekanMath.spacing;
        if (neighbour.x < contactLimit) {
          neighbour.x = contactLimit;
          neighbour.velocity = 0;
        } else {
          break;
        }
      }
      final overflow = row.first.x - KecrekanMath.rightX;
      if (overflow > 0) {
        for (var i = 0; i <= selectedIndex; i++) {
          row[i].x -= overflow;
        }
      }
    }

    for (final bead in row) {
      bead.x = bead.x
          .clamp(KecrekanMath.leftX, KecrekanMath.rightX)
          .toDouble();
    }
  }

  double _countingThreshold(KecrekanBead bead) {
    // Each bead has two packed resting positions. Their midpoint is its
    // crossing threshold; a fixed world-X threshold would miscount beads
    // because an untouched five-bead group spans across the frame's origin.
    final leftRest = KecrekanMath.leftX +
        (KecrekanMath.beadsPerRod - 1 - bead.index) *
            KecrekanMath.spacing;
    final rightRest = KecrekanMath.rightX -
        bead.index * KecrekanMath.spacing;
    return (leftRest + rightRest) / 2;
  }

  bool _isCounted(KecrekanBead bead) =>
      bead.x < _countingThreshold(bead);

  void _syncRowCount(int rod) {
    final count = beads
        .where((bead) => bead.rod == rod && _isCounted(bead))
        .length;
    math.setCount(rod, count);
  }

  void _writeRodNodes(int rod) {
    for (final bead in beads.where((bead) => bead.rod == rod)) {
      bead.node.position = vm.Vector3(bead.x, bead.y, bead.z);
    }
  }

  /// Physical positions are authoritative. Never spring siblings toward
  /// positions derived from a row count.
  void tick(Duration elapsed, double deltaSeconds) {
    if (!ready) return;
    for (final bead in beads) {
      if (bead.node.position.x != bead.x) {
        bead.node.position = vm.Vector3(bead.x, bead.y, bead.z);
      }
    }
  }

  @override
  void dispose() {
    for (final bead in _allBeads) {
      _beadsByName.remove(bead.node.name);
    }
    _allBeads.clear();
    beads.clear();
    _rowNodes.clear();
    _frameNodes.clear();
    scene.dispose();
    super.dispose();
  }
}
