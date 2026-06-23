import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/models/catalog_models.dart';
import 'package:streame/core/repositories/catalog_repository.dart';
import 'package:streame/core/repositories/profile_repository.dart';
import 'package:streame/features/collections/data/repositories/collection_items_repository.dart';
import 'package:streame/features/home/data/models/media_item.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';
import 'package:streame/core/focus/focusable.dart';
import 'package:streame/shared/widgets/skeleton_loader.dart';

final _currentCatalogProvider = FutureProvider.family<CatalogConfig?, String>((ref, catalogId) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return null;
  
  final catalogs = await ref.watch(catalogsProvider(profileId).future);
  return catalogs.where((c) => c.id == catalogId).firstOrNull;
});

class CollectionDetailsScreen extends ConsumerWidget {
  final String catalogId;

  const CollectionDetailsScreen({super.key, required this.catalogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(_currentCatalogProvider(catalogId));

    return catalogAsync.when(
      data: (catalog) {
        if (catalog == null) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundDark,
            body: Center(child: Text('Collection not found', style: TextStyle(color: AppTheme.textPrimary))),
          );
        }
        return _CollectionDetailsContent(catalog: catalog);
      },
      loading: () => Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(child: CircularProgressIndicator(color: AppTheme.focusRing)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(child: Text('Error: $err', style: TextStyle(color: AppTheme.textPrimary))),
      ),
    );
  }
}

class _CollectionDetailsContent extends ConsumerWidget {
  final CatalogConfig catalog;
  const _CollectionDetailsContent({required this.catalog});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(collectionItemsProvider(catalog));

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          if (catalog.collectionDescription != null && catalog.collectionDescription!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  catalog.collectionDescription!,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ),
            ),
          itemsAsync.when(
            data: (items) => _buildGrid(context, items),
            loading: () => _buildLoadingGrid(),
            error: (err, _) => SliverFillRemaining(
              child: Center(child: Text('Error loading items', style: TextStyle(color: AppTheme.textPrimary))),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final hasHero = catalog.collectionHeroImageUrl != null && catalog.collectionHeroImageUrl!.isNotEmpty;
    
    if (hasHero) {
      return SliverAppBar(
        expandedHeight: 300,
        pinned: true,
        backgroundColor: AppTheme.backgroundDark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        flexibleSpace: FlexibleSpaceBar(
          title: Text(catalog.title, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          background: Stack(
            fit: StackFit.expand,
            children: [
              ResilientNetworkImage(
                imageUrl: catalog.collectionHeroImageUrl!,
                fit: BoxFit.cover,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppTheme.backgroundDark.withValues(alpha: 0.8),
                      AppTheme.backgroundDark,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.backgroundDark,
      title: Text(catalog.title, style: TextStyle(color: AppTheme.textPrimary)),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<MediaItem> items) {
    final isLandscape = catalog.collectionTileShape == CollectionTileShape.landscape;
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isLandscape ? 2 : 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: isLandscape ? 16 / 9 : 2 / 3,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            return _CollectionItemCard(item: item, shape: catalog.collectionTileShape);
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2 / 3,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const SkeletonLoader(height: 200, width: 120),
          childCount: 12,
        ),
      ),
    );
  }
}

class _CollectionItemCard extends StatelessWidget {
  final MediaItem item;
  final CollectionTileShape shape;

  const _CollectionItemCard({required this.item, required this.shape});

  @override
  Widget build(BuildContext context) {
    final isLandscape = shape == CollectionTileShape.landscape;
    final imageUrl = isLandscape 
        ? (item.backdrop != null && item.backdrop!.isNotEmpty ? item.backdrop : item.image)
        : item.image;

    String fullImageUrl = '';
    if (imageUrl != null && imageUrl.isNotEmpty) {
      fullImageUrl = imageUrl.startsWith('http') 
          ? imageUrl 
          : 'https://image.tmdb.org/t/p/${isLandscape ? 'w780' : 'w500'}$imageUrl';
    }

    return StreameFocusable(
      onTap: () {
        final mt = item.mediaType == MediaType.tv ? 'tv' : 'movie';
        context.push('/details/$mt/${item.id}');
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (fullImageUrl.isNotEmpty)
              ResilientNetworkImage(
                imageUrl: fullImageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, error, stackTrace) => Container(
                  color: AppTheme.backgroundElevated,
                  child: Center(
                    child: Icon(Icons.movie, color: AppTheme.textTertiary),
                  ),
                ),
              )
            else
              Container(
                color: AppTheme.backgroundElevated,
                child: Center(
                  child: Icon(Icons.movie, color: AppTheme.textTertiary),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  ),
                ),
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
