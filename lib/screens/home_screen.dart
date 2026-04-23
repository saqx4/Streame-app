import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../api/tmdb_api.dart';
import '../services/settings_service.dart';
import '../api/stremio_service.dart';
import '../api/trakt_service.dart';
import '../api/simkl_service.dart';
import '../models/movie.dart';
import '../utils/app_theme.dart';
import '../widgets/my_list_button.dart';
import 'details_screen.dart';
import 'streaming_details_screen.dart';
import 'stremio_catalog_screen.dart';
import 'home/home_widgets.dart';
import 'home/continue_watching.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final TmdbApi _api = TmdbApi();
  final StremioService _stremio = StremioService();
  final PageController _heroController = PageController();
  bool _isFullscreen = false;
  
  late Future<List<Movie>> _trendingFuture;
  late Future<List<Movie>> _popularFuture;
  late Future<List<Movie>> _topRatedFuture;
  late Future<List<Movie>> _nowPlayingFuture;
  late Future<List<Movie>> _trendingTvFuture;
  late Future<List<Movie>> _topRatedTvFuture;
  late Future<List<Movie>> _airingTodayTvFuture;
  
  Timer? _heroTimer;
  int _heroIndex = 0;

  // Hero logo cache: movieId -> logo URL
  final Map<int, String> _heroLogos = {};

  // Stremio catalog data
  List<Map<String, dynamic>> _stremioCatalogs = [];
  final Map<String, List<Map<String, dynamic>>> _catalogItems = {};
  bool _catalogsLoaded = false;

  // Trakt personalized sections
  List<Movie> _traktRecommendations = [];
  List<Map<String, dynamic>> _traktCalendar = [];
  List<Map<String, dynamic>> _traktCalendarMovies = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _trendingFuture = _api.getTrending().then((movies) {
      _fetchHeroLogos(movies.take(5).toList());
      return movies;
    });
    _popularFuture = _api.getPopular();
    _topRatedFuture = _api.getTopRated();
    _nowPlayingFuture = _api.getNowPlaying();
    _trendingTvFuture = _api.getTrendingTv();
    _topRatedTvFuture = _api.getTopRatedTv();
    _airingTodayTvFuture = _api.getAiringTodayTv();

    _startHeroTimer();
    _loadStremioCatalogs();

    // Reload catalogs whenever addons are added/removed in Settings
    SettingsService.addonChangeNotifier.addListener(_onAddonsChanged);

    // Trakt auto-sync (runs once per session, no-op if not logged in)
    TraktService().fullSync();
    // Simkl auto-sync (runs once per session, no-op if not logged in)
    SimklService().fullSync();

    // Trakt personalized sections
    _loadTraktRecommendations();
    _loadTraktCalendar();
    _loadTraktCalendarMovies();
  }

  Future<void> _loadTraktRecommendations() async {
    try {
      if (!await TraktService().isLoggedIn()) return;
      // Fetch movie + show recommendations and convert via TMDB
      final movieRecs = await TraktService().getRecommendations('movies');
      final showRecs = await TraktService().getRecommendations('shows');
      final all = [...movieRecs, ...showRecs];
      final entries = all.take(20).map((rec) {
        final item = rec['movie'] ?? rec['show'];
        if (item == null) return null;
        final ids = item['ids'] as Map<String, dynamic>?;
        final tmdbId = ids?['tmdb'] as int?;
        if (tmdbId == null) return null;
        final type = rec.containsKey('show') ? 'tv' : 'movie';
        return (tmdbId: tmdbId, type: type);
      }).whereType<({int tmdbId, String type})>().toList();

      // Parallel TMDB lookups in batches of 5
      final movies = <Movie>[];
      for (var i = 0; i < entries.length; i += 5) {
        final batch = entries.skip(i).take(5);
        final results = await Future.wait(
          batch.map((e) async {
            try {
              return e.type == 'tv'
                  ? await _api.getTvDetails(e.tmdbId)
                  : await _api.getMovieDetails(e.tmdbId);
            } catch (_) { return null; }
          }),
        );
        movies.addAll(results.whereType<Movie>());
      }
      if (mounted && movies.isNotEmpty) {
        setState(() => _traktRecommendations = movies);
      }
    } catch (_) {}
  }

  Future<void> _loadTraktCalendar() async {
    try {
      if (!await TraktService().isLoggedIn()) return;
      final shows = await TraktService().getCalendarShows(days: 14);
      if (mounted && shows.isNotEmpty) {
        setState(() => _traktCalendar = shows.take(20).toList());
      }
    } catch (_) {}
  }

  Future<void> _loadTraktCalendarMovies() async {
    try {
      if (!await TraktService().isLoggedIn()) return;
      final movies = await TraktService().getCalendarMovies(days: 30);
      if (mounted && movies.isNotEmpty) {
        setState(() => _traktCalendarMovies = movies.take(20).toList());
      }
    } catch (_) {}
  }

  void _startHeroTimer() {
    if (AppTheme.isLightMode) return; // skip periodic rebuilds in light mode
    _heroTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (_heroController.hasClients) {
        final next = (_heroIndex + 1) % 5;
        _heroController.animateToPage(
          next,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
        );
        setState(() => _heroIndex = next);
      }
    });
  }

  Future<void> _fetchHeroLogos(List<Movie> movies) async {
    for (final movie in movies) {
      if (_heroLogos.containsKey(movie.id)) continue;
      try {
        final logoPath = await _api.getLogoPath(movie.id, mediaType: movie.mediaType);
        if (logoPath.isNotEmpty && mounted) {
          setState(() => _heroLogos[movie.id] = TmdbApi.getImageUrl(logoPath));
        }
      } catch (_) {}
    }
  }

  void _onAddonsChanged() {
    // Clear stale data and schedule a rebuild so the old sliders disappear
    // immediately while the new ones load.
    setState(() {
      _stremioCatalogs = [];
      _catalogItems.clear();
      _catalogsLoaded = false;
    });
    _loadStremioCatalogs();
  }

  @override
  void dispose() {
    SettingsService.addonChangeNotifier.removeListener(_onAddonsChanged);
    _heroTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  Widget _buildTraktCalendarSection() {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upcoming Schedule',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 3,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _traktCalendar.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final entry = _traktCalendar[index];
              final show = entry['show'] as Map<String, dynamic>? ?? {};
              final episode = entry['episode'] as Map<String, dynamic>? ?? {};
              final showTitle = show['title'] as String? ?? 'Unknown';
              final epTitle = episode['title'] as String? ?? '';
              final season = episode['season'] as int? ?? 0;
              final number = episode['number'] as int? ?? 0;
              final aired = entry['first_aired'] as String? ?? '';
              String dateLabel = '';
              if (aired.isNotEmpty) {
                try {
                  final dt = DateTime.parse(aired).toLocal();
                  final wd = weekdays[dt.weekday - 1];
                  final mo = months[dt.month - 1];
                  dateLabel = '$wd, $mo ${dt.day}';
                } catch (_) {}
              }
              final showIds = show['ids'] as Map<String, dynamic>? ?? {};
              final tmdbId = showIds['tmdb'] as int?;

              return GestureDetector(
                onTap: () async {
                  if (tmdbId == null) return;
                  try {
                    final movie = await _api.getTvDetails(tmdbId);
                    if (mounted) _openDetails(movie);
                  } catch (_) {}
                },
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
                    boxShadow: AppTheme.isLightMode ? null : [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(showTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('S${season.toString().padLeft(2, '0')}E${number.toString().padLeft(2, '0')}',
                        style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      if (epTitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(epTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                      ],
                      const Spacer(),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time_rounded, size: 13, color: Colors.white.withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(dateLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTraktCalendarMoviesSection() {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.movie_filter_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upcoming Movies',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 3,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _traktCalendarMovies.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final entry = _traktCalendarMovies[index];
              final movie = entry['movie'] as Map<String, dynamic>? ?? {};
              final title = movie['title'] as String? ?? 'Unknown';
              final year = movie['year'] as int?;
              final released = entry['released'] as String? ?? '';
              String dateLabel = '';
              if (released.isNotEmpty) {
                try {
                  final dt = DateTime.parse(released);
                  final wd = weekdays[dt.weekday - 1];
                  final mo = months[dt.month - 1];
                  dateLabel = '$wd, $mo ${dt.day}';
                } catch (_) {}
              }
              final movieIds = movie['ids'] as Map<String, dynamic>? ?? {};
              final tmdbId = movieIds['tmdb'] as int?;

              return GestureDetector(
                onTap: () async {
                  if (tmdbId == null) return;
                  try {
                    final m = await _api.getMovieDetails(tmdbId);
                    if (mounted) _openDetails(m);
                  } catch (_) {}
                },
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
                    boxShadow: AppTheme.isLightMode ? null : [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      if (year != null) ...[
                        const SizedBox(height: 4),
                        Text('$year', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                      ],
                      const Spacer(),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 13, color: Colors.white.withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(dateLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openDetails(Movie movie) async {
    final settings = SettingsService();
    final isStreaming = await settings.isStreamingModeEnabled();
    
    if (!mounted) return;

    if (isStreaming) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => StreamingDetailsScreen(movie: movie)));
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(movie: movie)));
    }
  }

  Future<void> _loadStremioCatalogs() async {
    try {
      final catalogs = await _stremio.getAllCatalogs();
      if (!mounted || catalogs.isEmpty) return;

      // Group non-search-required catalogs by addon, preserving order.
      final Map<String, List<Map<String, dynamic>>> byAddon = {};
      for (final c in catalogs) {
        if (c['searchRequired'] == true) continue;
        final key = c['addonBaseUrl'] as String;
        byAddon.putIfAbsent(key, () => []).add(c);
      }

      // Mark that we've started loading so the build can show shimmer / placeholders.
      if (mounted) setState(() => _catalogsLoaded = true);

      // For each addon, try catalogs in order until one returns items.
      // All addons are tried in parallel; within each addon they are tried sequentially.
      await Future.wait(byAddon.values.map((addonCatalogs) async {
        for (final cat in addonCatalogs) {
          try {
            final items = await _stremio.getCatalog(
              baseUrl: cat['addonBaseUrl'],
              type: cat['catalogType'],
              id: cat['catalogId'],
            );
            if (items.isEmpty) continue; // try next catalog for this addon

            // Tag each item with the addon that provided it
            for (final item in items) {
              item['_addonBaseUrl'] = cat['addonBaseUrl'];
              item['_addonName'] = cat['addonName'];
            }
            if (mounted) {
              final itemKey = '${cat['addonBaseUrl']}/${cat['catalogType']}/${cat['catalogId']}';
              setState(() {
                // Add the winning catalog to the list if not already present
                if (!_stremioCatalogs.any((c) =>
                    c['addonBaseUrl'] == cat['addonBaseUrl'] &&
                    c['catalogId'] == cat['catalogId'])) {
                  _stremioCatalogs = [..._stremioCatalogs, cat];
                }
                _catalogItems[itemKey] = items;
              });
            }
            return; // done for this addon
          } catch (_) {}
        }
      }));
    } catch (e) {
      debugPrint('[HomeScreen] Error loading Stremio catalogs: $e');
    }
  }

  void _openStremioCatalog(Map<String, dynamic> catalog) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StremioCatalogScreen(initialCatalog: catalog)),
    );
  }

  Future<void> _openStremioItem(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final type = item['type']?.toString() ?? 'movie';
    final name = item['name']?.toString() ?? 'Unknown';
    final poster = item['poster']?.toString() ?? '';
    final isCustomId = !id.startsWith('tt');
    
    // Check if this is a collection by ID prefix
    final isCollection = id.startsWith('ctmdb.') || type == 'collections';

    // IMDB ID â†’ TMDB lookup
    if (!isCustomId && !isCollection) {
      try {
        final movie = await _api.findByImdbId(id, mediaType: type == 'series' ? 'tv' : 'movie');
        if (movie != null && mounted) {
          // Always use DetailsScreen for Stremio items
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => DetailsScreen(movie: movie, stremioItem: item),
          ));
          return;
        }
      } catch (_) {}
    }

    // For non-custom IDs that failed, try name search
    if (!isCustomId && !isCollection) {
      try {
        final results = await _api.searchMulti(name);
        if (results.isNotEmpty && mounted) {
          final match = results.firstWhere(
            (m) => m.title.toLowerCase() == name.toLowerCase(),
            orElse: () => results.first,
          );
          // Always use DetailsScreen for Stremio items
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => DetailsScreen(movie: match, stremioItem: item),
          ));
          return;
        }
      } catch (_) {}
    }

    // Custom ID, collection, or all lookups failed
    if (mounted) {
      // Override type to 'collections' if it's a collection ID
      final actualType = isCollection ? 'collections' : (type == 'series' ? 'tv' : 'movie');
      
      final movie = Movie(
        id: id.hashCode,
        imdbId: id.startsWith('tt') ? id : null,
        title: name,
        posterPath: poster,
        backdropPath: item['background']?.toString() ?? poster,
        voteAverage: double.tryParse(item['imdbRating']?.toString() ?? '') ?? 0,
        releaseDate: item['releaseInfo']?.toString() ?? '',
        overview: item['description']?.toString() ?? '',
        mediaType: actualType,
      );
      
      // Update the stremioItem type to collections if needed
      final updatedItem = Map<String, dynamic>.from(item);
      if (isCollection) {
        updatedItem['type'] = 'collections';
      }
      
      // Always use DetailsScreen for Stremio items
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => DetailsScreen(movie: movie, stremioItem: updatedItem),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          CustomScrollView(
            cacheExtent: 1000, // Increased for smoother scrolling
            physics: const BouncingScrollPhysics(),
            slivers: [
          // Hero
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: FutureBuilder<List<Movie>>(
                future: _trendingFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildHeroShimmer();
                  }
                  return _buildHeroCarousel(snapshot.data!.take(5).toList());
                },
              ),
            ),
          ),
          // Continue Watching
          const SliverToBoxAdapter(child: RepaintBoundary(child: ContinueWatchingSection())),
          // Trending
          SliverToBoxAdapter(child: RepaintBoundary(child: MovieSection(title: 'Trending Now', icon: Icons.local_fire_department_rounded, future: _trendingFuture, onMovieTap: _openDetails))),
          // Popular
          SliverToBoxAdapter(child: RepaintBoundary(child: MovieSection(title: 'Popular', icon: Icons.movie_filter_rounded, future: _popularFuture, onMovieTap: _openDetails, isPortrait: true, showRank: true))),
          // Stremio Addon Catalogs
          if (_catalogsLoaded)
            ..._stremioCatalogs.map((cat) {
              final key = '${cat['addonBaseUrl']}/${cat['catalogType']}/${cat['catalogId']}';
              final items = _catalogItems[key];
              if (items == null || items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: StremioCatalogSection(
                    catalog: cat,
                    items: items,
                    onItemTap: _openStremioItem,
                    onShowAll: () => _openStremioCatalog(cat),
                  ),
                ),
              );
            }),
          // Top Rated
          SliverToBoxAdapter(child: RepaintBoundary(child: MovieSection(title: 'Top Rated', icon: Icons.star_rounded, future: _topRatedFuture, onMovieTap: _openDetails))),
          // Trending TV Shows
          SliverToBoxAdapter(child: RepaintBoundary(child: MovieSection(title: 'Trending TV Shows', icon: Icons.tv_rounded, future: _trendingTvFuture, onMovieTap: _openDetails, isPortrait: true))),
          // Top Rated TV Shows
          SliverToBoxAdapter(child: RepaintBoundary(child: MovieSection(title: 'Top Rated TV Shows', icon: Icons.emoji_events_rounded, future: _topRatedTvFuture, onMovieTap: _openDetails, isPortrait: true))),
          // New Releases TV Shows (Airing Today)
          SliverToBoxAdapter(child: RepaintBoundary(child: MovieSection(title: 'New Releases TV', icon: Icons.live_tv_rounded, future: _airingTodayTvFuture, onMovieTap: _openDetails, isPortrait: true))),
          // Trakt Recommendations
          if (_traktRecommendations.isNotEmpty)
            SliverToBoxAdapter(child: RepaintBoundary(child: StaticMovieSection(title: 'Recommended for You', icon: Icons.recommend_rounded, movies: _traktRecommendations, onMovieTap: _openDetails))),
          // Trakt Calendar
          if (_traktCalendar.isNotEmpty)
            SliverToBoxAdapter(child: RepaintBoundary(child: _buildTraktCalendarSection())),
          // Trakt Calendar Movies
          if (_traktCalendarMovies.isNotEmpty)
            SliverToBoxAdapter(child: RepaintBoundary(child: _buildTraktCalendarMoviesSection())),
          // New Releases
          SliverToBoxAdapter(child: RepaintBoundary(child: MovieSection(title: 'New Releases', icon: Icons.new_releases_rounded, future: _nowPlayingFuture, onMovieTap: _openDetails, isPortrait: true))),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
          // Fullscreen button
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.overlay.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: IconButton(
                icon: Icon(
                  _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: AppTheme.textPrimary,
                  size: 20,
                ),
                onPressed: () async {
                  setState(() {
                    _isFullscreen = !_isFullscreen;
                  });
                  await WindowManager.instance.setFullScreen(_isFullscreen);
                },
                tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroShimmer() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final h = isLandscape ? MediaQuery.of(context).size.height * 0.6 : MediaQuery.of(context).size.height * 0.72;
    return Container(
      height: h,
      color: AppTheme.bgDark,
      child: Shimmer.fromColors(
        baseColor: AppTheme.shimmerBase,
        highlightColor: AppTheme.shimmerHighlight,
        child: Container(color: Colors.white),
      ),
    );
  }

  Widget _buildHeroCarousel(List<Movie> movies) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final height = isLandscape ? MediaQuery.of(context).size.height * 0.6 : MediaQuery.of(context).size.height * 0.72;
    final heroMovie = movies[_heroIndex];
    
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Background image with crossfade
          PageView.builder(
            controller: _heroController,
            itemCount: movies.length,
            onPageChanged: (i) => setState(() => _heroIndex = i),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: movie.backdropPath.isNotEmpty 
                        ? TmdbApi.getBackdropUrl(movie.backdropPath) 
                        : TmdbApi.getImageUrl(movie.posterPath),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  // Bottom fade gradient
                  Container(decoration: BoxDecoration(gradient: AppTheme.bottomFade(0.35))),
                ],
              );
            },
          ),
          
          // Content overlay
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo or Title
                  _buildHeroLogoOrTitle(heroMovie, isLandscape),
                  const SizedBox(height: 16),
                  
                  // Meta row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRatingBadge(heroMovie.voteAverage),
                        const SizedBox(width: AppSpacing.md),
                        if (heroMovie.releaseDate.isNotEmpty)
                          Text(
                            heroMovie.releaseDate.split('-').first,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        const SizedBox(width: AppSpacing.md),
                        if (heroMovie.mediaType == 'tv')
                          _buildTypeBadge('SERIES'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Synopsis
                  if (heroMovie.overview.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Text(
                        heroMovie.overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPrimaryPlayButton(heroMovie),
                        const SizedBox(width: 12),
                        _buildSecondaryInfoButton(heroMovie),
                        const SizedBox(width: 12),
                        MyListButton.movie(movie: heroMovie),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Minimal page indicator
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(movies.length, (i) => AnimatedContainer(
                        duration: AppDurations.normal,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 3,
                        width: i == _heroIndex ? 24 : 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i == _heroIndex ? AppTheme.current.primaryColor : AppTheme.textDisabled.withValues(alpha: 0.3),
                        ),
                      )),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Navigation arrows
          _buildHeroArrow(
            isLeft: true,
            onTap: () {
              if (_heroController.hasClients && _heroIndex > 0) {
                _heroController.animateToPage(
                  _heroIndex - 1,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                );
              }
            },
          ),
          _buildHeroArrow(
            isLeft: false,
            onTap: () {
              if (_heroController.hasClients && _heroIndex < movies.length - 1) {
                _heroController.animateToPage(
                  _heroIndex + 1,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroArrow({required bool isLeft, required VoidCallback onTap}) {
    return Positioned(
      left: isLeft ? 12 : null,
      right: isLeft ? null : 12,
      top: 0,
      bottom: 0,
      child: Center(
        child: FocusableControl(
          onTap: onTap,
          borderRadius: 30,
          child: _buildFrostedArrow(
            icon: isLeft ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroLogoOrTitle(Movie heroMovie, bool isLandscape) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _heroLogos.containsKey(heroMovie.id) && _heroLogos[heroMovie.id]!.isNotEmpty
          ? ConstrainedBox(
              key: ValueKey('logo_${heroMovie.id}'),
              constraints: BoxConstraints(
                maxWidth: isLandscape ? 400 : 300,
                maxHeight: 100,
              ),
              child: CachedNetworkImage(
                imageUrl: _heroLogos[heroMovie.id]!,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorWidget: (_, __, ___) => _buildHeroTitle(heroMovie, isLandscape),
              ),
            )
          : _buildHeroTitle(heroMovie, isLandscape),
    );
  }

  Widget _buildRatingBadge(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1),
      ),
    );
  }

  Widget _buildPrimaryPlayButton(Movie movie) {
    return FocusableControl(
      onTap: () => _openDetails(movie),
      borderRadius: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
            SizedBox(width: 8),
            Text('Play', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryInfoButton(Movie movie) {
    return FocusableControl(
      onTap: () => _openDetails(movie),
      borderRadius: AppRadius.md,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.textPrimary, size: 20),
            const SizedBox(width: 8),
            Text('Details', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }


  Widget _buildHeroTitle(Movie movie, bool isLandscape) {
    return Text(
      movie.title,
      style: TextStyle(
        fontSize: isLandscape ? 48 : 36,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
        height: 1.0,
        letterSpacing: -1.0,
        shadows: AppTheme.isLightMode ? null : [
          const Shadow(color: Colors.black, blurRadius: 40),
          Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 80),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFrostedArrow({required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.overlay.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.border),
      ),
      child: Icon(icon, color: AppTheme.textPrimary, size: 18),
    );
  }
}

