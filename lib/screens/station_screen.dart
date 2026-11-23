import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/catalog.dart';
import '../core/models.dart';
import '../core/progress.dart';
import '../theme.dart';
import '../widgets/ocean_background.dart';
import '../widgets/ui_kit.dart';
import 'jarimatika_screen.dart';
import 'kecrekan_mission_screen.dart';

class StationScreen extends StatelessWidget {
  const StationScreen({super.key, required this.kind});

  final StationKind kind;

  void _openMission(BuildContext context, Mission mission) {
    if (mission.station == StationKind.jarimatika) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => JarimatikaScreen(mission: mission)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => KecrekanMissionScreen(mission: mission),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final missions = missionsFor(kind);
    final isJarima = kind == StationKind.jarimatika;

    return Scaffold(
      body: OceanBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: OceanHeader(
                        title: kind.stationName,
                        subtitle:
                            '${kind.label} · ${progress.stationStars(kind)} '
                            'of ${missions.length * 3} stars',
                        onBack: () => Navigator.of(context).maybePop(),
                        trailing: RoundIconButton(
                          icon: Icons.volume_up_rounded,
                          size: 42,
                          color: Colors.white.withValues(alpha: 0.16),
                          iconColor: OceanColors.foam,
                          onTap: () => AudioService.instance.speak(
                            '${kind.stationName}. ${kind.blurb}.',
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _StationHero(
                        kind: kind,
                        progress: progress,
                        onDive: () {
                          final mission = randomChallengeFor(kind);
                          if (isJarima &&
                              !progress.jarimatikaChallengeUnlocked) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const JarimatikaScreen(practice: true),
                              ),
                            );
                            return;
                          }
                          if (isJarima &&
                              !progress.isMissionUnlocked(mission)) {
                            showOceanSnack(
                              context,
                              'Finish the earlier finger challenge first.',
                              icon: Icons.lock_rounded,
                            );
                            return;
                          }
                          _openMission(context, mission);
                        },
                      ),
                    ),
                  ),
                  if (isJarima)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _MasteryPanel(progress: progress),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Choose how to explore',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: OceanColors.foam,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _ModeCard(
                            icon: Icons.menu_book_rounded,
                            title: 'Learn',
                            description: isJarima
                                ? 'Discover how the fingers represent numbers.'
                                : kind == StationKind.counting
                                ? 'Learn to count treasures one by one.'
                                : kind == StationKind.addition
                                ? 'See how two groups join together.'
                                : 'See what happens when a group gets smaller.',
                            color: OceanColors.aqua,
                            onTap: () {
                              if (isJarima) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const JarimatikaScreen(learnMode: true),
                                  ),
                                );
                              } else {
                                final lesson = missionsFor(kind).first;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => KecrekanMissionScreen(
                                      mission: lesson,
                                      practice: true,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          _ModeCard(
                            icon: Icons.waves_rounded,
                            title: 'Challenge',
                            description: isJarima
                                ? 'Get a fresh random number and show it with both hands.'
                                : 'Get a fresh task each time. No choosing the answer.',
                            color: OceanColors.sunny,
                            locked: isJarima && !progress.jarimatikaChallengeUnlocked,
                            onTap: () {
                              if (isJarima && !progress.jarimatikaChallengeUnlocked) {
                                showOceanSnack(
                                  context,
                                  'Explore Learn first and build your finger skills to unlock challenges.',
                                  icon: Icons.lock_rounded,
                                );
                                return;
                              }
                              final challenge = randomChallengeFor(kind);
                              _openMission(context, challenge);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OceanColors.shell.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: color, size: 29),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: OceanColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OceanColors.inkSoft,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                locked ? Icons.lock_rounded : Icons.arrow_forward_ios_rounded,
                color: OceanColors.inkSoft,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationHero extends StatelessWidget {
  const _StationHero({
    required this.kind,
    required this.progress,
    required this.onDive,
  });

  final StationKind kind;
  final ProgressController progress;
  final VoidCallback onDive;

  @override
  Widget build(BuildContext context) {
    final missions = missionsFor(kind);
    final stars = progress.stationStars(kind);
    final maxStars = missions.length * 3;
    final isJarima = kind == StationKind.jarimatika;
    final challengeReady = progress.jarimatikaChallengeUnlocked;
    final label = isJarima && !challengeReady
        ? 'Practice the hands'
        : stars >= maxStars
        ? 'Play again'
        : 'Dive in';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kind.deepColor,
            Color.lerp(kind.deepColor, OceanColors.abyss, 0.45)!,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.5,
        ),
        boxShadow: oceanShadow(blur: 24, y: 10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(kind.icon, color: Colors.white, size: 38),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.blurb,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!isJarima)
                      Row(
                        children: [
                          StarRow(stars: (stars / 3).ceil(), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$stars / $maxStars',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      )
                    else
                      Text(
                        challengeReady
                            ? 'Challenge unlocked — first-try mastery!'
                            : 'Practice is open. Build mastery to unlock the '
                                  'challenge.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BigButton(
                  label: label,
                  icon: isJarima && !challengeReady
                      ? Icons.back_hand_rounded
                      : Icons.waves_rounded,
                  colors: [
                    kind.color,
                    Color.lerp(kind.color, Colors.white, 0.3)!,
                  ],
                  textColor: OceanColors.ink,
                  onTap: onDive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MasteryPanel extends StatelessWidget {
  const _MasteryPanel({required this.progress});
  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    final goals = progress.masteryGoals;
    final ready = progress.jarimatikaChallengeUnlocked;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      radius: 22,
      color: OceanColors.shell.withValues(alpha: 0.95),
      borderColor: Colors.white.withValues(alpha: 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.verified_rounded : Icons.school_rounded,
                color: ready ? OceanColors.teal : OceanColors.lilacDeep,
                size: 21,
              ),
              const SizedBox(width: 7),
              Text(
                ready ? 'Mastery complete!' : 'Mastery evidence',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: OceanColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              OceanPill(
                label: ready ? 'Unlocked' : 'Practice open',
                emoji: ready ? '✅' : '✋',
                compact: true,
                color: (ready ? OceanColors.aqua : OceanColors.lilac)
                    .withValues(alpha: 0.18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final goal in goals)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Text(goal.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      goal.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OceanColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 74,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: goal.fraction,
                        minHeight: 7,
                        backgroundColor: OceanColors.ink.withValues(
                          alpha: 0.08,
                        ),
                        valueColor: AlwaysStoppedAnimation(
                          goal.done ? OceanColors.aqua : OceanColors.lilac,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${goal.current}/${goal.goal}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OceanColors.inkSoft,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Mastery counts correct answers on the first try. Practice never '
            'locks, so there is always a way to keep going.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OceanColors.inkSoft.withValues(alpha: 0.8),
              fontSize: 10.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({
    required this.index,
    required this.mission,
    required this.stars,
    required this.unlocked,
    required this.onTap,
  });

  final int index;
  final Mission mission;
  final int stars;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1 : 0.72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color: OceanColors.shell.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.4,
              ),
              boxShadow: oceanShadow(blur: 14, y: 6),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: stars > 0
                        ? OceanColors.aqua.withValues(alpha: 0.22)
                        : OceanColors.ink.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    mission.emoji,
                    style: const TextStyle(fontSize: 21),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: OceanColors.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              height: 1.05,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mission.shortPrompt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OceanColors.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (!unlocked)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.lock_rounded,
                      color: OceanColors.inkSoft,
                      size: 18,
                    ),
                  )
                else
                  StarRow(stars: stars, size: 15),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: OceanColors.inkSoft,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FreePlayCard extends StatelessWidget {
  const _FreePlayCard({required this.kind, required this.onTap});
  final StationKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OceanColors.abyss.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Text('💧', style: TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Free play',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: OceanColors.foam,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Slide beads with no timer, no score, and no wrong answers.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OceanColors.mint.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: OceanColors.mint),
          ],
        ),
      ),
    );
  }
}
