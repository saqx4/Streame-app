import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:streame/core/theme/app_theme.dart';

class StreameModal {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, _) {
        final curvedAnim = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return Center(
          child: FadeTransition(
            opacity: curvedAnim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(curvedAnim),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

// ─── Episode long-press modal ───
class EpisodeActionModal extends StatelessWidget {
  final int episodeNumber;
  final int seasonNumber;
  final String? name;
  final bool isWatched;
  final VoidCallback onMarkAsWatched;
  final VoidCallback onPlay;

  const EpisodeActionModal({
    super.key,
    required this.episodeNumber,
    required this.seasonNumber,
    this.name,
    this.isWatched = false,
    required this.onMarkAsWatched,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final title = name?.trim().isNotEmpty == true ? name!.trim() : 'Episode $episodeNumber';
    final badge = 'S${seasonNumber}E${episodeNumber.toString().padLeft(2, '0')}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: AppTheme.backgroundCard.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.textPrimary.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.backgroundDark.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              // Episode badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: AppTheme.accentPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 20),
              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: AppTheme.textPrimary.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 8),
              // Actions
              _ModalAction(
                icon: isWatched ? Icons.history_rounded : Icons.check_circle_outline_rounded,
                label: isWatched ? 'Unmark as Watched' : 'Mark as Watched',
                color: isWatched ? AppTheme.accentYellow : AppTheme.textPrimary,
                onTap: () {
                  Navigator.of(context).pop();
                  onMarkAsWatched();
                },
              ),
              _ModalAction(
                icon: Icons.play_arrow_rounded,
                label: 'Play',
                color: AppTheme.textPrimary,
                onTap: () {
                  Navigator.of(context).pop();
                  onPlay();
                },
              ),
              const SizedBox(height: 8),
              // Cancel
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Cancel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Season long-press modal ───
class SeasonActionModal extends StatelessWidget {
  final int seasonNumber;
  final String? name;
  final int episodeCount;
  final VoidCallback onMarkAllWatched;
  final VoidCallback onSelect;

  const SeasonActionModal({
    super.key,
    required this.seasonNumber,
    this.name,
    this.episodeCount = 0,
    required this.onMarkAllWatched,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final title = name ?? 'Season $seasonNumber';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: AppTheme.backgroundCard.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.textPrimary.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.backgroundDark.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              // Season icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.movie_rounded,
                  color: AppTheme.accentPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (episodeCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$episodeCount episodes',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: AppTheme.textPrimary.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 8),
              // Actions
              _ModalAction(
                icon: Icons.check_circle_outline_rounded,
                label: 'Mark All Watched',
                color: AppTheme.accentGreen,
                onTap: () {
                  Navigator.of(context).pop();
                  onMarkAllWatched();
                },
              ),
              _ModalAction(
                icon: Icons.visibility_rounded,
                label: 'View Episodes',
                color: AppTheme.textPrimary,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect();
                },
              ),
              const SizedBox(height: 8),
              // Cancel
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Cancel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reusable modal action row ───
class _ModalAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModalAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
