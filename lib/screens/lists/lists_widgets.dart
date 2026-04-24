import 'package:flutter/material.dart';
import '../../api/trakt_service.dart';
import '../../api/mdblist_service.dart';
import '../../api/tmdb_api.dart';
import '../../models/movie.dart';
import '../../utils/app_theme.dart';
import '../details_screen.dart';

class TraktListItemsScreen extends StatefulWidget {
  final String listId;
  final String listName;
  final int itemCount;

  const TraktListItemsScreen({super.key, 
    required this.listId,
    required this.listName,
    required this.itemCount,
  });

  @override
  State<TraktListItemsScreen> createState() => _TraktListItemsScreenState();
}

class _TraktListItemsScreenState extends State<TraktListItemsScreen> {
  final TraktService _trakt = TraktService();
  final TmdbApi _api = TmdbApi();
  List<Movie> _movies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await _trakt.getListItems(widget.listId);
      final entries = items.map((item) {
        final media = item['movie'] ?? item['show'];
        if (media == null) return null;
        final type = item.containsKey('show') ? 'tv' : 'movie';
        final ids = media['ids'] as Map<String, dynamic>? ?? {};
        final tmdbId = ids['tmdb'] as int?;
        if (tmdbId == null) return null;
        return (tmdbId: tmdbId, type: type);
      }).whereType<({int tmdbId, String type})>().toList();

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
      if (mounted) setState(() { _movies = movies; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeItem(Movie movie) async {
    final type = movie.mediaType == 'tv' ? 'shows' : 'movies';
    final entry = <String, dynamic>{
      'ids': {'tmdb': movie.id},
    };
    final success = await _trakt.removeFromList(
      listId: widget.listId,
      movies: type == 'movies' ? [entry] : [],
      shows: type == 'shows' ? [entry] : [],
    );
    if (success && mounted) {
      setState(() => _movies.removeWhere((m) => m.id == movie.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${movie.title}"')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove item')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Text(widget.listName, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        : _movies.isEmpty
          ? Center(child: Text('No items', style: TextStyle(color: AppTheme.textDisabled)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _movies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final movie = _movies[index];
                return _movieListTile(
                  movie: movie,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DetailsScreen(movie: movie),
                  )),
                  onRemove: () => _removeItem(movie),
                );
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MDBLIST ITEMS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class MdblistItemsScreen extends StatefulWidget {
  final int listId;
  final String listName;
  final bool isUserList;

  const MdblistItemsScreen({super.key, 
    required this.listId,
    required this.listName,
    this.isUserList = false,
  });

  @override
  State<MdblistItemsScreen> createState() => _MdblistItemsScreenState();
}

class _MdblistItemsScreenState extends State<MdblistItemsScreen> {
  final MdblistService _mdblist = MdblistService();
  final TmdbApi _api = TmdbApi();
  List<Movie> _movies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await _mdblist.getListItems(widget.listId);
      final entries = items.map((item) {
        final tmdbId = item['tmdb_id'] as int? ?? item['id'] as int?;
        final mediaType = item['mediatype']?.toString() ?? 'movie';
        if (tmdbId == null) return null;
        return (tmdbId: tmdbId, type: mediaType);
      }).whereType<({int tmdbId, String type})>().toList();

      final movies = <Movie>[];
      for (var i = 0; i < entries.length; i += 5) {
        final batch = entries.skip(i).take(5);
        final results = await Future.wait(
          batch.map((e) async {
            try {
              return e.type == 'show'
                  ? await _api.getTvDetails(e.tmdbId)
                  : await _api.getMovieDetails(e.tmdbId);
            } catch (_) { return null; }
          }),
        );
        movies.addAll(results.whereType<Movie>());
      }
      if (mounted) setState(() { _movies = movies; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeItem(Movie movie) async {
    final success = await _mdblist.removeFromList(
      listId: widget.listId,
      tmdbId: movie.id,
      mediaType: movie.mediaType,
    );
    if (success && mounted) {
      setState(() => _movies.removeWhere((m) => m.id == movie.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${movie.title}"')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove item')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Text(widget.listName, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        : _movies.isEmpty
          ? Center(child: Text('No items', style: TextStyle(color: AppTheme.textDisabled)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _movies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final movie = _movies[index];
                return _movieListTile(
                  movie: movie,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DetailsScreen(movie: movie),
                  )),
                  onRemove: widget.isUserList ? () => _removeItem(movie) : null,
                );
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHARED MOVIE LIST TILE
// ═══════════════════════════════════════════════════════════════════════════════

Widget _movieListTile({
  required Movie movie,
  required VoidCallback onTap,
  VoidCallback? onRemove,
}) {
  final posterUrl = movie.posterPath.isNotEmpty
      ? TmdbApi.getImageUrl(movie.posterPath)
      : '';

  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: posterUrl.isNotEmpty
              ? Image.network(posterUrl, width: 50, height: 75, fit: BoxFit.cover)
              : Container(
                  width: 50, height: 75,
                  color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
                  child: Icon(Icons.movie, color: AppTheme.textDisabled, size: 24),
                ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movie.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (movie.releaseDate.isNotEmpty)
                      Text(movie.releaseDate.split('-').first,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    if (movie.mediaType == 'tv') ...[
                      if (movie.releaseDate.isNotEmpty)
                        Text('  •  ', style: TextStyle(color: AppTheme.textDisabled, fontSize: 12)),
                      Text('TV', style: TextStyle(color: AppTheme.primaryColor.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                    if (movie.voteAverage > 0) ...[
                      Text('  •  ', style: TextStyle(color: AppTheme.textDisabled, fontSize: 12)),
                      const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(movie.voteAverage.toStringAsFixed(1),
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Colors.redAccent.withValues(alpha: 0.7), size: 22),
              onPressed: onRemove,
            ),
        ],
      ),
    ),
  );
}
