import 'package:flutter/material.dart';

import '../core/audio_service.dart';
import '../core/progress.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

Future<void> showSettingsSheet(BuildContext context) {
  final progress = ProgressScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: OceanColors.abyss.withValues(alpha: 0.6),
    builder: (_) => _SettingsSheet(progress: progress),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.progress});
  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: AnimatedBuilder(
          animation: progress,
          builder: (context, _) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              decoration: BoxDecoration(
                color: OceanColors.shell,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: oceanShadow(blur: 34, y: 14),
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
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: OceanColors.mint.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('⚙️', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Settings',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: OceanColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 27,
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
                  const SizedBox(height: 12),
                  _ToggleRow(
                    emoji: '🔊',
                    title: 'Sound effects',
                    subtitle: 'Bead clicks, bubbles and cheers',
                    value: progress.soundOn,
                    onChanged: (value) {
                      progress.setSound(value);
                      AudioService.instance.soundOn = value;
                      if (value) AudioService.instance.sfx('ui_tap');
                    },
                  ),
                  _ToggleRow(
                    emoji: '🗣️',
                    title: 'Voice guide',
                    subtitle: 'Tala reads each mission out loud',
                    value: progress.voiceOn,
                    onChanged: (value) {
                      progress.setVoice(value);
                      AudioService.instance.voiceOn = value;
                      if (!value) AudioService.instance.stopSpeaking();
                    },
                  ),
                  _ToggleRow(
                    emoji: '🌊',
                    title: 'Ocean ambience',
                    subtitle: 'A gentle underwater loop',
                    value: progress.ambienceOn,
                    onChanged: (value) {
                      progress.setAmbience(value);
                      AudioService.instance.setAmbienceEnabled(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: OceanColors.mint.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Text('⭐', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${progress.totalStars} stars · '
                            '${progress.completedMissions} missions · '
                            '${progress.treasureCount} treasures',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: OceanColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        Text(
                          '💧 ${progress.pearls}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: OceanColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _confirmReset(context),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Start the adventure again'),
                    style: TextButton.styleFrom(
                      foregroundColor: OceanColors.coralDeep,
                    ),
                  ),
                  Text(
                    'Math Rings · Ocean Numberland\n'
                    'A little maths world for big ocean explorers.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OceanColors.inkSoft.withValues(alpha: 0.7),
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: OceanColors.shell,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌀', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 6),
              Text(
                'Start again?',
                style: Theme.of(dialogContext).textTheme.headlineSmall
                    ?.copyWith(
                      color: OceanColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Stars, pearls and treasures will drift away. '
                'This cannot be undone.',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: OceanColors.inkSoft,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: BigButton(
                      label: 'Keep',
                      icon: Icons.favorite_rounded,
                      height: 48,
                      colors: const [Color(0xFFE6F5F1), Color(0xFFCDEAE4)],
                      onTap: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BigButton(
                      label: 'Reset',
                      icon: Icons.delete_outline_rounded,
                      height: 48,
                      colors: const [Color(0xFFFFB09D), Color(0xFFFF8768)],
                      onTap: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (yes == true) {
      progress.resetAll();
      AudioService.instance.sfx('reset');
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OceanColors.ink.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 19)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: OceanColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: OceanColors.inkSoft, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: OceanColors.aqua,
            inactiveTrackColor: OceanColors.ink.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}
