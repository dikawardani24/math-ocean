import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../adventure/coral_cove_adventure.dart';
import '../adventure/kelp_forest_adventure.dart';
import '../adventure/shell_shore_adventure.dart';
import '../core/audio_service.dart';
import '../core/feedback.dart';
import '../core/progress.dart';
import '../discovery/journal_screen.dart';
import '../screens/jarimatika_screen.dart';
import '../screens/rewards_screen.dart';
import '../screens/settings_sheet.dart';
import '../core/models.dart';
import '../theme.dart';
import '../widgets/turtle_companion.dart';
import '../widgets/ui_kit.dart';

/// Living underwater world map — the heart of the adventure.
///
/// Coral Cove is the playable vertical slice. Other locations are visible
/// landmarks that unlock as the child discovers the ocean.
class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life;
  int _greeting = 0;

  static const _greetings = [
    'Hi! I’m Tala. Tap Coral Cove to begin our adventure!',
    'The reef is alive today. What will we discover?',
    'Tap a glowing place to dive in. I’ll swim with you!',
    'Find ocean friends, then count their treasures with beads.',
  ];

  @override
  void initState() {
    super.initState();
    _life = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioService.instance.speak(_greetings[0]);
    });
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  void _nextGreeting() {
    setState(() => _greeting = (_greeting + 1) % _greetings.length);
    AudioService.instance.speak(_greetings[_greeting]);
    AudioService.instance.sfx('bubble');
  }

  Future<void> _openCoralCove() async {
    AudioService.instance.sfx('whoosh');
    Feel.tap();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CoralCoveAdventure()),
    );
    if (!mounted) return;
    if (result == true) {
      AudioService.instance.speak(
        'Shell Shore is waking up! And your discovery journal has new friends.',
      );
    }
  }

  Future<void> _openLocked(String name, String tease) async {
    AudioService.instance.sfx('bubble');
    Feel.tap();
    showOceanSnack(context, tease);
    AudioService.instance.speak(tease);
  }

  Future<void> _openShellShore() async {
    AudioService.instance.sfx('whoosh');
    Feel.tap();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ShellShoreAdventure()),
    );
    if (!mounted) return;
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _openKelpForest() async {
    AudioService.instance.sfx('whoosh');
    Feel.tap();
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const KelpForestAdventure()),
    );
    if (!mounted) return;
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _openFingerReef() async {
    AudioService.instance.sfx('whoosh');
    Feel.tap();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JarimatikaScreen(practice: true)),
    );
  }

  Future<void> _openJournal() async {
    AudioService.instance.sfx('whoosh');
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JournalScreen()),
    );
  }

  Future<void> _openRewards() async {
    AudioService.instance.sfx('whoosh');
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RewardsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final coralDone = progress.hasCompletedAdventure('coral_cove');
    final shellOpen =
        progress.isLocationUnlocked('shell_shore') || coralDone;
    final kelpOpen = progress.hasCompletedAdventure('shell_shore');

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _life,
            builder: (context, _) => CustomPaint(
              painter: _WorldOceanPainter(t: _life.value),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _MapTopBar(
                  onJournal: _openJournal,
                  onSettings: () => showSettingsSheet(context),
                  onChest: _openRewards,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: TurtleTalk(
                    message: coralDone
                        ? 'Coral Cove friends are in your journal. Where next?'
                        : _greetings[_greeting],
                    size: 88,
                    onTap: _nextGreeting,
                    cheering: coralDone,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return AnimatedBuilder(
                        animation: _life,
                        builder: (context, _) {
                          final t = _life.value;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Ambient reef fish
                              for (final fish in _ambientFish)
                                Positioned(
                                  left: constraints.maxWidth *
                                      ((fish.x + t * fish.speed) % 1.2 - 0.1),
                                  top: constraints.maxHeight * fish.y +
                                      math.sin(t * math.pi * 2 + fish.phase) *
                                          6,
                                  child: Text(
                                    fish.emoji,
                                    style: TextStyle(fontSize: fish.size),
                                  ),
                                ),

                              // Coral Cove — primary hotspot (lower left / center)
                              Positioned(
                                left: constraints.maxWidth * 0.08,
                                top: constraints.maxHeight * 0.28,
                                child: _Hotspot(
                                  label: 'Coral Cove',
                                  emoji: '🪸',
                                  color: OceanColors.aqua,
                                  pulse: t,
                                  badge: coralDone ? '✓' : null,
                                  onTap: _openCoralCove,
                                ),
                              ),

                              // Turtle sparkle when not yet discovered
                              if (!progress.hasDiscovered('green_turtle'))
                                Positioned(
                                  left: constraints.maxWidth * 0.28,
                                  top: constraints.maxHeight * 0.18 +
                                      math.sin(t * math.pi * 2) * 10,
                                  child: GestureDetector(
                                    onTap: _openCoralCove,
                                    child: const Text(
                                      '🐢',
                                      style: TextStyle(fontSize: 36),
                                    ),
                                  ),
                                ),

                              // Shell Shore
                              Positioned(
                                right: constraints.maxWidth * 0.06,
                                top: constraints.maxHeight * 0.20,
                                child: _Hotspot(
                                  label: 'Shell Shore',
                                  emoji: '🐚',
                                  color: OceanColors.coral,
                                  pulse: t,
                                  locked: !shellOpen,
                                  onTap: shellOpen
                                      ? _openShellShore
                                      : () => _openLocked(
                                            'Shell Shore',
                                            'Finish Coral Cove to open Shell Shore!',
                                          ),
                                ),
                              ),

                              // Kelp Forest
                              Positioned(
                                left: constraints.maxWidth * 0.12,
                                bottom: constraints.maxHeight * 0.12,
                                child: _Hotspot(
                                  label: 'Kelp Forest',
                                  emoji: '🌿',
                                  color: OceanColors.lilac,
                                  pulse: t,
                                  locked: !kelpOpen,
                                  onTap: kelpOpen
                                      ? _openKelpForest
                                      : () => _openLocked(
                                            'Kelp Forest',
                                            'Finish Shell Shore to open Kelp Forest!',
                                          ),
                                ),
                              ),

                              // Finger Reef
                              Positioned(
                                right: constraints.maxWidth * 0.10,
                                bottom: constraints.maxHeight * 0.16,
                                child: _Hotspot(
                                  label: 'Finger Reef',
                                  emoji: '✋',
                                  color: OceanColors.sunny,
                                  pulse: t,
                                  locked: !progress.jarimatikaChallengeUnlocked,
                                  onTap: progress.jarimatikaChallengeUnlocked
                                      ? _openFingerReef
                                      : () => _openLocked(
                                            'Finger Reef',
                                            'Complete more adventures to unlock Finger Reef!',
                                          ),
                                ),
                              ),

                              // Discovery count chip
                              Positioned(
                                left: 16,
                                bottom: 8,
                                child: GestureDetector(
                                  onTap: _openJournal,
                                  child: OceanPill(
                                    label:
                                        '${progress.discoveryCount} friends',
                                    emoji: '📖',
                                    compact: true,
                                    color: OceanColors.shell,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientFish {
  const _AmbientFish(this.x, this.y, this.speed, this.phase, this.size, this.emoji);
  final double x;
  final double y;
  final double speed;
  final double phase;
  final double size;
  final String emoji;
}

const _ambientFish = [
  _AmbientFish(0.0, 0.15, 0.35, 0.2, 22, '🐟'),
  _AmbientFish(0.4, 0.45, 0.22, 1.1, 18, '🐠'),
  _AmbientFish(0.7, 0.70, 0.28, 2.0, 20, '🐡'),
];

class _MapTopBar extends StatelessWidget {
  const _MapTopBar({
    required this.onJournal,
    required this.onSettings,
    required this.onChest,
  });

  final VoidCallback onJournal;
  final VoidCallback onSettings;
  final VoidCallback onChest;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Math Ocean',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: OceanColors.shell,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    height: 1,
                    shadows: const [
                      Shadow(color: Color(0x66000000), blurRadius: 10),
                    ],
                  ),
                ),
                Text(
                  'UNDERWATER ADVENTURE',
                  style: TextStyle(
                    color: OceanColors.aqua,
                    fontSize: 10,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Baloo2',
                    shadows: const [
                      Shadow(color: Color(0x88000000), blurRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
          OceanPill(
            label: '${progress.pearls}',
            emoji: '💧',
            compact: true,
          ),
          const SizedBox(width: 6),
          RoundIconButton(
            icon: Icons.menu_book_rounded,
            size: 42,
            color: Colors.white.withValues(alpha: 0.18),
            iconColor: OceanColors.foam,
            tooltip: 'Discovery journal',
            onTap: onJournal,
          ),
          const SizedBox(width: 6),
          RoundIconButton(
            icon: Icons.card_giftcard_rounded,
            size: 42,
            color: Colors.white.withValues(alpha: 0.18),
            iconColor: OceanColors.foam,
            tooltip: 'Treasure grotto',
            onTap: onChest,
          ),
          const SizedBox(width: 6),
          RoundIconButton(
            icon: Icons.settings_rounded,
            size: 42,
            color: Colors.white.withValues(alpha: 0.18),
            iconColor: OceanColors.foam,
            tooltip: 'Settings',
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _Hotspot extends StatelessWidget {
  const _Hotspot({
    required this.label,
    required this.emoji,
    required this.color,
    required this.pulse,
    required this.onTap,
    this.locked = false,
    this.badge,
  });

  final String label;
  final String emoji;
  final Color color;
  final double pulse;
  final VoidCallback onTap;
  final bool locked;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final glow = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(pulse * math.pi * 2));
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: locked
                        ? [
                            Colors.white.withValues(alpha: 0.25),
                            Colors.white.withValues(alpha: 0.12),
                          ]
                        : [
                            Color.lerp(color, Colors.white, 0.35)!,
                            color,
                          ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: locked ? 0.3 : glow),
                    width: 3,
                  ),
                  boxShadow: locked
                      ? null
                      : [
                          BoxShadow(
                            color: color.withValues(alpha: 0.45 * glow),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                ),
                child: Text(
                  locked ? '🔒' : emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              if (badge != null)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: OceanColors.sunny,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: OceanColors.abyss.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: OceanColors.foam,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldOceanPainter extends CustomPainter {
  _WorldOceanPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF034556),
          Color(0xFF0A7A88),
          Color(0xFF0C5A68),
          Color(0xFF032A36),
        ],
        stops: [0, 0.35, 0.7, 1],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // God rays
    final ray = Paint()..color = const Color(0x33FFE8A0);
    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.15 + i * 0.18 + math.sin(t * math.pi * 2 + i) * 0.02);
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 40, 0)
        ..lineTo(x + 90, size.height * 0.7)
        ..lineTo(x - 20, size.height * 0.7)
        ..close();
      canvas.drawPath(path, ray);
    }

    // Seabed
    final sand = Paint()..color = const Color(0xFFC9A86C).withValues(alpha: 0.45);
    final bed = Path()
      ..moveTo(0, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.76,
        size.width * 0.5,
        size.height * 0.84,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.90,
        size.width,
        size.height * 0.80,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(bed, sand);

    // Soft coral mounds (map landmarks, not cards)
    void mound(double cx, double cy, double r, Color c) {
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()..color = c.withValues(alpha: 0.35),
      );
    }

    mound(size.width * 0.22, size.height * 0.55, 55, const Color(0xFFFF7A6A));
    mound(size.width * 0.78, size.height * 0.42, 48, const Color(0xFFFFB07A));
    mound(size.width * 0.30, size.height * 0.78, 40, const Color(0xFF7BC47F));
    mound(size.width * 0.72, size.height * 0.72, 44, const Color(0xFFFFD06A));

    // Bubbles
    final bubble = Paint()..color = Colors.white.withValues(alpha: 0.15);
    for (var i = 0; i < 12; i++) {
      final x = size.width * ((0.08 * i + t * 0.15) % 1);
      final y = size.height * (1 - ((t * 0.4 + i * 0.07) % 1));
      canvas.drawCircle(Offset(x, y), 3 + (i % 3).toDouble(), bubble);
    }
  }

  @override
  bool shouldRepaint(covariant _WorldOceanPainter oldDelegate) =>
      oldDelegate.t != t;
}
