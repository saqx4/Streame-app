import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:streame/core/models/catalog_models.dart';
import 'package:streame/core/repositories/tmdb_repository.dart';
import 'package:streame/core/repositories/addon_repository.dart';
import 'package:streame/core/repositories/profile_repository.dart';
import 'package:streame/features/home/data/models/media_item.dart';

class CollectionItemsRepository {
  final TmdbRepository _tmdbRepo;
  final AddonRepository _addonRepo;
  final http.Client _http;

  CollectionItemsRepository({
    required TmdbRepository tmdbRepo,
    required AddonRepository addonRepo,
    http.Client? httpClient,
  })  : _tmdbRepo = tmdbRepo,
        _addonRepo = addonRepo,
        _http = httpClient ?? http.Client();

  Future<List<MediaItem>> fetchCollectionItems(CatalogConfig config, {int page = 1}) async {
    if (config.collectionSources.isEmpty) {
      // Fallback for preinstalled or standard catalogs if they don't have sources defined
      return _fetchStandardCatalog(config, page: page);
    }

    final allItems = <MediaItem>[];
    for (final source in config.collectionSources) {
      try {
        final items = await _fetchSourceItems(source, page: page);
        allItems.addAll(items);
      } catch (e) {
        debugPrint('Error fetching source ${source.kind}: $e');
      }
    }

    // Deduplicate
    final seen = <String>{};
    return allItems.where((item) => seen.add('${item.mediaType.name}_${item.id}')).toList();
  }

  Future<List<MediaItem>> _fetchStandardCatalog(CatalogConfig config, {int page = 1}) async {
    switch (config.id) {
      case 'trending_movies':
        return _tmdbRepo.getTrendingMovies(page: page);
      case 'trending_tv':
        return _tmdbRepo.getTrendingTv(page: page);
      case 'top_rated_movies':
        return _tmdbRepo.getTopRatedMovies(page: page);
      case 'popular_tv':
        return _tmdbRepo.getPopularTv(page: page);
      default:
        return [];
    }
  }

  Future<List<MediaItem>> _fetchSourceItems(CollectionSourceConfig source, {int page = 1}) async {
    switch (source.kind) {
      case CollectionSourceKind.tmdbGenre:
        if (source.mediaType == 'tv') {
          return _tmdbRepo.discoverTv(genreId: source.tmdbGenreId, sortBy: source.sortBy, page: page);
        }
        return _tmdbRepo.discoverMovies(genreId: source.tmdbGenreId, sortBy: source.sortBy, page: page);

      case CollectionSourceKind.tmdbPerson:
        // Implementation for person-based discovery could be added to TmdbRepository
        return [];

      case CollectionSourceKind.tmdbCollection:
        // Implementation for TMDB collections
        return [];

      case CollectionSourceKind.tmdbKeyword:
        // Implementation for keywords
        return [];

      case CollectionSourceKind.tmdbWatchProvider:
        if (source.mediaType == 'tv') {
          return _tmdbRepo.discoverTv(region: source.watchRegion, page: page);
        }
        return _tmdbRepo.discoverMovies(region: source.watchRegion, page: page);

      case CollectionSourceKind.addonCatalog:
        return _fetchAddonCatalog(source, page: page);

      case CollectionSourceKind.mdblistPublic:
        return _fetchMdblist(source.mdblistSlug, page: page);

      case CollectionSourceKind.curatedIds:
        return _fetchCurated(source.curatedRefs ?? []);
    }
  }

  Future<List<MediaItem>> _fetchAddonCatalog(CollectionSourceConfig source, {int page = 1}) async {
    final addons = await _addonRepo.getInstalledAddons();
    final addon = addons.where((a) => a.id == source.addonId).firstOrNull;
    if (addon == null || addon.url == null) return [];

    try {
      final uri = Uri.parse(addon.url!);
      final pathSegments = List<String>.from(uri.pathSegments);
      if (pathSegments.contains('manifest.json')) {
        pathSegments.removeLast();
      }
      final base = uri.replace(pathSegments: pathSegments).toString().replaceAll(RegExp(r'/+$'), '');
      
      final catalogType = source.addonCatalogType ?? 'movie';
      final catalogId = source.addonCatalogId ?? '';
      
      // Stremio catalog URL: /catalog/{type}/{id}[/{extra}].json
      var url = '$base/catalog/$catalogType/$catalogId';
      if (page > 1) {
        final skip = (page - 1) * 20; // Assuming 20 items per page
        url += '/skip=$skip';
      }
      url += '.json';

      final response = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final metas = data['metas'] as List<dynamic>? ?? [];
      
      return metas.map((m) {
        final map = m as Map<String, dynamic>;
        final type = map['type'] == 'series' || map['type'] == 'tv' ? MediaType.tv : MediaType.movie;
        
        // Handle Stremio meta to MediaItem conversion
        return MediaItem(
          id: int.tryParse(map['id']?.toString().replaceAll('tt', '') ?? '0') ?? 0,
          title: map['name'] as String? ?? '',
          mediaType: type,
          image: map['poster'] as String? ?? '',
          backdrop: map['background'] as String?,
          year: map['releaseInfo']?.toString() ?? map['year']?.toString() ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('Addon catalog fetch error: $e');
      return [];
    }
  }

  Future<List<MediaItem>> _fetchMdblist(String? slug, {int page = 1}) async {
    if (slug == null) return [];
    // Placeholder: MDBList implementation
    return [];
  }

  Future<List<MediaItem>> _fetchCurated(List<String> refs) async {
    final items = <MediaItem>[];
    for (final ref in refs) {
      // ref format usually: "movie:123" or "tv:456"
      final parts = ref.split(':');
      if (parts.length != 2) continue;
      final type = parts[0] == 'tv' ? MediaType.tv : MediaType.movie;
      final id = int.tryParse(parts[1]) ?? 0;
      if (id == 0) continue;

      try {
        final detail = type == MediaType.tv 
            ? await _tmdbRepo.getTvDetails(id) 
            : await _tmdbRepo.getMovieDetails(id);
        if (detail != null) items.add(detail);
      } catch (_) {}
    }
    return items;
  }
}

final collectionItemsRepositoryProvider = Provider<CollectionItemsRepository>((ref) {
  final tmdbRepo = ref.watch(tmdbRepositoryProvider);
  // We need a profile ID for addonRepo, but CatalogConfig might be global or profile-specific.
  // For now, assume we can get it from activeProfileIdProvider.
  final profileId = ref.watch(activeProfileIdProvider) ?? 'default';
  final addonRepo = ref.watch(addonRepositoryProvider(profileId));
  return CollectionItemsRepository(tmdbRepo: tmdbRepo, addonRepo: addonRepo);
});

final collectionItemsProvider = FutureProvider.family<List<MediaItem>, CatalogConfig>((ref, config) async {
  final repo = ref.watch(collectionItemsRepositoryProvider);
  return repo.fetchCollectionItems(config);
});
