import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/catalog.dart';
import '../core/models.dart';
import '../core/progress.dart';
import '../theme.dart';
import '../widgets/ocean_background.dart';
import '../widgets/turtle_companion.dart';
import '../widgets/ui_kit.dart';
import 'rewards_screen.dart';
import 'settings_sheet.dart';
import 'station_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;
  int _greeting = 0;

  static const _greetings = [
    'Hi! I\'m Tala. Ready to count treasures with me?',
    'The reef is full of numbers today. Shall we dive in?',
    'Tap a shell to start a mission. I\'ll swim beside you!',
    'Psst… the Finger Reef opens when your maths is strong.',
  ];

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  void _nextGreeting() {
    setState(() => _greeting = (_greeting + 1) % _greetings.length);
    AudioService.instance.speak(_greetings[_greeting]);
    AudioService.instance.sfx('bubble');
  }

  Future<void> _openStation(StationKind kind) async {
    AudioService.instance.sfx('whoosh');
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StationScreen(kind: kind)),
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
    final width = MediaQuery.sizeOf(context).width;
    final wide = width > 700;

    return Scaffold(
      body: OceanBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    sliver: SliverToBoxAdapter(
                      child: _TopBar(wide: wide),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    sliver: SliverToBoxAdapter(
                      child: TurtleTalk(
                        message: _greetings[_greeting],
                        size: wide ? 122 : 104,
                        onTap: _nextGreeting,
                        cheering: progress.completedMissions > 0,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Text(
                            'The reef map',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: OceanColors.foam,
                                  fontWeight: FontWeight.w800,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x55000000),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                          ),
                          const SizedBox(width: 8),
                          const Text('🐚', style: TextStyle(fontSize: 18)),
                          const Spacer(),
                          OceanPill(
                            label: '${progress.totalStars} stars',
                            emoji: '⭐',
                            compact: true,
                            color: OceanColors.abyss.withValues(alpha: 0.35),
                            foreground: OceanColors.foam,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    sliver: SliverList.builder(
                      itemCount: StationKind.values.length + 1,
                      itemBuilder: (context, index) {
                        if (index == StationKind.values.length) {
                          return _ChestCard(onTap: _openRewards);
                        }
                        final kind = StationKind.values[index];
                        return AnimatedBuilder(
                          animation: _bob,
                          builder: (context, child) {
                            final y = math.sin(
                                  _bob.value * math.pi * 2 + index * 1.15,
                                ) *
                                2.2;
                            return Transform.translate(
                              offset: Offset(0, y),
                              child: child,
                            );
                          },
                          child: _StationCard(
                            kind: kind,
                            progress: progress,
                            alignRight: index.isOdd,
                            onTap: () => _openStation(kind),
                          ),
                        );
                      },
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 28)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [OceanColors.aqua, OceanColors.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 2,
            ),
            boxShadow: oceanShadow(blur: 16, y: 6),
          ),
          child: const Text('🧮', style: TextStyle(fontSize: 26)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Math Rings',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: OceanColors.shell,
                      fontSize: wide ? 31 : 26,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      shadows: const [
                        Shadow(color: Color(0x66000000), blurRadius: 10),
                      ],
                    ),
              ),
              Text(
                'OCEAN NUMBERLAND',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: OceanColors.aqua,
                  fontSize: wide ? 11 : 9.5,
                  letterSpacing: 1.7,
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
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            OceanPill(
              label: '${progress.pearls}',
              emoji: '💧',
              compact: true,
            ),
            const SizedBox(height: 5),
            OceanPill(
              label: '${progress.totalStars}',
              emoji: '⭐',
              compact: true,
            ),
          ],
        ),
        const SizedBox(width: 8),
        RoundIconButton(
          icon: Icons.settings_rounded,
          size: 42,
          color: Colors.white.withValues(alpha: 0.16),
          iconColor: OceanColors.foam,
          tooltip: 'Settings',
          onTap: () => showSettingsSheet(context),
        ),
      ],
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.kind,
    required this.progress,
    required this.alignRight,
    required this.onTap,
  });

  final StationKind kind;
  final ProgressController progress;
  final bool alignRight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missions = missionsFor(kind);
    final stars = progress.stationStars(kind);
    final maxStars = missions.length * 3;
    final jarima = kind == StationKind.jarimatika;
    final locked = jarima && !progress.jarimatikaChallengeUnlocked;

    return Padding(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: alignRight ? 26 : 0,
        right: alignRight ? 0 : 26,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  OceanColors.shell,
                  Color.lerp(OceanColors.shell, kind.color, 0.22)!,
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.65),
                width: 1.6,
              ),
              boxShadow: oceanShadow(blur: 20, y: 8),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(kind.color, Colors.white, 0.22)!,
                        kind.deepColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: [
                      BoxShadow(
                        color: kind.deepColor.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(kind.icon, color: Colors.white, size: 31),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              kind.stationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: OceanColors.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 19,
                                    height: 1.05,
                                  ),
                            ),
                          ),
                          if (locked)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.lock_rounded,
                                size: 15,
                                color: OceanColors.inkSoft,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        jarima && locked
                            ? 'Practice open · challenge locked'
                            : kind.blurb,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: OceanColors.inkSoft,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              height: 1.1,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          if (jarima)
                            _MasteryPips(progress: progress)
                          else ...[
                            StarRow(stars: _wholeStars(stars), size: 15),
                            const SizedBox(width: 6),
                            Text(
                              '$stars/$maxStars',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: OceanColors.inkSoft,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: kind.deepColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: kind.deepColor,
                    size: 25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _wholeStars(int stars) {
    if (stars <= 0) return 0;
    if (stars >= 9) return 3;
    if (stars >= 5) return 2;
    return 1;
  }
}

class _MasteryPips extends StatelessWidget {
  const _MasteryPips({required this.progress});
  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    final goals = progress.masteryGoals;
    final done = goals.where((g) => g.done).length;
    return Row(
      children: [
        for (var i = 0; i < goals.length; i++)
          Container(
            width: 26,
            height: 6,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: i < done
                  ? OceanColors.lilacDeep
                  : OceanColors.ink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        const SizedBox(width: 4),
        Text(
          progress.jarimatikaChallengeUnlocked ? 'Ready!' : '$done/4',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OceanColors.inkSoft,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

class _ChestCard extends StatelessWidget {
  const _ChestCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10, left: 8, right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8C6DE0), Color(0xFF5F44B8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.6,
            ),
            boxShadow: oceanShadow(blur: 22, y: 9),
          ),
          child: Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Treasure Grotto',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                          ),
                    ),
                    Text(
                      '${progress.treasureCount}/12 treasures · '
                      '${progress.pearls} pearls',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
