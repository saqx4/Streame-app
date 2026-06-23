import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/core/theme/app_theme.dart';

import 'package:streame/core/repositories/watchlist_repository.dart';
import 'package:streame/core/repositories/profile_repository.dart';
import 'package:streame/core/providers/shared_providers.dart';
import 'package:streame/features/home/data/models/media_item.dart';
import 'package:streame/shared/widgets/media_card.dart';
import 'package:streame/shared/widgets/streame_toast.dart';


class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  int _selectedTab = 0; // 0 = All, 1 = Movies, 2 = TV

  @override
  Widget build(BuildContext context) {
    final watchlistAsync = ref.watch(userWatchlistProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final isLandscape = prefs.getBool('settings_card_landscape') ?? false;
    final edgeStyle = prefs.getString('settings_card_edge_style') ?? 'rounded';

    // Search/Watchlist standard dimensions
    final cardWidth = isLandscape ? 175.0 : 110.0;
    final cardHeight = isLandscape ? 100.0 : 165.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: watchlistAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return _buildEmptyState();
          }

          final filtered = _selectedTab == 0
              ? items
              : _selectedTab == 1
                  ? items.where((i) => i.mediaType == 'movie').toList()
                  : items.where((i) => i.mediaType != 'movie').toList();

          final movieCount = items.where((i) => i.mediaType == 'movie').length;
          final tvCount = items.where((i) => i.mediaType != 'movie').length;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── Header ───
              SliverToBoxAdapter(
                child: Container(
                  color: AppTheme.backgroundDark,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8),
                        Text(
                          'My List',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: 16),
                        // ─── Filter chips ───
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'All',
                                count: items.length,
                                isSelected: _selectedTab == 0,
                                onTap: () => setState(() => _selectedTab = 0),
                              ),
                              SizedBox(width: 8),
                              _FilterChip(
                                label: 'Movies',
                                count: movieCount,
                                isSelected: _selectedTab == 1,
                                onTap: () => setState(() => _selectedTab = 1),
                              ),
                              SizedBox(width: 8),
                              _FilterChip(
                                label: 'TV Shows',
                                count: tvCount,
                                isSelected: _selectedTab == 2,
                                onTap: () => setState(() => _selectedTab = 2),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _calcColumns(context, isLandscape),
                    childAspectRatio: cardWidth / cardHeight,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filtered[index];
                      final mediaItem = MediaItem(
                        id: item.tmdbId,
                        title: item.title,
                        mediaType: item.mediaType == 'tv' ? MediaType.tv : MediaType.movie,
                        image: item.posterPath ?? '',
                      );

                      return MediaCard(
                        item: mediaItem,
                        isLandscape: isLandscape,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        edgeStyle: edgeStyle,
                        onDismiss: () => _removeItem(item),
                        onTap: () => context.push('/details/${item.mediaType}/${item.tmdbId}'),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.textTertiary, strokeWidth: 2),
        ),
        error: (_, __) => Center(
          child: Text('Error loading watchlist', style: TextStyle(color: AppTheme.textTertiary)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.textPrimary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_outline_rounded,
                color: AppTheme.textTertiary,
                size: 36,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Nothing saved yet',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Movies and shows you save will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeItem(dynamic item) async {
    try {
      final profileId = ref.read(activeProfileIdProvider);
      if (profileId == null) return;
      final repo = ref.read(watchlistRepositoryProvider(profileId));
      await repo.removeFromWatchlist(item.tmdbId, item.mediaType, imdbId: item.imdbId);
      ref.invalidate(userWatchlistProvider);
      if (mounted) {
        StreameToast.show(
          context,
          message: 'Removed from list',
          type: StreameToastType.info,
        );
      }
    } catch (_) {}
  }

  int _calcColumns(BuildContext context, bool isLandscape) {
    final width = MediaQuery.of(context).size.width;
    final baseWidth = isLandscape ? 180.0 : 125.0;
    return (width / baseWidth).floor().clamp(2, 8);
  }
}

// ─── Filter chip ───
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentPrimary.withValues(alpha: 0.15)
              : AppTheme.backgroundCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentPrimary.withValues(alpha: 0.4)
                : AppTheme.borderLight.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accentPrimary : AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppTheme.accentPrimary.withValues(alpha: 0.2)
                      : AppTheme.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? AppTheme.accentPrimary : AppTheme.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
