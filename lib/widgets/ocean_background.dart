import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class OceanBackground extends StatefulWidget {
  const OceanBackground({
    super.key,
    this.child,
    this.intensity = 1,
    this.showSand = true,
    this.showFish = true,
  });

  final Widget? child;
  final double intensity;
  final bool showSand;
  final bool showFish;

  @override
  State<OceanBackground> createState() => _OceanBackgroundState();
}

class _OceanBackgroundState extends State<OceanBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Bubble> _bubbles = [];
  final List<_Fish> _fish = [];

  @override
  void initState() {
    super.initState();
    final random = math.Random(71);
    for (var i = 0; i < 34; i++) {
      _bubbles.add(
        _Bubble(
          x: random.nextDouble(),
          phase: random.nextDouble(),
          size: 1.6 + random.nextDouble() * 7,
          speed: 0.35 + random.nextDouble() * 0.8,
          drift: (random.nextDouble() - 0.5) * 0.05,
          opacity: 0.12 + random.nextDouble() * 0.3,
        ),
      );
    }
    for (var i = 0; i < 5; i++) {
      _fish.add(
        _Fish(
          y: 0.18 + random.nextDouble() * 0.55,
          size: 5 + random.nextDouble() * 7,
          speed: 0.014 + random.nextDouble() * 0.024,
          phase: random.nextDouble(),
          flip: random.nextBool(),
        ),
      );
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _OceanPainter(
            t: _controller.value,
            bubbles: _bubbles,
            fish: _fish,
            intensity: widget.intensity,
            showSand: widget.showSand,
            showFish: widget.showFish,
          ),
          child: child,
        ),
        child: widget.child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _Bubble {
  const _Bubble({
    required this.x,
    required this.phase,
    required this.size,
    required this.speed,
    required this.drift,
    required this.opacity,
  });
  final double x;
  final double phase;
  final double size;
  final double speed;
  final double drift;
  final double opacity;
}

class _Fish {
  const _Fish({
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.flip,
  });
  final double y;
  final double size;
  final double speed;
  final double phase;
  final bool flip;
}

class _OceanPainter extends CustomPainter {
  _OceanPainter({
    required this.t,
    required this.bubbles,
    required this.fish,
    required this.intensity,
    required this.showSand,
    required this.showFish,
  });

  final double t;
  final List<_Bubble> bubbles;
  final List<_Fish> fish;
  final double intensity;
  final bool showSand;
  final bool showFish;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF042F42),
            Color(0xFF075263),
            Color(0xFF0A7482),
            Color(0xFF032836),
          ],
          stops: [0, 0.32, 0.66, 1],
        ).createShader(rect),
    );

    // Sunlight pooling at the surface.
    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.1, -1.0),
        radius: 1.15,
        colors: [
          OceanColors.mint.withValues(alpha: 0.34 * intensity),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glow);

    _paintRays(canvas, size);
    _paintFarReef(canvas, size);
    if (showFish) _paintFish(canvas, size);
    _paintBubbles(canvas, size);
    if (showSand) _paintSand(canvas, size);
  }

  void _paintRays(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < 5; i++) {
      final sway = math.sin((t * math.pi * 2) + i * 1.7) * size.width * 0.035;
      final topX = size.width * (0.12 + i * 0.2) + sway;
      final width = size.width * (0.06 + (i % 3) * 0.025);
      final path = Path()
        ..moveTo(topX - width, -20)
        ..lineTo(topX + width, -20)
        ..lineTo(topX + width * 3.4 + size.width * 0.08, size.height * 0.92)
        ..lineTo(topX - width * 1.2 + size.width * 0.05, size.height * 0.92)
        ..close();
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          OceanColors.foam.withValues(alpha: 0.10 * intensity),
          OceanColors.aqua.withValues(alpha: 0.015 * intensity),
        ],
      ).createShader(rectOf(path));
      canvas.drawPath(path, paint);
    }
  }

  Rect rectOf(Path path) => path.getBounds();

  void _paintFarReef(Canvas canvas, Size size) {
    final base = size.height * 0.9;
    final paint = Paint()
      ..color = const Color(0xFF06303C).withValues(alpha: 0.55);
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, base);
    for (var i = 0; i <= 8; i++) {
      final x = size.width * i / 8;
      final y =
          base - (i.isEven ? 20 : 54) - math.sin(i * 1.3 + t * math.pi * 2) * 8;
      path.quadraticBezierTo(x - size.width / 16, y, x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);

    // Two soft coral fans in the distance.
    for (final side in [0.04, 0.93]) {
      final cx = size.width * side;
      final fan = Paint()
        ..color = const Color(0xFF0A4653).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      for (var i = -2; i <= 2; i++) {
        final p = Path()
          ..moveTo(cx, base + 12)
          ..quadraticBezierTo(
            cx + i * 16,
            base - 30,
            cx + i * 30,
            base - 68 - (2 - i.abs()) * 16,
          );
        canvas.drawPath(p, fan);
      }
    }
  }

  void _paintFish(Canvas canvas, Size size) {
    for (final f in fish) {
      final span = 1.4;
      final progress = ((t * f.speed * 40) + f.phase) % span;
      final normalized = progress / span;
      final x = (f.flip ? 1 - normalized : normalized) * (size.width + 60) - 30;
      final y = size.height * f.y + math.sin(t * math.pi * 4 + f.phase * 9) * 6;
      canvas.save();
      canvas.translate(x, y);
      if (f.flip) canvas.scale(-1, 1);
      final body = Paint()..color = Colors.white.withValues(alpha: 0.14);
      final s = f.size;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 2.4, height: s),
        body,
      );
      final tail = Path()
        ..moveTo(-s * 1.1, 0)
        ..lineTo(-s * 1.9, -s * 0.7)
        ..lineTo(-s * 1.9, s * 0.7)
        ..close();
      canvas.drawPath(tail, body);
      canvas.restore();
    }
  }

  void _paintBubbles(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      final progress = (t * bubble.speed + bubble.phase) % 1;
      final y = size.height * (1.04 - progress * 1.1);
      final x =
          size.width * bubble.x +
          math.sin(progress * math.pi * 6 + bubble.phase * 8) *
              size.width *
              bubble.drift;
      final r = bubble.size;
      final alpha =
          bubble.opacity *
          (0.4 + 0.6 * math.sin(progress * math.pi).clamp(0, 1));
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.45),
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = Colors.white.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        Offset(x - r * 0.3, y - r * 0.3),
        r * 0.18,
        Paint()..color = Colors.white.withValues(alpha: alpha * 1.3),
      );
    }
  }

  void _paintSand(Canvas canvas, Size size) {
    final top = size.height * 0.93;
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, top + 8);
    for (var i = 0; i <= 6; i++) {
      final x = size.width * i / 6;
      final y = top + (i.isEven ? 4 : 16);
      path.quadraticBezierTo(x - size.width / 12, y - 6, x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFD39D), Color(0xFFC99F63)],
        ).createShader(Rect.fromLTWH(0, top, size.width, size.height - top)),
    );
    // A few shells on the sand line.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.22);
    for (var i = 0; i < 7; i++) {
      final x = size.width * (0.08 + i * 0.13);
      canvas.drawCircle(Offset(x, top + 18 + (i % 3) * 5), 2.4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _OceanPainter oldDelegate) => true;
}
