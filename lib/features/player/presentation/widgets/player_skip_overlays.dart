import 'package:flutter/material.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/focus/focusable.dart';

/// Skip overlay shown during seek (Nuvio: SkipOverlay)
class PlayerSkipOverlay extends StatelessWidget {
  final String skipDirection;
  final VoidCallback onDismiss;

  const PlayerSkipOverlay({
    super.key,
    required this.skipDirection,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isForward = skipDirection == 'forward';
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isForward ? Icons.forward_10 : Icons.replay_10, color: AppTheme.textPrimary, size: 32),
            const SizedBox(width: 8),
            Text(isForward ? '+10s' : '-10s', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// Skip intro/recap/outro button (Nuvio: SkipIntroButton)
class PlayerSkipIntroButton extends StatelessWidget {
  final String type;
  final Duration remaining;
  final VoidCallback onSkip;

  const PlayerSkipIntroButton({
    super.key,
    required this.type,
    required this.remaining,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      'recap' => 'Skip Recap',
      'outro' => 'Skip Credits',
      _ => 'Skip Intro',
    };
    return Positioned(
      bottom: 120,
      right: 24,
      child: StreameFocusable(
        onTap: onSkip,
        focusedScale: 1.04,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.arcticWhite12,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderMedium, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.skip_next, color: AppTheme.textPrimary, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
