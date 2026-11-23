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
    _targetSnacks = 3 + rng.nextInt(3); // 3 to 5
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
    // Keep the food and the physical counting frame in lockstep: a child
    // must represent the previous item with one bead before gathering another.
    if (_collectedSnacks.contains(index) || _completed) return;
    if (_kecrekan.total != _collectedSnacks.length) return;
    setState(() {
      _collectedSnacks.add(index);
    });
    AudioService.instance.sfx('bead_slide');
    Feel.snap();

    _speak(
      'You found seagrass ${_collectedSnacks.length}. Move one bead for this one!',
    );
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
          const _ReefWorldBackdrop(),

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
                  child: Stack(
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
                                  child: Text('🪸', style: TextStyle(fontSize: 66)),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 4,
                                  child: Text(
                                    _clownfishEncountered ? '🐠✨' : '🐠',
                                    style: const TextStyle(fontSize: 42),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Floating seagrass items in the reef
                      ..._buildSeagrassItems(context),

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

  List<Widget> _buildSeagrassItems(BuildContext context) {
    final positions = [
      const Offset(0.15, 0.35),
      const Offset(0.75, 0.28),
      const Offset(0.22, 0.55),
      const Offset(0.80, 0.52),
      const Offset(0.50, 0.42),
    ];

    final widgets = <Widget>[];
    for (var i = 0; i < _targetSnacks; i++) {
      if (_collectedSnacks.contains(i)) continue;
      final pos = positions[i % positions.length];
      widgets.add(
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final scale = 1.0 + math.sin(_pulse.value * math.pi + i) * 0.08;
            return Positioned(
              left: MediaQuery.of(context).size.width * pos.dx - 32,
              top: MediaQuery.of(context).size.height * pos.dy - 32,
              child: Transform.scale(
                scale: scale,
                child: GestureDetector(
                  onTap: () => _collectSnack(i),
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: OceanColors.mint.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: oceanShadow(blur: 14, y: 4),
                    ),
                    child: const Text('🌿', style: TextStyle(fontSize: 32)),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return widgets;
  }
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
