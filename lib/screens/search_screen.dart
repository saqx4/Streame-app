import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/tmdb_api.dart';
import '../api/stremio_service.dart';
import '../services/settings_service.dart';
import '../models/movie.dart';
import '../utils/app_theme.dart';
import 'details_screen.dart';
import 'streaming_details_screen.dart';
import 'main_screen.dart';
import 'search/search_widgets.dart';

/// A single result section that streams in dynamically.
class _SearchSection {
  final String key;
  final String title;
  final String? icon; // network icon URL (for addon sections)
  final bool isTmdb;
  List<dynamic> results; // Movie for TMDB, Map<String,dynamic> for addons

  _SearchSection({
    required this.key,
    required this.title,
    this.icon,
    this.isTmdb = false,
    List<dynamic>? results,
  }) : results = results ?? [];
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
  final TmdbApi _api = TmdbApi();
  final StremioService _stremio = StremioService();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  String _query = '';

  /// All search-capable addon providers (loaded once).
  List<Map<String, dynamic>> _addonProviders = [];

  /// Currently visible sections (populated dynamically as results arrive).
  final List<_SearchSection> _sections = [];

  /// Track which search generation we're on to discard stale results.
  int _searchGeneration = 0;

  /// True while at least one provider hasn't responded yet.
  bool _isSearching = false;

  /// Search history (last 10 queries)
  static const _searchHistoryKey = 'search_history';
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadProviders();
    _loadSearchHistory();
    MainScreen.stremioSearchNotifier.addListener(_onExternalSearch);
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_searchHistoryKey) ?? [];
    if (mounted) setState(() => _searchHistory = stored);
  }

  Future<void> _addToSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    _searchHistory = [query, ..._searchHistory.where((q) => q != query)];
    if (_searchHistory.length > 10) _searchHistory = _searchHistory.sublist(0, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchHistoryKey, _searchHistory);
    if (mounted) setState(() {});
  }

  Future<void> _clearSearchHistory() async {
    _searchHistory = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
    if (mounted) setState(() {});
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadProviders() async {
    final catalogs = await _stremio.getAllCatalogs();
    final Map<String, Map<String, dynamic>> providers = {};
    for (final c in catalogs) {
      if (c['supportsSearch'] != true) continue;
      final key = c['addonBaseUrl'] as String;
      if (!providers.containsKey(key)) {
        providers[key] = {
          'id': key,
          'name': c['addonName'],
          'icon': c['addonIcon'],
          'baseUrl': key,
          'catalogs': <Map<String, dynamic>>[],
        };
      }
      (providers[key]!['catalogs'] as List).add(c);
    }
    if (mounted) {
      setState(() => _addonProviders = providers.values.toList());
    }
  }

  void _onExternalSearch() async {
    final data = MainScreen.stremioSearchNotifier.value;
    if (data == null || (data['query'] ?? '').isEmpty) return;
    final query = data['query']!;
    if (_addonProviders.isEmpty) await _loadProviders();
    if (mounted) {
      _controller.text = query;
      _onSearchChanged(query);
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _query = query);
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _sections.clear();
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _addToSearchHistory(query);
      _performUnifiedSearch(query);
    });
  }

  /// Fire all search APIs in parallel; results stream in as they arrive.
  Future<void> _performUnifiedSearch(String query) async {
    if (query.trim().isEmpty) return;

    final gen = ++_searchGeneration;
    setState(() {
      _sections.clear();
      _isSearching = true;
    });

    int pendingCount = 1 + _addonProviders.length; // TMDB + each addon

    void decPending() {
      pendingCount--;
      if (pendingCount <= 0 && gen == _searchGeneration && mounted) {
        setState(() => _isSearching = false);
      }
    }

    // ── TMDB ──
    _searchTmdb(query, gen).then((_) => decPending());

    // ── Stremio Addons ──
    for (final provider in _addonProviders) {
      _searchAddon(query, provider, gen).then((_) => decPending());
    }
  }

  Future<void> _searchTmdb(String query, int gen) async {
    try {
      final results = await _api.searchMulti(query);
      if (gen != _searchGeneration || !mounted) return;

      final movies = results.where((m) => m.mediaType == 'movie').toList();
      final shows = results.where((m) => m.mediaType == 'tv').toList();

      setState(() {
        if (movies.isNotEmpty) {
          _sections.insert(0, _SearchSection(
            key: 'tmdb_movies',
            title: 'TMDB Movies',
            isTmdb: true,
            results: movies,
          ));
        }
        if (shows.isNotEmpty) {
          // Insert after tmdb_movies if it exists, else at 0
          final idx = _sections.indexWhere((s) => s.key == 'tmdb_movies');
          _sections.insert(idx >= 0 ? idx + 1 : 0, _SearchSection(
            key: 'tmdb_shows',
            title: 'TMDB Shows',
            isTmdb: true,
            results: shows,
          ));
        }
      });
    } catch (e) {
      debugPrint('TMDB search error: $e');
    }
  }

  Future<void> _searchAddon(String query, Map<String, dynamic> provider, int gen) async {
    final providerBaseUrl = provider['baseUrl'] as String;
    final providerName = provider['name'] as String;
    final providerIcon = provider['icon']?.toString() ?? '';
    final catalogs = provider['catalogs'] as List<Map<String, dynamic>>;

    // Group results by type (movie / series)
    final Map<String, List<Map<String, dynamic>>> byType = {};

    await Future.wait(catalogs.map((cat) async {
      try {
        final results = await _stremio.getCatalog(
          baseUrl: cat['addonBaseUrl'],
          type: cat['catalogType'],
          id: cat['catalogId'],
          search: query,
        );
        for (final r in results) {
          r['_addonBaseUrl'] = providerBaseUrl;
          r['_addonName'] = providerName;
        }
        final type = cat['catalogType']?.toString() ?? 'other';
        byType.putIfAbsent(type, () => []);
        byType[type]!.addAll(results);
      } catch (_) {}
    }));

    if (gen != _searchGeneration || !mounted) return;

    setState(() {
      for (final entry in byType.entries) {
        // Deduplicate within this type
        final seen = <String>{};
        final deduped = entry.value.where((r) {
          final id = r['id']?.toString() ?? '';
          if (id.isEmpty || seen.contains(id)) return false;
          seen.add(id);
          return true;
        }).toList();

        if (deduped.isEmpty) continue;

        final typeLabel = entry.key == 'series' ? 'Shows' : (entry.key == 'movie' ? 'Movies' : entry.key);
        _sections.add(_SearchSection(
          key: '${providerBaseUrl}_${entry.key}',
          title: '$providerName $typeLabel',
          icon: providerIcon,
          results: deduped,
        ));
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation helpers (unchanged from original)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openDetails(Movie movie) async {
    final settings = SettingsService();
    final isStreaming = await settings.isStreamingModeEnabled();
    if (!mounted) return;
    if (isStreaming) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => StreamingDetailsScreen(movie: movie)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(movie: movie)));
    }
  }

  Future<void> _openStremioItem(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final type = item['type']?.toString() ?? 'movie';
    final name = item['name']?.toString() ?? 'Unknown';
    final poster = item['poster']?.toString() ?? '';
    final isCustomId = !id.startsWith('tt');
    final isCollection = id.startsWith('ctmdb.') || type == 'collections';

    if (!isCustomId && !isCollection) {
      try {
        final movie = await _api.findByImdbId(id, mediaType: type == 'series' ? 'tv' : 'movie');
        if (movie != null && mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(movie: movie, stremioItem: item)));
          return;
        }
      } catch (_) {}
    }

    if (!isCustomId && !isCollection) {
      try {
        final results = await _api.searchMulti(name);
        if (results.isNotEmpty && mounted) {
          final match = results.firstWhere(
            (m) => m.title.toLowerCase() == name.toLowerCase(),
            orElse: () => results.first,
          );
          Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(movie: match, stremioItem: item)));
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
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
      final updatedItem = Map<String, dynamic>.from(item);
      if (isCollection) updatedItem['type'] = 'collections';
      Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(movie: movie, stremioItem: updatedItem)));
    }
  }

  @override
  void dispose() {
    MainScreen.stremioSearchNotifier.removeListener(_onExternalSearch);
    _controller.dispose();
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Search movies, shows...',
            hintStyle: TextStyle(color: AppTheme.textDisabled),
            border: InputBorder.none,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: AppTheme.textSecondary),
                    onPressed: () {
                      _controller.clear();
                      _onSearchChanged('');
                    },
                  )
                : Icon(Icons.search, color: AppTheme.textSecondary),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_query.isEmpty) return _buildEmpty();
    if (_sections.isEmpty && _isSearching) {
      return Center(child: CircularProgressIndicator(color: AppTheme.current.primaryColor));
    }
    if (_sections.isEmpty && !_isSearching) return _buildEmpty();

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _sections.length + (_isSearching ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _sections.length) {
          // Loading indicator at the bottom while more results are coming
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))),
          );
        }
        final section = _sections[index];
        return _buildSliderSection(section);
      },
    );
  }

  Widget _buildSliderSection(_SearchSection section) {
    final cardWidth = MediaQuery.of(context).size.width > 600 ? 140.0 : 120.0;
    final cardHeight = cardWidth * 1.5;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (section.icon != null && section.icon!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: section.icon!,
                      width: 20, height: 20,
                      errorWidget: (_, _, _) => const Icon(Icons.extension, size: 16, color: Colors.white38),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else if (section.isTmdb) ...[
                  const Icon(Icons.movie, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                ],
                Text(
                  section.title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${section.results.length}',
                  style: TextStyle(color: AppTheme.textDisabled, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Horizontal slider with scroll arrows
          ScrollableSlider(
            height: cardHeight + 32,
            itemCount: section.results.length,
            cardWidth: cardWidth,
            itemBuilder: (context, index) {
              final item = section.results[index];
              if (item is Movie) {
                return SizedBox(
                  width: cardWidth,
                  child: SearchCard(movie: item, onTap: () => _openDetails(item)),
                );
              } else {
                final map = item as Map<String, dynamic>;
                return SizedBox(
                  width: cardWidth,
                  child: StremioSearchCard(item: map, onTap: () => _openStremioItem(map)),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    if (_query.isEmpty && _searchHistory.isNotEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
            child: Row(
              children: [
                Text('Recent Searches', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: _clearSearchHistory,
                  child: Text('Clear All', style: TextStyle(color: AppTheme.textDisabled, fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchHistory.length,
              itemBuilder: (context, index) {
                final query = _searchHistory[index];
                return ListTile(
                  leading: Icon(Icons.history, color: AppTheme.textDisabled, size: 20),
                  title: Text(query, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  trailing: Icon(Icons.north_west, color: AppTheme.textDisabled, size: 16),
                  onTap: () {
                    _controller.text = query;
                    _onSearchChanged(query);
                  },
                );
              },
            ),
          ),
        ],
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _query.isEmpty ? Icons.search : Icons.movie_filter_outlined,
            size: 80,
            color: AppTheme.textDisabled.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _query.isEmpty ? 'Search for your favorite content' : 'No results found',
            style: TextStyle(color: AppTheme.textDisabled, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _query.isEmpty
                ? 'Movies, shows, anime — find it all here'
                : 'Try different keywords or check the spelling',
            style: TextStyle(color: AppTheme.textDisabled, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Scrollable slider with left/right arrows
