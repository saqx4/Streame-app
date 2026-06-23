import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/focus/focusable.dart';
import 'package:streame/core/repositories/tmdb_repository.dart';

import 'package:streame/core/providers/shared_providers.dart';
import 'package:streame/features/home/data/models/media_item.dart';
import 'package:streame/shared/widgets/media_card.dart';

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
    final prefs = ref.watch(sharedPreferencesProvider);
    final isLandscape = prefs.getBool('settings_card_landscape') ?? false;
    final edgeStyle = prefs.getString('settings_card_edge_style') ?? 'rounded';

    // Search/Watchlist standard dimensions
    final cardWidth = isLandscape ? 175.0 : 110.0;
    final cardHeight = isLandscape ? 100.0 : 165.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── Header + Search Bar ───
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.backgroundDark,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 14),
                    // Search input
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search movies & TV shows',
                        hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 16),
                        prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textTertiary, size: 24),
                        prefixIconConstraints: BoxConstraints(minWidth: 50, minHeight: 0),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded, color: AppTheme.textTertiary, size: 20),
                                onPressed: () {
                                  _controller.clear();
                                  ref.read(searchQueryProvider.notifier).state = '';
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppTheme.backgroundCard.withValues(alpha: 0.8),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppTheme.borderLight.withValues(alpha: 0.1), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppTheme.accentPrimary.withValues(alpha: 0.5), width: 1.5),
                        ),
                      ),
                      onChanged: (value) => _debouncer.run(() {
                        ref.read(searchQueryProvider.notifier).state = value;
                      }),
                      onSubmitted: (value) {
                        ref.read(searchQueryProvider.notifier).state = value;
                        _addRecentSearch(value);
                      },
                    ),
                    SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),

          // ─── Recent Searches ───
          if (!hasQuery && _recentSearches.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECENT',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _recentSearches.map((q) => GestureDetector(
                        onTap: () {
                          _controller.text = q;
                          ref.read(searchQueryProvider.notifier).state = q;
                        },
                        onLongPress: () => _removeRecentSearch(q),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundCard,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_rounded, size: 13, color: AppTheme.textTertiary),
                              SizedBox(width: 6),
                              Text(
                                q,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),

          // ─── Filter Chips ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: filter == 'all',
                    onTap: () => ref.read(searchFilterProvider.notifier).state = 'all',
                  ),
                  SizedBox(width: 8),
                  _FilterChip(
                    label: 'Movies',
                    isSelected: filter == 'movie',
                    onTap: () => ref.read(searchFilterProvider.notifier).state = 'movie',
                  ),
                  SizedBox(width: 8),
                  _FilterChip(
                    label: 'Shows',
                    isSelected: filter == 'tv',
                    onTap: () => ref.read(searchFilterProvider.notifier).state = 'tv',
                  ),
                ],
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
                      padding: const EdgeInsets.only(top: 72),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
                          SizedBox(height: 14),
                          Text('No results found', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                          SizedBox(height: 6),
                          Text('Try different keywords', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ));
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _calcColumns(context, isLandscape),
                      childAspectRatio: cardWidth / cardHeight,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];
                        return MediaCard(
                          item: item,
                          isLandscape: isLandscape,
                          cardWidth: cardWidth,
                          cardHeight: cardHeight,
                          edgeStyle: edgeStyle,
                          onTap: () {
                            _addRecentSearch(query);
                            final mt = item.mediaType == MediaType.tv ? 'tv' : 'movie';
                            context.push('/details/$mt/${item.id}');
                          },
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(child: Center(
                child: Padding(padding: const EdgeInsets.only(top: 72), child: Column(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(color: AppTheme.accentPrimary, strokeWidth: 2.5),
                    ),
                    SizedBox(height: 14),
                    Text('Searching...', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
                  ],
                )),
              )),
              error: (_, __) => SliverToBoxAdapter(child: Center(
                child: Padding(padding: const EdgeInsets.only(top: 72), child: Text('Search error', style: TextStyle(color: AppTheme.textTertiary))),
              )),
            )
          else
            // ─── Discover (no query) ───
            discoverAsync.when(
              data: (categories) {
                if (categories.isEmpty) return SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, catIndex) {
                      final entry = categories.entries.elementAt(catIndex);
                      return _DiscoverRail(
                        title: entry.key,
                        items: entry.value,
                        edgeStyle: edgeStyle,
                      );
                    },
                    childCount: categories.length,
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(child: Center(
                child: Padding(padding: const EdgeInsets.only(top: 72), child: CircularProgressIndicator(color: AppTheme.accentPrimary, strokeWidth: 2.5)),
              )),
              error: (_, __) => SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
        ],
      ),
    );
  }

  int _calcColumns(BuildContext context, bool isLandscape) {
    final width = MediaQuery.of(context).size.width;
    final baseWidth = isLandscape ? 180.0 : 125.0;
    return (width / baseWidth).floor().clamp(2, 8);
  }
}

// ═══════════════════════════════════════════════
// FILTER CHIP
// ═══════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreameFocusable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentPrimary.withValues(alpha: 0.15)
              : AppTheme.backgroundCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentPrimary.withValues(alpha: 0.5)
                : AppTheme.borderLight.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.accentPrimary : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// DISCOVER RAIL — Horizontal scroll row
// ═══════════════════════════════════════════════
class _DiscoverRail extends ConsumerWidget {
  final String title;
  final List<MediaItem> items;
  final String edgeStyle;

  const _DiscoverRail({
    required this.title,
    required this.items,
    this.edgeStyle = 'rounded',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const cardWidth = 175.0;
    const cardHeight = 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            height: cardHeight + 20,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: MediaCard(
                    item: item,
                    isLandscape: true,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    edgeStyle: edgeStyle,
                    onTap: () {
                      final mt = item.mediaType == MediaType.tv ? 'tv' : 'movie';
                      context.push('/details/$mt/${item.id}');
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
