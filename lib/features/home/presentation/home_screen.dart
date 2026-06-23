import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/focus/focusable.dart';
import 'package:streame/core/repositories/tmdb_repository.dart';
import 'package:streame/core/repositories/home_cache_repository.dart';
import 'package:streame/core/providers/shared_providers.dart';

import 'package:streame/features/home/data/models/media_item.dart';
import 'package:streame/shared/widgets/skeleton_loader.dart';
import 'package:streame/shared/widgets/media_card.dart';

final tmdbLogoPathProvider = FutureProvider.family<String?, ({int id, MediaType type})>((ref, p) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  return repo.getLogoPath(p.id, mediaType: p.type);
});

final _enrichedContinueWatchingProvider = FutureProvider<List<ContinueWatchingItem>>((ref) async {
  final items = await ref.watch(continueWatchingProvider.future);
  if (items.isEmpty) return items;

  final repo = ref.read(tmdbRepositoryProvider);
  final enriched = <ContinueWatchingItem>[];

  for (final item in items) {
    if (item.posterPath != null && item.backdropPath != null) {
      enriched.add(item);
      continue;
    }
    try {
      final details = item.mediaType == 'tv'
          ? await repo.getTvDetails(item.tmdbId)
          : await repo.getMovieDetails(item.tmdbId);
      if (details != null) {
        enriched.add(item.copyWith(
          posterPath: details.posterPath,
          backdropPath: details.backdrop,
        ));
      } else {
        enriched.add(item);
      }
    } catch (_) {
      enriched.add(item);
    }
  }
  return enriched;
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
    final continueWatchingAsync = ref.watch(_enrichedContinueWatchingProvider);

    // Read card customization settings
    final prefs = ref.watch(sharedPreferencesProvider);
    final cardSize = prefs.getDouble('settings_card_size') ?? 0.5;
    final isLandscape = prefs.getBool('settings_card_landscape') ?? false;
    final edgeStyle = prefs.getString('settings_card_edge_style') ?? 'rounded';

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
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
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
                    cardSize: cardSize,
                    defaultLandscape: true,
                    edgeStyle: edgeStyle,
                  ))
                : const SliverToBoxAdapter(child: SizedBox.shrink()),
            loading: () => SliverToBoxAdapter(child: _LoadingRail(title: 'Continue Watching')),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          // ─── Trending Movies (ranked top 10) ───
          trendingMoviesAsync.when(
            data: (movies) => SliverToBoxAdapter(child: _MediaRail(
              title: 'Popular Movies',
              items: movies,
              isRanked: true,
              viewAllCategory: ViewAllCategory.trendingMovies,
              cardSize: cardSize,
              defaultLandscape: isLandscape,
              edgeStyle: edgeStyle,
            )),
            loading: () => SliverToBoxAdapter(child: _LoadingRail(title: 'Popular Movies')),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          // ─── Trending TV ───
          trendingTvAsync.when(
            data: (shows) => SliverToBoxAdapter(child: _MediaRail(
              title: 'Popular Series',
              items: shows,
              viewAllCategory: ViewAllCategory.trendingTv,
              cardSize: cardSize,
              defaultLandscape: isLandscape,
              edgeStyle: edgeStyle,
            )),
            loading: () => SliverToBoxAdapter(child: _LoadingRail(title: 'Popular Series')),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          // ─── Top Rated Movies ───
          topRatedMoviesAsync.when(
            data: (movies) => SliverToBoxAdapter(child: _MediaRail(
              title: 'Top Rated Movies',
              items: movies,
              viewAllCategory: ViewAllCategory.topRatedMovies,
              cardSize: cardSize,
              defaultLandscape: isLandscape,
              edgeStyle: edgeStyle,
            )),
            loading: () => SliverToBoxAdapter(child: _LoadingRail(title: 'Top Rated Movies')),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          // ─── Popular TV ───
          popularTvAsync.when(
            data: (shows) => SliverToBoxAdapter(child: _MediaRail(
              title: 'Popular TV',
              items: shows,
              viewAllCategory: ViewAllCategory.popularTv,
              cardSize: cardSize,
              defaultLandscape: isLandscape,
              edgeStyle: edgeStyle,
            )),
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
        child: Center(child: CircularProgressIndicator(color: AppTheme.textTertiary)),
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
          Container(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.5, 1.0],
              colors: [
                Colors.transparent,
                AppTheme.backgroundDark.withValues(alpha: 0.50),
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
                    final logoAsync = ref.watch(tmdbLogoPathProvider((id: item.id, type: type)));
                    final logoPath = logoAsync.valueOrNull;
                    if (logoPath == null || logoPath.isEmpty) {
                      return Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          shadows: [Shadow(color: AppTheme.backgroundDark, blurRadius: 12)],
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
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            shadows: [Shadow(color: AppTheme.backgroundDark, blurRadius: 12)],
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
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
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
                    child: Text(
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
  final double cardSize;
  final bool defaultLandscape;
  final String edgeStyle;

  const _MediaRail({
    required this.title,
    required this.items,
    this.isRanked = false,
    this.isContinueWatching = false,
    this.continueItems,
    this.viewAllCategory,
    this.cardSize = 0.5,
    this.defaultLandscape = false,
    this.edgeStyle = 'rounded',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Requirements: Home screen portrait cards are 126x189
    final isLandscapeCard = isContinueWatching || defaultLandscape;
    final cardWidth = isLandscapeCard ? 200.0 : 126.0;
    final cardHeight = isLandscapeCard ? 112.0 : 189.0;
    final cardHeightForRail = isLandscapeCard ? cardHeight + 12 : cardHeight + 24;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                StreameFocusable(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ViewAllScreen(
                      title: title,
                      items: items,
                      category: viewAllCategory,
                      cardSize: cardSize,
                      edgeStyle: edgeStyle,
                    ),
                  )),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View All', style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        )),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, color: AppTheme.textTertiary, size: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: cardHeightForRail,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final cwItem = isContinueWatching && continueItems != null && index < continueItems!.length
                    ? continueItems![index] : null;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: MediaCard(
                    item: item,
                    isLandscape: isLandscapeCard,
                    isRanked: isRanked && index < 10,
                    rank: isRanked ? index + 1 : null,
                    showProgress: isContinueWatching,
                    progress: cwItem?.progress ?? 0.0,
                    cwItem: cwItem,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    edgeStyle: edgeStyle,
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
// LOADING RAIL
// ═══════════════════════════════════════════════
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(title, style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
            )),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 189,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => Container(
                width: 126, height: 189,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(14),
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
// VIEW ALL
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
  final double cardSize;
  final String edgeStyle;
  
  const ViewAllScreen({
    super.key, 
    required this.title, 
    required this.items, 
    this.category,
    this.cardSize = 0.5,
    this.edgeStyle = 'rounded',
  });

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

    try {
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
    } catch (_) {
      _hasMore = false;
    }

    if (mounted) setState(() => _isLoadingMore = false);
  }

  int _calcColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 8;
    if (width > 900) return 6;
    if (width > 600) return 4;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final canPaginate = widget.category != null;
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Sticky header
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.backgroundDark,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundCard.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.borderLight.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Text(
                      '${_allItems.length} items',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Grid
          _allItems.isEmpty
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: Text('No items found', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _calcColumns(context),
                      childAspectRatio: 126 / 189,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        if (i >= _allItems.length) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: _isLoadingMore
                                   ? CircularProgressIndicator(color: AppTheme.textPrimary, strokeWidth: 2)
                                  : const SizedBox.shrink(),
                            ),
                          );
                        }
                        final item = _allItems[i];
                        return MediaCard(
                          item: item,
                          cardWidth: 126,
                          cardHeight: 189,
                          edgeStyle: widget.edgeStyle,
                          onTap: () {
                            final mt = item.mediaType == MediaType.tv ? 'tv' : 'movie';
                            context.push('/details/$mt/${item.id}');
                          },
                        );
                      },
                      childCount: _allItems.length + ((canPaginate && _hasMore) ? 1 : 0),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
