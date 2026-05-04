// Next Episode Overlay — auto-play countdown shown at end of episode
import 'package:flutter/material.dart';
import 'package:streame/core/theme/app_theme.dart';

class NextEpisodeOverlay extends StatefulWidget {
  final String title;
  final int season;
  final int episode;
  final VoidCallback onPlay;
  final VoidCallback onCancel;
  final Duration countdownDuration;

  const NextEpisodeOverlay({
    super.key,
    required this.title,
    required this.season,
    required this.episode,
    required this.onPlay,
    required this.onCancel,
    this.countdownDuration = const Duration(seconds: 10),
  });

  @override
  State<NextEpisodeOverlay> createState() => _NextEpisodeOverlayState();
}

class _NextEpisodeOverlayState extends State<NextEpisodeOverlay>
    with SingleTickerProviderStateMixin {
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownDuration.inSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        widget.onPlay();
      } else {
        _startCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 24,
      bottom: 80,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('Next Episode', style: TextStyle(
              color: AppTheme.textTertiary, fontSize: 12,
            )),
            const SizedBox(height: 4),
            Text('S${widget.season} E${widget.episode}: ${widget.title}', style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: widget.onPlay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.focusRing,
                    foregroundColor: AppTheme.backgroundDark,
                  ),
                  child: Text('Play ($_remaining)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
