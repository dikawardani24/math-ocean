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


enum _CoralStep { greeting, counting, collecting, feeding, discovery }

class CoralCoveAdventure extends StatefulWidget {
  const CoralCoveAdventure({super.key});
  @override
  State<CoralCoveAdventure> createState() => _CoralCoveAdventureState();
}

class _CoralCoveAdventureState extends State<CoralCoveAdventure>
    with TickerProviderStateMixin {
  static int? _lastTarget;
  late final OceanCreature _turtle;
  late final AnimationController _swim;
  late final AnimationController _pulse;
  late final KecrekanController _kecrekan;
  int _target = 3;
  final Set<int> _collected = {};
  _CoralStep _step = _CoralStep.greeting;
  bool _recorded = false;
  String _dialogue = 'I am hungry! Can you help me find some seagrass?';

  @override
  void initState() {
    super.initState();
    _turtle = creatureById('green_turtle')!;
    final choices = [2, 3, 4, 5]..remove(_lastTarget);
    _target = choices[math.Random().nextInt(choices.length)];
    _lastTarget = _target;
    _kecrekan = KecrekanController(
      initialCount: 0,
      activeRowCount: KecrekanMath.rowsForChallenge(start: 0, target: _target),
    );
    _swim = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _kecrekan.addListener(_onBeadsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AudioService.instance.speak(_dialogue);
    });
  }

  @override
  void dispose() {
    _kecrekan.removeListener(_onBeadsChanged);
    _kecrekan.dispose();
    _swim.dispose();
    _pulse.dispose();
    AudioService.instance.stopSpeaking();
    super.dispose();
  }

  void _say(String message) {
    if (!mounted) return;
    setState(() => _dialogue = message);
    AudioService.instance.speak(message);
  }

  void _startCounting() {
    setState(() => _step = _CoralStep.counting);
    _say('We need ' + _target.toString() + ' pieces of seagrass. Make that number on the Kecrekan!');
  }

  void _onBeadsChanged() {
    if (_step != _CoralStep.counting) return;
    final total = _kecrekan.total;
    if (total == _target) {
      setState(() => _step = _CoralStep.collecting);
      Feel.success();
      AudioService.instance.sfx('mission_complete');
      _say('That is ' + _target.toString() + '! Now find the seagrass around the reef.');
    } else if (total > _target) {
      _say('Oops, that is too many. Slide a bead back.');
    }
  }

  void _collectGrass(int index) {
    if (_step != _CoralStep.collecting || _collected.contains(index)) return;
    setState(() => _collected.add(index));
    Feel.snap();
    AudioService.instance.sfx('bead_slide');
    final count = _collected.length;
    if (count == _target) {
      setState(() => _step = _CoralStep.feeding);
      _say('You found all the seagrass! Take it to the turtle.');
    } else {
      _say('You found ' + count.toString() + '! Keep looking.');
    }
  }

  final Set<int> _fedGrass = {};
  int? _feedingGrassIndex;
  bool _isEating = false;
  bool _finishingFeed = false;

  void _feedOne(int grassIndex) {
    // Only one piece may enter the turtle's mouth at a time. Keep the
    // basket item visible until the complete bite animation has finished.
    if (_step != _CoralStep.feeding ||
        _isEating ||
        _finishingFeed ||
        _fedGrass.contains(grassIndex)) {
      return;
    }

    setState(() {
      _feedingGrassIndex = grassIndex;
      _isEating = true;
    });
    AudioService.instance.sfx('bead_slide');

    Future<void>.delayed(const Duration(milliseconds: 950), () {
      if (!mounted || _step != _CoralStep.feeding) return;

      setState(() {
        _fedGrass.add(grassIndex);
        _feedingGrassIndex = null;
        _isEating = false;
      });
      Feel.success();

      if (_fedGrass.length == _target) {
        setState(() => _finishingFeed = true);
        _say('Munch, munch! My tummy is full. Thank you, friend!');
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _completeFeeding();
        });
      } else {
        final remaining = _target - _fedGrass.length;
        _say(remaining == 1
            ? 'Crunch! That was tasty. One more piece, please!'
            : 'Crunch, crunch! That was tasty. $remaining more pieces!');
      }
    });
  }

  void _completeFeeding() {
    if (_recorded || !mounted) return;
    _recorded = true;
    setState(() => _step = _CoralStep.discovery);
    final progress = ProgressScope.read(context);
    progress.discoverCreature(_turtle.id);
    progress.recordSuccess(
      Mission(
        id: 'coral_turtle_adventure',
        station: StationKind.counting,
        title: 'Coral Cove Feast',
        story: 'Count and collect seagrass, then feed the green sea turtle.',
        target: _target,
        emoji: '🐢',
      ),
      stars: 3,
      firstTry: true,
    );
    progress.completeAdventure('coral_cove');
    progress.addPearls(1);
    Feel.success();
    AudioService.instance.sfx('mission_complete');
    _say('Sea turtles graze on seagrass and help keep underwater meadows healthy!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF063D4B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CoralCove3DBackdrop(),
          SafeArea(
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: switch (_step) {
                      _CoralStep.greeting => _greeting(),
                      _CoralStep.counting => _counting(),
                      _CoralStep.collecting => _collecting(),
                      _CoralStep.feeding => _feeding(),
                      _CoralStep.discovery => _discovery(context),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _greeting() => Center(
    key: const ValueKey('greeting'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _swim,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, math.sin(_swim.value * math.pi * 2) * 8),
              child: child,
            ),
            child: TurtleCompanion(size: 196, onTap: () => AudioService.instance.speak(_dialogue)),
          ),
          const SizedBox(height: 14),
          SpeechBubble(message: _dialogue),
          const SizedBox(height: 24),
          BigButton(label: 'Help the turtle!', icon: Icons.favorite_rounded, onTap: _startCounting),
        ],
      ),
    ),
  );

  Widget _counting() => Padding(
    key: const ValueKey('counting'),
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
    child: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: OceanColors.shell, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              const Text('HOW MUCH SEAGRASS?', style: TextStyle(color: OceanColors.inkSoft, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_target, (_) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(width: 26, height: 36, child: CustomPaint(painter: _SeagrassPainter())),
                )),
              ),
              Text('Make ' + _target.toString() + ' on your Kecrekan', style: const TextStyle(color: OceanColors.ink, fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: KecrekanStage(
            controller: _kecrekan,
            interactive: true,
            showTotal: true,
            showResetButton: true,
            showHintOverlay: true,
            hint: 'Move the beads to make the same amount',
          ),
        ),
      ],
    ),
  );

  Widget _collecting() => LayoutBuilder(
    key: const ValueKey('collecting'),
    builder: (context, constraints) {
      const size = 68.0;
      const positions = [
        Offset(.17, .10), Offset(.76, .04), Offset(.22, .70),
        Offset(.80, .66), Offset(.50, .38),
      ];
      final freeHeight = math.max(0.0, constraints.maxHeight - 224 - size);
      return Stack(
        children: [
          Positioned(
            left: 10, right: 10, top: 4,
            child: Column(
              children: [
                SpeechBubble(message: _dialogue, onTap: () => AudioService.instance.speak(_dialogue)),
                const SizedBox(height: 8),
                _FoodBasket(count: _collected.length, target: _target),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: constraints.maxWidth * .34,
            child: TurtleCompanion(size: 112),
          ),
          for (var i = 0; i < _target; i++)
            if (!_collected.contains(i))
              Positioned(
                left: (constraints.maxWidth * positions[i].dx - size / 2).clamp(8.0, math.max(8.0, constraints.maxWidth - size - 8)),
                top: 132 + freeHeight * positions[i].dy,
                width: size,
                height: size,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Transform.scale(
                    scale: 1 + math.sin(_pulse.value * math.pi + i) * .07,
                    child: child,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _collectGrass(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF063F48).withValues(alpha: .5),
                        shape: BoxShape.circle,
                        border: Border.all(color: OceanColors.mint, width: 2),
                        boxShadow: oceanShadow(blur: 14, y: 5),
                      ),
                      alignment: Alignment.center,
                      child: const SizedBox(width: 48, height: 48, child: CustomPaint(painter: _SeagrassPainter())),
                    ),
                  ),
                ),
              ),
        ],
      );
    },
  );

  Widget _feeding() => Padding(
    key: const ValueKey('feeding'),
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
    child: Column(
      children: [
        SpeechBubble(message: _dialogue),
        const SizedBox(height: 12),
        Expanded(
          child: DragTarget<int>(
            onWillAccept: (index) =>
                index != null &&
                !_isEating &&
                !_finishingFeed &&
                !_fedGrass.contains(index),
            onAccept: _feedOne,
            builder: (context, candidateData, rejectedData) {
              final hovering = candidateData.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: hovering
                      ? OceanColors.mint.withValues(alpha: .2)
                      : Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: hovering ? OceanColors.sunny : OceanColors.mint.withValues(alpha: .45),
                    width: hovering ? 4 : 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: hovering ? 1.12 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: TurtleCompanion(
                        size: 190,
                        cheering: _fedGrass.isNotEmpty && !_isEating,
                        eating: _isEating,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: hovering ? OceanColors.sunny : OceanColors.shell,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        _finishingFeed
                            ? 'YUMMY! TUMMY FULL!'
                            : _isEating
                                ? 'NOM NOM NOM...'
                                : hovering
                                    ? 'LET GO TO FEED ME!'
                                    : 'DROP THE SEAGRASS HERE',
                        style: const TextStyle(
                          color: OceanColors.ink,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_fedGrass.length} / $_target pieces eaten',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: OceanColors.shell,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'YOUR SEAGRASS BASKET',
                    style: TextStyle(
                      color: OceanColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${_target - _fedGrass.length} LEFT',
                    style: const TextStyle(
                      color: OceanColors.inkSoft,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _target; i++)
                    if (!_fedGrass.contains(i))
                      Draggable<int>(
                        data: i,
                        maxSimultaneousDrags: (_isEating || _finishingFeed) ? 0 : 1,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _SeagrassToken(size: 62, lifted: true),
                        ),
                        childWhenDragging: Opacity(
                          opacity: .2,
                          child: _SeagrassToken(size: 54),
                        ),
                        child: Opacity(
                          opacity: _feedingGrassIndex == i ? .22 : 1,
                          child: _SeagrassToken(
                            size: 54,
                            lifted: _feedingGrassIndex == i,
                          ),
                        ),
                      )
                    else
                      _SeagrassToken(size: 54, eaten: true),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isEating
                    ? 'Wait for the turtle to finish chewing!'
                    : 'Drag one piece at a time to the turtle',
                style: TextStyle(
                  color: OceanColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _discovery(BuildContext context) => Center(
    key: const ValueKey('discovery'),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TurtleCompanion(size: 184, cheering: true),
          const SizedBox(height: 10),
          SpeechBubble(message: _dialogue),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: OceanColors.shell, borderRadius: BorderRadius.circular(22)),
            child: Column(
              children: [
                const Text('🐢  OCEAN DISCOVERY', style: TextStyle(color: OceanColors.inkSoft, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(_turtle.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: OceanColors.ink, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(_turtle.habitat + '\nSea turtles graze on seagrass and help keep underwater meadows healthy.', textAlign: TextAlign.center, style: const TextStyle(color: OceanColors.ink, fontWeight: FontWeight.w600, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BigButton(label: 'Explore the reef', icon: Icons.explore_rounded, onTap: () => Navigator.of(context).pop(true)),
        ],
      ),
    ),
  );

  Widget _header(BuildContext context) {
    final label = switch (_step) {
      _CoralStep.greeting => 'Meet the turtle',
      _CoralStep.counting => 'Count the food',
      _CoralStep.collecting => 'Collect seagrass',
      _CoralStep.feeding => 'Feeding time',
      _CoralStep.discovery => 'Ocean discovery',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            size: 44,
            color: Colors.white.withValues(alpha: .2),
            iconColor: OceanColors.foam,
            onTap: () {
              if (_step == _CoralStep.greeting) {
                Navigator.of(context).pop();
              } else if (_step == _CoralStep.counting) {
                _kecrekan.reset();
                setState(() => _step = _CoralStep.greeting);
              } else {
                // Do not return to a completed collection step: that would
                // leave the child with an empty reef and no way forward.
                Navigator.of(context).pop(_recorded);
              }
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coral Cove', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: OceanColors.foam, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(color: OceanColors.mint, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          OceanPill(
            label: _step == _CoralStep.collecting
                ? _collected.length.toString() + '/' + _target.toString()
                : _step == _CoralStep.feeding
                    ? _fedGrass.length.toString() + '/' + _target.toString()
                    : _target.toString() + ' 🌿',
            emoji: '🐢',
            compact: true,
            color: OceanColors.mint,
          ),
        ],
      ),
    );
  }
}

class _SeagrassToken extends StatelessWidget {
  const _SeagrassToken({
    required this.size,
    this.lifted = false,
    this.eaten = false,
  });

  final double size;
  final bool lifted;
  final bool eaten;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: size,
    height: size,
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: eaten
          ? OceanColors.mint.withValues(alpha: .35)
          : const Color(0xFFE9F6D7),
      shape: BoxShape.circle,
      border: Border.all(
        color: eaten ? OceanColors.mint : const Color(0xFF75C85F),
        width: lifted ? 3 : 2,
      ),
      boxShadow: lifted ? oceanShadow(blur: 16, y: 6) : null,
    ),
    child: eaten
        ? const Icon(Icons.check_rounded, color: Color(0xFF187B5B), size: 28)
        : const CustomPaint(painter: _SeagrassPainter()),
  );
}

class _FoodBasket extends StatelessWidget {
  const _FoodBasket({required this.count, required this.target, this.large = false});
  final int count;
  final int target;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: large ? 24 : 16, vertical: large ? 16 : 9),
    decoration: BoxDecoration(
      color: OceanColors.shell,
      borderRadius: BorderRadius.circular(large ? 24 : 18),
      border: Border.all(color: OceanColors.sunny, width: 2),
      boxShadow: oceanShadow(blur: 14, y: 5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('🧺', style: TextStyle(fontSize: large ? 46 : 26)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count / $target', style: TextStyle(color: OceanColors.ink, fontSize: large ? 25 : 18, fontWeight: FontWeight.w900)),
            Text('SEAGRASS', style: TextStyle(color: OceanColors.inkSoft, fontSize: large ? 11 : 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
          ],
        ),
      ],
    ),
  );
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
