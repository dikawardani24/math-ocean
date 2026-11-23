import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/feedback.dart';
import '../core/models.dart';
import '../core/progress.dart';
import '../creatures/creature.dart';
import '../creatures/creature_catalog.dart';
import '../kecrekan/kecrekan_controller.dart';
import '../kecrekan/kecrekan_math.dart';
import '../kecrekan/kecrekan_stage.dart';
import '../theme.dart';
import '../widgets/coral_cove_3d_backdrop.dart';
import '../widgets/turtle_companion.dart';
import '../widgets/ui_kit.dart';

/// True game adventure for Coral Cove: seamless reef exploration,
/// tactile seagrass gathering, and organic coral abacus counting.
class CoralCoveAdventure extends StatefulWidget {
  const CoralCoveAdventure({super.key});

  @override
  State<CoralCoveAdventure> createState() => _CoralCoveAdventureState();
}

class _CoralCoveAdventureState extends State<CoralCoveAdventure>
    with TickerProviderStateMixin {
  static const _adventureId = 'coral_cove';
  static int? _lastTargetSnacks;

  late final OceanCreature _turtle;
  late final AnimationController _swim;
  late final AnimationController _pulse;
  late KecrekanController _kecrekan;

  int _targetSnacks = 4;
  final Set<int> _collectedSnacks = {};
  bool _completed = false;
  bool _celebrating = false;
  bool _turtleEncountered = false;
  bool _clownfishEncountered = false;
  String _dialogue = 'Look around the reef. Tap a sea friend to see what it does!';

  @override
  void initState() {
    super.initState();
    _turtle = creatureById('green_turtle')!;
    final rng = math.Random();
    // Keep each visit feeling fresh; the next reef task cannot repeat the
    // previous target during this app session.
    final choices = [2, 3, 4, 5]..remove(_lastTargetSnacks);
    _targetSnacks = choices[rng.nextInt(choices.length)];
    _lastTargetSnacks = _targetSnacks;
    _kecrekan = KecrekanController(
      initialCount: 0,
      activeRowCount: KecrekanMath.rowsForChallenge(start: 0, target: _targetSnacks),
    );

    _swim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioService.instance.speak(_dialogue);
    });

    // Listen to abacus changes for organic real-time feedback
    _kecrekan.addListener(_onAbacusChanged);
  }

  @override
  void dispose() {
    _kecrekan.removeListener(_onAbacusChanged);
    _swim.dispose();
    _pulse.dispose();
    _kecrekan.dispose();
    AudioService.instance.stopSpeaking();
    super.dispose();
  }

  void _speak(String text) {
    setState(() => _dialogue = text);
    AudioService.instance.speak(text);
  }

  void _encounterTurtle() {
    final firstEncounter = !_turtleEncountered;
    setState(() => _turtleEncountered = true);
    if (firstEncounter) {
      ProgressScope.read(context).discoverCreature(_turtle.id);
      _speak(_turtle.encounterLines.first);
    } else {
      _speak(_turtle.encounterLines[1]);
    }
  }

  void _encounterClownfish() {
    final clownfish = creatureById('clownfish')!;
    final firstEncounter = !_clownfishEncountered;
    setState(() => _clownfishEncountered = true);
    if (firstEncounter) {
      ProgressScope.read(context).discoverCreature(clownfish.id);
      _speak(clownfish.encounterLines.first);
    } else {
      _speak(clownfish.encounterLines.last);
    }
  }

  void _collectSnack(int index) {
    // Let children explore and collect every visible item freely. Counting is
    // a separate, connected action: the Kecrekan total must match the number
    // of seagrass they discovered before the reef celebrates.
    if (_collectedSnacks.contains(index) || _completed) return;

    setState(() {
      _collectedSnacks.add(index);
    });
    AudioService.instance.sfx('bead_slide');
    Feel.snap();

    final count = _collectedSnacks.length;
    _speak(
      count == _targetSnacks
          ? 'You found all the seagrass! Count them on the coral abacus.'
          : 'You found $count seagrass! Find the rest, then count them on the coral abacus.',
    );

    // Also handle the case where the child had already set the matching bead
    // total before collecting the final seagrass.
    if (count == _targetSnacks && _kecrekan.total == count) {
      _triggerSuccess();
    }
  }

  void _onAbacusChanged() {
    if (_completed) return;
    final total = _kecrekan.total;
    final collected = _collectedSnacks.length;

    if (total == collected && collected == _targetSnacks) {
      _triggerSuccess();
    } else if (total == collected && collected > 0) {
      _speak('That is one bead for each seagrass! Find the next piece.');
    } else if (total > collected) {
      _speak('One bead for each seagrass. Slide one bead back.');
    } else if (total < collected) {
      _speak('You found another piece of seagrass. Move one bead to count it!');
    }
  }

  void _triggerSuccess() {
    setState(() {
      _completed = true;
      _celebrating = true;
    });

    final progress = ProgressScope.read(context);
    final mission = Mission(
      id: 'coral_turtle_adventure',
      station: StationKind.counting,
      title: 'Coral Cove Feast',
      story: 'Feed the green sea turtle with reef seagrass and coral beads.',
      target: _targetSnacks,
      emoji: '🐢',
    );
    progress.recordSuccess(mission, stars: 3, firstTry: true);
    progress.completeAdventure(_adventureId);
    progress.addPearls(1);

    AudioService.instance.sfx('mission_complete');
    Feel.success();
    _speak('Amazing! You helped the turtle find her seagrass. What else can you discover in the reef?');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Living reef backdrop with dynamic light rays
          const CoralCove3DBackdrop(),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: TurtleTalk(
                    message: _dialogue,
                    size: 80,
                    onTap: () => AudioService.instance.speak(_dialogue),
                    cheering: _completed,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                    children: [
                      // Swimming turtle companion
                      AnimatedBuilder(
                        animation: _swim,
                        builder: (context, _) {
                          final x = math.sin(_swim.value * math.pi * 2) * 20;
                          final y = math.cos(_swim.value * math.pi * 4) * 8;
                          return Positioned(
                            left: MediaQuery.of(context).size.width * 0.35 + x,
                            top: 40 + y,
                            child: TurtleCompanion(
                              size: 112,
                              cheering: _completed,
                              onTap: _encounterTurtle,
                            ),
                          );
                        },
                      ),

                      // A clownfish peeks out of its anemone. Discovery is
                      // recorded only when the child chooses to meet it.
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.12,
                        top: 176,
                        child: GestureDetector(
                          onTap: _encounterClownfish,
                          child: SizedBox(
                            width: 104,
                            height: 104,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Positioned(
                                  bottom: 0,
                                  child: SizedBox(
                                    width: 88,
                                    height: 76,
                                    child: CustomPaint(painter: _AnemonePainter()),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 0,
                                  child: SizedBox(
                                    width: 64,
                                    height: 46,
                                    child: CustomPaint(
                                      painter: _ClownfishPainter(
                                        discovered: _clownfishEncountered,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Floating seagrass items in the reef
                      ..._buildSeagrassItems(context, constraints),

                      // Organic coral abacus (Kecrekan) embedded at the bottom of the reef world
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 12,
                        height: 220,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF043B46).withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: OceanColors.aqua.withValues(alpha: 0.6),
                              width: 2.5,
                            ),
                            boxShadow: oceanShadow(blur: 16, y: 6),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🪸 Coral Abacus ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                                  Text('(${_kecrekan.total}/$_targetSnacks)', style: const TextStyle(color: OceanColors.sunny, fontWeight: FontWeight.w800, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: KecrekanStage(
                                  controller: _kecrekan,
                                  interactive: !_completed,
                                  showTotal: false,
                                  showResetButton: false,
                                  showHintOverlay: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_celebrating)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: OceanColors.shell,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: oceanShadow(blur: 24, y: 10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🐢✨', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 12),
                        Text(
                          _turtle.name,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: OceanColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _turtle.habitat,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: OceanColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        BigButton(
                          label: 'Explore More Ocean',
                          icon: Icons.explore_rounded,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            size: 44,
            color: Colors.white.withValues(alpha: 0.2),
            iconColor: OceanColors.foam,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Coral Cove',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: OceanColors.foam,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6)],
              ),
            ),
          ),
          OceanPill(
            label: '${_collectedSnacks.length}/$_targetSnacks Snacks',
            emoji: '🌿',
            compact: true,
            color: OceanColors.mint,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSeagrassItems(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    // The abacus owns the bottom 244 logical pixels. Collectibles are
    // positioned only in the remaining playfield, never beneath its hit area.
    const itemSize = 64.0;
    const reservedBottom = 244.0;
    final playfieldHeight = math.max(
      0.0,
      constraints.maxHeight - reservedBottom,
    );
    final maxTop = math.max(0.0, playfieldHeight - itemSize).toDouble();
    final positions = [
      const Offset(0.16, 0.12),
      const Offset(0.76, 0.08),
      const Offset(0.22, 0.68),
      const Offset(0.80, 0.62),
      const Offset(0.50, 0.36),
    ];

    final widgets = <Widget>[];
    for (var i = 0; i < _targetSnacks; i++) {
      if (_collectedSnacks.contains(i)) continue;
      final pos = positions[i % positions.length];
      final left = (constraints.maxWidth * pos.dx - itemSize / 2)
          .clamp(
            8.0,
            math.max(8.0, constraints.maxWidth - itemSize - 8.0),
          )
          .toDouble();
      final top = (maxTop * pos.dy).clamp(0.0, maxTop).toDouble();
      widgets.add(
        Positioned(
          left: left,
          top: top,
          width: itemSize,
          height: itemSize,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final scale =
                  1.0 + math.sin(_pulse.value * math.pi + i) * 0.08;
              return Transform.scale(
                scale: scale,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _collectSnack(i),
                  child: Container(
                    width: itemSize,
                    height: itemSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF063F48).withValues(alpha: 0.28),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: OceanColors.mint.withValues(alpha: 0.65),
                        width: 1.5,
                      ),
                      boxShadow: oceanShadow(blur: 12, y: 4),
                    ),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: CustomPaint(painter: _SeagrassPainter()),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    return widgets;
  }
}

/// Lightweight vector marine-life illustrations keep the reef readable
/// at phone sizes without relying on platform emoji glyphs.
class _SeagrassPainter extends CustomPainter {
  const _SeagrassPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stemPaint = Paint()
      ..color = const Color(0xFF9BE36C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final leafPaint = Paint()
      ..color = const Color(0xFF55C978)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.28 + i * 0.22);
      final path = Path()
        ..moveTo(x, size.height * 0.92)
        ..cubicTo(x - 5, size.height * 0.65, x + 7, size.height * 0.35, x, 4);
      canvas.drawPath(path, stemPaint);
      for (var j = 0; j < 3; j++) {
        final y = size.height * (0.72 - j * 0.2);
        final direction = ((i + j).isEven ? 1 : -1).toDouble();
        final leaf = Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(
            x + direction * 15,
            y - 12,
            x + direction * 13,
            y - 2,
          )
          ..quadraticBezierTo(x + direction * 5, y + 3, x, y);
        canvas.drawPath(leaf, leafPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeagrassPainter oldDelegate) => false;
}

class _AnemonePainter extends CustomPainter {
  const _AnemonePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.76);
    final tentacle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 11; i++) {
      final angle = math.pi + (math.pi * i / 10);
      final start = Offset(
        center.dx + math.cos(angle) * 10,
        center.dy + math.sin(angle) * 4,
      );
      final end = Offset(
        center.dx + math.cos(angle) * (size.width * 0.43),
        center.dy + math.sin(angle) * (size.height * 0.67),
      );
      tentacle.color = i.isEven
          ? const Color(0xFFFF8DAA)
          : const Color(0xFFFFC0A5);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          center.dx + math.cos(angle) * size.width * 0.34 + (i % 3 - 1) * 5,
          center.dy + math.sin(angle) * size.height * 0.38,
          end.dx,
          end.dy,
        );
      canvas.drawPath(path, tentacle);
      canvas.drawCircle(end, 3, Paint()..color = tentacle.color);
    }
    final base = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 7),
      width: size.width * 0.46,
      height: size.height * 0.25,
    );
    canvas.drawOval(base, Paint()..color = const Color(0xFFE77F91));
    canvas.drawOval(
      base.deflate(5),
      Paint()..color = const Color(0xFFFFB0A7),
    );
  }

  @override
  bool shouldRepaint(covariant _AnemonePainter oldDelegate) => false;
}

class _ClownfishPainter extends CustomPainter {
  const _ClownfishPainter({required this.discovered});
  final bool discovered;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Path()
      ..moveTo(size.width * 0.12, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.34, -size.height * 0.05, size.width * 0.78, size.height * 0.34)
      ..quadraticBezierTo(size.width * 0.96, size.height * 0.5, size.width * 0.78, size.height * 0.66)
      ..quadraticBezierTo(size.width * 0.34, size.height * 1.05, size.width * 0.12, size.height * 0.5);
    canvas.drawPath(
      body,
      Paint()..color = const Color(0xFFFF8A28),
    );
    final tail = Path()
      ..moveTo(size.width * 0.14, size.height * 0.5)
      ..lineTo(0, size.height * 0.18)
      ..quadraticBezierTo(size.width * 0.04, size.height * 0.5, 0, size.height * 0.82)
      ..close();
    canvas.drawPath(tail, Paint()..color = const Color(0xFFFFA33D));
    final stripe = Paint()
      ..color = const Color(0xFFFFF7E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.105;
    for (final x in [0.34, 0.68]) {
      canvas.drawLine(
        Offset(size.width * x, size.height * 0.13),
        Offset(size.width * x, size.height * 0.87),
        stripe,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.82, size.height * 0.43),
        width: 5,
        height: 5,
      ),
      Paint()..color = const Color(0xFF172B35),
    );
    canvas.drawCircle(
      Offset(size.width * 0.835, size.height * 0.415),
      1.2,
      Paint()..color = Colors.white,
    );
    if (discovered) {
      final sparkle = Paint()
        ..color = const Color(0xFFFFE58A)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final point = Offset(size.width * 0.9, size.height * 0.12);
      canvas.drawLine(point.translate(-4, 0), point.translate(4, 0), sparkle);
      canvas.drawLine(point.translate(0, -4), point.translate(0, 4), sparkle);
    }
  }

  @override
  bool shouldRepaint(covariant _ClownfishPainter oldDelegate) =>
      discovered != oldDelegate.discovered;
}

class _ReefWorldBackdrop extends StatelessWidget {
  const _ReefWorldBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF034F5C),
            Color(0xFF068A94),
            Color(0xFF0B5D68),
            Color(0xFF022630),
          ],
          stops: [0, 0.3, 0.65, 1],
        ),
      ),
      child: CustomPaint(painter: _ReefPainter(), child: const SizedBox.expand()),
    );
  }
}

class _ReefPainter extends CustomPainter {
  const _ReefPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sand = Paint()..color = const Color(0xFFD4B483).withValues(alpha: 0.4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.98),
        width: size.width * 1.3,
        height: size.height * 0.22,
      ),
      sand,
    );

    final bubble = Paint()..color = Colors.white.withValues(alpha: 0.15);
    for (final x in [0.2, 0.45, 0.7, 0.85]) {
      canvas.drawCircle(Offset(size.width * x, size.height * 0.2), 5, bubble);
      canvas.drawCircle(Offset(size.width * x + 15, size.height * 0.45), 8, bubble);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
