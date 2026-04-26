import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:streame_core/services/my_list_service.dart';
import 'package:streame_core/api/tmdb_api.dart';
import 'package:streame_core/services/settings_service.dart';
import 'package:streame_core/models/movie.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'details_screen.dart';
import 'streaming_details_screen.dart';

class MyListScreen extends StatefulWidget {
  const MyListScreen({super.key});

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  final MyListService _myList = MyListService();
  final TmdbApi _api = TmdbApi();
  List<Map<String, dynamic>> _items = [];
  String _sortMode = 'recent'; // 'recent', 'title', 'rating'
  String _filterMode = 'all'; // 'all', 'movie', 'tv'

  @override
  void initState() {
    super.initState();
    _items = _applySortAndFilter(_myList.items);
    MyListService.changeNotifier.addListener(_onListChanged);
  }

  void _onListChanged() {
    if (mounted) {
      setState(() => _items = _applySortAndFilter(_myList.items));
    }
  }

  List<Map<String, dynamic>> _applySortAndFilter(List<Map<String, dynamic>> items) {
    // Filter
    var filtered = items;
    if (_filterMode == 'movie') {
      filtered = items.where((i) => i['mediaType'] == 'movie').toList();
    } else if (_filterMode == 'tv') {
      filtered = items.where((i) => i['mediaType'] == 'tv' || i['mediaType'] == 'series').toList();
    }
    // Sort
    final sorted = List<Map<String, dynamic>>.from(filtered);
    if (_sortMode == 'title') {
      sorted.sort((a, b) => (a['title'] ?? '').toString().toLowerCase().compareTo((b['title'] ?? '').toString().toLowerCase()));
    } else if (_sortMode == 'rating') {
      sorted.sort((a, b) => ((b['voteAverage'] as num?)?.toDouble() ?? 0).compareTo((a['voteAverage'] as num?)?.toDouble() ?? 0));
    } else {
      // 'recent' — items are already in add-order from MyListService
    }
    return sorted;
  }

  @override
  void dispose() {
    MyListService.changeNotifier.removeListener(_onListChanged);
    super.dispose();
  }

  Widget _buildFilterChip(String label, String mode) {
    final active = _filterMode == mode;
    final primary = AppTheme.current.primaryColor;
    return GestureDetector(
      onTap: () => setState(() {
        _filterMode = mode;
        _items = _applySortAndFilter(_myList.items);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? primary.withValues(alpha: 0.15) : GlassColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? primary.withValues(alpha: 0.3) : GlassColors.borderSubtle, width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    final settings = SettingsService();
    final isStreaming = await settings.isStreamingModeEnabled();
    if (!mounted) return;

    final source = item['source']?.toString() ?? 'tmdb';
    final tmdbId = item['tmdbId'] as int?;
    final imdbId = item['imdbId']?.toString();
    final title = item['title']?.toString() ?? 'Unknown';
    final poster = item['posterPath']?.toString() ?? '';
    final mediaType = item['mediaType']?.toString() ?? 'movie';

    // TMDB source — we have the tmdbId directly
    if (source == 'tmdb' && tmdbId != null) {
      try {
        final Movie details;
        if (mediaType == 'tv') {
          details = await _api.getTvDetails(tmdbId);
        } else {
          details = await _api.getMovieDetails(tmdbId);
        }
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => isStreaming
                ? StreamingDetailsScreen(movie: details)
                : DetailsScreen(movie: details),
          ));
          return;
        }
      } catch (_) {}
    }

    // Stremio source or fallback — try IMDB lookup
    if (imdbId != null && imdbId.startsWith('tt')) {
      try {
        final movie = await _api.findByImdbId(imdbId, mediaType: mediaType == 'series' ? 'tv' : mediaType);
        if (movie != null && mounted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => isStreaming
                ? StreamingDetailsScreen(movie: movie)
                : DetailsScreen(movie: movie),
          ));
          return;
        }
      } catch (_) {}
    }

    // Last resort — build a Movie from saved data
    if (mounted) {
      final movie = Movie(
        id: tmdbId ?? title.hashCode,
        imdbId: imdbId,
        title: title,
        posterPath: poster,
        backdropPath: poster,
        voteAverage: (item['voteAverage'] as num?)?.toDouble() ?? 0,
        releaseDate: item['releaseDate']?.toString() ?? '',
        mediaType: mediaType == 'series' ? 'tv' : mediaType,
      );
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => isStreaming
            ? StreamingDetailsScreen(movie: movie)
            : DetailsScreen(movie: movie),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final crossAxisCount = isDesktop ? 6 : (screenWidth > 600 ? 4 : 3);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppTheme.bgDark,
            title: Row(
              children: [
                const Icon(Icons.bookmark, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text('My List', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Text(
                  '${_items.length} items',
                  style: TextStyle(color: AppTheme.textDisabled, fontSize: 14, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            actions: [
              // Filter chips
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 4),
                    _buildFilterChip('Movies', 'movie'),
                    const SizedBox(width: 4),
                    _buildFilterChip('TV', 'tv'),
                  ],
                ),
              ),
              // Sort dropdown
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.sort_rounded, color: AppTheme.textSecondary),
                  tooltip: 'Sort',
                  onSelected: (val) => setState(() {
                    _sortMode = val;
                    _items = _applySortAndFilter(_myList.items);
                  }),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'recent', child: Text('Recently Added${_sortMode == 'recent' ? ' ✓' : ''}')),
                    PopupMenuItem(value: 'title', child: Text('Title A-Z${_sortMode == 'title' ? ' ✓' : ''}')),
                    PopupMenuItem(value: 'rating', child: Text('Top Rated${_sortMode == 'rating' ? ' ✓' : ''}')),
                  ],
                ),
              ),
            ],
          ),

          // Empty state
          if (_items.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border, size: 80, color: AppTheme.textDisabled.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text(
                      'Your list is empty',
                      style: TextStyle(color: AppTheme.textDisabled, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button on any movie or show to add it here',
                      style: TextStyle(color: AppTheme.textDisabled, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2 / 3,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _items[index];
                    return _MyListCard(
                      item: item,
                      onTap: () => _openItem(item),
                      onRemove: () async {
                        await _myList.remove(item['uniqueId']);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Removed "${item['title']}" from My List'),
                              duration: const Duration(seconds: 2),
                              action: SnackBarAction(
                                label: 'UNDO',
                                onPressed: () {
                                  // Re-add the item
                                  if (item['source'] == 'stremio') {
                                    _myList.addStremioItem({
                                      'name': item['title'],
                                      'poster': item['posterPath'],
                                      'type': item['stremioType'] ?? item['mediaType'],
                                      'imdb_id': item['imdbId'],
                                      'imdbRating': item['voteAverage']?.toString(),
                                      'releaseInfo': item['releaseDate'],
                                    });
                                  } else {
                                    _myList.addMovie(
                                      tmdbId: item['tmdbId'] ?? 0,
                                      imdbId: item['imdbId'],
                                      title: item['title'] ?? '',
                                      posterPath: item['posterPath'] ?? '',
                                      mediaType: item['mediaType'] ?? 'movie',
                                      voteAverage: (item['voteAverage'] as num?)?.toDouble() ?? 0,
                                      releaseDate: item['releaseDate'] ?? '',
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My List Card
// ─────────────────────────────────────────────────────────────────────────────

class _MyListCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _MyListCard({required this.item, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? 'Unknown';
    final poster = item['posterPath']?.toString() ?? '';
    final mediaType = item['mediaType']?.toString() ?? 'movie';
    final source = item['source']?.toString() ?? 'tmdb';
    final rating = (item['voteAverage'] as num?)?.toDouble() ?? 0;

    // TMDB relative paths start with "/" and need the base URL
    final imageUrl = source == 'tmdb' && poster.startsWith('/')
        ? TmdbApi.getImageUrl(poster)
        : poster;

    return FocusableControl(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppTheme.isLightMode ? null : [AppShadows.medium],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster image
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppTheme.bgCard),
                errorWidget: (_, _, _) => Container(
                  color: AppTheme.bgCard,
                  child: Center(child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppTheme.textDisabled))),
                ),
              )
            else
              Container(
                color: AppTheme.bgCard,
                child: Center(child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppTheme.textDisabled))),
              ),

            // Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.55, 1.0],
                ),
              ),
            ),

            // Rating badge
            if (rating > 0)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.2), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 10, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                    ],
                  ),
                ),
              ),

            // Type badge
            Positioned(
              top: 6, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: mediaType == 'tv' || mediaType == 'series'
                      ? Colors.blue.withValues(alpha: 0.7)
                      : AppTheme.primaryColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  mediaType == 'tv' || mediaType == 'series' ? 'TV' : 'MOVIE',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ),
            ),

            // Title
            Positioned(
              bottom: 8, left: 8, right: 28,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),

            // Remove button — must be AFTER title so it renders on top
            Positioned(
              bottom: 4, right: 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 14, color: AppTheme.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
