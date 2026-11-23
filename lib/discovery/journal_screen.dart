import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/progress.dart';
import '../creatures/creature.dart';
import '../creatures/creature_catalog.dart';
import '../theme.dart';
import '../widgets/ocean_background.dart';
import '../widgets/ui_kit.dart';

/// Discovery journal — supplements exploration; never replaces it.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final discovered = kCreatures
        .where((c) => progress.hasDiscovered(c.id))
        .toList();
    final locked = kCreatures
        .where((c) => !progress.hasDiscovered(c.id))
        .toList();

    return Scaffold(
      body: OceanBackground(
        showFish: false,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
                        'Discovery Journal',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: OceanColors.foam,
                          fontWeight: FontWeight.w800,
                          shadows: const [
                            Shadow(color: Color(0x66000000), blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                    OceanPill(
                      label: '${discovered.length}/${kCreatures.length}',
                      emoji: '🐢',
                      compact: true,
                      color: OceanColors.shell,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  discovered.isEmpty
                      ? 'Dive into Coral Cove to meet your first ocean friend!'
                      : 'Friends you have met on your adventures.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: OceanColors.foam,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    for (final creature in discovered)
                      _CreatureEntry(
                        creature: creature,
                        locked: false,
                        onTap: () {
                          AudioService.instance.sfx('bubble');
                          AudioService.instance.speak(
                            '${creature.name}. ${creature.funFact}.',
                          );
                        },
                      ),
                    for (final creature in locked)
                      _CreatureEntry(creature: creature, locked: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatureEntry extends StatelessWidget {
  const _CreatureEntry({
    required this.creature,
    required this.locked,
    this.onTap,
  });

  final OceanCreature creature;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: locked
                  ? Colors.white.withValues(alpha: 0.08)
                  : OceanColors.shell.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: locked ? 0.15 : 0.55),
              ),
              boxShadow: locked ? null : oceanShadow(blur: 14, y: 5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: locked
                        ? Colors.white12
                        : OceanColors.aqua.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    locked ? '❓' : creature.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: locked
                      ? Text(
                          'Mystery friend',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: OceanColors.foam.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w700,
                              ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              creature.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: OceanColors.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '🏠 ${creature.habitat}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: OceanColors.inkSoft,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              '🍃 ${creature.diet}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: OceanColors.inkSoft,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              '✨ ${creature.funFact}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: OceanColors.inkSoft,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
