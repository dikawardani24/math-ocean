import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/audio_service.dart';
import '../core/catalog.dart';
import '../core/feedback.dart';
import '../core/models.dart';
import '../core/progress.dart';
import '../theme.dart';
import '../widgets/ocean_background.dart';
import '../widgets/ui_kit.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  Future<void> _openChest() async {
    final progress = ProgressScope.read(context);
    if (_opening) return;
    if (progress.pearls < 3) {
      AudioService.instance.sfx('wrong');
      showOceanSnack(
        context,
        'You need 3 pearls to open the chest. Finish a mission first!',
        icon: Icons.lock_rounded,
      );
      return;
    }
    if (progress.treasureCount >= kTreasures.length) {
      showOceanSnack(
        context,
        'Every treasure is already yours. The whole reef is proud of you!',
        icon: Icons.workspace_premium_rounded,
      );
      return;
    }
    setState(() => _opening = true);
    AudioService.instance.sfx('chest_open');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final id = progress.openChest();
    if (!mounted) return;
    setState(() => _opening = false);
    if (id == null) return;
    final treasure = treasureById(id);
    AudioService.instance.sfx('star');
    Feel.success();
    AudioService.instance.speak('You found the ${treasure.name}!');
    await showDialog<void>(
      context: context,
      barrierColor: OceanColors.abyss.withValues(alpha: 0.65),
      builder: (_) => _TreasureDialog(treasure: treasure),
    );
  }

  void _showTreasure(Treasure treasure) {
    AudioService.instance.sfx('bubble');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TreasureSheet(treasure: treasure),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    return Scaffold(
      body: OceanBackground(
        showSand: false,
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
                        title: 'Treasure Grotto',
                        subtitle:
                            '${progress.treasureCount} of ${kTreasures.length} '
                            'treasures found',
                        onBack: () => Navigator.of(context).maybePop(),
                        trailing: OceanPill(
                          label: '${progress.pearls}',
                          emoji: '💧',
                          compact: true,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ChestHero(
                        bob: _bob,
                        opening: _opening,
                        pearls: progress.pearls,
                        complete: progress.treasureCount >= kTreasures.length,
                        onOpen: _openChest,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Text(
                            'Your collection',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: OceanColors.foam,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(width: 8),
                          const Text('🌺', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 150,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: kTreasures.length,
                      itemBuilder: (context, index) {
                        final treasure = kTreasures[index];
                        final owned = progress.treasures.contains(treasure.id);
                        return _TreasureTile(
                          treasure: treasure,
                          owned: owned,
                          onTap: owned ? () => _showTreasure(treasure) : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChestHero extends StatelessWidget {
  const _ChestHero({
    required this.bob,
    required this.opening,
    required this.pearls,
    required this.complete,
    required this.onOpen,
  });

  final AnimationController bob;
  final bool opening;
  final int pearls;
  final bool complete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8063D8), Color(0xFF49348F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: oceanShadow(blur: 26, y: 12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 132,
            child: AnimatedBuilder(
              animation: bob,
              builder: (context, _) {
                final t = bob.value * math.pi * 2;
                final lift = math.sin(t) * 3;
                final wiggle = opening ? math.sin(t * 8) * 0.06 : 0.0;
                return Transform.translate(
                  offset: Offset(0, lift),
                  child: Transform.rotate(
                    angle: wiggle,
                    child: CustomPaint(
                      size: const Size(150, 120),
                      painter: _ChestPainter(opening: opening),
                    ),
                  ),
                );
              },
            ),
          ),
          Text(
            complete ? 'The grotto is complete' : 'A chest of reef treasures',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            complete ? 'You found every single treasure. Tala is doing flips!' : 'Spend 3 pearls to open one. Every chest hides something new.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 280,
            child: BigButton(
              label: complete
                  ? 'Collection complete'
                  : opening
                  ? 'Opening…'
                  : 'Open chest · 3 💧',
              icon: complete
                  ? Icons.workspace_premium_rounded
                  : Icons.redeem_rounded,
              enabled: !complete && !opening,
              colors: const [OceanColors.sunny, OceanColors.coral],
              onTap: onOpen,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChestPainter extends CustomPainter {
  _ChestPainter({required this.opening});
  final bool opening;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.38, w * 0.84, h * 0.48),
      Radius.circular(w * 0.09),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB98142), Color(0xFF7D4C22)],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF4A2B12),
    );
    // Bands.
    final band = Paint()..color = const Color(0xFFFFD05C);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.08, h * 0.56, w * 0.84, h * 0.055),
      band,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.42, h * 0.52, w * 0.16, h * 0.16),
        Radius.circular(w * 0.04),
      ),
      band,
    );
    // Lid.
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, h * 0.22, w * 0.88, h * 0.24),
      Radius.circular(w * 0.16),
    );
    final lidLift = opening ? -h * 0.12 : 0.0;
    canvas.save();
    canvas.translate(0, lidLift);
    canvas.drawRRect(
      lid,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD99A55), Color(0xFF95602B)],
        ).createShader(lid.outerRect),
    );
    canvas.drawRRect(
      lid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF4A2B12),
    );
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.33, w * 0.8, h * 0.045), band);
    canvas.restore();
    // Hovering sparkle.
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.15),
      3.2,
      Paint()..color = OceanColors.foam.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      Offset(w * 0.16, h * 0.12),
      2,
      Paint()..color = OceanColors.sunny.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _ChestPainter oldDelegate) =>
      oldDelegate.opening != opening;
}

class _TreasureTile extends StatelessWidget {
  const _TreasureTile({
    required this.treasure,
    required this.owned,
    required this.onTap,
  });
  final Treasure treasure;
  final bool owned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: owned
                ? OceanColors.shell.withValues(alpha: 0.96)
                : OceanColors.abyss.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: owned
                  ? treasure.color.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1.4,
            ),
            boxShadow: owned ? oceanShadow(blur: 12, y: 5) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                owned ? treasure.emoji : '🔒',
                style: TextStyle(
                  fontSize: 38,
                  color: owned ? null : Colors.white24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                owned ? treasure.name : 'Hidden',
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: owned ? OceanColors.ink : Colors.white54,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TreasureDialog extends StatelessWidget {
  const _TreasureDialog({required this.treasure});
  final Treasure treasure;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(26),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: OceanColors.shell,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: oceanShadow(blur: 40, y: 16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: treasure.color.withValues(alpha: 0.24),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: treasure.color.withValues(alpha: 0.4),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Text(treasure.emoji, style: const TextStyle(fontSize: 54)),
            ),
            const SizedBox(height: 12),
            Text(
              'New treasure!',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: OceanColors.coralDeep, letterSpacing: 1.5),
            ),
            Text(
              treasure.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: OceanColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              treasure.blurb,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OceanColors.inkSoft,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            BigButton(
              label: 'Lovely!',
              icon: Icons.favorite_rounded,
              colors: const [OceanColors.aqua, OceanColors.teal],
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreasureSheet extends StatelessWidget {
  const _TreasureSheet({required this.treasure});
  final Treasure treasure;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
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
              const SizedBox(height: 16),
              Text(treasure.emoji, style: const TextStyle(fontSize: 54)),
              Text(
                treasure.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: OceanColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                treasure.blurb,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OceanColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              BigButton(
                label: 'Back to the grotto',
                icon: Icons.arrow_back_rounded,
                colors: const [OceanColors.aqua, OceanColors.teal],
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
