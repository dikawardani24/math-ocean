import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.color = OceanColors.shell,
    this.iconColor = OceanColors.ink,
    this.size = 44,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final Color iconColor;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: iconColor, size: size * 0.52),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: oceanShadow(blur: 12, y: 4),
      ),
      child: tooltip == null
          ? button
          : Tooltip(message: tooltip!, child: button),
    );
  }
}

class OceanPill extends StatelessWidget {
  const OceanPill({
    super.key,
    required this.label,
    this.icon,
    this.color = OceanColors.shell,
    this.foreground = OceanColors.ink,
    this.emoji,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color foreground;
  final String? emoji;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: oceanShadow(blur: 10, y: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            Text(emoji!, style: TextStyle(fontSize: compact ? 14 : 16)),
          if (icon != null)
            Icon(icon, size: compact ? 15 : 17, color: foreground),
          if (emoji != null || icon != null) const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              fontSize: compact ? 12.5 : 14,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class BigButton extends StatefulWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.arrow_forward_rounded,
    this.colors = const [OceanColors.aqua, OceanColors.teal],
    this.enabled = true,
    this.height = 58,
    this.expand = true,
    this.textColor = OceanColors.ink,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final List<Color> colors;
  final bool enabled;
  final double height;
  final bool expand;
  final Color textColor;

  @override
  State<BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<BigButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.45,
          child: Container(
            width: widget.expand ? double.infinity : null,
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.colors.last.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.22),
                  blurRadius: 2,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: widget.textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(widget.icon, color: widget.textColor, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.stars,
    this.size = 18,
    this.max = 3,
    this.spacing = 2,
  });

  final int stars;
  final double size;
  final int max;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: EdgeInsets.only(right: i == max - 1 ? 0 : spacing),
            child: Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < stars ? OceanColors.sunny : Colors.white38,
              shadows: i < stars
                  ? [
                      Shadow(
                        color: OceanColors.sunnyDeep.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.color,
    this.borderColor,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.22),
          width: 1.5,
        ),
        boxShadow: shadow ? oceanShadow(blur: 18, y: 8) : null,
      ),
      child: child,
    );
  }
}

class CelebrationBurst extends StatefulWidget {
  const CelebrationBurst({super.key, this.color = OceanColors.sunny});

  final Color color;

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Spark> _sparks = [];
  final math.Random _random = math.Random(11);

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 46; i++) {
      final a = _random.nextDouble() * math.pi * 2;
      final speed = 0.25 + _random.nextDouble() * 0.8;
      _sparks.add(
        _Spark(
          dx: math.cos(a) * speed,
          dy: math.sin(a) * speed - 0.3,
          size: 3 + _random.nextDouble() * 7,
          delay: _random.nextDouble() * 0.25,
          star: _random.nextDouble() > 0.45,
          color: _random.nextBool() ? widget.color : Colors.white,
        ),
      );
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _BurstPainter(progress: _controller.value, sparks: _sparks),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Spark {
  const _Spark({
    required this.dx,
    required this.dy,
    required this.size,
    required this.delay,
    required this.star,
    required this.color,
  });
  final double dx;
  final double dy;
  final double size;
  final double delay;
  final bool star;
  final Color color;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.sparks});
  final double progress;
  final List<_Spark> sparks;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.48);
    for (final spark in sparks) {
      final p = ((progress - spark.delay) / (1 - spark.delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final ease = Curves.easeOutCubic.transform(p);
      final gravity = p * p * size.height * 0.22;
      final pos =
          origin +
          Offset(
            spark.dx * size.width * 0.6 * ease,
            spark.dy * size.height * 0.5 * ease + gravity,
          );
      final alpha = (1 - p).clamp(0.0, 1.0);
      final paint = Paint()..color = spark.color.withValues(alpha: alpha);
      if (spark.star) {
        _star(canvas, pos, spark.size * (0.6 + ease * 0.7), paint);
      } else {
        canvas.drawCircle(pos, spark.size * 0.6, paint);
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final radius = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a) * radius, math.sin(a) * radius);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// A rounded page header with a back button, title and optional trailing.
class OceanHeader extends StatelessWidget {
  const OceanHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: RoundIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
              size: 42,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: OceanColors.shell,
                  fontSize: 26,
                  shadows: const [
                    Shadow(color: Color(0x66000000), blurRadius: 8),
                  ],
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OceanColors.mint.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

void showOceanSnack(BuildContext context, String message, {IconData? icon}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: OceanColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: OceanColors.sunny, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: OceanColors.shell,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Baloo2',
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
