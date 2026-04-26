import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:streame_core/api/stremio_service.dart';
import 'package:streame_core/api/tmdb_api.dart';
import 'package:streame_core/models/movie.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'details_screen.dart';
import 'stremio/stremio_widgets.dart';

/// Full-screen catalog browser for Stremio addons.
/// Shows all catalogs from installed addons, supports genre filtering,
/// search within catalogs, and pagination.
class StremioCatalogScreen extends StatefulWidget {
  /// If set, opens directly to this specific catalog.
  final Map<String, dynamic>? initialCatalog;
  /// If set, pre-fills the search field.
  final String? initialSearch;

  const StremioCatalogScreen({super.key, this.initialCatalog, this.initialSearch});

  @override
  State<StremioCatalogScreen> createState() => _StremioCatalogScreenState();
}

class _StremioCatalogScreenState extends State<StremioCatalogScreen> {
  final StremioService _stremio = StremioService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allCatalogs = [];
  Map<String, dynamic>? _selectedCatalog;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _skip = 0;
  String? _selectedGenre;
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'movie', 'series'
  bool _isSidebarCollapsed = false;
  bool _sidebarInitDone = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialSearch != null) {
      _searchController.text = widget.initialSearch!;
      _searchQuery = widget.initialSearch!;
    }
    _loadCatalogs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sidebarInitDone) return;
    final width = MediaQuery.of(context).size.width;
    if (width > 900 && width < 1200) {
      _isSidebarCollapsed = true;
    }
    _sidebarInitDone = true;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadCatalogs() async {
    final catalogs = await _stremio.getAllCatalogs();
    if (!mounted) return;
    setState(() {
      _allCatalogs = catalogs;
      if (widget.initialCatalog != null) {
        _selectedCatalog = widget.initialCatalog;
      } else if (catalogs.isNotEmpty) {
        _selectedCatalog = catalogs.first;
      }
      _isLoading = false;
    });
    if (_selectedCatalog != null) {
      _fetchCatalogItems();
    }
  }

  List<Map<String, dynamic>> get _filteredCatalogs {
    if (_filterType == 'all') return _allCatalogs;
    return _allCatalogs.where((c) => c['catalogType'] == _filterType).toList();
  }

  Future<void> _fetchCatalogItems() async {
    if (_selectedCatalog == null) return;
    setState(() {
      _isLoading = true;
      _items = [];
      _skip = 0;
      _hasMore = true;
    });

    final cat = _selectedCatalog!;
    final results = await _stremio.getCatalog(
      baseUrl: cat['addonBaseUrl'],
      type: cat['catalogType'],
      id: cat['catalogId'],
      genre: _selectedGenre,
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
    );

    // Tag each item with the addon that provided it
    for (final item in results) {
      item['_addonBaseUrl'] = cat['addonBaseUrl'];
      item['_addonName'] = cat['addonName'];
    }

    if (!mounted) return;
    setState(() {
      _items = results;
      _isLoading = false;
      _hasMore = results.length >= 100;
      _skip = results.length;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _selectedCatalog == null) return;
    final cat = _selectedCatalog!;
    if (cat['supportsSkip'] != true) return;

    setState(() => _isLoadingMore = true);
    final results = await _stremio.getCatalog(
      baseUrl: cat['addonBaseUrl'],
      type: cat['catalogType'],
      id: cat['catalogId'],
      genre: _selectedGenre,
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      skip: _skip,
    );
    // Tag each item with the addon that provided it
    for (final item in results) {
      item['_addonBaseUrl'] = cat['addonBaseUrl'];
      item['_addonName'] = cat['addonName'];
    }
    if (!mounted) return;
    setState(() {
      _items.addAll(results);
      _skip += results.length;
      _hasMore = results.length >= 100;
      _isLoadingMore = false;
    });
  }

  void _selectCatalog(Map<String, dynamic> catalog) {
    setState(() {
      _selectedCatalog = catalog;
      _selectedGenre = null;
      _searchQuery = '';
      _searchController.clear();
    });
    _fetchCatalogItems();
  }

  void _selectGenre(String? genre) {
    setState(() => _selectedGenre = genre);
    _fetchCatalogItems();
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final type = item['type']?.toString() ?? 'movie';
    final name = item['name']?.toString() ?? 'Unknown';
    final isCustomId = !id.startsWith('tt');
    
    // Check if this is a collection by ID prefix
    final isCollection = id.startsWith('ctmdb.') || type == 'collections';

    // Tag item with addon info from the selected catalog
    if (_selectedCatalog != null) {
      item['_addonBaseUrl'] ??= _selectedCatalog!['addonBaseUrl'];
      item['_addonName'] ??= _selectedCatalog!['addonName'];
    }

    // If IMDB id → resolve via TMDB
    if (!isCustomId && !isCollection) {
      final tmdb = TmdbApi();
      try {
        final movie = await tmdb.findByImdbId(id, mediaType: type == 'series' ? 'tv' : 'movie');
        if (movie != null && mounted) {
          _navigateToDetails(movie);
          return;
        }
      } catch (_) {}
    }

    // For non-custom IDs that failed IMDB lookup, try name search
    if (!isCustomId && !isCollection) {
      final tmdb = TmdbApi();
      try {
        final results = await tmdb.searchMulti(name);
        if (results.isNotEmpty && mounted) {
          final match = results.firstWhere(
            (m) => m.title.toLowerCase() == name.toLowerCase(),
            orElse: () => results.first,
          );
          _navigateToDetails(match);
          return;
        }
      } catch (_) {}
    }

    // Custom ID, collection, or all lookups failed → use Stremio poster directly
    if (mounted) {
      // Update the item type to collections if needed
      if (isCollection) {
        item['type'] = 'collections';
      }
      
      final movie = _stremioMetaToMovie(item);
      _navigateToDetails(movie, stremioItem: item);
    }
  }

  Movie _stremioMetaToMovie(Map<String, dynamic> meta) {
    final id = meta['id']?.toString() ?? '';
    final type = meta['type']?.toString() ?? 'movie';
    final imdbId = id.startsWith('tt') ? id : null;
    final isCollection = id.startsWith('ctmdb.') || type == 'collections';
    
    return Movie(
      id: imdbId != null ? 0 : id.hashCode,
      imdbId: imdbId,
      title: meta['name']?.toString() ?? 'Unknown',
      posterPath: meta['poster']?.toString() ?? '',
      backdropPath: meta['background']?.toString() ?? meta['poster']?.toString() ?? '',
      voteAverage: double.tryParse(meta['imdbRating']?.toString() ?? '') ?? 0.0,
      releaseDate: meta['releaseInfo']?.toString() ?? '',
      overview: meta['description']?.toString() ?? '',
      genres: (meta['genres'] as List?)?.cast<String>() ?? [],
      mediaType: isCollection ? 'collections' : ((type == 'series' || type == 'channel') ? 'tv' : 'movie'),
      numberOfSeasons: 0,
    );
  }

  Future<void> _navigateToDetails(Movie movie, {Map<String, dynamic>? stremioItem}) async {
    // Always use DetailsScreen for Stremio catalog items (they have addon context)
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DetailsScreen(movie: movie, stremioItem: stremioItem),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: _allCatalogs.isEmpty && !_isLoading
          ? _buildEmptyState()
          : isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.extension_off, size: 80, color: AppTheme.textDisabled.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No catalog addons installed', style: TextStyle(color: AppTheme.textDisabled, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Install Stremio addons in Settings', style: TextStyle(color: AppTheme.textDisabled, fontSize: 13)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DESKTOP LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left sidebar — catalog list
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: _isSidebarCollapsed ? 64 : 300,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A2E), Color(0xFF0D0D16)],
            ),
            border: Border(right: BorderSide(color: GlassColors.borderSubtle)),
          ),
          child: Column(
            children: [
              _buildSidebarHeader(),
              if (!_isSidebarCollapsed) _buildTypeFilter(),
              Expanded(child: _buildCatalogList()),
            ],
          ),
        ),
        // Right content
        Expanded(child: _buildContentArea()),
      ],
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        _isSidebarCollapsed ? 12 : 20,
        MediaQuery.of(context).padding.top + 16,
        _isSidebarCollapsed ? 12 : 20,
        16,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: GlassColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: GlassColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textSecondary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (!_isSidebarCollapsed) const SizedBox(width: 14),
          if (!_isSidebarCollapsed)
            Expanded(
              child: Text('Catalogs', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            ),
          if (!_isSidebarCollapsed) const SizedBox(width: 8),
          if (_isSidebarCollapsed)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
                onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                tooltip: 'Expand sidebar',
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
                onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                tooltip: 'Collapse sidebar',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('Movies', 'movie'),
            const SizedBox(width: 8),
            _buildFilterChip('Series', 'series'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    final selected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.current.primaryColor : GlassColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppTheme.textPrimary : AppTheme.textDisabled,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogList() {
    final catalogs = _filteredCatalogs;
    // Group by addon name
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final c in catalogs) {
      final name = c['addonName'] as String;
      grouped.putIfAbsent(name, () => []).add(c);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Row(
              children: [
                if ((entry.value.first['addonIcon'] ?? '').toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: entry.value.first['addonIcon'],
                      width: 18, height: 18,
                      errorWidget: (_, _, _) => Icon(Icons.extension, size: 18, color: AppTheme.textDisabled),
                    ),
                  ),
                if ((entry.value.first['addonIcon'] ?? '').toString().isNotEmpty)
                  const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(color: AppTheme.textDisabled, fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          for (final cat in entry.value)
            _buildCatalogTile(cat),
        ],
      ],
    );
  }

  Widget _buildCatalogTile(Map<String, dynamic> cat) {
    final isSelected = _selectedCatalog != null &&
        _selectedCatalog!['addonBaseUrl'] == cat['addonBaseUrl'] &&
        _selectedCatalog!['catalogId'] == cat['catalogId'] &&
        _selectedCatalog!['catalogType'] == cat['catalogType'];

    if (_isSidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Tooltip(
          message: cat['catalogName'],
          child: Material(
            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => _selectCatalog(cat),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  cat['catalogType'] == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
                  size: 20,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textDisabled,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Material(
        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _selectCatalog(cat),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.current.primaryColor.withValues(alpha: 0.2)
                        : GlassColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    cat['catalogType'] == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
                    size: 16,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textDisabled,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cat['catalogName'],
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: GlassColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      cat['catalogType'].toString().toUpperCase(),
                      style: TextStyle(color: AppTheme.textDisabled, fontSize: 9),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MOBILE LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout() {
    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── App Bar ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: GlassColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textSecondary, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Catalogs', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                        if (_selectedCatalog != null)
                          Text(
                            '${_selectedCatalog!['addonName']} • ${_selectedCatalog!['catalogName']}',
                            style: TextStyle(color: AppTheme.textDisabled, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.dashboard_rounded, color: AppTheme.primaryColor, size: 20),
                        onPressed: _showCatalogPicker,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Type filter chips ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  _buildMobileFilterPill('All', 'all'),
                  const SizedBox(width: 8),
                  _buildMobileFilterPill('Movies', 'movie'),
                  const SizedBox(width: 8),
                  _buildMobileFilterPill('Series', 'series'),
                ],
              ),
            ),
          ),

          // ── Quick catalog scroller ──
          SliverToBoxAdapter(
            child: _buildMobileCatalogScroller(),
          ),

          // ── Genre chips ──
          if (_selectedCatalog != null && (_selectedCatalog!['genres'] as List).isNotEmpty)
            SliverToBoxAdapter(child: _buildGenreChips()),

          // ── Search bar ──
          if (_selectedCatalog != null && _selectedCatalog!['supportsSearch'] == true)
            SliverToBoxAdapter(child: _buildSearchBar()),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        body: _buildContentGrid(),
      ),
    );
  }

  Widget _buildMobileFilterPill(String label, String type) {
    final selected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.current.primaryColor : GlassColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.textPrimary : AppTheme.textDisabled,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCatalogScroller() {
    final catalogs = _filteredCatalogs;
    if (catalogs.isEmpty) return const SizedBox.shrink();

    // Group catalogs by addon
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final c in catalogs) {
      grouped.putIfAbsent(c['addonName'] as String, () => []).add(c);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: catalogs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final cat = catalogs[index];
            final isSelected = _selectedCatalog != null &&
                _selectedCatalog!['addonBaseUrl'] == cat['addonBaseUrl'] &&
                _selectedCatalog!['catalogId'] == cat['catalogId'] &&
                _selectedCatalog!['catalogType'] == cat['catalogType'];
            final addonIcon = (cat['addonIcon'] ?? '').toString();

            return GestureDetector(
              onTap: () => _selectCatalog(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 130,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.current.primaryColor.withValues(alpha: 0.15) : GlassColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppTheme.current.primaryColor.withValues(alpha: 0.5) : GlassColors.borderSubtle,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (addonIcon.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: addonIcon, width: 16, height: 16,
                              errorWidget: (_, _, _) => Icon(
                                cat['catalogType'] == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
                                size: 16, color: AppTheme.textDisabled,
                              ),
                            ),
                          )
                        else
                          Icon(
                            cat['catalogType'] == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
                            size: 16, color: isSelected ? AppTheme.primaryColor : AppTheme.textDisabled,
                          ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: cat['catalogType'] == 'series'
                                ? Colors.blue.withValues(alpha: 0.2)
                                : AppTheme.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (cat['catalogType'] as String).toUpperCase(),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: cat['catalogType'] == 'series' ? Colors.blue[300] : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      cat['catalogName'] as String,
                      style: TextStyle(
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat['addonName'] as String,
                      style: TextStyle(color: AppTheme.textDisabled, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCatalogPicker() {
    final catalogs = _filteredCatalogs;
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final c in catalogs) {
      grouped.putIfAbsent(c['addonName'] as String, () => []).add(c);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppTheme.textDisabled, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.dashboard_rounded, color: AppTheme.primaryColor, size: 22),
                const SizedBox(width: 10),
                Text('All Catalogs', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${catalogs.length}', style: TextStyle(color: AppTheme.textDisabled, fontSize: 13)),
              ],
            ),
          ),
          Divider(color: GlassColors.borderSubtle, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                    child: Row(
                      children: [
                        if ((entry.value.first['addonIcon'] ?? '').toString().isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: CachedNetworkImage(
                              imageUrl: entry.value.first['addonIcon'],
                              width: 20, height: 20,
                              errorWidget: (_, _, _) => Icon(Icons.extension, size: 20, color: AppTheme.textDisabled),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(entry.key,
                            style: TextStyle(color: AppTheme.textDisabled, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  for (final cat in entry.value)
                    _buildCatalogPickerTile(cat, ctx),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogPickerTile(Map<String, dynamic> cat, BuildContext sheetCtx) {
    final isSelected = _selectedCatalog != null &&
        _selectedCatalog!['addonBaseUrl'] == cat['addonBaseUrl'] &&
        _selectedCatalog!['catalogId'] == cat['catalogId'] &&
        _selectedCatalog!['catalogType'] == cat['catalogType'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            Navigator.pop(sheetCtx);
            _selectCatalog(cat);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  cat['catalogType'] == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
                  size: 20,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textDisabled,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cat['catalogName'] as String,
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cat['catalogType'] == 'series'
                        ? Colors.blue.withValues(alpha: 0.15)
                        : AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    (cat['catalogType'] as String).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: cat['catalogType'] == 'series' ? Colors.blue[300] : AppTheme.primaryColor,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenreChips() {
    final genres = (_selectedCatalog!['genres'] as List).cast<String>();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: genres.length + 1, // +1 for "All" chip
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildGenreChip('All', null);
            }
            return _buildGenreChip(genres[index - 1], genres[index - 1]);
          },
        ),
      ),
    );
  }

  Widget _buildGenreChip(String label, String? genre) {
    final isSelected = _selectedGenre == genre;
    return GestureDetector(
      onTap: () => _selectGenre(genre),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.current.primaryColor.withValues(alpha: 0.25) : GlassColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.current.primaryColor.withValues(alpha: 0.5) : GlassColors.borderSubtle, width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.textPrimary : AppTheme.textDisabled,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search in ${_selectedCatalog!['catalogName']}...',
          hintStyle: TextStyle(color: AppTheme.textDisabled, fontSize: 14),
          filled: true,
          fillColor: AppTheme.bgCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: GlassColors.borderSubtle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: GlassColors.borderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppTheme.primaryColor),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppTheme.textDisabled, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _fetchCatalogItems();
                  },
                )
              : Icon(Icons.search, color: AppTheme.textDisabled, size: 18),
        ),
        onSubmitted: (query) {
          setState(() => _searchQuery = query);
          _fetchCatalogItems();
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CONTENT AREA (shared)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildContentArea() {
    return Column(
      children: [
        if (_selectedCatalog != null) ...[
          _buildContentHeader(),
          if (_selectedCatalog!['supportsSearch'] == true) _buildDesktopSearchBar(),
          if ((_selectedCatalog!['genres'] as List).isNotEmpty) _buildGenreChips(),
        ],
        const SizedBox(height: 8),
        Expanded(child: _buildContentGrid()),
      ],
    );
  }

  Widget _buildContentHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 12),
      child: Row(
        children: [
          if ((_selectedCatalog!['addonIcon'] ?? '').toString().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: _selectedCatalog!['addonIcon'],
                width: 32, height: 32,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if ((_selectedCatalog!['addonIcon'] ?? '').toString().isNotEmpty)
            const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCatalog!['catalogName'],
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'from ${_selectedCatalog!['addonName']}',
                  style: TextStyle(color: AppTheme.textDisabled, fontSize: 13),
                ),
              ],
            ),
          ),
          if (_items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: GlassColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_items.length} items',
                style: TextStyle(color: AppTheme.textDisabled, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search in ${_selectedCatalog!['catalogName']}...',
          hintStyle: TextStyle(color: AppTheme.textDisabled, fontSize: 14),
          filled: true,
          fillColor: GlassColors.surfaceSubtle,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textDisabled, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: AppTheme.textDisabled, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _fetchCatalogItems();
                  },
                )
              : null,
        ),
        onSubmitted: (query) {
          setState(() => _searchQuery = query);
          _fetchCatalogItems();
        },
      ),
    );
  }

  Widget _buildContentGrid() {
    if (_isLoading && _items.isEmpty) {
      return _buildShimmerGrid();
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter, size: 60, color: AppTheme.textDisabled.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No results for "$_searchQuery"' : 'No items in this catalog',
              style: TextStyle(color: AppTheme.textDisabled, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    // Determine poster shape from first item
    final shape = _items.firstOrNull?['posterShape']?.toString() ?? 'poster';
    final double aspectRatio;
    final int crossAxisCount;

    if (shape == 'landscape') {
      aspectRatio = 16 / 9;
      crossAxisCount = width > 1200 ? 5 : (width > 900 ? 4 : (width > 600 ? 3 : 2));
    } else if (shape == 'square') {
      aspectRatio = 1.0;
      crossAxisCount = width > 1200 ? 6 : (width > 900 ? 5 : (width > 600 ? 4 : 3));
    } else {
      aspectRatio = 2 / 3;
      crossAxisCount = width > 1200 ? 7 : (width > 900 ? 5 : (width > 600 ? 4 : 3));
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: _items.length + (_isLoadingMore ? 3 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return _buildShimmerCard();
        }
        return StremioCatalogCard(
          item: _items[index],
          onTap: () => _openItem(_items[index]),
        );
      },
    );
  }

  Widget _buildShimmerGrid() {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200 ? 7 : (width > 900 ? 5 : (width > 600 ? 4 : 3));

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: 20,
      itemBuilder: (_, _) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: AppTheme.bgCard,
      highlightColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CATALOG CARD
// ═══════════════════════════════════════════════════════════════════════════════
