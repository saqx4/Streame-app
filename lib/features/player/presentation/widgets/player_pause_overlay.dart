import 'package:flutter/material.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';

/// Pause metadata overlay (Nuvio: PauseMetadataOverlay)
/// Shows "You're watching", logo/title, and episode info when paused
class PlayerPauseOverlay extends StatelessWidget {
  final String? logoUrl;
  final String? mediaTitle;
  final int? seasonNumber;
  final int? episodeNumber;

  const PlayerPauseOverlay({
    super.key,
    required this.logoUrl,
    required this.mediaTitle,
    this.seasonNumber,
    this.episodeNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppTheme.backgroundDark.withValues(alpha: 0.85),
                  AppTheme.backgroundDark.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 40,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're watching",
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                if (logoUrl != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240, maxHeight: 80),
                    child: ResilientNetworkImage(
                      imageUrl: logoUrl!,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => _titleFallback(),
                    ),
                  )
                else
                  _titleFallback(),
                if (seasonNumber != null && episodeNumber != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'S$seasonNumber E$episodeNumber',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _titleFallback() {
    return Text(
      mediaTitle ?? '',
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
