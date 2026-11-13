import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

enum Finger { thumb, indexFinger, middle, ring, pinky }

const List<Finger> kFingerOrder = [
  Finger.thumb,
  Finger.indexFinger,
  Finger.middle,
  Finger.ring,
  Finger.pinky,
];

/// The canonical Jarimatika shapes for one hand.
///
/// Right hand counts ones. 1 index, 2 index+middle, 3 plus ring, 4 plus
/// pinky, 5 thumb, 6 thumb+index, 7 plus middle, 8 plus ring, 9 all five.
/// The left hand is the same shape times ten.
const Map<int, Set<Finger>> kJarimatikaShapes = {
  0: <Finger>{},
  1: {Finger.indexFinger},
  2: {Finger.indexFinger, Finger.middle},
  3: {Finger.indexFinger, Finger.middle, Finger.ring},
  4: {Finger.indexFinger, Finger.middle, Finger.ring, Finger.pinky},
  5: {Finger.thumb},
  6: {Finger.thumb, Finger.indexFinger},
  7: {Finger.thumb, Finger.indexFinger, Finger.middle},
  8: {Finger.thumb, Finger.indexFinger, Finger.middle, Finger.ring},
  9: {
    Finger.thumb,
    Finger.indexFinger,
    Finger.middle,
    Finger.ring,
    Finger.pinky,
  },
};

int? handValue(Set<Finger> fingers) {
  for (final entry in kJarimatikaShapes.entries) {
    if (entry.value.length == fingers.length &&
        entry.value.containsAll(fingers)) {
      return entry.key;
    }
  }
  return null;
}

Set<Finger> fingersFor(int digit) =>
    Set<Finger>.from(kJarimatikaShapes[digit.clamp(0, 9)] ?? const {});

String fingerName(Finger finger) => switch (finger) {
      Finger.thumb => 'Thumb',
      Finger.indexFinger => 'Index',
      Finger.middle => 'Middle',
      Finger.ring => 'Ring',
      Finger.pinky => 'Pinky',
    };

class _FingerGeometry {
  const _FingerGeometry({
    required this.base,
    required this.tip,
    required this.foldedTip,
    required this.control,
    required this.foldedControl,
    required this.width,
  });

  final Offset base;
  final Offset tip;
  final Offset foldedTip;
  final Offset control;
  final Offset foldedControl;
  final double width;

  Offset tipAt(double e) => Offset.lerp(foldedTip, tip, e)!;
  Offset controlAt(double e) => Offset.lerp(foldedControl, control, e)!;
}

const Map<Finger, _FingerGeometry> _geometry = {
  Finger.thumb: _FingerGeometry(
    base: Offset(58, 196),
    tip: Offset(24, 140),
    foldedTip: Offset(86, 206),
    control: Offset(32, 174),
    foldedControl: Offset(48, 210),
    width: 27,
  ),
  Finger.indexFinger: _FingerGeometry(
    base: Offset(78, 146),
    tip: Offset(64, 42),
    foldedTip: Offset(78, 178),
    control: Offset(66, 92),
    foldedControl: Offset(58, 166),
    width: 23,
  ),
  Finger.middle: _FingerGeometry(
    base: Offset(104, 140),
    tip: Offset(103, 22),
    foldedTip: Offset(103, 184),
    control: Offset(103, 78),
    foldedControl: Offset(94, 168),
    width: 25,
  ),
  Finger.ring: _FingerGeometry(
    base: Offset(130, 144),
    tip: Offset(145, 34),
    foldedTip: Offset(128, 184),
    control: Offset(139, 86),
    foldedControl: Offset(118, 170),
    width: 23,
  ),
  Finger.pinky: _FingerGeometry(
    base: Offset(153, 154),
    tip: Offset(178, 66),
    foldedTip: Offset(150, 190),
    control: Offset(168, 108),
    foldedControl: Offset(142, 180),
    width: 19,
  ),
};

/// One cartoon hand that curls and uncurls its fingers.
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
  late final AnimationController _controller;
  List<double> _from = List.filled(5, 0);
  List<double> _to = List.filled(5, 0);
  List<double> _visual = List.filled(5, 0);

  List<double> _targets(Set<Finger> fingers) => [
        for (final finger in kFingerOrder)
          fingers.contains(finger) ? 1.0 : 0.0,
      ];

  @override
  void initState() {
    super.initState();
    _to = _targets(widget.fingers);
    _from = List.of(_to);
    _visual = List.of(_to);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1,
    );
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
    _controller.dispose();
    super.dispose();
  }

  void _tap(TapUpDetails details) {
    final callback = widget.onToggle;
    if (callback == null) return;
    final scale = widget.size / 220;
    var x = details.localPosition.dx / scale;
    final y = details.localPosition.dy / scale;
    if (widget.mirrored) x = 220 - x;
    Finger? best;
    var bestDistance = double.infinity;
    for (final finger in kFingerOrder) {
      final g = _geometry[finger]!;
      final extension = _visual[kFingerOrder.indexOf(finger)];
      final tip = g.tipAt(extension);
      final distance = _distanceToSegment(
        Offset(x, y),
        g.base,
        tip,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        best = finger;
      }
    }
    if (best != null && bestDistance < 34) callback(best);
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.18,
      child: GestureDetector(
        onTapUp: _tap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeOutBack.transform(
              _controller.value.clamp(0.0, 1.0),
            );
            _visual = [
              for (var i = 0; i < 5; i++)
                _from[i] + (_to[i] - _from[i]) * t.clamp(0.0, 1.0),
            ];
            return Column(
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
                  child: Transform.scale(
                    scaleX: widget.mirrored ? -1 : 1,
                    child: CustomPaint(
                      size: Size(widget.size, widget.size * 1.02),
                      painter: _HandPainter(
                        extension: _visual,
                        accent: widget.accent,
                        active: widget.fingers.isNotEmpty,
                      ),
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
            );
          },
        ),
      ),
    );
  }
}

class _HandPainter extends CustomPainter {
  _HandPainter({
    required this.extension,
    required this.accent,
    required this.active,
  });

  final List<double> extension;
  final Color accent;
  final bool active;

  static const _skin = Color(0xFFF3BE93);
  static const _skinLight = Color(0xFFFFDDBC);
  static const _skinShadow = Color(0xFFD6946B);
  static const _outline = Color(0xFF6D422E);
  static const _nail = Color(0xFFFFE9D9);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 220;
    canvas.save();
    canvas.scale(scale);

    _cuff(canvas);
    _palm(canvas);
    _fingers(canvas);
    _creases(canvas);
    _glow(canvas);

    canvas.restore();
  }

  void _cuff(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(64, 224, 92, 42),
      const Radius.circular(16),
    );
    canvas.drawRRect(rect, Paint()..color = accent.withValues(alpha: 0.9));
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _outline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(64, 236, 92, 8),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );
  }

  void _palm(Canvas canvas) {
    final path = Path()
      ..moveTo(52, 152)
      ..quadraticBezierTo(40, 184, 52, 222)
      ..quadraticBezierTo(68, 246, 110, 244)
      ..quadraticBezierTo(154, 246, 170, 220)
      ..quadraticBezierTo(182, 184, 168, 150)
      ..quadraticBezierTo(150, 126, 110, 126)
      ..quadraticBezierTo(70, 126, 52, 152)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_skinLight, _skin, _skinShadow],
          stops: [0, 0.55, 1],
        ).createShader(const Rect.fromLTWH(40, 120, 150, 130)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..color = _outline,
    );
    // Soft shine on the palm.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(90, 168), width: 46, height: 60),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
    // A heart of light when the hand is making a shape.
    if (active) {
      canvas.drawCircle(
        const Offset(110, 178),
        30,
        Paint()..color = accent.withValues(alpha: 0.12),
      );
    }
  }

  void _fingers(Canvas canvas) {
    for (var i = 0; i < kFingerOrder.length; i++) {
      final finger = kFingerOrder[i];
      final g = _geometry[finger]!;
      final e = extension[i];
      final tip = g.tipAt(e);
      final control = g.controlAt(e);
      final path = Path()
        ..moveTo(g.base.dx, g.base.dy)
        ..quadraticBezierTo(control.dx, control.dy, tip.dx, tip.dy);

      // Shadow side.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = g.width + 4
          ..strokeCap = StrokeCap.round
          ..color = _outline,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = g.width
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _skinLight,
              _skin,
              _skin.withValues(alpha: 0.95),
            ],
          ).createShader(Rect.fromPoints(g.base, tip)),
      );
      // Inner highlight.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = g.width * 0.22
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.3),
      );

      // Nail on extended fingers.
      if (e > 0.65) {
        final dir = (tip - control).normalized;
        final nailCentre = tip - dir * (g.width * 0.28);
        canvas.save();
        canvas.translate(nailCentre.dx, nailCentre.dy);
        canvas.rotate(math.atan2(dir.dy, dir.dx) + math.pi / 2);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: g.width * 0.52,
            height: g.width * 0.62,
          ),
          Paint()..color = _nail.withValues(alpha: 0.85),
        );
        canvas.restore();
      }
    }
  }

  void _creases(Canvas canvas) {
    final crease = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = _outline.withValues(alpha: 0.28);
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(110, 194), width: 64, height: 34),
      0.2,
      math.pi - 0.4,
      false,
      crease,
    );
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(108, 208), width: 40, height: 20),
      0.1,
      math.pi - 0.2,
      false,
      crease,
    );
    canvas.drawLine(const Offset(82, 156), const Offset(74, 178), crease);
    canvas.drawLine(const Offset(138, 156), const Offset(146, 178), crease);
  }

  void _glow(Canvas canvas) {
    if (!active) return;
    canvas.drawCircle(
      const Offset(110, 150),
      92,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant _HandPainter oldDelegate) =>
      oldDelegate.extension != extension ||
      oldDelegate.accent != accent ||
      oldDelegate.active != active;
}

extension on Offset {
  Offset get normalized {
    final length = distance;
    if (length == 0) return this;
    return this / length;
  }
}
