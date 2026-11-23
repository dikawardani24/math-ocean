import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/catalog.dart';
import '../core/feedback.dart';
import '../core/models.dart';
import '../core/progress.dart';
import '../kecrekan/kecrekan_controller.dart';
import '../kecrekan/kecrekan_math.dart';
import '../kecrekan/kecrekan_stage.dart';
import '../theme.dart';
import '../widgets/ocean_background.dart';
import '../widgets/ui_kit.dart';

/// The mission screen around the real 3D Kecrekan.
class KecrekanMissionScreen extends StatefulWidget {
  const KecrekanMissionScreen({
    super.key,
    this.mission,
    this.practice = false,
    this.practiceKind = StationKind.counting,
  });

  final Mission? mission;
  final bool practice;
  final StationKind practiceKind;

  @override
  State<KecrekanMissionScreen> createState() => _KecrekanMissionScreenState();
}

class _KecrekanMissionScreenState extends State<KecrekanMissionScreen>
    with SingleTickerProviderStateMixin {
  late KecrekanController _controller;
  late int _target;
  late final AnimationController _shake;
  Timer? _speakTimer;

  int _attempts = 0;
  bool _usedHint = false;
  bool _solved = false;
  bool _eventRevealed = false;
  bool _celebrate = false;
  String _encouragement = '';
  int _reward = 0;
  int _stars = 0;

  Mission? get _mission => widget.mission;
  bool get _isPractice => widget.practice || _mission == null;

  @override
  void initState() {
    super.initState();
    _target = _mission?.target ?? _randomTarget();
    _controller = KecrekanController(
      initialCount: _mission?.startValue ?? 0,
      activeRowCount: KecrekanMath.rowsForChallenge(
        start: _mission?.startValue ?? 0,
        target: _target,
      ),
    );
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _speakTimer = Timer(const Duration(milliseconds: 900), _speak);
  }

  int _randomTarget() => 1 + math.Random().nextInt(10);

  void _speak() {
    if (!mounted) return;
    final mission = _mission;
    final line = mission == null
        ? 'Can you make $_target? Explore the beads and find the number.'
        : mission.isAddition
        ? 'Look at the pearls already here. How many can you count?'
        : mission.isSubtraction
        ? 'Look at all the bubbles before anything happens. How many can you count?'
        : mission.voice;
    AudioService.instance.speak(line);
  }

  @override
  void dispose() {
    _speakTimer?.cancel();
    _shake.dispose();
    _controller.dispose();
    AudioService.instance.stopSpeaking();
    super.dispose();
  }

  void _revealEvent() {
    if (_eventRevealed) return;
    setState(() => _eventRevealed = true);
    AudioService.instance.sfx('bubble');
    final line = _mission?.isAddition == true
        ? 'More pearls have arrived! Count the new group. Bring the two groups together. How many pearls are there altogether?'
        : 'Some bubbles have popped and disappeared. Look at the bubbles still floating. How many are left?';
    AudioService.instance.speak(line);
  }

  void _hint() {
    final mission = _mission;
    if (!_eventRevealed &&
        mission != null &&
        (mission.isAddition || mission.isSubtraction)) {
      setState(() => _eventRevealed = true);
    }
    final progress = ProgressScope.read(context);
    setState(() {
      _usedHint = true;
      _encouragement = _mission?.hint ??
          'Move the beads and notice how the group changes.';
    });
    AudioService.instance.sfx('bubble');
    AudioService.instance.speak(_encouragement);
    progress.markTipSeen('hint_${_mission?.id ?? 'practice'}');
  }

  void _wrong() {
    AudioService.instance.sfx('wrong');
    Feel.nope();
    _shake.forward(from: 0);
    setState(() {
      _attempts++;
      _encouragement = _attempts == 1
          ? (_mission?.isAddition == true
                ? 'Look at both groups. How many are together now?'
                : _mission?.isSubtraction == true
                ? 'Some have gone away. Count the ones that are still here.'
                : 'Count the beads you have moved, then try again.')
          : 'Keep exploring. Tala believes in you!';
    });
    AudioService.instance.speak(_encouragement);
  }

  void _check() {
    if (_solved) return;
    if (_controller.total == _target) {
      _success();
    } else {
      _wrong();
    }
  }

  void _success() {
    final progress = ProgressScope.read(context);
    final firstTry = _attempts == 0 && !_usedHint;
    final stars = firstTry ? 3 : (_attempts <= 1 && !_usedHint ? 2 : 1);
    var reward = 0;
    if (!_isPractice && _mission != null) {
      reward = progress.recordSuccess(
        _mission!,
        stars: stars,
        firstTry: firstTry,
      );
    } else {
      progress.recordPractice(
        kind: _mission?.station ?? widget.practiceKind,
        firstTry: firstTry,
        correct: true,
      );
    }
    AudioService.instance.sfx('correct');
    Future.delayed(
      const Duration(milliseconds: 220),
      () => AudioService.instance.sfx('mission_complete'),
    );
    Feel.success();
    AudioService.instance.speak(
      _isPractice
          ? 'That is $_target! Beautiful counting.'
          : 'You did it! $_target beads. ${stars == 1 ? 'One shiny star' : '$stars shiny stars'} for you.',
    );
    setState(() {
      _solved = true;
      _celebrate = true;
      _stars = stars;
      _reward = reward;
    });
    Future.delayed(const Duration(milliseconds: 900), _showRewardSheet);
  }

  Future<void> _showRewardSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: OceanColors.abyss.withValues(alpha: 0.6),
      builder: (sheetContext) => _RewardSheet(
        title: _isPractice ? 'Beautiful counting!' : 'You did it!',
        stars: _isPractice ? 0 : _stars,
        reward: _reward,
        practice: _isPractice,
        equation: _mission == null
            ? null
            : _mission!.isAddition || _mission!.isSubtraction
            ? _mission!.equation
            : 'You counted $_target beads',
        target: _target,
        onAgain: () {
          Navigator.of(sheetContext).pop();
          _again();
        },
        onNext: _isPractice
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                _nextMission();
              },
        onDone: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).maybePop();
        },
      ),
    );
  }

  void _again() {
    setState(() {
      _solved = false;
      _celebrate = false;
      _eventRevealed = false;
      _attempts = 0;
      _usedHint = false;
      _encouragement = '';
      if (_isPractice) _target = _randomTarget();
      _controller.setActiveRowCount(
        KecrekanMath.rowsForChallenge(
          start: _mission?.startValue ?? 0,
          target: _target,
        ),
      );
      _controller.resetTo(_mission?.startValue ?? 0);
    });
    _speak();
  }

  void _nextMission() {
    final current = _mission;
    if (current == null) {
      Navigator.of(context).maybePop();
      return;
    }
    final list = missionsFor(current.station);
    final index = list.indexWhere((m) => m.id == current.id);
    if (index < 0 || index == list.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => KecrekanMissionScreen(mission: list[index + 1]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mission = _mission;
    final title = mission?.title ?? 'Free play';
    final story =
        mission?.story ??
        'Slide beads, count them, and build any number you like. '
            'Can you make $_target?';
    final progress = ProgressScope.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          OceanBackground(
            showSand: false,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    OceanHeader(
                      title: title,
                      subtitle: mission == null
                          ? '${widget.practiceKind.stationName} · free play'
                          : '${mission.station.stationName} · ${mission.station.label}',
                      onBack: () => Navigator.of(context).maybePop(),
                      trailing: RoundIconButton(
                        icon: progress.soundOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        size: 42,
                        color: Colors.white.withValues(alpha: 0.16),
                        iconColor: OceanColors.foam,
                        onTap: () {
                          final on = !progress.soundOn;
                          progress.setSound(on);
                          AudioService.instance.soundOn = on;
                          if (on) AudioService.instance.sfx('ui_tap');
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MissionObjective(
                      emoji: mission?.emoji ?? '💧',
                      title: mission?.title ?? 'Free play',
                      target: _target,
                      prompt: mission == null
                          ? 'Make $_target'
                          : mission.isAddition
                          ? 'How many altogether?'
                          : mission.isSubtraction
                          ? 'How many are left?'
                          : mission.question,
                      onHelp: () {
                        showDialog<void>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: OceanColors.shell,
                            title: Text(
                              mission?.title ?? 'How to play',
                              style: const TextStyle(
                                color: OceanColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            content: Text(
                              story,
                              style: const TextStyle(
                                color: OceanColors.ink,
                                height: 1.35,
                              ),
                            ),
                            actions: [
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  _speak();
                                },
                                icon: const Icon(Icons.volume_up_rounded),
                                label: const Text('Listen'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                child: const Text('Got it'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (mission != null &&
                        (mission.isAddition || mission.isSubtraction)) ...[
                      const SizedBox(height: 5),
                      _OperationStoryStrip(
                        mission: mission,
                        revealed: _eventRevealed,
                      ),
                      const SizedBox(height: 5),
                    ],
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _shake,
                        builder: (context, child) {
                          final t = _shake.value;
                          final dx = math.sin(t * math.pi * 7) * (1 - t) * 9;
                          return Transform.translate(
                            offset: Offset(dx, 0),
                            child: child,
                          );
                        },
                        child: IgnorePointer(
                          ignoring: mission != null &&
                              (mission.isAddition || mission.isSubtraction) &&
                              !_eventRevealed,
                          child: KecrekanStage(
                            controller: _controller,
                            showTotal: false,
                            showResetButton: false,
                            showHintOverlay: false,
                            onInteraction: () {
                              if (_encouragement.isNotEmpty) {
                                setState(() => _encouragement = '');
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    if (_encouragement.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _TipLine(text: _encouragement),
                      ),
                    const SizedBox(height: 6),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final total = _controller.total;
                        return Row(
                          children: [
                            _TotalChip(
                              total: total,
                              target: _target,
                              showTarget:
                                  _mission == null ||
                                  (!_mission!.isAddition &&
                                      !_mission!.isSubtraction),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: BigButton(
                                label: _solved
                                    ? 'Solved!'
                                    : mission != null &&
                                          (mission.isAddition ||
                                              mission.isSubtraction) &&
                                          !_eventRevealed
                                    ? 'Watch what happens'
                                    : 'Check my beads',
                                icon: _solved
                                    ? Icons.check_circle_rounded
                                    : Icons.chevron_right_rounded,
                                colors: _solved
                                    ? const [OceanColors.mint, OceanColors.aqua]
                                    : const [
                                        OceanColors.sunny,
                                        OceanColors.coral,
                                      ],
                                onTap: mission != null &&
                                        (mission.isAddition ||
                                            mission.isSubtraction) &&
                                        !_eventRevealed
                                    ? _revealEvent
                                    : _check,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _hint,
                          icon: const Icon(Icons.lightbulb_rounded, size: 18),
                          label: const Text('Hint'),
                          style: TextButton.styleFrom(
                            foregroundColor: OceanColors.mint,
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () {
                            AudioService.instance.sfx('reset');
                            _controller.resetTo(_mission?.startValue ?? 0);
                            setState(() {
                              _eventRevealed = false;
                              _solved = false;
                              _celebrate = false;
                              _attempts = 0;
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Start over'),
                          style: TextButton.styleFrom(
                            foregroundColor: OceanColors.mint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_celebrate) const CelebrationBurst(),
        ],
      ),
    );
  }
}


class _MissionObjective extends StatelessWidget {
  const _MissionObjective({
    required this.emoji,
    required this.title,
    required this.target,
    required this.prompt,
    required this.onHelp,
  });

  final String emoji;
  final String title;
  final int target;
  final String prompt;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: OceanColors.shell.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
              boxShadow: oceanShadow(blur: 9, y: 3),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: OceanColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Baloo2',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: OceanColors.teal,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    prompt,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Baloo2',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 7),
        Material(
          color: OceanColors.shell.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Mission help',
            visualDensity: VisualDensity.compact,
            onPressed: onHelp,
            icon: const Icon(Icons.help_outline_rounded, color: OceanColors.teal),
          ),
        ),
      ],
    );
  }
}

/// Makes the two quantities visible as separate concrete groups. The
/// Kecrekan starts with the first group already built; the second group is
/// the new arrival or the group that disappears in the story.
class _OperationStoryStrip extends StatelessWidget {
  const _OperationStoryStrip({
    required this.mission,
    required this.revealed,
  });

  final Mission mission;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final firstCount = mission.isAddition ? (mission.a ?? 0) : (mission.start ?? 0);
    final secondCount = mission.b ?? 0;
    final firstLabel = mission.isAddition ? 'Already here' : 'At the start';
    final secondLabel = mission.isAddition ? 'New arrivals' : 'Popped';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: OceanColors.abyss.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StoryGroup(
              count: firstCount,
              emoji: mission.emoji,
              label: firstLabel,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              mission.isAddition ? '+' : '−',
              style: const TextStyle(
                color: OceanColors.foam,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: _StoryGroup(
              count: revealed ? secondCount : 0,
              emoji: mission.emoji,
              label: revealed ? secondLabel : 'Not yet',
              faded: mission.isSubtraction,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              '= ?',
              style: TextStyle(
                color: OceanColors.sunny,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryGroup extends StatelessWidget {
  const _StoryGroup({
    required this.count,
    required this.emoji,
    required this.label,
    this.faded = false,
  });

  final int count;
  final String emoji;
  final String label;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: OceanColors.foam.withValues(alpha: 0.82),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            fontFamily: 'Baloo2',
          ),
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 1,
          runSpacing: 1,
          children: List.generate(
            count,
            (_) => Opacity(
              opacity: faded ? 0.42 : 1,
              child: Text(emoji, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalChip extends StatelessWidget {
  const _TotalChip({
    required this.total,
    required this.target,
    this.showTarget = true,
  });
  final int total;
  final int target;
  final bool showTarget;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: OceanColors.shell.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        boxShadow: oceanShadow(blur: 14, y: 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$total',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: showTarget && total == target
                  ? OceanColors.teal
                  : OceanColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 27,
              height: 1,
            ),
          ),
          const SizedBox(width: 6),
          if (showTarget)
            Text(
              '/ $target',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OceanColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.lightbulb_rounded, color: OceanColors.sunny, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OceanColors.mint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RewardSheet extends StatelessWidget {
  const _RewardSheet({
    required this.title,
    required this.stars,
    required this.reward,
    required this.practice,
    required this.target,
    required this.onAgain,
    required this.onDone,
    this.onNext,
    this.equation,
  });

  final String title;
  final int stars;
  final int reward;
  final bool practice;
  final int target;
  final String? equation;
  final VoidCallback onAgain;
  final VoidCallback onDone;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: OceanColors.shell,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: oceanShadow(blur: 30, y: 12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: OceanColors.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              const Text('🐢', style: TextStyle(fontSize: 44)),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: OceanColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 30,
                ),
              ),
              if (equation != null)
                Text(
                  equation!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: OceanColors.teal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (!practice) ...[
                const SizedBox(height: 8),
                StarRow(stars: stars, size: 42),
                const SizedBox(height: 4),
                Text(
                  stars == 3
                      ? 'Perfect first try!'
                      : stars == 2
                      ? 'Lovely work!'
                      : 'You kept going — that counts!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OceanColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'You made $target. Practice makes progress!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OceanColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (reward > 0) ...[
                const SizedBox(height: 10),
                OceanPill(
                  label: '+$reward pearls',
                  emoji: '💧',
                  color: OceanColors.mint.withValues(alpha: 0.8),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: BigButton(
                      label: practice ? 'Another' : 'Next',
                      icon: Icons.arrow_forward_rounded,
                      onTap: onNext ?? onAgain,
                      colors: const [OceanColors.aqua, OceanColors.teal],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: BigButton(
                      label: practice ? 'Reset' : 'Replay',
                      icon: Icons.refresh_rounded,
                      height: 48,
                      colors: const [Color(0xFFE6F5F1), Color(0xFFCDEAE4)],
                      onTap: onAgain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BigButton(
                      label: 'Map',
                      icon: Icons.map_rounded,
                      height: 48,
                      colors: const [Color(0xFFFFE6BE), Color(0xFFFFD28C)],
                      onTap: onDone,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
