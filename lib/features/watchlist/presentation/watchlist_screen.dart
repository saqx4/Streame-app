import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/focus/focusable.dart';
import 'package:streame/core/repositories/trakt_repository.dart';
import 'package:streame/core/repositories/watchlist_repository.dart';
import 'package:streame/core/repositories/tmdb_repository.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';

final _watchlistPosterProvider = FutureProvider.family<String?, ({int tmdbId, String mediaType})>((ref, p) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  final details = p.mediaType == 'tv' ? await repo.getTvDetails(p.tmdbId) : await repo.getMovieDetails(p.tmdbId);
  final img = details?.posterPath ?? '';
  return img.isNotEmpty ? img : null;
});

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  @override
  Widget build(BuildContext context) {
    final watchlistAsync = ref.watch(traktWatchlistProvider);
    final localWatchlistAsync = ref.watch(userWatchlistProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: watchlistAsync.when(
        data: (traktItems) {
          return localWatchlistAsync.when(
            data: (localItems) {
              // Merge: prefer Trakt items, add local items not in Trakt
              final traktImdbIds = traktItems.where((i) => i.imdbId != null).map((i) => i.imdbId!).toSet();
              final allItems = <_WatchlistEntry>[];

              for (final t in traktItems) {
                allItems.add(_WatchlistEntry(
                  title: t.title ?? 'Unknown',
                  mediaType: t.mediaType ?? 'movie',
                  tmdbId: t.tmdbId != null ? int.tryParse(t.tmdbId!) : null,
                  imdbId: t.imdbId,
                  year: t.year?.toString(),
                  posterPath: null, // Trakt doesn't provide poster
                  source: 'Trakt',
                ));
              }
              for (final l in localItems) {
                if (!traktImdbIds.contains(l.imdbId)) {
                  allItems.add(_WatchlistEntry(
                    title: l.title,
                    mediaType: l.mediaType,
                    tmdbId: l.tmdbId,
                    imdbId: l.imdbId,
                    year: l.year,
                    posterPath: l.posterPath,
                    source: 'Local',
                  ));
                }
              }

              // Separate into sections (Nuvio: shelf sections)
              final movies = allItems.where((i) => i.mediaType == 'movie').toList();
              final shows = allItems.where((i) => i.mediaType != 'movie').toList();

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ─── Nuvio-style sticky header ───
                  SliverToBoxAdapter(
                    child: Container(
                      color: AppTheme.backgroundDark,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundCard,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary, size: 20),
                                onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'My List',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (allItems.isEmpty)
                    SliverFillRemaining(
                      child: _EmptyStateCard(
                        icon: Icons.bookmark_border,
                        title: 'Your watchlist is empty',
                        message: 'Add shows and movies to keep track of what you want to watch',
                      ),
                    )
                  else ...[
                    // Pull-to-refresh
                    SliverToBoxAdapter(
                      child: RefreshIndicator(
                        color: AppTheme.textPrimary,
                        backgroundColor: AppTheme.backgroundCard,
                        onRefresh: () async {
                          ref.invalidate(traktWatchlistProvider);
                          ref.invalidate(userWatchlistProvider);
                        },
                        child: const SizedBox.shrink(),
                      ),
                    ),
                    if (movies.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                          child: Row(
                            children: [
                              Text('Movies', style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2,
                              )),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.textPrimary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${movies.length}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _calcColumns(context),
                            childAspectRatio: 0.58,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _WatchlistCard(entry: movies[index]),
                            childCount: movies.length,
                          ),
                        ),
                      ),
                    ],
                    if (shows.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                          child: Row(
                            children: [
                              Text('TV Shows', style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2,
                              )),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.textPrimary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${shows.length}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _calcColumns(context),
                            childAspectRatio: 0.58,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _WatchlistCard(entry: shows[index]),
                            childCount: shows.length,
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ],
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: AppTheme.textPrimary.withValues(alpha: 0.5), strokeWidth: 2.5)),
            error: (_, __) => const Center(child: Text('Error loading watchlist', style: TextStyle(color: AppTheme.textTertiary))),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: AppTheme.textPrimary.withValues(alpha: 0.5), strokeWidth: 2.5)),
        error: (_, __) => const Center(child: Text('Error loading watchlist', style: TextStyle(color: AppTheme.textTertiary))),
      ),
    );
  }

  int _calcColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return (width / 180).floor().clamp(3, 6);
  }
}

// ═══════════════════════════════════════════════
// WATCHLIST POSTER CARD (Nuvio: HomePosterCard style)
// ═══════════════════════════════════════════════
class _WatchlistCard extends ConsumerStatefulWidget {
  final _WatchlistEntry entry;
  const _WatchlistCard({required this.entry});

  @override
  ConsumerState<_WatchlistCard> createState() => _WatchlistCardState();
}

class _WatchlistCardState extends ConsumerState<_WatchlistCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final directPoster = e.posterPath != null && e.posterPath!.isNotEmpty
        ? (e.posterPath!.startsWith('http') ? e.posterPath! : 'https://image.tmdb.org/t/p/w500${e.posterPath}')
        : null;
    final posterAsync = (directPoster == null && e.tmdbId != null)
        ? ref.watch(_watchlistPosterProvider((tmdbId: e.tmdbId!, mediaType: e.mediaType)))
        : null;
    final fetchedPosterPath = posterAsync?.valueOrNull;
    final fetchedPosterUrl = fetchedPosterPath != null
        ? (fetchedPosterPath.startsWith('http') ? fetchedPosterPath : 'https://image.tmdb.org/t/p/w500$fetchedPosterPath')
        : null;
    final posterUrl = directPoster ?? fetchedPosterUrl;

    return StreameFocusable(
      onTap: () {
        if (e.tmdbId != null) {
          context.push('/details/${e.mediaType}/${e.tmdbId}');
        }
      },
      child: GestureDetector(
        child: Focus(
          onFocusChange: (f) => setState(() => _isFocused = f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: _isFocused
                  ? Border.all(color: AppTheme.textPrimary, width: 2)
                  : Border.all(color: AppTheme.borderLight.withValues(alpha: 0.24), width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster image or placeholder
                  if (posterUrl != null)
                    ResilientNetworkImage(
                      imageUrl: posterUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.backgroundElevated,
                        child: Center(
                          child: Icon(
                            e.mediaType == 'movie' ? Icons.movie : Icons.tv,
                            color: AppTheme.textTertiary.withValues(alpha: 0.4),
                            size: 32,
                          ),
                        ),
                      ),
                    )
                  else if (posterAsync != null && posterAsync.isLoading)
                    Container(
                      color: AppTheme.backgroundElevated,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white.withValues(alpha: 0.7),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: AppTheme.backgroundElevated,
                      child: Center(
                        child: Icon(
                          e.mediaType == 'movie' ? Icons.movie : Icons.tv,
                          color: AppTheme.textTertiary.withValues(alpha: 0.4),
                          size: 32,
                        ),
                      ),
                    ),
                  // Bottom gradient overlay for title
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.9),
                        ],
                        stops: const [0.0, 0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                  // Media type badge
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: e.mediaType == 'movie' ? AppTheme.accentYellow.withValues(alpha: 0.9) : AppTheme.accentGreen.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        e.mediaType == 'movie' ? 'Movie' : 'TV',
                        style: const TextStyle(color: AppTheme.backgroundDark, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  // Source badge
                  if (e.source == 'Trakt')
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Trakt', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  // Title at bottom over gradient
                  Positioned(
                    bottom: 8, left: 8, right: 8,
                    child: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 4)])),
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

// ═══════════════════════════════════════════════
// EMPTY STATE CARD (Nuvio: HomeEmptyStateCard)
// ═══════════════════════════════════════════════
class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyStateCard({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight.withValues(alpha: 0.24), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppTheme.textPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppTheme.textSecondary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _WatchlistEntry {
  final String title;
  final String mediaType;
  final int? tmdbId;
  final String? imdbId;
  final String? year;
  final String? posterPath;
  final String source;

  const _WatchlistEntry({
    required this.title,
    required this.mediaType,
    this.tmdbId,
    this.imdbId,
    this.year,
    this.posterPath,
    required this.source,
  });
}