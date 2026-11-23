import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Tala, the baby sea turtle. She bobs, paddles, blinks and cheers.
class TurtleCompanion extends StatefulWidget {
  const TurtleCompanion({
    super.key,
    this.size = 150,
    this.cheering = false,
    this.onTap,
    this.flip = false,
  });

  final double size;
  final bool cheering;
  final VoidCallback? onTap;
  final bool flip;

  @override
  State<TurtleCompanion> createState() => _TurtleCompanionState();
}

class _TurtleCompanionState extends State<TurtleCompanion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // A quick blink once per cycle.
          final blink = t > 0.60 && t < 0.655
              ? math.sin((t - 0.60) / 0.055 * math.pi)
              : 0.0;
          return Transform.scale(
            scaleX: widget.flip ? -1 : 1,
            child: CustomPaint(
              size: Size(widget.size, widget.size * 0.9),
              painter: _TurtlePainter(
                t: t,
                blink: blink,
                cheering: widget.cheering,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TurtlePainter extends CustomPainter {
  _TurtlePainter({
    required this.t,
    required this.blink,
    required this.cheering,
  });

  final double t;
  final double blink;
  final bool cheering;

  static const _outline = Color(0xFF0A4C4C);
  static const _skin = Color(0xFF86E3B6);
  static const _skinLight = Color(0xFFC8FBE1);
  static const _shellDark = Color(0xFF1A7F7B);
  static const _shellMid = Color(0xFF2FB6A4);
  static const _shellLight = Color(0xFF8BEBD1);
  static const _coral = Color(0xFFFF9279);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200.0;
    canvas.save();
    canvas.scale(scale);

    final wave = math.sin(t * math.pi * 2);
    final bob = wave * 3.2;
    final cheer = cheering ? math.sin(t * math.pi * 8) * 4 : 0.0;
    canvas.translate(0, bob + cheer);

    _shadow(canvas, 100, 168 - bob * 0.4);
    _backFlipper(canvas, left: true, wave: wave);
    _backFlipper(canvas, left: false, wave: wave);
    _frontFlipper(canvas, left: true, wave: wave);
    _frontFlipper(canvas, left: false, wave: wave);
    _body(canvas);
    _head(canvas);
    if (cheering || t < 0.25) _bubbles(canvas);
    canvas.restore();
  }

  void _shadow(Canvas canvas, double x, double y) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: 120, height: 18),
      Paint()..color = const Color(0xFF00151D).withValues(alpha: 0.22),
    );
  }

  void _ellipse(
    Canvas canvas,
    Offset c,
    double rx,
    double ry, {
    required Paint fill,
    Paint? stroke,
  }) {
    final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    canvas.drawOval(rect, fill);
    if (stroke != null) canvas.drawOval(rect, stroke);
  }

  void _body(Canvas canvas) {
    final rim = Paint()..color = _shellDark;
    _ellipse(canvas, const Offset(98, 108), 55, 40, fill: rim);

    final shellRect = Rect.fromCenter(
      center: const Offset(98, 104),
      width: 104,
      height: 70,
    );
    canvas.drawOval(
      shellRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_shellLight, _shellMid, _shellDark],
          stops: [0, 0.55, 1],
        ).createShader(shellRect),
    );
    canvas.drawOval(
      shellRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..color = _outline,
    );

    // Scutes.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = _outline.withValues(alpha: 0.34);
    final centre = const Offset(98, 104);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + math.pi / 6;
      canvas.drawLine(
        centre,
        centre + Offset(math.cos(a) * 45, math.sin(a) * 28),
        line,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: centre, width: 44, height: 30),
      line,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: centre,
          width: 70.0 + i * 16,
          height: 46.0 + i * 10,
        ),
        0.2,
        math.pi * 1.35,
        false,
        line,
      );
    }
    // Sunlit sliver on the shell.
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(94, 96), width: 78, height: 46),
      math.pi * 1.08,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.32),
    );
  }

  void _head(Canvas canvas) {
    final neck = Path()
      ..moveTo(124, 86)
      ..quadraticBezierTo(142, 74, 148, 70)
      ..lineTo(158, 96)
      ..quadraticBezierTo(138, 104, 124, 112)
      ..close();
    canvas.drawPath(neck, Paint()..color = _skin);
    canvas.drawPath(
      neck,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _outline,
    );

    final headRect = Rect.fromCenter(
      center: const Offset(154, 73),
      width: 60,
      height: 55,
    );
    canvas.drawOval(
      headRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.5),
          colors: [_skinLight, _skin],
        ).createShader(headRect),
    );
    canvas.drawOval(
      headRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..color = _outline,
    );

    // Cheeks.
    final blush = Paint()..color = _coral.withValues(alpha: 0.45);
    canvas.drawCircle(const Offset(136, 84), 6.5, blush);
    canvas.drawCircle(const Offset(176, 82), 6.5, blush);

    _eye(canvas, const Offset(144, 64));
    _eye(canvas, const Offset(168, 63));

    // Smile.
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(157, 84), width: 18, height: 13),
      0.18,
      math.pi - 0.36,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = _outline,
    );

    // Tiny nostril dots.
    final dot = Paint()..color = _outline.withValues(alpha: 0.5);
    canvas.drawCircle(const Offset(163, 77), 1.2, dot);
    canvas.drawCircle(const Offset(169, 77), 1.2, dot);
  }

  void _eye(Canvas canvas, Offset centre) {
    if (blink > 0.7) {
      canvas.drawLine(
        centre + const Offset(-7, 0),
        centre + const Offset(7, 0),
        Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = _outline,
      );
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: centre,
        width: 17,
        height: 19 * (1 - blink * 0.85),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: centre + const Offset(0, 1),
        width: 17,
        height: 19 * (1 - blink * 0.85),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _outline,
    );
    canvas.drawCircle(
      centre + const Offset(1.5, 1.5),
      5.6 * (1 - blink * 0.7),
      Paint()..color = _outline,
    );
    canvas.drawCircle(
      centre + const Offset(-1, -1.5),
      2.1 * (1 - blink * 0.6),
      Paint()..color = Colors.white,
    );
  }

  void _frontFlipper(
    Canvas canvas, {
    required bool left,
    required double wave,
  }) {
    final angle = (left ? -1 : 1) * (0.32 + wave * 0.16);
    final pivot = left ? const Offset(64, 104) : const Offset(132, 108);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, -8)
      ..quadraticBezierTo(left ? -34 : 34, -2, left ? -50 : 50, 18)
      ..quadraticBezierTo(left ? -28 : 28, 26, 0, 12)
      ..close();
    canvas.drawPath(path, Paint()..color = _skin);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _outline,
    );
    canvas.restore();
  }

  void _backFlipper(Canvas canvas, {required bool left, required double wave}) {
    final angle = (left ? 1 : -1) * (0.2 + wave * 0.12);
    final pivot = left ? const Offset(64, 132) : const Offset(132, 134);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(left ? -24 : 24, 8, left ? -34 : 34, 26)
      ..quadraticBezierTo(left ? -14 : 14, 26, 0, 10)
      ..close();
    canvas.drawPath(path, Paint()..color = _shellMid);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _outline,
    );
    canvas.restore();
  }

  void _bubbles(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.45);
    for (var i = 0; i < 3; i++) {
      final y = 46.0 - i * 18 - (t * 10) % 10;
      canvas.drawCircle(Offset(188 + i * 6, y), 3.4 + i * 1.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TurtlePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.blink != blink ||
      oldDelegate.cheering != cheering;
}

class TurtleTalk extends StatelessWidget {
  const TurtleTalk({
    super.key,
    required this.message,
    this.onTap,
    this.size = 108,
    this.cheering = false,
    this.flip = false,
  });

  final String message;
  final VoidCallback? onTap;
  final double size;
  final bool cheering;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TurtleCompanion(
          size: size,
          cheering: cheering,
          onTap: onTap,
          flip: flip,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: SpeechBubble(message: message, tailOnLeft: true, onTap: onTap),
        ),
      ],
    );
  }
}

class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.message,
    this.tailOnLeft = false,
    this.onTap,
  });

  final String message;
  final bool tailOnLeft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
        decoration: BoxDecoration(
          color: OceanColors.shell,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(tailOnLeft ? 6 : 22),
            topRight: Radius.circular(tailOnLeft ? 22 : 6),
            bottomLeft: const Radius.circular(22),
            bottomRight: const Radius.circular(22),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.65),
            width: 2,
          ),
          boxShadow: oceanShadow(blur: 16, y: 6),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: OceanColors.ink,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}
