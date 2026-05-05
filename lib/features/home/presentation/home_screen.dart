import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/focus/focusable.dart';
import 'package:streame/core/repositories/tmdb_repository.dart';
import 'package:streame/core/repositories/home_cache_repository.dart';
import 'package:streame/features/home/data/models/media_item.dart';
import 'package:streame/shared/widgets/skeleton_loader.dart';

final _tmdbLogoPathProvider = FutureProvider.family<String?, ({int id, MediaType type})>((ref, p) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  return repo.getLogoPath(p.id, mediaType: p.type);
});

final _tmdbGenresProvider = FutureProvider.family<List<String>, ({int id, MediaType type})>((ref, p) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  return repo.getGenreNames(p.id, mediaType: p.type);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trendingMoviesAsync = ref.watch(trendingMoviesProvider(1));
    final trendingTvAsync = ref.watch(trendingTvProvider(1));
    final topRatedMoviesAsync = ref.watch(topRatedMoviesProvider);
    final popularTvAsync = ref.watch(popularTvProvider);
    final continueWatchingAsync = ref.watch(continueWatchingProvider);

    return RefreshIndicator(
      color: AppTheme.focusRing,
      backgroundColor: AppTheme.backgroundCard,
      onRefresh: () async {
        ref.invalidate(trendingMoviesProvider);
        ref.invalidate(trendingTvProvider);
        ref.invalidate(topRatedMoviesProvider);
        ref.invalidate(popularTvProvider);
        ref.invalidate(continueWatchingProvider);
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ─── Hero Banner ───
          SliverToBoxAdapter(child: _HeroBanner(moviesAsync: trendingMoviesAsync)),
          // ─── Continue Watching ───
          continueWatchingAsync.when(
            data: (items) => items.isNotEmpty
                ? SliverToBoxAdapter(child: _MediaRail(
                    title: 'Continue Watching',
                    items: items.map((i) => MediaItem(
                      id: i.tmdbId,
                      title: i.title,
                      mediaType: i.mediaType == 'tv' ? MediaType.tv : MediaType.movie,
                      image: i.posterPath ?? '',
                    )).toList(),
                    isContinueWatching: true,
                    continueItems: items,
                  ))
                : const SliverToBoxAdapter(child: SizedBox.shrink()),
            loading: () => SliverToBoxAdapter(child: _LoadingRail(title: 'Continue Watching')),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          // ─── Trending Movies (ranked top 10) ───
          trendingMoviesAsync.when(
            data: (movies) => SliverToBoxAdapter(child: _MediaRail(
              title: 'Popular - Movies',
              items: movies,
              isRanked: true,
              viewAllCategory: ViewAllCategory.trendingMovies,
            )),
            loading: () => SliverToBoxAdapter(child: _LoadingRail(title: 'Trending Movies')),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          // ─── Trending TV ───
          trendingTvAsync.when(
            data: (shows) => SliverToBoxAdapter(child: _MediaRail(title: 'Popular - Series', items: shows, viewAllCategory: ViewAllCategory.trendingTv)),
            loading: () => SliverToBoxAdapter(child: _LoadingRail(title: 'Trending TV')),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          // ─── Top Rated Movies ───
          topRatedMoviesAsync.when(
            data: (movies) => SliverToBoxAdapter(child: _MediaRail(title: 'Top Rated Movies', items: movies, viewAllCategory: ViewAllCategory.topRatedMovies)),
            loading: () => SliverToBoxAdapter(child: _LoadingRail(title: 'Top Rated Movies')),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          // ─── Popular TV ───
          popularTvAsync.when(
            data: (shows) => SliverToBoxAdapter(child: _MediaRail(title: 'Popular TV', items: shows, viewAllCategory: ViewAllCategory.popularTv)),
            loading: () => SliverToBoxAdapter(child: _LoadingRail(title: 'Popular TV')),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// HERO BANNER — Full-width featured content
// ═══════════════════════════════════════════════
class _HeroBanner extends ConsumerStatefulWidget {
  final AsyncValue<List<MediaItem>> moviesAsync;
  const _HeroBanner({required this.moviesAsync});

  @override
  ConsumerState<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends ConsumerState<_HeroBanner> {
  static const _heroHeight = 540.0;
  static const _autoAdvanceEvery = Duration(seconds: 10);
  static const _maxItems = 10;

  final _controller = PageController(viewportFraction: 1.0);
  Timer? _timer;
  int _index = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _ensureTimer(int itemCount) {
    if (itemCount <= 1) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    _timer = Timer.periodic(_autoAdvanceEvery, (_) {
      if (!mounted) return;
      final next = (_index + 1) % itemCount;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.moviesAsync.when(
      data: (movies) {
        if (movies.isEmpty) return const SizedBox.shrink();
        final items = movies.take(_maxItems).toList();
        _ensureTimer(items.length);

        return SizedBox(
          height: _heroHeight,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: items.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final featured = items[i];
                  final backdrop = featured.backdrop ?? featured.image;
                  return _HeroCard(item: featured, backdropUrl: backdrop);
                },
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 12,
                child: _HeroDots(count: items.length, activeIndex: _index),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: _heroHeight,
        color: AppTheme.backgroundCard,
        child: const Center(child: CircularProgressIndicator(color: AppTheme.textTertiary)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final MediaItem item;
  final String? backdropUrl;
  const _HeroCard({required this.item, this.backdropUrl});

  static const _heroHeight = 540.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop image
          if (backdropUrl != null && backdropUrl!.isNotEmpty)
            ResilientNetworkImage(
              imageUrl: backdropUrl!.startsWith('http') ? backdropUrl! : 'https://image.tmdb.org/t/p/w1280$backdropUrl',
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: AppTheme.backgroundElevated),
            )
          else
            Container(color: AppTheme.backgroundElevated),
          // Gradient overlay (matching Kotlin's triple-stop gradient)
          Container(decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.5, 1.0],
              colors: [
                Colors.transparent,
                Color(0x8008090A),
                AppTheme.backgroundDark,
              ],
            ),
          )),
          // Content overlay
          Positioned(
            left: 24,
            right: 24,
            bottom: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final type = item.mediaType;
                    final logoAsync = ref.watch(_tmdbLogoPathProvider((id: item.id, type: type)));
                    final logoPath = logoAsync.valueOrNull;
                    if (logoPath == null || logoPath.isEmpty) {
                      return Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
                        ),
                      );
                    }
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 90, maxWidth: 320),
                      child: ResilientNetworkImage(
                        imageUrl: 'https://image.tmdb.org/t/p/w500$logoPath',
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Consumer(
                  builder: (context, ref, _) {
                    final genresAsync = ref.watch(_tmdbGenresProvider((id: item.id, type: item.mediaType)));
                    final genres = genresAsync.valueOrNull ?? const <String>[];
                    final dateLabel = item.year.isNotEmpty ? item.year : '—';
                    final typeLabel = item.mediaType == MediaType.tv ? 'Series' : 'Movie';
                    final genreStr = genres.isNotEmpty ? genres.first : '';
                    final text = genreStr.isNotEmpty ? '$typeLabel  •  $genreStr  •  $dateLabel' : '$typeLabel  •  $dateLabel';
                    return Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                    );
                  },
                ),
                const SizedBox(height: 18),
                StreameFocusable(
                  onTap: () {
                    final mt = item.mediaType == MediaType.tv ? 'tv' : 'movie';
                    context.push('/details/$mt/${item.id}');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.textPrimary,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(
                        color: AppTheme.backgroundDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  const _HeroDots({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isActive ? 18 : 6,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.textPrimary : AppTheme.borderMedium,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════
// MEDIA RAIL — Horizontal scroll row of cards
// ═══════════════════════════════════════════════
class _MediaRail extends ConsumerWidget {
  final String title;
  final List<MediaItem> items;
  final bool isRanked;
  final bool isContinueWatching;
  final List<ContinueWatchingItem>? continueItems;
  final ViewAllCategory? viewAllCategory;

  const _MediaRail({
    required this.title,
    required this.items,
    this.isRanked = false,
    this.isContinueWatching = false,
    this.continueItems,
    this.viewAllCategory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StreameFocusable(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ViewAllScreen(title: title, items: items, category: viewAllCategory))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundElevated,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View All', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                        SizedBox(width: 6),
                        Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: isContinueWatching ? 170 : 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final cwItem = isContinueWatching && continueItems != null && index < continueItems!.length
                    ? continueItems![index] : null;
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _StreameMediaCard(
                    item: item,
                    isLandscape: isContinueWatching,
                    isRanked: isRanked && index < 10,
                    rank: isRanked ? index + 1 : null,
                    showProgress: isContinueWatching,
                    progress: cwItem?.progress ?? 0.0,
                    cwItem: cwItem,
                    onDismiss: isContinueWatching && cwItem != null
                        ? () async {
                            final cacheRepo = ref.read(homeCacheRepositoryProvider);
                            await cacheRepo.dismissContinueWatching(
                              cwItem.tmdbId, cwItem.mediaType, cwItem.season, cwItem.episode,
                            );
                            ref.invalidate(continueWatchingProvider);
                          }
                        : null,
                    onTap: () {
                      final mt = item.mediaType == MediaType.tv ? 'tv' : 'movie';
                      if (isContinueWatching && cwItem != null) {
                        final posMs = cwItem.position.inMilliseconds;
                        final startParam = posMs > 0 ? '&startPositionMs=$posMs' : '';
                        final imdbParam = cwItem.imdbId != null ? '&imdbId=${cwItem.imdbId}' : '';
                        context.push('/player/${mt}/${item.id}?seasonNumber=${cwItem.season}&episodeNumber=${cwItem.episode}$startParam$imdbParam');
                      } else {
                        context.push('/details/$mt/${item.id}');
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// STREAME MEDIA CARD — Focusable card with outline
// ═══════════════════════════════════════════════
class _StreameMediaCard extends StatefulWidget {
  final MediaItem item;
  final bool isLandscape;
  final bool isRanked;
  final int? rank;
  final bool showProgress;
  final double progress;
  final ContinueWatchingItem? cwItem;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const _StreameMediaCard({
    required this.item,
    this.isLandscape = true,
    this.isRanked = false,
    this.rank,
    this.showProgress = false,
    this.progress = 0.0,
    this.cwItem,
    this.onTap,
    this.onDismiss,
  });

  @override
  State<_StreameMediaCard> createState() => _StreameMediaCardState();
}

class _StreameMediaCardState extends State<_StreameMediaCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final cardWidth = widget.isLandscape ? 260.0 : 140.0;
    final cardHeight = widget.isLandscape ? 146.0 : 210.0;
    final imageUrl = widget.isLandscape
        ? (widget.item.backdrop ?? widget.item.image)
        : widget.item.image;
    final borderRadius = BorderRadius.circular(widget.isLandscape ? 10.0 : 16.0);

    return GestureDetector(
      onTap: widget.onTap,
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: cardWidth,
          height: cardHeight,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()..scale(_isFocused ? 1.05 : 1.0),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: _isFocused
                ? Border.all(color: AppTheme.focusRing, width: 2.5)
                : Border.all(color: AppTheme.borderLight, width: 1),
            boxShadow: _isFocused
                ? [BoxShadow(color: AppTheme.focusGlow, blurRadius: 12, spreadRadius: 2)]
                : [],
          ),
          child: widget.isLandscape
              ? ClipRRect(
                  borderRadius: borderRadius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl.isNotEmpty)
                        ResilientNetworkImage(
                          imageUrl: imageUrl.startsWith('http') ? imageUrl : 'https://image.tmdb.org/t/p/w500$imageUrl',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _MissingArtwork(title: widget.item.title),
                        )
                      else
                        _MissingArtwork(title: widget.item.title),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                          ),
                        ),
                      ),
                      // Dismiss button for CW items
                      if (widget.showProgress && widget.onDismiss != null)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: widget.onDismiss,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white70),
                            ),
                          ),
                        )
                      else if (widget.item.tmdbRatingDouble > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accentYellow,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 12, color: AppTheme.backgroundDark),
                                const SizedBox(width: 3),
                                Text(
                                  widget.item.tmdbRating,
                                  style: const TextStyle(
                                    color: AppTheme.backgroundDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (widget.isRanked && widget.rank != null)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: const BoxDecoration(
                              color: AppTheme.accentYellow,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Text(
                              '${widget.rank}',
                              style: const TextStyle(
                                color: AppTheme.backgroundDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      // Bottom info area for CW cards
                      if (widget.showProgress && widget.cwItem != null) ...[
                        Positioned(
                          bottom: 10,
                          left: 10,
                          right: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Builder(builder: (_) {
                                final cw = widget.cwItem!;
                                final remaining = cw.totalDuration - cw.position;
                                final minsLeft = remaining.inMinutes;
                                final epLabel = cw.mediaType == 'tv'
                                    ? 'S${cw.season} E${cw.episode}  •  '
                                    : '';
                                final timeLabel = minsLeft > 0
                                    ? '${minsLeft}m left'
                                    : '${(widget.progress * 100).round()}%';
                                return Text(
                                  '$epLabel$timeLabel',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                            child: LinearProgressIndicator(
                              value: widget.progress,
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              valueColor: const AlwaysStoppedAnimation(AppTheme.accentGreen),
                              minHeight: 3,
                            ),
                          ),
                        ),
                      ]
                      else ...[
                        Positioned(
                          bottom: 8,
                          left: 10,
                          right: 10,
                          child: Text(
                            widget.item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : ClipRRect(
                  borderRadius: borderRadius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl.isNotEmpty)
                        ResilientNetworkImage(
                          imageUrl: imageUrl.startsWith('http') ? imageUrl : 'https://image.tmdb.org/t/p/w500$imageUrl',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _MissingArtwork(title: widget.item.title),
                        )
                      else
                        _MissingArtwork(title: widget.item.title),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// Missing artwork fallback — branded gradient with title
class _MissingArtwork extends StatelessWidget {
  final String title;
  const _MissingArtwork({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
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
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      ),
    );
  }
}

// Loading rail with skeleton cards
class _LoadingRail extends StatelessWidget {
  final String title;
  const _LoadingRail({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(title.toUpperCase(), style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppTheme.textSecondary,
            )),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 157,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 48),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, __) => Container(
                width: 280, height: 157,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const SkeletonCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// VIEW ALL — Full grid with infinite scrolling
// ═══════════════════════════════════════════════

enum ViewAllCategory {
  trendingMovies,
  trendingTv,
  topRatedMovies,
  popularTv,
  trendingAll,
}

class ViewAllScreen extends ConsumerStatefulWidget {
  final String title;
  final List<MediaItem> items;
  final ViewAllCategory? category;
  const ViewAllScreen({super.key, required this.title, required this.items, this.category});

  @override
  ConsumerState<ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends ConsumerState<ViewAllScreen> {
  final _scrollController = ScrollController();
  final List<MediaItem> _allItems = [];
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _allItems.addAll(widget.items);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (widget.category == null) return;
    setState(() => _isLoadingMore = true);

    final repo = ref.read(tmdbRepositoryProvider);
    final nextPage = _currentPage + 1;
    List<MediaItem> newItems;

    switch (widget.category!) {
      case ViewAllCategory.trendingMovies:
        newItems = await repo.getTrendingMovies(page: nextPage);
        break;
      case ViewAllCategory.trendingTv:
        newItems = await repo.getTrendingTv(page: nextPage);
        break;
      case ViewAllCategory.topRatedMovies:
        newItems = await repo.getTopRatedMovies(page: nextPage);
        break;
      case ViewAllCategory.popularTv:
        newItems = await repo.getPopularTv(page: nextPage);
        break;
      case ViewAllCategory.trendingAll:
        newItems = await repo.getTrendingAll(page: nextPage);
        break;
    }

    if (newItems.isEmpty) {
      _hasMore = false;
    } else {
      _currentPage = nextPage;
      _allItems.addAll(newItems);
    }

    if (mounted) setState(() => _isLoadingMore = false);
  }

  int _calcColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 6;
    if (width > 900) return 5;
    if (width > 600) return 4;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final canPaginate = widget.category != null;
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        title: Text(widget.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/home'),
        ),
      ),
      body: _allItems.isEmpty
          ? const Center(child: Text('No items found', style: TextStyle(color: AppTheme.textSecondary)))
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _calcColumns(context),
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
              ),
              itemCount: _allItems.length + ((canPaginate && _hasMore) ? 1 : 0),
              itemBuilder: (context, i) {
                // Loading indicator at the bottom
                if (i >= _allItems.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _isLoadingMore
                          ? const CircularProgressIndicator(color: AppTheme.textPrimary, strokeWidth: 2)
                          : const SizedBox.shrink(),
                    ),
                  );
                }
                final item = _allItems[i];
                final img = item.image;
                return StreameFocusable(
                  onTap: () {
                    final mt = item.mediaType == MediaType.tv ? 'tv' : 'movie';
                    context.push('/details/$mt/${item.id}');
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: img.isNotEmpty
                              ? ResilientNetworkImage(
                                  imageUrl: img.startsWith('http') ? img : 'https://image.tmdb.org/t/p/w500$img',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorWidget: (_, __, ___) => Container(color: AppTheme.backgroundElevated, child: const Icon(Icons.movie, color: AppTheme.textTertiary)),
                                )
                              : Container(color: AppTheme.backgroundElevated, child: const Icon(Icons.movie, color: AppTheme.textTertiary)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
