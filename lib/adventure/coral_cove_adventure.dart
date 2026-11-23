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
import 'adventure_beat.dart';

/// Coral Cove vertical slice: encounter → explore → guided count → free count.
enum CoralPhase {
  enter,
  encounter,
  explore,
  teach,
  guidedCount,
  freeCount,
  celebrate,
}

class CoralCoveAdventure extends StatefulWidget {
  const CoralCoveAdventure({super.key});

  @override
  State<CoralCoveAdventure> createState() => _CoralCoveAdventureState();
}

class _CoralCoveAdventureState extends State<CoralCoveAdventure>
    with TickerProviderStateMixin {
  static const _adventureId = 'coral_cove';
  static const _guidedMissionId = 'coral_turtle_guided';
  static const _freeMissionId = 'coral_turtle_free';

  late final OceanCreature _turtle;
  late final AnimationController _swim;
  late final AnimationController _shake;
  late KecrekanController _kecrekan;
  late BeatRunner _beats;

  CoralPhase _phase = CoralPhase.enter;
  int _lineIndex = 0;
  int _collected = 0;
  late int _foodTarget;
  late int _guidedTarget;
  late int _freeTarget;
  bool _celebrate = false;
  bool _usedHint = false;
  int _attempts = 0;
  String _prompt = '';
  String _tip = '';
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _turtle = creatureById('green_turtle')!;
    final rng = math.Random();
    _foodTarget = 4 + rng.nextInt(3); // 4–6
    _guidedTarget = _foodTarget;
    _freeTarget = 3 + rng.nextInt(5); // 3–7
    _kecrekan = KecrekanController(
      initialCount: 0,
      activeRowCount: KecrekanMath.rowsForChallenge(
        start: 0,
        target: math.max(_guidedTarget, _freeTarget),
      ),
    );
    _beats = BeatRunner();
    _swim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _autoTimer = Timer(const Duration(milliseconds: 700), _beginEnter);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _swim.dispose();
    _shake.dispose();
    _kecrekan.dispose();
    AudioService.instance.stopSpeaking();
    super.dispose();
  }

  void _speak(String line) {
    setState(() => _prompt = line);
    AudioService.instance.speak(line);
  }

  void _beginEnter() {
    if (!mounted) return;
    _speak('Welcome to Coral Cove! Soft coral and warm water all around.');
    _autoTimer = Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      setState(() => _phase = CoralPhase.encounter);
      _speakEncounterLine(0);
    });
  }

  void _speakEncounterLine(int index) {
    _lineIndex = index;
    if (index >= _turtle.encounterLines.length) {
      setState(() => _phase = CoralPhase.explore);
      _speak(
        'Tap the seagrass snacks to gather $_foodTarget pieces for the turtle.',
      );
      return;
    }
    _speak(_turtle.encounterLines[index]);
  }

  void _onTurtleTap() {
    if (_phase != CoralPhase.encounter) return;
    AudioService.instance.sfx('bubble');
    Feel.tap();
    _speakEncounterLine(_lineIndex + 1);
  }

  void _collectFood(int index) {
    if (_phase != CoralPhase.explore) return;
    if (_collected >= _foodTarget) return;
    setState(() => _collected++);
    AudioService.instance.sfx('bead_slide');
    Feel.snap();
    if (_collected >= _foodTarget) {
      _speak('You found $_foodTarget snacks! Now let’s count them with beads.');
      _autoTimer?.cancel();
      _autoTimer = Timer(const Duration(milliseconds: 2200), _startTeach);
    } else {
      _speak('$_collected… keep looking!');
    }
  }

  void _startTeach() {
    if (!mounted) return;
    setState(() {
      _phase = CoralPhase.teach;
      _beats.reset();
    });
    _speak(
      'Watch. One snack means one bead. I will slide ${_guidedTarget > 1 ? 'one' : 'a'} bead for the first snack.',
    );
    _autoTimer?.cancel();
    _autoTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      // Demonstrate one bead if the frame is ready and still empty.
      if (_kecrekan.ready && _kecrekan.total == 0) {
        final next = KecrekanMath.nextUncountedIndex(0);
        KecrekanBead? bead;
        for (final candidate in _kecrekan.beads) {
          if (candidate.rod == 0 && candidate.index == next) {
            bead = candidate;
            break;
          }
        }
        if (bead != null) {
          _kecrekan.toggleBead(bead);
          AudioService.instance.bead();
          Feel.snap();
        }
      }
      _beats.advance(); // narrate
      _speak('Each bead is one snack.');
      _autoTimer = Timer(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        _beats.goTo(AdventureBeat.invite);
        setState(() => _phase = CoralPhase.guidedCount);
        _kecrekan.resetTo(0);
        _speak(
          'Your turn! Slide $_guidedTarget beads to the left — one for each snack.',
        );
      });
    });
  }

  void _hint() {
    setState(() {
      _usedHint = true;
      _tip = 'Slide beads to the left. Stop when you have $_currentTarget.';
    });
    AudioService.instance.sfx('bubble');
    AudioService.instance.speak(_tip);
    ProgressScope.read(context).markTipSeen('coral_cove_hint');
  }

  int get _currentTarget =>
      _phase == CoralPhase.freeCount ? _freeTarget : _guidedTarget;

  void _checkCount() {
    if (_kecrekan.total == _currentTarget) {
      _onCountSuccess();
    } else {
      _onCountWrong();
    }
  }

  void _onCountWrong() {
    AudioService.instance.sfx('wrong');
    Feel.nope();
    _shake.forward(from: 0);
    setState(() {
      _attempts++;
      _tip = _attempts == 1
          ? 'Count the beads you moved. Need $_currentTarget.'
          : 'Almost! Keep sliding until you reach $_currentTarget.';
    });
    AudioService.instance.speak(_tip);
  }

  void _onCountSuccess() {
    final progress = ProgressScope.read(context);
    final firstTry = _attempts == 0 && !_usedHint;
    final stars = firstTry
        ? 3
        : (!_usedHint && _attempts <= 1)
        ? 2
        : 1;
    final mission = Mission(
      id: _phase == CoralPhase.freeCount ? _freeMissionId : _guidedMissionId,
      station: StationKind.counting,
      title: _phase == CoralPhase.freeCount ? 'Turtle Treats' : 'Snack Count',
      story: 'Help the turtle by counting her snacks.',
      target: _currentTarget,
      emoji: '🐢',
    );
    progress.recordSuccess(mission, stars: stars, firstTry: firstTry);
    AudioService.instance.sfx('correct');
    Feel.success();

    if (_phase == CoralPhase.guidedCount) {
      _speak('Yes! $_guidedTarget snacks. The turtle is happy!');
      _autoTimer?.cancel();
      _autoTimer = Timer(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        setState(() {
          _phase = CoralPhase.freeCount;
          _attempts = 0;
          _usedHint = false;
          _tip = '';
          _kecrekan.resetTo(0);
        });
        _speak(
          'New challenge! Count $_freeTarget bubbles for her next bite.',
        );
      });
      return;
    }

    // Free count complete → celebrate.
    progress.discoverCreature(_turtle.id);
    progress.discoverCreature('clownfish');
    progress.completeAdventure(_adventureId);
    progress.addPearls(1);
    AudioService.instance.sfx('mission_complete');
    setState(() {
      _phase = CoralPhase.celebrate;
      _celebrate = true;
    });
    _speak(
      'You discovered the green sea turtle! She lives on the reef, eats '
      'seagrass, and swims with her flippers. Let’s keep exploring!',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _CoralReefBackdrop(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildBody(context)),
                if (_phase == CoralPhase.guidedCount ||
                    _phase == CoralPhase.freeCount ||
                    _phase == CoralPhase.teach)
                  _buildCountChrome(context),
                if (_phase == CoralPhase.celebrate) _buildCelebrateChrome(context),
              ],
            ),
          ),
          if (_celebrate) const CelebrationBurst(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            size: 44,
            color: Colors.white.withValues(alpha: 0.2),
            iconColor: OceanColors.foam,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Coral Cove',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: OceanColors.foam,
                fontWeight: FontWeight.w800,
                shadows: const [
                  Shadow(color: Color(0x66000000), blurRadius: 8),
                ],
              ),
            ),
          ),
          if (_phase == CoralPhase.explore)
            OceanPill(
              label: '$_collected/$_foodTarget',
              emoji: '🌿',
              compact: true,
              color: OceanColors.shell,
            ),
          if (_phase == CoralPhase.guidedCount ||
              _phase == CoralPhase.freeCount)
            OceanPill(
              label: '$_currentTarget',
              emoji: '🎯',
              compact: true,
              color: OceanColors.shell,
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_phase) {
      case CoralPhase.enter:
      case CoralPhase.encounter:
        return _EncounterStage(
          swim: _swim,
          turtle: _turtle,
          prompt: _prompt,
          onTurtleTap: _onTurtleTap,
          showTapHint: _phase == CoralPhase.encounter && _lineIndex == 0,
        );
      case CoralPhase.explore:
        return _ExploreStage(
          swim: _swim,
          foodTarget: _foodTarget,
          collected: _collected,
          prompt: _prompt,
          onCollect: _collectFood,
        );
      case CoralPhase.teach:
      case CoralPhase.guidedCount:
      case CoralPhase.freeCount:
        return _CountingStage(
          kecrekan: _kecrekan,
          shake: _shake,
          prompt: _prompt,
          tip: _tip,
          interactive: _phase != CoralPhase.teach,
          snacks: _phase == CoralPhase.freeCount ? _freeTarget : _guidedTarget,
          showSnacks: true,
        );
      case CoralPhase.celebrate:
        return _CelebrateStage(turtle: _turtle, prompt: _prompt);
    }
  }

  Widget _buildCountChrome(BuildContext context) {
    final playing =
        _phase == CoralPhase.guidedCount || _phase == CoralPhase.freeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          if (_tip.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _tip,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OceanColors.foam,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: BigButton(
                  label: 'Hint',
                  icon: Icons.lightbulb_rounded,
                  colors: const [OceanColors.sunny, OceanColors.sunnyDeep],
                  enabled: playing,
                  onTap: _hint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: BigButton(
                  label: playing ? 'Check my beads' : 'Watch…',
                  icon: Icons.check_rounded,
                  enabled: playing,
                  onTap: _checkCount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrateChrome(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: BigButton(
        label: 'Back to the ocean',
        icon: Icons.explore_rounded,
        onTap: () => Navigator.of(context).pop(true),
      ),
    );
  }
}

// ── Backdrop ───────────────────────────────────────────────────────────────

class _CoralReefBackdrop extends StatelessWidget {
  const _CoralReefBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF046B7A),
            Color(0xFF0A9AA0),
            Color(0xFF1A6B7A),
            Color(0xFF0D3D4A),
          ],
          stops: [0, 0.35, 0.7, 1],
        ),
      ),
      child: CustomPaint(painter: _ReefPainter(), child: SizedBox.expand()),
    );
  }
}

class _ReefPainter extends CustomPainter {
  const _ReefPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final coral = Paint()..color = const Color(0xFFE86A5A).withValues(alpha: 0.55);
    final coral2 = Paint()..color = const Color(0xFFFF9A6C).withValues(alpha: 0.45);
    final anemone = Paint()..color = const Color(0xFFD96BB0).withValues(alpha: 0.4);
    final sand = Paint()..color = const Color(0xFFE8D4A0).withValues(alpha: 0.35);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.95),
        width: size.width * 1.2,
        height: size.height * 0.28,
      ),
      sand,
    );

    void fan(Offset c, double r, Paint p) {
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + (i - 2) * 0.35;
        canvas.drawCircle(
          c + Offset(math.cos(a) * r * 0.55, math.sin(a) * r * 0.7),
          r * 0.28,
          p,
        );
      }
      canvas.drawCircle(c, r * 0.22, p);
    }

    fan(Offset(size.width * 0.18, size.height * 0.82), 48, coral);
    fan(Offset(size.width * 0.78, size.height * 0.78), 56, coral2);
    fan(Offset(size.width * 0.55, size.height * 0.88), 40, anemone);
    fan(Offset(size.width * 0.35, size.height * 0.86), 32, coral2);

    final bubble = Paint()..color = Colors.white.withValues(alpha: 0.12);
    for (final x in [0.12, 0.4, 0.65, 0.88]) {
      canvas.drawCircle(Offset(size.width * x, size.height * 0.25), 6, bubble);
      canvas.drawCircle(Offset(size.width * x + 10, size.height * 0.4), 4, bubble);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Encounter ──────────────────────────────────────────────────────────────

class _EncounterStage extends StatelessWidget {
  const _EncounterStage({
    required this.swim,
    required this.turtle,
    required this.prompt,
    required this.onTurtleTap,
    required this.showTapHint,
  });

  final AnimationController swim;
  final OceanCreature turtle;
  final String prompt;
  final VoidCallback onTurtleTap;
  final bool showTapHint;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: swim,
      builder: (context, _) {
        final bob = math.sin(swim.value * math.pi * 2) * 14;
        final drift = math.sin(swim.value * math.pi * 2 + 1.2) * 18;
        return Column(
          children: [
            const Spacer(),
            Transform.translate(
              offset: Offset(drift, bob),
              child: TurtleCompanion(
                size: 160,
                onTap: onTurtleTap,
                cheering: false,
              ),
            ),
            if (showTapHint)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tap the turtle!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: OceanColors.sunny,
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(color: Color(0x88000000), blurRadius: 6),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            _PromptBubble(text: prompt.isEmpty ? turtle.encounterLines.first : prompt),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

// ── Explore ────────────────────────────────────────────────────────────────

class _ExploreStage extends StatelessWidget {
  const _ExploreStage({
    required this.swim,
    required this.foodTarget,
    required this.collected,
    required this.prompt,
    required this.onCollect,
  });

  final AnimationController swim;
  final int foodTarget;
  final int collected;
  final String prompt;
  final ValueChanged<int> onCollect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: _PromptBubble(text: prompt),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: swim,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final positions = <Offset>[
                    Offset(0.18, 0.28),
                    Offset(0.72, 0.22),
                    Offset(0.42, 0.48),
                    Offset(0.78, 0.55),
                    Offset(0.22, 0.62),
                    Offset(0.55, 0.72),
                  ];
                  return Stack(
                    children: [
                      Positioned(
                        left: 16,
                        bottom: 24,
                        child: TurtleCompanion(size: 96, cheering: collected > 0),
                      ),
                      for (var i = 0; i < foodTarget; i++)
                        if (i >= collected)
                          Positioned(
                            left: positions[i].dx * constraints.maxWidth - 28,
                            top: positions[i].dy * constraints.maxHeight -
                                8 +
                                math.sin(swim.value * math.pi * 2 + i) * 6,
                            child: GestureDetector(
                              onTap: () => onCollect(i),
                              child: Container(
                                width: 64,
                                height: 64,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: OceanColors.mint.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    width: 2,
                                  ),
                                  boxShadow: oceanShadow(blur: 12, y: 4),
                                ),
                                child: const Text('🌿', style: TextStyle(fontSize: 30)),
                              ),
                            ),
                          ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Counting ───────────────────────────────────────────────────────────────

class _CountingStage extends StatelessWidget {
  const _CountingStage({
    required this.kecrekan,
    required this.shake,
    required this.prompt,
    required this.tip,
    required this.interactive,
    required this.snacks,
    required this.showSnacks,
  });

  final KecrekanController kecrekan;
  final AnimationController shake;
  final String prompt;
  final String tip;
  final bool interactive;
  final int snacks;
  final bool showSnacks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PromptBubble(text: prompt),
        ),
        if (showSnacks)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var i = 0; i < snacks; i++)
                  const Text('🌿', style: TextStyle(fontSize: 26)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: AnimatedBuilder(
            animation: shake,
            builder: (context, child) {
              final t = Curves.easeOut.transform(shake.value);
              final dx = math.sin(t * math.pi * 6) * (1 - t) * 10;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: KecrekanStage(
                controller: kecrekan,
                interactive: interactive,
                showTotal: true,
                showResetButton: interactive,
                showHintOverlay: interactive,
                hint: 'Slide one bead for each snack',
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: kecrekan,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: OceanPill(
              label: 'Your beads: ${kecrekan.total}',
              emoji: '🧮',
              color: OceanColors.shell,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Celebrate ──────────────────────────────────────────────────────────────

class _CelebrateStage extends StatelessWidget {
  const _CelebrateStage({required this.turtle, required this.prompt});

  final OceanCreature turtle;
  final String prompt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Spacer(),
          TurtleCompanion(size: 150, cheering: true),
          const SizedBox(height: 12),
          Text(
            turtle.name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: OceanColors.foam,
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(color: Color(0x88000000), blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 10),
          _FactChip(emoji: '🏠', text: turtle.habitat),
          _FactChip(emoji: '🍃', text: turtle.diet),
          _FactChip(emoji: '🌊', text: turtle.movement),
          const Spacer(),
          _PromptBubble(text: prompt),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.emoji, required this.text});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OceanColors.foam,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptBubble extends StatelessWidget {
  const _PromptBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: OceanColors.shell.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: oceanShadow(blur: 14, y: 5),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: OceanColors.ink,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }
}
