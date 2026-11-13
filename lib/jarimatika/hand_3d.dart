import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../theme.dart';
import 'jarimatika_math.dart';

/// One hand of the Jarimatika pair, drawn as a locally bundled, skinned 3D
/// model.
///
/// The GLB carries a real skeleton (`index_01`…`pinky_03`, `thumb_01`…`04`),
/// vertex-coloured skin, a normal map and separate nail meshes. Finger state
/// is the extension of each chain: 1 is straight, 0 curls into the palm. The
/// left hand is the same model mirrored, so both hands stay anatomically
/// consistent while the maths stays identical.
class JarimatikaHand extends StatefulWidget {
  const JarimatikaHand({
    super.key,
    required this.fingers,
    required this.label,
    required this.subLabel,
    required this.accent,
    this.mirrored = false,
    this.onToggle,
    this.size = 210,
  });

  static const String assetPath = 'assets/3d/hand/hand.glb';

  final Set<Finger> fingers;
  final String label;
  final String subLabel;
  final Color accent;
  final bool mirrored;
  final ValueChanged<Finger>? onToggle;
  final double size;

  @override
  State<JarimatikaHand> createState() => _JarimatikaHandState();
}

class _JarimatikaHandState extends State<JarimatikaHand>
    with SingleTickerProviderStateMixin {
  final Scene _scene = Scene();
  final Map<String, Node> _bones = {};
  final Map<String, vm.Quaternion> _rest = {};

  Node? _model;
  PerspectiveCamera? _camera;
  bool _ready = false;
  String? _error;

  late final AnimationController _controller;
  List<double> _from = List.filled(kFingerOrder.length, 0);
  List<double> _to = List.filled(kFingerOrder.length, 0);
  List<double> _visual = List.filled(kFingerOrder.length, 0);
  Size _viewSize = Size.zero;

  List<double> _targets(Set<Finger> fingers) => [
    for (final finger in kFingerOrder) fingers.contains(finger) ? 1.0 : 0.0,
  ];

  @override
  void initState() {
    super.initState();
    _to = _targets(widget.fingers);
    _from = List.of(_to);
    _visual = List.of(_to);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    )..addListener(_advance);
    _load();
  }

  @override
  void didUpdateWidget(covariant JarimatikaHand oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _targets(widget.fingers);
    if (listEquals(next, _to)) return;
    _from = List.of(_visual);
    _to = next;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_advance)
      ..dispose();
    if (_model != null) unawaited(releaseScene(JarimatikaHand.assetPath));
    _scene.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await Scene.initializeStaticResources();
      final model = await loadScene(JarimatikaHand.assetPath);
      model.scale = vm.Vector3(widget.mirrored ? -1 : 1, 1, 1);
      _model = model;

      for (final finger in kFingerOrder) {
        for (final name in [
          ...fingerBoneNames(finger),
          fingerTipName(finger),
        ]) {
          final node = model.getChildByName(name);
          if (node == null) continue;
          _bones[name] = node;
          _rest[name] = node.rotation.clone();
        }
      }

      _scene.add(model);
      _scene.environmentIntensity = 0.0;
      _scene.directionalLight = DirectionalLight(
        // Travels down and into the screen, from over the viewer's shoulder.
        direction: vm.Vector3(-0.38, -0.72, -0.62),
        color: vm.Vector3(1.0, 0.97, 0.92),
        intensity: 2.7,
      );
      // A cool rim and a warm fill keep the silhouette readable against the
      // dark ocean card without flattening the form.
      _addPointLight(
        position: vm.Vector3(1.9, 1.5, 2.6),
        color: vm.Vector3(1.0, 0.86, 0.74),
        intensity: 9.0,
      );
      _addPointLight(
        position: vm.Vector3(-2.1, 1.2, -1.8),
        color: vm.Vector3(0.55, 0.78, 1.0),
        intensity: 11.0,
      );

      _camera = PerspectiveCamera(
        position: vm.Vector3(widget.mirrored ? -0.62 : 0.62, 0.80, 4.15),
        target: vm.Vector3(0, 0.76, 0),
        fovRadiansY: 33 * math.pi / 180,
        fovNear: 0.1,
        fovFar: 24,
      );

      _visual = List.of(_to);
      _applyPose();
      if (mounted) setState(() => _ready = true);
    } catch (exception, stack) {
      debugPrint('Jarimatika hand failed to load: $exception\n$stack');
      if (mounted) setState(() => _error = '$exception');
    }
  }

  void _addPointLight({
    required vm.Vector3 position,
    required vm.Vector3 color,
    required double intensity,
  }) {
    final node = Node(name: 'HandFill')
      ..position = position
      ..addComponent(
        PointLightComponent(
          PointLight(color: color, intensity: intensity, range: 9),
        ),
      );
    _scene.add(node);
  }

  void _advance() {
    final t = Curves.easeOutCubic.transform(_controller.value.clamp(0.0, 1.0));
    _visual = [
      for (var i = 0; i < _visual.length; i++)
        _from[i] + (_to[i] - _from[i]) * t,
    ];
    _applyPose();
  }

  void _applyPose() {
    if (_bones.isEmpty) return;
    for (var i = 0; i < kFingerOrder.length; i++) {
      final finger = kFingerOrder[i];
      final angles = poseAngles(finger, _visual[i]);
      final names = fingerBoneNames(finger);
      for (var j = 0; j < names.length && j < angles.length; j++) {
        final node = _bones[names[j]];
        final rest = _rest[names[j]];
        if (node == null || rest == null) continue;
        node.rotation =
            rest * vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), angles[j]);
      }
    }
  }

  void _tapUp(TapUpDetails details) {
    final callback = widget.onToggle;
    final camera = _camera;
    if (callback == null || camera == null || !_ready) return;
    if (_viewSize.isEmpty) return;

    final projected = <Finger, List<Offset>>{};
    for (final finger in kFingerOrder) {
      final points = <Offset>[];
      for (final name in [...fingerBoneNames(finger), fingerTipName(finger)]) {
        final node = _bones[name];
        if (node == null) continue;
        final screen = camera.worldToScreen(
          node.globalTransform.getTranslation(),
          _viewSize,
        );
        if (screen != null) points.add(screen);
      }
      if (points.length < 2) continue;
      // Extend past the last joint to cover the fleshy fingertip.
      final tip = points.last + (points.last - points[points.length - 2]) * 0.9;
      points.add(tip);
      projected[finger] = points;
    }

    final finger = hitTestFinger(
      position: details.localPosition,
      projected: projected,
      maxDistance: fingerHitRadius(widget.size),
    );
    if (finger != null) callback(finger);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.18,
      child: Column(
        children: [
          Text(
            widget.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: OceanColors.foam,
              fontSize: widget.size * 0.055,
              letterSpacing: 0.6,
            ),
          ),
          Expanded(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _viewSize = constraints.biggest;
                  return GestureDetector(
                    onTapUp: _tapUp,
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_camera != null)
                          SceneView(
                            _scene,
                            camera: _camera,
                            autoTick: true,
                            maxFrameRate: 60,
                          )
                        else
                          _HandLoading(
                            accent: widget.accent,
                            error: _error,
                            onRetry: _error == null
                                ? null
                                : () {
                                    setState(() => _error = null);
                                    _load();
                                  },
                          ),
                        if (!_ready && _camera != null)
                          _HandLoading(accent: widget.accent),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Text(
            widget.subLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: widget.accent,
              fontWeight: FontWeight.w700,
              fontSize: widget.size * 0.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _HandLoading extends StatelessWidget {
  const _HandLoading({required this.accent, this.error, this.onRetry});

  final Color accent;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pan_tool_alt_outlined, color: accent, size: 28),
            const SizedBox(height: 6),
            Text(
              'Hand needs a tap',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: OceanColors.foam),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text('Retry', style: TextStyle(color: accent)),
              ),
          ],
        ),
      );
    }
    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(accent),
        ),
      ),
    );
  }
}
