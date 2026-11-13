import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/catalog.dart';
import '../core/feedback.dart';
import '../core/models.dart';
import '../core/progress.dart';
import '../jarimatika/hand_painter.dart';
import '../theme.dart';
import '../widgets/ocean_background.dart';
import '../widgets/ui_kit.dart';

/// Finger maths. Right hand = ones, left hand = tens, using the canonical
/// Jarimatika finger shapes.
class JarimatikaScreen extends StatefulWidget {
  const JarimatikaScreen({super.key, this.mission, this.practice = false});

  final Mission? mission;
  final bool practice;

  @override
  State<JarimatikaScreen> createState() => _JarimatikaScreenState();
}

class _JarimatikaScreenState extends State<JarimatikaScreen>
    with SingleTickerProviderStateMixin {
  final Set<Finger> _right = {};
  final Set<Finger> _left = {};
  late int _target;
  late final AnimationController _shake;
  Timer? _speakTimer;

  bool _solved = false;
  bool _celebrate = false;
  bool _usedHint = false;
  int _attempts = 0;
  int _stars = 0;
  int _reward = 0;
  String _encouragement = '';

  bool get _isPractice => widget.practice || widget.mission == null;

  int? get _rightValue => handValue(_right);
  int? get _leftValue => handValue(_left);
  int? get _total {
    final right = _rightValue;
    final left = _leftValue;
    if (right == null || left == null) return null;
    return left * 10 + right;
  }

  @override
  void initState() {
    super.initState();
    _target = widget.mission?.target ?? (1 + math.Random().nextInt(10));
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _speakTimer = Timer(const Duration(milliseconds: 800), _speak);
  }

  void _speak() {
    if (!mounted) return;
    AudioService.instance.speak(
      widget.mission?.voice ??
          'Show $_target with your fingers. Right hand counts ones. '
              'Left hand counts tens.',
    );
  }

  @override
  void dispose() {
    _speakTimer?.cancel();
    _shake.dispose();
    AudioService.instance.stopSpeaking();
    super.dispose();
  }

  void _toggle(Set<Finger> hand, Finger finger) {
    if (_solved) return;
    AudioService.instance.sfx('hand_tap', volume: 0.6);
    Feel.tap();
    setState(() {
      if (!hand.remove(finger)) hand.add(finger);
      _encouragement = '';
    });
  }

  void _clear() {
    AudioService.instance.sfx('finger_down');
    Feel.tap();
    setState(() {
      _right.clear();
      _left.clear();
      _solved = false;
      _celebrate = false;
      _attempts = 0;
      _encouragement = '';
    });
  }

  void _hint() {
    final ones = _target % 10;
    final tens = _target ~/ 10;
    final hand = tens > 0 ? 'left' : 'right';
    final digit = tens > 0 ? tens : ones;
    final fingers = fingersFor(digit);
    final label = fingers.map(fingerName).join(', ');
    setState(() {
      _usedHint = true;
      _encouragement = tens > 0
          ? 'Use your $hand hand: $label. One left finger means ten.'
          : 'Use your $hand hand: $label.';
    });
    AudioService.instance.speak(_encouragement);
  }

  void _wrong() {
    AudioService.instance.sfx('wrong');
    Feel.nope();
    _shake.forward(from: 0);
    final total = _total;
    setState(() {
      _attempts++;
      if (total == null) {
        _encouragement =
            'That finger shape is not a Jarimatika number yet. Tap fingers to '
            'match the guide.';
      } else {
        _encouragement = 'You are showing $total. Can you show $_target?';
      }
    });
    AudioService.instance.speak(_encouragement);
  }

  void _check() {
    if (_solved) return;
    if (_total == _target) {
      _success();
    } else {
      _wrong();
    }
  }

  void _success() {
    final progress = ProgressScope.read(context);
    final firstTry = _attempts == 0 && !_usedHint;
    final stars = firstTry ? 3 : (_attempts <= 1 ? 2 : 1);
    var reward = 0;
    if (!_isPractice && widget.mission != null) {
      reward = progress.recordSuccess(
        widget.mission!,
        stars: stars,
        firstTry: firstTry,
      );
    } else {
      progress.recordPractice(
        kind: StationKind.jarimatika,
        firstTry: firstTry,
        correct: true,
      );
    }
    AudioService.instance.sfx('hand_success');
    Future.delayed(
      const Duration(milliseconds: 260),
      () => AudioService.instance.sfx('mission_complete'),
    );
    Feel.success();
    AudioService.instance.speak('Yes! $_target with Jarimatika fingers!');
    setState(() {
      _solved = true;
      _celebrate = true;
      _stars = stars;
      _reward = reward;
    });
    Future.delayed(const Duration(milliseconds: 950), _showSheet);
  }

  Future<void> _showSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: OceanColors.abyss.withValues(alpha: 0.6),
      builder: (sheetContext) => _FingerRewardSheet(
        title: _isPractice ? 'Finger magic!' : 'Jarimatika master!',
        stars: _isPractice ? 0 : _stars,
        reward: _reward,
        practice: _isPractice,
        target: _target,
        onAgain: () {
          Navigator.of(sheetContext).pop();
          _again();
        },
        onNext: _isPractice
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                _next();
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
      _right.clear();
      _left.clear();
      _solved = false;
      _celebrate = false;
      _attempts = 0;
      _usedHint = false;
      _encouragement = '';
      if (_isPractice) _target = 1 + math.Random().nextInt(10);
    });
    _speak();
  }

  void _next() {
    final mission = widget.mission;
    if (mission == null) {
      Navigator.of(context).maybePop();
      return;
    }
    final list = missionsFor(StationKind.jarimatika);
    final index = list.indexWhere((m) => m.id == mission.id);
    if (index < 0 || index == list.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => JarimatikaScreen(mission: list[index + 1]),
      ),
    );
  }

  void _showGuide() {
    AudioService.instance.sfx('bubble');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _JarimatikaGuide(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final media = MediaQuery.sizeOf(context);
    final handSize = math.min((media.width - 58) / 2, 194.0);
    final total = _total;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          OceanBackground(
            showSand: false,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  children: [
                    OceanHeader(
                      title: widget.mission?.title ?? 'Jarimatika',
                      subtitle: 'Finger Reef · ones and tens',
                      onBack: () => Navigator.of(context).maybePop(),
                      trailing: RoundIconButton(
                        icon: Icons.menu_book_rounded,
                        size: 42,
                        color: Colors.white.withValues(alpha: 0.16),
                        iconColor: OceanColors.foam,
                        onTap: _showGuide,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _FingerPrompt(
                      target: _target,
                      story:
                          widget.mission?.story ??
                          'Can you show $_target with your fingers? '
                              'Tap a finger to open or fold it.',
                      onSpeak: _speak,
                      onGuide: _showGuide,
                    ),
                    const SizedBox(height: 4),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            JarimatikaHand(
                              fingers: _left,
                              label: 'LEFT HAND',
                              subLabel: 'tens',
                              accent: OceanColors.lilac,
                              mirrored: true,
                              size: handSize,
                              onToggle: (f) => _toggle(_left, f),
                            ),
                            JarimatikaHand(
                              fingers: _right,
                              label: 'RIGHT HAND',
                              subLabel: 'ones',
                              accent: OceanColors.coral,
                              size: handSize,
                              onToggle: (f) => _toggle(_right, f),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _FingerSum(
                      left: _leftValue,
                      right: _rightValue,
                      total: total,
                      target: _target,
                      soundOn: progress.soundOn,
                      onToggleSound: () {
                        final on = !progress.soundOn;
                        progress.setSound(on);
                        AudioService.instance.soundOn = on;
                        if (on) AudioService.instance.sfx('ui_tap');
                      },
                    ),
                    if (_encouragement.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _encouragement,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: OceanColors.mint,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: BigButton(
                            label: _solved ? 'Solved!' : 'Check my fingers',
                            icon: _solved
                                ? Icons.check_circle_rounded
                                : Icons.back_hand_rounded,
                            colors: _solved
                                ? const [OceanColors.mint, OceanColors.aqua]
                                : const [OceanColors.sunny, OceanColors.coral],
                            onTap: _check,
                          ),
                        ),
                      ],
                    ),
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
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: _clear,
                          icon: const Icon(Icons.backspace_rounded, size: 18),
                          label: const Text('Clear'),
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

class _FingerPrompt extends StatelessWidget {
  const _FingerPrompt({
    required this.target,
    required this.story,
    required this.onSpeak,
    required this.onGuide,
  });

  final int target;
  final String story;
  final VoidCallback onSpeak;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      radius: 22,
      color: OceanColors.shell.withValues(alpha: 0.96),
      borderColor: Colors.white.withValues(alpha: 0.7),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [OceanColors.sunny, OceanColors.coral],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: oceanShadow(blur: 10, y: 4),
            ),
            child: Text(
              '$target',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: OceanColors.ink,
                fontFamily: 'Baloo2',
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              story,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OceanColors.ink,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          IconButton(
            onPressed: onSpeak,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.volume_up_rounded, color: OceanColors.teal),
          ),
          IconButton(
            onPressed: onGuide,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.help_outline_rounded,
              color: OceanColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}

class _FingerSum extends StatelessWidget {
  const _FingerSum({
    required this.left,
    required this.right,
    required this.total,
    required this.target,
    required this.soundOn,
    required this.onToggleSound,
  });

  final int? left;
  final int? right;
  final int? total;
  final int target;
  final bool soundOn;
  final VoidCallback onToggleSound;

  @override
  Widget build(BuildContext context) {
    final matched = total == target;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: OceanColors.abyss.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          _MiniChip(
            label: left == null ? '?' : '${left! * 10}',
            caption: 'tens',
            color: OceanColors.lilac,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '+',
              style: TextStyle(
                color: OceanColors.mint,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'Baloo2',
              ),
            ),
          ),
          _MiniChip(
            label: right == null ? '?' : '$right',
            caption: 'ones',
            color: OceanColors.coral,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '=',
              style: TextStyle(
                color: OceanColors.mint,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'Baloo2',
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(
              color: matched
                  ? OceanColors.aqua
                  : OceanColors.shell.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              total == null ? '?' : '$total',
              style: TextStyle(
                color: OceanColors.ink,
                fontSize: 24,
                height: 1,
                fontWeight: FontWeight.w800,
                fontFamily: 'Baloo2',
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onToggleSound,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: OceanColors.mint,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.caption,
    required this.color,
  });
  final String label;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            fontFamily: 'Baloo2',
            height: 1,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          caption,
          style: TextStyle(
            color: OceanColors.mint.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            fontFamily: 'Baloo2',
          ),
        ),
      ],
    );
  }
}

class _FingerRewardSheet extends StatelessWidget {
  const _FingerRewardSheet({
    required this.title,
    required this.stars,
    required this.reward,
    required this.practice,
    required this.target,
    required this.onAgain,
    required this.onDone,
    this.onNext,
  });

  final String title;
  final int stars;
  final int reward;
  final bool practice;
  final int target;
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
              const SizedBox(height: 12),
              const Text('🙌', style: TextStyle(fontSize: 44)),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: OceanColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                ),
              ),
              Text(
                'You showed $target with Jarimatika',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OceanColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!practice) ...[
                const SizedBox(height: 8),
                StarRow(stars: stars, size: 40),
              ],
              if (reward > 0) ...[
                const SizedBox(height: 8),
                OceanPill(
                  label: '+$reward pearls',
                  emoji: '💧',
                  color: OceanColors.mint.withValues(alpha: 0.8),
                ),
              ],
              const SizedBox(height: 14),
              BigButton(
                label: practice ? 'Try another number' : 'Next challenge',
                icon: Icons.arrow_forward_rounded,
                colors: const [OceanColors.aqua, OceanColors.teal],
                onTap: onNext ?? onAgain,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: BigButton(
                      label: 'Replay',
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

class _JarimatikaGuide extends StatelessWidget {
  const _JarimatikaGuide();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: OceanColors.shell,
            borderRadius: BorderRadius.circular(30),
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
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('🖐️', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The Jarimatika shapes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: OceanColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  RoundIconButton(
                    icon: Icons.close_rounded,
                    size: 34,
                    color: const Color(0xFFE6F5F1),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Right hand counts ones. Left hand is the same shape, times ten.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OceanColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var row = 0; row < 3; row++)
                        Row(
                          children: [
                            for (var col = 0; col < 3; col++)
                              Expanded(
                                child: _ShapeCard(digit: row * 3 + col + 1),
                              ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: OceanColors.lilac.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '10',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: OceanColors.lilacDeep,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'One finger on the left hand means one ten.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: OceanColors.inkSoft,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const Text('👈', style: TextStyle(fontSize: 22)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShapeCard extends StatelessWidget {
  const _ShapeCard({required this.digit});
  final int digit;

  @override
  Widget build(BuildContext context) {
    final fingers = fingersFor(digit);
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: OceanColors.mint.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$digit',
            style: const TextStyle(
              color: OceanColors.ink,
              fontSize: 19,
              height: 1,
              fontWeight: FontWeight.w800,
              fontFamily: 'Baloo2',
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final finger in kFingerOrder)
                Container(
                  width: 7,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: fingers.contains(finger)
                        ? OceanColors.coral
                        : OceanColors.ink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
