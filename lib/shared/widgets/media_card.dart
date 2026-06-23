import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/providers/shared_providers.dart';
import 'package:streame/core/repositories/tmdb_repository.dart';
import 'package:streame/core/repositories/trakt_repository.dart' show traktWatchedProvider, traktFullyWatchedProvider;
import 'package:streame/features/home/data/models/media_item.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';

final tmdbLogoPathProvider = FutureProvider.family<String?, ({int id, MediaType type})>((ref, p) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  return repo.getLogoPath(p.id, mediaType: p.type);
});

class MediaCard extends ConsumerWidget {
  final MediaItem item;
  final bool isLandscape;
  final bool isRanked;
  final int? rank;
  final bool showProgress;
  final double progress;
  final ContinueWatchingItem? cwItem;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final double cardWidth;
  final double cardHeight;
  final String edgeStyle;

  const MediaCard({
    super.key,
    required this.item,
    this.isLandscape = false,
    this.isRanked = false,
    this.rank,
    this.showProgress = false,
    this.progress = 0.0,
    this.cwItem,
    this.onTap,
    this.onDismiss,
    this.cardWidth = 126,
    this.cardHeight = 189,
    this.edgeStyle = 'rounded',
  });

  BorderRadius _borderRadius() {
    switch (edgeStyle) {
      case 'sharp':
        return BorderRadius.circular(4);
      case 'soft':
        return BorderRadius.circular(8);
      case 'rounded':
        return BorderRadius.circular(14);
      case 'pill':
        return BorderRadius.circular(20);
      default:
        return BorderRadius.circular(14);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final br = _borderRadius();
    final imageUrl = isLandscape
        ? (item.backdrop ?? item.image)
        : item.image;

    final logoAsync = ref.watch(tmdbLogoPathProvider((id: item.id, type: item.mediaType)));
    final logoPath = logoAsync.valueOrNull;
    
    // Always show logo in landscape if available
    final hasLogo = isLandscape && logoPath != null && logoPath.isNotEmpty;

    final watchedItems = ref.watch(traktWatchedProvider).valueOrNull ?? [];
    final isWatchedRaw = watchedItems.any((w) => w.tmdbId == item.id.toString());
    
    final bool isWatched;
    if (item.mediaType == MediaType.tv && isWatchedRaw) {
      isWatched = ref.watch(traktFullyWatchedProvider(item.id)).valueOrNull ?? false;
    } else {
      isWatched = isWatchedRaw;
    }

    return Semantics(
      button: true,
      label: item.title,
      child: _FocusableCard(
        cardWidth: cardWidth,
        cardHeight: cardHeight,
        borderRadius: br,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: br,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Artwork
              if (imageUrl.isNotEmpty)
                ResilientNetworkImage(
                  imageUrl: imageUrl.startsWith('http') ? imageUrl : 'https://image.tmdb.org/t/p/w300$imageUrl',
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _MissingArtwork(title: item.title),
                )
              else
                _MissingArtwork(title: item.title),

              // Gradient scrim
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.55, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
              ),

              // Rating badge
              if (!showProgress && item.tmdbRatingDouble > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _RatingBadge(rating: item.tmdbRating),
                ),

              // Ranked badge
              if (isRanked && rank != null)
                Positioned(
                  top: 0,
                  left: 0,
                  child: _RankBadge(rank: rank!, radius: br),
                ),

              // Watched overlay
              if (isWatched)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Color(0xFF00DF80),
                      size: 16,
                    ),
                  ),
                ),

              // Dismiss button for CW items
              if (showProgress && onDismiss != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Semantics(
                    button: true,
                    label: 'Dismiss',
                    child: GestureDetector(
                      onTap: onDismiss,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white70),
                      ),
                    ),
                  ),
                ),

              // Logo / Title
              if (hasLogo)
                // New Requirement: Landscape logo at bottom-left
                Positioned(
                  left: 12,
                  bottom: showProgress ? 32 : 12,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: cardWidth * 0.6,
                      maxHeight: cardHeight * 0.35,
                    ),
                    child: Image(
                      image: NetworkImage('https://image.tmdb.org/t/p/w300$logoPath'),
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomLeft,
                      errorBuilder: (_, __, ___) => _CardTitle(title: item.title),
                    ),
                  ),
                )
              else
                // Portrait or Landscape without logo: Title at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: showProgress ? 22 : 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: _CardTitle(title: item.title),
                  ),
                ),

              // Progress bar for CW
              if (showProgress && cwItem != null) ...[
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 6,
                  child: _ProgressInfo(cwItem: cwItem!, progress: progress),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _ProgressBar(progress: progress, borderRadius: br),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final String title;
  const _CardTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.25,
        shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
      ),
    );
  }
}

class _ProgressInfo extends StatelessWidget {
  final ContinueWatchingItem cwItem;
  final double progress;
  const _ProgressInfo({required this.cwItem, required this.progress});

  @override
  Widget build(BuildContext context) {
    final remaining = cwItem.totalDuration - cwItem.position;
    final minsLeft = remaining.inMinutes;
    final epLabel = cwItem.mediaType == 'tv'
        ? 'S${cwItem.season} E${cwItem.episode}  ·  '
        : '';
    final timeLabel = minsLeft > 0
        ? '${minsLeft}m left'
        : '${(progress * 100).round()}%';
    return Text(
      '$epLabel$timeLabel',
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 9,
        fontWeight: FontWeight.w500,
        shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final BorderRadius borderRadius;
  const _ProgressBar({required this.progress, required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(borderRadius.bottomLeft.x),
        bottomRight: Radius.circular(borderRadius.bottomRight.x),
      ),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation(AppTheme.accentGreen),
        minHeight: 2.5,
      ),
    );
  }
}

class _FocusableCard extends StatefulWidget {
  final double cardWidth;
  final double cardHeight;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final Widget child;

  const _FocusableCard({
    required this.cardWidth,
    required this.cardHeight,
    required this.borderRadius,
    this.onTap,
    required this.child,
  });

  @override
  State<_FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<_FocusableCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: widget.cardWidth,
          height: widget.cardHeight,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()..scale(_focused ? 1.05 : 1.0),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppTheme.focusGlow,
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final String rating;
  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 11, color: AppTheme.accentYellow),
          const SizedBox(width: 3),
          Text(
            rating,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final BorderRadius radius;
  const _RankBadge({required this.rank, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accentYellow,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius.topLeft.x),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: AppTheme.backgroundDark,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MissingArtwork extends StatelessWidget {
  final String title;
  const _MissingArtwork({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.backgroundElevated, AppTheme.backgroundCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(title, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      ),
    );
  }
}
