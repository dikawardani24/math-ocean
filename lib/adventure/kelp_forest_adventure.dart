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

/// Kelp Forest Adventure: Seahorse subtraction (removing quantities).
class KelpForestAdventure extends StatefulWidget {
  const KelpForestAdventure({super.key});

  @override
  State<KelpForestAdventure> createState() => _KelpForestAdventureState();
}

class _KelpForestAdventureState extends State<KelpForestAdventure>
    with TickerProviderStateMixin {
  static const _adventureId = 'kelp_forest';

  late final OceanCreature _seahorse;
  late KecrekanController _kecrekan;

  late int _initialCount;
  late int _subtractCount;
  late int _targetRemaining;
  bool _completed = false;
  String _dialogue = '';

  @override
  void initState() {
    super.initState();
    _seahorse = creatureById('seahorse')!;

    final rng = math.Random();
    _initialCount = 4 + rng.nextInt(2); // 4 or 5
    _subtractCount = 1 + rng.nextInt(2); // 1 or 2
    _targetRemaining = _initialCount - _subtractCount;

    _kecrekan = KecrekanController(
      initialCount: 0,
      activeRowCount: KecrekanMath.rowsForChallenge(start: 0, target: _targetRemaining),
    );

    _dialogue = 'In the Kelp Forest, $_initialCount seahorses were swimming. $_subtractCount swam away into a cave. How many remain?';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioService.instance.speak(_dialogue);
    });

    _kecrekan.addListener(_onAbacusChanged);
  }

  @override
  void dispose() {
    _kecrekan.removeListener(_onAbacusChanged);
    _kecrekan.dispose();
    AudioService.instance.stopSpeaking();
    super.dispose();
  }

  void _speak(String text) {
    setState(() => _dialogue = text);
    AudioService.instance.speak(text);
  }

  void _onAbacusChanged() {
    if (_completed) return;
    if (_kecrekan.total == _targetRemaining) {
      _triggerSuccess();
    }
  }

  void _triggerSuccess() {
    setState(() => _completed = true);
    final progress = ProgressScope.read(context);
    final mission = Mission(
      id: 'kelp_subtraction',
      station: StationKind.subtraction,
      title: 'Kelp Forest Subtraction',
      story: 'Calculate remaining seahorses in the kelp.',
      target: _targetRemaining,
      emoji: '🌿',
    );
    progress.recordSuccess(mission, stars: 3, firstTry: true);
    progress.discoverCreature(_seahorse.id);
    progress.completeAdventure(_adventureId);
    progress.addPearls(1);

    AudioService.instance.sfx('mission_complete');
    Feel.success();
    _speak('Wonderful! $_initialCount minus $_subtractCount leaves $_targetRemaining seahorses. Finger Reef is now ready!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF044852), Color(0xFF076673), Color(0xFF022026)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
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
                          'Kelp Forest',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: OceanColors.foam,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      OceanPill(
                        label: '$_initialCount - $_subtractCount = ?',
                        emoji: '➖',
                        compact: true,
                        color: OceanColors.lilac,
                      ),
                    ],
                  ),
                ),
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
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🌿', style: TextStyle(fontSize: 72)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < _initialCount; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      '🐴',
                                      style: TextStyle(
                                        fontSize: 32,
                                        color: i >= _targetRemaining
                                            ? Colors.white.withValues(alpha: 0.3)
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '($_subtractCount swam into the cave)',
                              style: const TextStyle(color: OceanColors.sunny, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
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
                            border: Border.all(color: OceanColors.lilac, width: 2.5),
                            boxShadow: oceanShadow(blur: 16, y: 6),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🌿 Kelp Abacus Total: ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                                  Text('${_kecrekan.total} / $_targetRemaining', style: const TextStyle(color: OceanColors.sunny, fontWeight: FontWeight.w800, fontSize: 14)),
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
          if (_completed)
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
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🐴✨', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 12),
                        Text('Seahorse Discovered!', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 20),
                        BigButton(
                          label: 'Continue Adventure',
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
}
