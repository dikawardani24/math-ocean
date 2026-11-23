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

/// Shell Shore Adventure: Hermit crab addition (combining two groups of shells).
class ShellShoreAdventure extends StatefulWidget {
  const ShellShoreAdventure({super.key});

  @override
  State<ShellShoreAdventure> createState() => _ShellShoreAdventureState();
}

class _ShellShoreAdventureState extends State<ShellShoreAdventure>
    with TickerProviderStateMixin {
  static const _adventureId = 'shell_shore';

  late final OceanCreature _crab;
  late final AnimationController _swim;
  late KecrekanController _kecrekan;

  late int _groupA;
  late int _groupB;
  late int _targetTotal;
  bool _completed = false;
  String _dialogue = '';

  @override
  void initState() {
    super.initState();
    _crab = creatureById('hermit_crab')!;

    final rng = math.Random();
    _groupA = 2 + rng.nextInt(2); // 2 or 3
    _groupB = 1 + rng.nextInt(2); // 1 or 2
    _targetTotal = _groupA + _groupB;

    _kecrekan = KecrekanController(
      initialCount: 0,
      activeRowCount: KecrekanMath.rowsForChallenge(start: 0, target: _targetTotal),
    );

    _swim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _dialogue = 'Welcome to Shell Shore! A hermit crab found $_groupA shells and discovered $_groupB more. How many in total?';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioService.instance.speak(_dialogue);
    });

    _kecrekan.addListener(_onAbacusChanged);
  }

  @override
  void dispose() {
    _kecrekan.removeListener(_onAbacusChanged);
    _swim.dispose();
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
    if (_kecrekan.total == _targetTotal) {
      _triggerSuccess();
    }
  }

  void _triggerSuccess() {
    setState(() => _completed = true);
    final progress = ProgressScope.read(context);
    final mission = Mission(
      id: 'shell_addition',
      station: StationKind.addition,
      title: 'Shell Shore Addition',
      story: 'Combine shell groups for the hermit crab.',
      target: _targetTotal,
      emoji: '🐚',
    );
    progress.recordSuccess(mission, stars: 3, firstTry: true);
    progress.discoverCreature(_crab.id);
    progress.completeAdventure(_adventureId);
    progress.unlockLocation('kelp_forest');
    progress.addPearls(1);

    AudioService.instance.sfx('mission_complete');
    Feel.success();
    _speak('Brilliant! $_groupA plus $_groupB equals $_targetTotal shells! Kelp Forest is now unlocked.');
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
                colors: [Color(0xFF075E6E), Color(0xFF0A8494), Color(0xFF043642)],
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
                          'Shell Shore',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: OceanColors.foam,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      OceanPill(
                        label: '$_groupA + $_groupB = ?',
                        emoji: '➕',
                        compact: true,
                        color: OceanColors.coral,
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
                            const Text('🦀', style: TextStyle(fontSize: 72)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < _groupA; i++)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Text('🐚', style: TextStyle(fontSize: 32)),
                                  ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('+', style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w900)),
                                ),
                                for (var i = 0; i < _groupB; i++)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Text('🐚', style: TextStyle(fontSize: 32)),
                                  ),
                              ],
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
                            border: Border.all(color: OceanColors.coral, width: 2.5),
                            boxShadow: oceanShadow(blur: 16, y: 6),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🐚 Shell Abacus Total: ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                                  Text('${_kecrekan.total} / $_targetTotal', style: const TextStyle(color: OceanColors.sunny, fontWeight: FontWeight.w800, fontSize: 14)),
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
                        const Text('🦀✨', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 12),
                        Text('Hermit Crab Discovered!', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
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
