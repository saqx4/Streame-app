import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/focus/focusable.dart';
import 'package:streame/core/repositories/tmdb_repository.dart';
import 'package:streame/features/home/data/models/media_item.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchFilterProvider = StateProvider<String>((ref) => 'all');

final searchResultsProvider = FutureProvider.autoDispose<List<MediaItem>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.length < 2) return [];
  final repo = ref.watch(tmdbRepositoryProvider);
  final filter = ref.watch(searchFilterProvider);
  if (filter == 'tv') {
    return repo.search(query, mediaType: MediaType.tv);
  } else if (filter == 'movie') {
    return repo.search(query, mediaType: MediaType.movie);
  }
  return repo.search(query);
});

// Discover categories when no search query
final discoverProvider = FutureProvider<Map<String, List<MediaItem>>>((ref) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  final results = <String, List<MediaItem>>{};
  final trending = await repo.getTrendingMovies(page: 1);
  final popularTv = await repo.getPopularTv(page: 1);
  results['Trending Now'] = trending;
  results['Popular TV'] = popularTv;
  return results;
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _debouncer = _Debouncer(milliseconds: 400);
  final List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('recent_searches') ?? [];
    if (mounted) setState(() => _recentSearches.addAll(saved.take(8)));
  }

  Future<void> _addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 8) _recentSearches.removeRange(8, _recentSearches.length);
    await prefs.setStringList('recent_searches', _recentSearches);
    if (mounted) setState(() {});
  }

  Future<void> _removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query);
    await prefs.setStringList('recent_searches', _recentSearches);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final filter = ref.watch(searchFilterProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final discoverAsync = ref.watch(discoverProvider);
    final hasQuery = query.length >= 2;

    // Determine header title (Nuvio: changes based on context)
    final headerTitle = hasQuery ? 'Search' : 'Search';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // ─── Nuvio-style sticky header ───
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.backgroundDark,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header title (Nuvio: NuvioScreenHeader)
                    Text(
                      headerTitle,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Search input (Nuvio: NuvioInputField — rounded, filled)
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundElevated,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: _focusNode.hasFocus ? AppTheme.textPrimary.withValues(alpha: 0.5) : AppTheme.borderLight.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Search movies, shows...',
                          hintStyle: const TextStyle(color: AppTheme.textTertiary),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8),
                            child: Icon(Icons.search, color: AppTheme.textSecondary, size: 22),
                          ),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                                  onPressed: () {
                                    _controller.clear();
                                    ref.read(searchQueryProvider.notifier).state = '';
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        ),
                        onChanged: (value) => _debouncer.run(() {
                          ref.read(searchQueryProvider.notifier).state = value;
                        }),
                        onSubmitted: (value) {
                          ref.read(searchQueryProvider.notifier).state = value;
                          _addRecentSearch(value);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
          // ─── Recent searches (Nuvio: SearchRecentSection) ───
          if (!hasQuery && _recentSearches.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Searches',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._recentSearches.map((q) => _RecentSearchRow(
                      query: q,
                      onTap: () {
                        _controller.text = q;
                        ref.read(searchQueryProvider.notifier).state = q;
                      },
                      onRemove: () => _removeRecentSearch(q),
                    )),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          // ─── Filter chips ───
          if (!hasQuery)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _NuvioFilterChip(label: 'All', isSelected: filter == 'all', onTap: () => ref.read(searchFilterProvider.notifier).state = 'all'),
                      const SizedBox(width: 8),
                      _NuvioFilterChip(label: 'Movies', isSelected: filter == 'movie', onTap: () => ref.read(searchFilterProvider.notifier).state = 'movie'),
                      const SizedBox(width: 8),
                      _NuvioFilterChip(label: 'TV Shows', isSelected: filter == 'tv', onTap: () => ref.read(searchFilterProvider.notifier).state = 'tv'),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _NuvioFilterChip(label: 'All', isSelected: filter == 'all', onTap: () => ref.read(searchFilterProvider.notifier).state = 'all'),
                      const SizedBox(width: 8),
                      _NuvioFilterChip(label: 'Movies', isSelected: filter == 'movie', onTap: () => ref.read(searchFilterProvider.notifier).state = 'movie'),
                      const SizedBox(width: 8),
                      _NuvioFilterChip(label: 'TV Shows', isSelected: filter == 'tv', onTap: () => ref.read(searchFilterProvider.notifier).state = 'tv'),
                    ],
                  ),
                ),
              ),
            ),
          // ─── Search Results ───
          if (hasQuery)
            resultsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return SliverToBoxAdapter(child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 48, color: AppTheme.textTertiary.withValues(alpha: 0.6)),
                          const SizedBox(height: 16),
                          Text('No results found', style: TextStyle(color: AppTheme.textTertiary, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Try different keywords', style: TextStyle(color: AppTheme.textTertiary.withValues(alpha: 0.6), fontSize: 14)),
                        ],
                      ),
                    ),
                  ));
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _calcColumns(context),
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 20,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];
                        final mt = item.mediaType == MediaType.tv ? 'tv' : 'movie';
                        return _SearchCard(item: item, onTap: () {
                          _addRecentSearch(query);
                          context.push('/details/$mt/${item.id}');
                        });
                      },
                      childCount: items.length,
                    ),
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(child: Center(
                child: Padding(padding: const EdgeInsets.only(top: 64), child: Column(
                  children: [
                    CircularProgressIndicator(color: AppTheme.textPrimary.withValues(alpha: 0.5), strokeWidth: 2.5),
                    const SizedBox(height: 16),
                    Text('Searching...', style: TextStyle(color: AppTheme.textTertiary, fontSize: 14)),
                  ],
                )),
              )),
              error: (_, __) => SliverToBoxAdapter(child: Center(
                child: Padding(padding: const EdgeInsets.only(top: 64), child: Text('Search error', style: TextStyle(color: AppTheme.textTertiary))),
              )),
            )
          else
            // ─── Discover categories (when no query) ───
            discoverAsync.when(
              data: (categories) {
                if (categories.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, catIndex) {
                      final entry = categories.entries.elementAt(catIndex);
                      return _DiscoverRail(title: entry.key, items: entry.value);
                    },
                    childCount: categories.length,
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(child: Center(
                child: Padding(padding: const EdgeInsets.only(top: 64), child: CircularProgressIndicator(color: AppTheme.textPrimary.withValues(alpha: 0.5), strokeWidth: 2.5)),
              )),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
        ],
      ),
    );
  }

  int _calcColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return (width / 160).floor().clamp(3, 8);
  }
}

// ═══════════════════════════════════════════════
// NUVIO-STYLE FILTER CHIP (rounded 16dp, animated)
// ═══════════════════════════════════════════════
class _NuvioFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NuvioFilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreameFocusable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.textPrimary : AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.textPrimary : AppTheme.borderLight.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? AppTheme.backgroundDark : AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        )),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// RECENT SEARCH ROW (Nuvio: SearchRecentSection item)
// ═══════════════════════════════════════════════
class _RecentSearchRow extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentSearchRow({required this.query, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return StreameFocusable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.history, color: AppTheme.textTertiary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(query, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Semantics(
              button: true,
              label: 'Remove $query',
              child: GestureDetector(
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, color: AppTheme.textTertiary, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// SEARCH RESULT CARD (same style as ViewAll screen)
// ═══════════════════════════════════════════════
class _SearchCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback? onTap;
  const _SearchCard({required this.item, this.onTap});

  @override
  State<_SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<_SearchCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final img = widget.item.image;
    return StreameFocusable(
      onTap: widget.onTap ?? () {},
      child: Semantics(
        button: true,
        label: widget.item.title,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Focus(
            onFocusChange: (focused) => setState(() => _isFocused = focused),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (img.isNotEmpty)
                          ResilientNetworkImage(
                          imageUrl: img.startsWith('http') ? img : 'https://image.tmdb.org/t/p/w500$img',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.backgroundElevated,
                            child: const Icon(Icons.movie, color: AppTheme.textTertiary),
                          ),
                        )
                      else
                        Container(
                          color: AppTheme.backgroundElevated,
                          child: const Icon(Icons.movie, color: AppTheme.textTertiary),
                        ),
                      // Rating badge
                      if (widget.item.tmdbRatingDouble > 0)
                        Positioned(
                          top: 6, right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.accentYellow, borderRadius: BorderRadius.circular(4)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.star, size: 10, color: AppTheme.backgroundDark),
                              const SizedBox(width: 2),
                              Text(widget.item.tmdbRating, style: const TextStyle(color: AppTheme.backgroundDark, fontSize: 10, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                      // Focus border
                      if (_isFocused)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.focusRing, width: 2.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ),
);
  }
}

// ═══════════════════════════════════════════════
// DISCOVER RAIL (Nuvio: NuvioShelfSection style)
// ═══════════════════════════════════════════════
class _DiscoverRail extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  const _DiscoverRail({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(title, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, letterSpacing: -0.2,
            )),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final imageUrl = item.backdrop ?? item.image;
                final mt = item.mediaType == MediaType.tv ? 'tv' : 'movie';
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: StreameFocusable(
                    onTap: () => context.push('/details/$mt/${item.id}'),
                    child: Container(
                      width: 260, height: 146,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight.withValues(alpha: 0.24), width: 0.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (imageUrl.isNotEmpty)
                              ResilientNetworkImage(
                                imageUrl: imageUrl.startsWith('http') ? imageUrl : 'https://image.tmdb.org/t/p/w500$imageUrl',
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(color: AppTheme.backgroundElevated),
                              )
                            else
                              Container(color: AppTheme.backgroundElevated),
                            Container(decoration: BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [Colors.transparent, AppTheme.backgroundDark.withValues(alpha: 0.85)]),
                            )),
                            Positioned(
                              bottom: 8, left: 10, right: 10,
                              child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600,
                                  shadows: [Shadow(color: AppTheme.backgroundDark, blurRadius: 4)])),
                            ),
                            if (item.tmdbRatingDouble > 0)
                              Positioned(
                                top: 8, right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(color: AppTheme.accentYellow, borderRadius: BorderRadius.circular(4)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.star, size: 12, color: AppTheme.backgroundDark),
                                    const SizedBox(width: 3),
                                    Text(item.tmdbRating, style: const TextStyle(color: AppTheme.backgroundDark, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
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

class _Debouncer {
  final int milliseconds;
  VoidCallback? _action;
  DateTime? _lastRun;

  _Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _action = action;
    final now = DateTime.now();
    final elapsed = _lastRun != null ? now.difference(_lastRun!).inMilliseconds : milliseconds;
    if (elapsed >= milliseconds) {
      _lastRun = now;
      _action!();
    }
  }
}
