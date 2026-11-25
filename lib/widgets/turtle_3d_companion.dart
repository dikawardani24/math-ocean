import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../turtle/turtle_animation.dart';
import '../turtle/turtle_behavior.dart';

/// Command handle for a [Turtle3DCompanion].
///
/// The rendering widget owns the ticker and the scene; the controller owns the
/// behaviour state. Gameplay (Coral Cove feeding) uses this small surface
/// without knowing anything about cameras, clips or transforms.
class Turtle3DCompanionController {
  Turtle3DCompanionController({TurtleBehaviorController? behavior})
    : behavior = behavior ?? TurtleBehaviorController();

  final TurtleBehaviorController behavior;

  _Turtle3DCompanionState? _state;

  bool get isAttached => _state != null;

  /// Point Tala at a global drag/drop position. Returns false when she is
  /// already eating or the widget is not mounted.
  bool feedAtGlobal(Offset globalPosition) {
    final point = _state?._normalizedFromGlobal(globalPosition);
    if (point == null) return false;
    return behavior.requestFeed(point);
  }

  /// The nearest reachable turtle-centre position for a global point.
  ///
  /// Feeding uses this so the seagrass token sits where Tala can actually
  /// reach instead of in reserved UI space.
  Offset? clampGlobalToSwimArea(Offset globalPosition) {
    final state = _state;
    if (state == null) return null;
    final point = state._normalizedFromGlobal(globalPosition);
    if (point == null) return null;
    return state._centerGlobalForNormalized(point);
  }

  /// Approximate world position of Tala's mouth, for coordinating food.
  Offset? get mouthGlobalPosition => _state?._mouthGlobalPosition();

  bool reactToPlayer({Offset? globalPosition}) {
    final from = globalPosition == null
        ? null
        : _state?._normalizedFromGlobal(globalPosition);
    return behavior.reactToPlayer(from: from);
  }

  bool celebrate() => behavior.celebrate();

  void finishFeeding() => behavior.finishFeeding();

  void setAutonomy(TurtleAutonomy autonomy) => behavior.setAutonomy(autonomy);

  void dispose() {
    _state = null;
  }

  void _attach(_Turtle3DCompanionState state) {
    _state = state;
  }

  void _detach(_Turtle3DCompanionState state) {
    if (identical(_state, state)) _state = null;
  }
}

/// Behaviour-driven 3D baby green sea turtle.
///
/// The GLB supplies Tala's appearance. Movement, turning, depth, resting,
/// feeding and reactions come from [TurtleBehaviorController]; the widget maps
/// the resulting pose onto the real scene node every frame, so the mesh turns
/// and swims through the water instead of a rendered image sliding on top of
/// the page.
class Turtle3DCompanion extends StatefulWidget {
  const Turtle3DCompanion({
    super.key,
    this.size = 180,
    this.area,
    this.expand = false,
    this.swimPadding = EdgeInsets.zero,
    this.autonomy = TurtleAutonomy.free,
    this.controller,
    this.onTap,
    this.onFoodReached,
    this.celebrateOnMount = false,
  });

  /// Nominal on-screen height of the turtle in logical pixels at its resting
  /// depth. The swim [area] should be larger than this so she has room to
  /// move.
  final double size;

  /// Fixed swim area. When null the widget uses a box around [size] unless
  /// [expand] is true.
  final Size? area;

  /// Fill the parent's bounded constraints with the swim area.
  final bool expand;

  /// Space reserved for surrounding UI inside [area].
  final EdgeInsets swimPadding;

  final TurtleAutonomy autonomy;

  /// Optional external command handle. The widget creates its own controller
  /// when this is null.
  final Turtle3DCompanionController? controller;

  final VoidCallback? onTap;

  /// Called once Tala reaches food requested through the controller.
  final VoidCallback? onFoodReached;

  /// Start with a short celebration (used on the discovery screen).
  final bool celebrateOnMount;

  @override
  State<Turtle3DCompanion> createState() => _Turtle3DCompanionState();
}

/// Geometry of the imported mesh, in the GLB's own coordinates.
///
/// The model is centred on the origin, `+Y` is up and the head points towards
/// `+Z` (verified against the asset). These constants are only used to frame
/// the camera, size the turtle on screen and locate the mouth.
class _TurtleModel {
  static const double height = .7055;

  /// Front of the mouth, in model space.
  static final vm.Vector3 mouth = vm.Vector3(0, .10, .47);
}

/// Screen-to-world frame for one laid-out widget.
class _TurtleFraming {
  const _TurtleFraming({
    required this.area,
    required this.worldScale,
    required this.centerX,
    required this.halfX,
    required this.centerY,
    required this.halfY,
    required this.depthHalf,
  });

  final Size area;

  /// Uniform scale applied to the imported mesh.
  final double worldScale;

  /// World-space centre of the reachable swim plane at `z == 0`.
  final double centerX;
  final double centerY;

  /// Half extents of the reachable swim plane in world units.
  final double halfX;
  final double halfY;

  /// How far, in world units, Tala may come towards or away from the camera.
  final double depthHalf;
}

class _Turtle3DCompanionState extends State<Turtle3DCompanion>
    with SingleTickerProviderStateMixin {
  static const double _stepSeconds = 1 / 30;
  static const double _fovY = 34 * math.pi / 180;
  static final vm.Vector3 _cameraPosition = vm.Vector3(-0.55, 1.05, -4.05);
  static final vm.Vector3 _cameraTarget = vm.Vector3(0, .20, 0);
  static const double _depthHalfWorld = .30;

  final GlobalKey _areaKey = GlobalKey();
  final SceneNodeController _nodeController = SceneNodeController();

  late final Turtle3DCompanionController _controller;
  late final Ticker _ticker;
  late final PerspectiveCamera _camera;

  late TurtlePose _pose;

  _TurtleFraming? _framing;
  Size? _lastLayoutArea;
  EdgeInsets? _lastSwimPadding;

  double _lastTickSeconds = 0;
  bool _hasTick = false;
  double _accumulator = 0;

  Set<String> _availableClips = const {};
  TurtleAnimationCue _cue = const TurtleAnimationCue(clip: null);
  int _cueSignature = 0;
  bool _disposed = false;

  /// Height of the widget when the caller does not provide an area.
  Size get _defaultArea => Size(widget.size * 1.7, widget.size * 1.3);

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? Turtle3DCompanionController();
    _controller._attach(this);
    _controller.setAutonomy(widget.autonomy);

    _camera = PerspectiveCamera(
      // In front of Tala and slightly above: the head points towards +Z, so
      // this is the only side where the child sees her face. The small X
      // offset gives a three-quarter view that reads as volume rather than a
      // flat, symmetrical cut-out.
      position: _cameraPosition.clone(),
      target: _cameraTarget.clone(),
      fovRadiansY: _fovY,
      fovNear: .05,
      fovFar: 30,
    );

    _pose = _controller.behavior.pose;
    _applyCue(_pose);
    if (widget.celebrateOnMount) {
      _controller.behavior.celebrate();
      _pose = _controller.behavior.pose;
    }
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(Turtle3DCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, oldWidget.controller)) {
      _controller._detach(this);
      _controller = widget.controller ?? Turtle3DCompanionController();
      _controller._attach(this);
      _applyCue(_controller.behavior.pose);
    }
    if (widget.autonomy != oldWidget.autonomy) {
      _controller.setAutonomy(widget.autonomy);
    }
    if (widget.size != oldWidget.size) {
      _lastLayoutArea = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    _controller._detach(this);
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_disposed) return;
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (_hasTick) {
      final delta = (seconds - _lastTickSeconds).clamp(0.0, .1);
      _accumulator += delta;
      var steps = 0;
      while (_accumulator >= _stepSeconds && steps < 4) {
        _controller.behavior.update(_stepSeconds);
        _accumulator -= _stepSeconds;
        steps++;
      }
    }
    _hasTick = true;
    _lastTickSeconds = seconds;

    _pose = _controller.behavior.pose;
    _applyPoseToNode(_pose);

    if (_controller.behavior.takeFeedArrived()) {
      final onFoodReached = widget.onFoodReached;
      if (onFoodReached == null) {
        _controller.finishFeeding();
      } else {
        onFoodReached();
      }
    }

    _syncCue(_pose);
  }

  bool _applyCue(TurtlePose pose) {
    final cue = turtleAnimationCueFor(pose.activity, pose.speedRatio);
    final changed = cue.signature != _cueSignature;
    _cue = cue;
    _cueSignature = cue.signature;
    return changed;
  }

  void _syncCue(TurtlePose pose) {
    final changed = _applyCue(pose);
    if (!_disposed && changed && _availableClips.isNotEmpty) {
      setState(() {});
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reactToPlayer(globalPosition: details.globalPosition);
    widget.onTap?.call();
  }

  String? _resolveClip(String? name) {
    if (name == null) return null;
    return _availableClips.contains(name) ? name : null;
  }

  List<SceneAnimationSpec> get _animationSpecs {
    final clip = _resolveClip(_cue.clip);
    if (clip == null) return const [];
    return [SceneAnimationSpec(clip, loop: _cue.loop, speed: _cue.speed)];
  }

  void _handleModelLoaded(Node root) {
    final clips = root.parsedAnimations.map((clip) => clip.name).toSet();
    debugPrint(
      'Tala GLB animations: '
      '${clips.isEmpty ? 'none; using procedural body motion' : clips.join(', ')}',
    );
    if (!mounted) return;
    _applyCue(_pose);
    setState(() {
      _availableClips = clips;
    });
  }

  // ── 3D pose ───────────────────────────────────────────────────────────────

  void _applyPoseToNode(TurtlePose pose) {
    final framing = _framing;
    final node = _nodeController.node;
    if (framing == null || node == null) return;
    node.localTransform = _poseMatrix(pose, framing);
  }

  /// `translate * yaw * pitch * roll * scale`.
  ///
  /// vector_math post-multiplies, so this applies scale first, then the body
  /// rotations, then the world translation — the same order used when the
  /// mouth is projected back to the screen.
  vm.Matrix4 _poseMatrix(TurtlePose pose, _TurtleFraming framing) {
    final x = framing.centerX + (pose.position.dx - .5) * 2 * framing.halfX;
    final y =
        framing.centerY +
        (.5 - pose.position.dy) * 2 * framing.halfY +
        pose.bob * _TurtleModel.height * framing.worldScale +
        pose.paddle * .012;
    final z = pose.depth * framing.depthHalf;
    final scale = framing.worldScale * pose.scale;

    return vm.Matrix4.identity()
      ..translateByDouble(x, y, z, 1)
      ..rotateY(pose.yaw)
      ..rotateX(-pose.pitch)
      ..rotateZ(pose.roll)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  /// Builds the projection frame from the camera and the laid-out area.
  ///
  /// The turtle's nominal height is [Turtle3DCompanion.size] on the `z == 0`
  /// plane. The reachable span is inset by most of the body so the head and
  /// flippers do not leave the view when she turns.
  _TurtleFraming _framingFor(Size area) {
    final padding = widget.swimPadding;
    final leftEdge = padding.left;
    final topEdge = padding.top;
    final rightEdge = math.max(leftEdge + 1, area.width - padding.right);
    final bottomEdge = math.max(topEdge + 1, area.height - padding.bottom);
    final contentWidth = rightEdge - leftEdge;
    final contentHeight = bottomEdge - topEdge;

    final halfXScreen = math.max(0.0, contentWidth / 2 - widget.size * .60);
    final halfYScreen = math.max(0.0, contentHeight / 2 - widget.size * .58);

    final center = Offset(
      (leftEdge + rightEdge) / 2,
      (topEdge + bottomEdge) / 2,
    );
    final left = _worldOnRestingPlane(
      Offset(center.dx - halfXScreen, center.dy),
      area,
    );
    final right = _worldOnRestingPlane(
      Offset(center.dx + halfXScreen, center.dy),
      area,
    );
    final top = _worldOnRestingPlane(
      Offset(center.dx, center.dy - halfYScreen),
      area,
    );
    final bottom = _worldOnRestingPlane(
      Offset(center.dx, center.dy + halfYScreen),
      area,
    );

    var centerX = 0.0;
    var halfX = .02;
    var centerY = 0.0;
    var halfY = .02;
    if (left != null && right != null) {
      centerX = (left.x + right.x) / 2;
      halfX = math.max(.02, (right.x - left.x) / 2);
    }
    if (top != null && bottom != null) {
      centerY = (top.y + bottom.y) / 2;
      halfY = math.max(.02, (top.y - bottom.y) / 2);
    }

    final forward = (_camera.target - _camera.position)..normalize();
    final centerWorld = vm.Vector3(centerX, centerY, 0);
    final distance = math.max(
      .5,
      (centerWorld - _camera.position).dot(forward),
    );
    final visibleHeight = 2 * distance * math.tan(_fovY / 2);
    final pxPerWorld = area.height / visibleHeight;
    final worldScale = widget.size / (pxPerWorld * _TurtleModel.height);

    return _TurtleFraming(
      area: area,
      worldScale: worldScale,
      centerX: centerX,
      halfX: halfX,
      centerY: centerY,
      halfY: halfY,
      depthHalf: _depthHalfWorld,
    );
  }

  vm.Vector3? _worldOnRestingPlane(Offset screen, Size area) {
    final ray = _camera.screenPointToRay(screen, area);
    final direction = ray.direction;
    if (direction.z.abs() < 1e-6) return null;
    final t = -ray.origin.z / direction.z;
    if (t <= 0) return null;
    return ray.at(t);
  }

  // ── Widget ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = _resolveArea(constraints);
        if (_lastLayoutArea != area || _lastSwimPadding != widget.swimPadding) {
          _lastLayoutArea = area;
          _lastSwimPadding = widget.swimPadding;
          _framing = _framingFor(area);
          _applyPoseToNode(_pose);
        }

        return SizedBox(
          key: _areaKey,
          width: area.width,
          height: area.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _handleTapUp,
            child: SceneView.declarative(
              camera: _camera,
              environmentIntensity: 1.15,
              maxFrameRate: 30,
              // The mesh itself moves and turns every frame, so the scene must
              // render every frame. 30 fps keeps it friendly to low-end phones.
              autoTick: true,
              children: [
                SceneModel(
                  'assets/3d/characters/tala_sea_turtle.glb',
                  key: const ValueKey('tala-sea-turtle-model'),
                  controller: _nodeController,
                  animations: _animationSpecs,
                  onLoaded: _handleModelLoaded,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Size _resolveArea(BoxConstraints constraints) {
    final explicit = widget.area;
    if (explicit != null) return explicit;
    if (widget.expand &&
        constraints.hasBoundedWidth &&
        constraints.hasBoundedHeight) {
      return constraints.biggest;
    }
    return _defaultArea;
  }

  // ── Global-to-local mapping used by feeding ───────────────────────────────

  RenderBox? get _box =>
      _areaKey.currentContext?.findRenderObject() as RenderBox?;

  Offset? _normalizedFromGlobal(Offset globalPosition) {
    final box = _box;
    final framing = _framing;
    if (box == null || framing == null) return null;
    final local = box.globalToLocal(globalPosition);
    final world = _worldOnRestingPlane(local, framing.area);
    if (world == null) return null;
    return Offset(
      (.5 + (world.x - framing.centerX) / (2 * framing.halfX))
          .clamp(0.0, 1.0)
          .toDouble(),
      (.5 - (world.y - framing.centerY) / (2 * framing.halfY))
          .clamp(0.0, 1.0)
          .toDouble(),
    );
  }

  Offset? _centerGlobalForNormalized(Offset normalized) {
    final box = _box;
    final framing = _framing;
    if (box == null || framing == null) return null;
    final world = vm.Vector3(
      framing.centerX + (normalized.dx - .5) * 2 * framing.halfX,
      framing.centerY + (.5 - normalized.dy) * 2 * framing.halfY,
      0,
    );
    final screen = _camera.worldToScreen(world, framing.area);
    if (screen == null) return null;
    return box.localToGlobal(screen);
  }

  Offset? _mouthGlobalPosition() {
    final box = _box;
    final framing = _framing;
    if (box == null || framing == null) return null;
    final matrix = _poseMatrix(_pose, framing);
    final mouthWorld = matrix.transform3(_TurtleModel.mouth);
    final screen = _camera.worldToScreen(mouthWorld, framing.area);
    if (screen == null) return null;
    return box.localToGlobal(screen);
  }
}
