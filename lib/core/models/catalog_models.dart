// Catalog models matching Kotlin CatalogModels.kt parity

// Import enums from media_item.dart
import 'package:streame/features/home/data/models/media_item.dart'
    show CollectionGroupKind, CollectionTileShape;

// Re-export for consumers
export 'package:streame/features/home/data/models/media_item.dart'
    show CollectionGroupKind, CollectionTileShape;

enum CatalogSourceType { preinstalled, trakt, mdblist, addon }

enum CatalogKind { standard, collection, collectionRail }

enum CollectionSourceKind {
  addonCatalog,
  tmdbGenre,
  tmdbPerson,
  tmdbCollection,
  tmdbKeyword,
  tmdbWatchProvider,
  curatedIds,
  mdblistPublic,
}

class CollectionSourceConfig {
  final CollectionSourceKind kind;
  final String? mediaType;
  final String? addonId;
  final String? addonCatalogType;
  final String? addonCatalogId;
  final int? tmdbGenreId;
  final int? tmdbPersonId;
  final int? tmdbCollectionId;
  final int? tmdbKeywordId;
  final int? tmdbWatchProviderId;
  final String? watchRegion;
  final String? sortBy;
  final List<String>? curatedRefs;
  final String? mdblistSlug;

  const CollectionSourceConfig({
    required this.kind,
    this.mediaType,
    this.addonId,
    this.addonCatalogType,
    this.addonCatalogId,
    this.tmdbGenreId,
    this.tmdbPersonId,
    this.tmdbCollectionId,
    this.tmdbKeywordId,
    this.tmdbWatchProviderId,
    this.watchRegion,
    this.sortBy,
    this.curatedRefs,
    this.mdblistSlug,
  });

  factory CollectionSourceConfig.fromJson(Map<String, dynamic> json) =>
      CollectionSourceConfig(
        kind: CollectionSourceKind.values.byName(json['kind'] as String? ?? 'addonCatalog'),
        mediaType: json['media_type'] as String?,
        addonId: json['addon_id'] as String?,
        addonCatalogType: json['addon_catalog_type'] as String?,
        addonCatalogId: json['addon_catalog_id'] as String?,
        tmdbGenreId: json['tmdb_genre_id'] as int?,
        tmdbPersonId: json['tmdb_person_id'] as int?,
        tmdbCollectionId: json['tmdb_collection_id'] as int?,
        tmdbKeywordId: json['tmdb_keyword_id'] as int?,
        tmdbWatchProviderId: json['tmdb_watch_provider_id'] as int?,
        watchRegion: json['watch_region'] as String?,
        sortBy: json['sort_by'] as String?,
        curatedRefs: (json['curated_refs'] as List?)?.cast<String>(),
        mdblistSlug: json['mdblist_slug'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'media_type': mediaType,
    'addon_id': addonId,
    'addon_catalog_type': addonCatalogType,
    'addon_catalog_id': addonCatalogId,
    'tmdb_genre_id': tmdbGenreId,
    'tmdb_person_id': tmdbPersonId,
    'tmdb_collection_id': tmdbCollectionId,
    'tmdb_keyword_id': tmdbKeywordId,
    'tmdb_watch_provider_id': tmdbWatchProviderId,
    'watch_region': watchRegion,
    'sort_by': sortBy,
    'curated_refs': curatedRefs,
    'mdblist_slug': mdblistSlug,
  };
}

class CatalogConfig {
  final String id;
  final String title;
  final CatalogSourceType sourceType;
  final String? sourceUrl;
  final String? sourceRef;
  final bool isPreinstalled;
  final String? addonId;
  final String? addonCatalogType;
  final String? addonCatalogId;
  final String? addonName;
  final CatalogKind kind;
  final CollectionGroupKind? collectionGroup;
  final String? collectionDescription;
  final String? collectionCoverImageUrl;
  final String? collectionFocusGifUrl;
  final String? collectionHeroImageUrl;
  final String? collectionHeroGifUrl;
  final String? collectionHeroVideoUrl;
  final String? collectionClearLogoUrl;
  final CollectionTileShape collectionTileShape;
  final bool collectionHideTitle;
  final List<CollectionSourceConfig> collectionSources;
  final List<String> requiredAddonUrls;

  const CatalogConfig({
    required this.id,
    required this.title,
    required this.sourceType,
    this.sourceUrl,
    this.sourceRef,
    this.isPreinstalled = false,
    this.addonId,
    this.addonCatalogType,
    this.addonCatalogId,
    this.addonName,
    this.kind = CatalogKind.standard,
    this.collectionGroup,
    this.collectionDescription,
    this.collectionCoverImageUrl,
    this.collectionFocusGifUrl,
    this.collectionHeroImageUrl,
    this.collectionHeroGifUrl,
    this.collectionHeroVideoUrl,
    this.collectionClearLogoUrl,
    this.collectionTileShape = CollectionTileShape.landscape,
    this.collectionHideTitle = false,
    this.collectionSources = const [],
    this.requiredAddonUrls = const [],
  });

  factory CatalogConfig.fromJson(Map<String, dynamic> json) => CatalogConfig(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    sourceType: CatalogSourceType.values.byName(json['source_type'] as String? ?? 'preinstalled'),
    sourceUrl: json['source_url'] as String?,
    sourceRef: json['source_ref'] as String?,
    isPreinstalled: json['is_preinstalled'] as bool? ?? false,
    addonId: json['addon_id'] as String?,
    addonCatalogType: json['addon_catalog_type'] as String?,
    addonCatalogId: json['addon_catalog_id'] as String?,
    addonName: json['addon_name'] as String?,
    kind: CatalogKind.values.byName(json['kind'] as String? ?? 'standard'),
    collectionGroup: json['collection_group'] != null
        ? CollectionGroupKind.values.byName(json['collection_group'] as String)
        : null,
    collectionDescription: json['collection_description'] as String?,
    collectionCoverImageUrl: json['collection_cover_image_url'] as String?,
    collectionFocusGifUrl: json['collection_focus_gif_url'] as String?,
    collectionHeroImageUrl: json['collection_hero_image_url'] as String?,
    collectionHeroGifUrl: json['collection_hero_gif_url'] as String?,
    collectionHeroVideoUrl: json['collection_hero_video_url'] as String?,
    collectionClearLogoUrl: json['collection_clear_logo_url'] as String?,
    collectionTileShape: json['collection_tile_shape'] != null
        ? CollectionTileShape.values.byName(json['collection_tile_shape'] as String)
        : CollectionTileShape.landscape,
    collectionHideTitle: json['collection_hide_title'] as bool? ?? false,
    collectionSources: (json['collection_sources'] as List?)
            ?.map((e) => CollectionSourceConfig.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    requiredAddonUrls: (json['required_addon_urls'] as List?)?.cast<String>() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'source_type': sourceType.name,
    'source_url': sourceUrl,
    'source_ref': sourceRef,
    'is_preinstalled': isPreinstalled,
    'addon_id': addonId,
    'addon_catalog_type': addonCatalogType,
    'addon_catalog_id': addonCatalogId,
    'addon_name': addonName,
    'kind': kind.name,
    'collection_group': collectionGroup?.name,
    'collection_description': collectionDescription,
    'collection_cover_image_url': collectionCoverImageUrl,
    'collection_focus_gif_url': collectionFocusGifUrl,
    'collection_hero_image_url': collectionHeroImageUrl,
    'collection_hero_gif_url': collectionHeroGifUrl,
    'collection_hero_video_url': collectionHeroVideoUrl,
    'collection_clear_logo_url': collectionClearLogoUrl,
    'collection_tile_shape': collectionTileShape.name,
    'collection_hide_title': collectionHideTitle,
    'collection_sources': collectionSources.map((s) => s.toJson()).toList(),
    'required_addon_urls': requiredAddonUrls,
  };
}

class CatalogDiscoveryResult {
  final String id;
  final String title;
  final String? description;
  final CatalogSourceType sourceType;
  final String sourceUrl;
  final String? creatorName;
  final String? creatorHandle;
  final String? updatedAt;
  final int? itemCount;
  final int? likes;
  final List<String> previewPosterUrls;

  const CatalogDiscoveryResult({
    required this.id,
    required this.title,
    this.description,
    required this.sourceType,
    required this.sourceUrl,
    this.creatorName,
    this.creatorHandle,
    this.updatedAt,
    this.itemCount,
    this.likes,
    this.previewPosterUrls = const [],
  });
}

class CatalogValidationResult {
  final bool isValid;
  final String? normalizedUrl;
  final CatalogSourceType? sourceType;
  final String? error;

  const CatalogValidationResult({
    required this.isValid,
    this.normalizedUrl,
    this.sourceType,
    this.error,
  });
}
