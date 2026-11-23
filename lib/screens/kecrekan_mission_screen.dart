import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/catalog.dart';
import '../core/feedback.dart';
import '../core/models.dart';
import '../core/progress.dart';
import '../kecrekan/kecrekan_controller.dart';
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
    _controller = KecrekanController(initialCount: _mission?.startValue ?? 0);
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _speakTimer = Timer(const Duration(milliseconds: 900), _speak);
  }

  int _randomTarget() => 1 + math.Random().nextInt(10);

  void _speak() {
    if (!mounted) return;
    final line =
        _mission?.voice ?? 'Can you make $_target? Tap the beads to count.';
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

  void _hint() {
    final progress = ProgressScope.read(context);
    setState(() {
      _usedHint = true;
      _encouragement =
          _mission?.hint ??
          'Tap one bead at a time. Each bead you slide over adds one.';
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
          ? 'Almost! Count the beads you slid over, then try again.'
          : 'Keep going. Tala believes in you!';
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
      _attempts = 0;
      _usedHint = false;
      _encouragement = '';
      if (_isPractice) _target = _randomTarget();
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
                    const SizedBox(height: 6),
                    _PromptCard(
                      emoji: mission?.emoji ?? '💧',
                      story: story,
                      target: _target,
                      equation: mission?.question,
                      onSpeak: _speak,
                      compact: true,
                    ),
                    const SizedBox(height: 6),
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
                        child: KecrekanStage(
                          controller: _controller,
                          onInteraction: () {
                            if (_encouragement.isNotEmpty) {
                              setState(() => _encouragement = '');
                            }
                          },
                        ),
                      ),
                    ),
                    if (_encouragement.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _TipLine(text: _encouragement),
                      ),
                    const SizedBox(height: 10),
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
                                label: _solved ? 'Solved!' : 'Check my beads',
                                icon: _solved
                                    ? Icons.check_circle_rounded
                                    : Icons.chevron_right_rounded,
                                colors: _solved
                                    ? const [OceanColors.mint, OceanColors.aqua]
                                    : const [
                                        OceanColors.sunny,
                                        OceanColors.coral,
                                      ],
                                onTap: _check,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 6),
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

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.emoji,
    required this.story,
    required this.target,
    required this.onSpeak,
    this.equation,
    this.compact = false,
  });

  final String emoji;
  final String story;
  final int target;
  final String? equation;
  final VoidCallback onSpeak;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      // Keep the mission instructions readable without letting this card
      // compete with the physical counting toy for vertical space.
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      radius: 18,
      color: OceanColors.shell.withValues(alpha: 0.96),
      borderColor: Colors.white.withValues(alpha: 0.7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OceanColors.mint.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 21)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        story,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: OceanColors.ink,
                          fontWeight: FontWeight.w600,
                          height: 1.22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: onSpeak,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.volume_up_rounded,
                          color: OceanColors.teal,
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (equation != null) ...[
                      Flexible(
                        child: _Chip(
                          text: equation!,
                          color: OceanColors.coral,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    _Chip(
                      text: equation == null ? 'Make $target' : 'Find total',
                      color: OceanColors.teal,
                      foreground: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.color,
    this.foreground = OceanColors.ink,
  });
  final String text;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground == Colors.white ? color : OceanColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          fontFamily: 'Baloo2',
        ),
      ),
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
