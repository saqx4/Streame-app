// Stream & addon models matching Kotlin Models.kt parity

/// Stream source from addons - enhanced with behavior hints
class StreamSource {
  final String rawName;
  final String rawTitle;
  final String source;
  final String addonName;
  final String addonId;
  final String quality;
  final String size;
  final int? sizeBytes;
  final String? url;
  final String? infoHash;
  final int? fileIdx;
  final StreamBehaviorHints? behaviorHints;
  final List<Subtitle> subtitles;
  final List<String> sources;

  const StreamSource({
    this.rawName = '',
    this.rawTitle = '',
    required this.source,
    required this.addonName,
    this.addonId = '',
    required this.quality,
    this.size = '',
    this.sizeBytes,
    this.url,
    this.infoHash,
    this.fileIdx,
    this.behaviorHints,
    this.subtitles = const [],
    this.sources = const [],
  });

  StreamSource copyWith({String? url, int? fileIdx}) => StreamSource(
    rawName: rawName,
    rawTitle: rawTitle,
    source: source,
    addonName: addonName,
    addonId: addonId,
    quality: quality,
    size: size,
    sizeBytes: sizeBytes,
    url: url ?? this.url,
    infoHash: infoHash,
    fileIdx: fileIdx ?? this.fileIdx,
    behaviorHints: behaviorHints,
    subtitles: subtitles,
    sources: sources,
  );

  /// Parse from Stremio addon stream JSON
  factory StreamSource.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final title = json['title'] as String? ?? '';
    final qualityStr = (json['quality'] ?? '') as String;
    return StreamSource(
      rawName: name,
      rawTitle: title,
      source: name.isNotEmpty ? name : title,
      addonName: '',
      addonId: '',
      quality: qualityStr,
      size: (json['size'] ?? '') as String,
      sizeBytes: json['sizeBytes'] as int?,
      url: json['url'] as String?,
      infoHash: json['infoHash'] as String?,
      fileIdx: json['fileIdx'] as int?,
      behaviorHints: json['behaviorHints'] != null
          ? StreamBehaviorHints.fromJson(json['behaviorHints'] as Map<String, dynamic>)
          : null,
      subtitles: (json['subtitles'] as List<dynamic>? ?? [])
          .map((s) => Subtitle.fromJson(s as Map<String, dynamic>))
          .toList(),
      sources: (json['sources'] as List<dynamic>? ?? [])
          .map((s) => s as String)
          .toList(),
    );
  }
}

class StreamBehaviorHints {
  final bool notWebReady;
  final bool? cached;
  final String? bingeGroup;
  final List<String>? countryWhitelist;
  final ProxyHeaders? proxyHeaders;
  final String? videoHash;
  final int? videoSize;
  final String? filename;

  const StreamBehaviorHints({
    this.notWebReady = false,
    this.cached,
    this.bingeGroup,
    this.countryWhitelist,
    this.proxyHeaders,
    this.videoHash,
    this.videoSize,
    this.filename,
  });

  factory StreamBehaviorHints.fromJson(Map<String, dynamic> json) => StreamBehaviorHints(
    notWebReady: json['notWebReady'] as bool? ?? false,
    cached: json['cached'] as bool?,
    bingeGroup: json['bingeGroup'] as String?,
    countryWhitelist: (json['countryWhitelist'] as List<dynamic>?)?.cast<String>(),
    proxyHeaders: json['proxyHeaders'] != null
        ? ProxyHeaders.fromJson(json['proxyHeaders'] as Map<String, dynamic>)
        : null,
    videoHash: json['videoHash'] as String?,
    videoSize: json['videoSize'] as int?,
    filename: json['filename'] as String?,
  );
}

class ProxyHeaders {
  final Map<String, String>? request;
  final Map<String, String>? response;

  const ProxyHeaders({this.request, this.response});

  factory ProxyHeaders.fromJson(Map<String, dynamic> json) => ProxyHeaders(
    request: (json['request'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())),
    response: (json['response'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())),
  );
}

/// Subtitle track
class Subtitle {
  final String id;
  final String url;
  final String lang;
  final String label;
  final bool isEmbedded;
  final int? groupIndex;
  final int? trackIndex;

  const Subtitle({
    required this.id,
    required this.url,
    required this.lang,
    required this.label,
    this.isEmbedded = false,
    this.groupIndex,
    this.trackIndex,
  });

  factory Subtitle.fromJson(Map<String, dynamic> json) => Subtitle(
    id: json['id'] as String? ?? '',
    url: json['url'] as String? ?? '',
    lang: json['lang'] as String? ?? '',
    label: json['label'] as String? ?? '',
    isEmbedded: json['isEmbedded'] as bool? ?? false,
    groupIndex: json['groupIndex'] as int?,
    trackIndex: json['trackIndex'] as int?,
  );
}

/// Stremio Addon Manifest
class AddonManifest {
  final String id;
  final String name;
  final String version;
  final String description;
  final String? logo;
  final String? background;
  final List<String> types;
  final List<AddonResource> resources;
  final List<AddonCatalog> catalogs;
  final List<String>? idPrefixes;
  final AddonBehaviorHints? behaviorHints;

  const AddonManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    this.logo,
    this.background,
    this.types = const [],
    this.resources = const [],
    this.catalogs = const [],
    this.idPrefixes,
    this.behaviorHints,
  });

  factory AddonManifest.fromJson(Map<String, dynamic> json) => AddonManifest(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    version: json['version'] as String? ?? '',
    description: json['description'] as String? ?? '',
    logo: json['logo'] as String?,
    background: json['background'] as String?,
    types: (json['types'] as List<dynamic>?)?.cast<String>() ?? [],
    resources: (json['resources'] as List<dynamic>?)
            ?.map((e) => e is Map<String, dynamic>
                ? AddonResource.fromJson(e)
                : AddonResource(name: e.toString()))
            .toList() ??
        [],
    catalogs: (json['catalogs'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((e) => AddonCatalog.fromJson(e))
            .toList() ??
        [],
    idPrefixes: (json['idPrefixes'] as List<dynamic>?)?.cast<String>(),
    behaviorHints: json['behaviorHints'] is Map<String, dynamic>
        ? AddonBehaviorHints.fromJson(json['behaviorHints'] as Map<String, dynamic>)
        : null,
  );
}

class AddonResource {
  final String name;
  final List<String> types;
  final List<String>? idPrefixes;

  const AddonResource({
    required this.name,
    this.types = const [],
    this.idPrefixes,
  });

  factory AddonResource.fromJson(Map<String, dynamic> json) => AddonResource(
    name: json['name'] as String? ?? '',
    types: (json['types'] as List<dynamic>?)?.cast<String>() ?? [],
    idPrefixes: (json['idPrefixes'] as List<dynamic>?)?.cast<String>(),
  );
}

class AddonCatalog {
  final String type;
  final String id;
  final String name;
  final List<String>? genres;
  final List<AddonCatalogExtra>? extra;

  const AddonCatalog({
    required this.type,
    required this.id,
    this.name = '',
    this.genres,
    this.extra,
  });

  factory AddonCatalog.fromJson(Map<String, dynamic> json) => AddonCatalog(
    type: json['type'] as String? ?? '',
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    genres: (json['genres'] as List<dynamic>?)?.cast<String>(),
    extra: (json['extra'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((e) => AddonCatalogExtra.fromJson(e))
            .toList(),
  );
}

class AddonCatalogExtra {
  final String name;
  final bool isRequired;
  final List<String>? options;

  const AddonCatalogExtra({
    required this.name,
    this.isRequired = false,
    this.options,
  });

  factory AddonCatalogExtra.fromJson(Map<String, dynamic> json) => AddonCatalogExtra(
    name: json['name'] as String? ?? '',
    isRequired: json['isRequired'] as bool? ?? false,
    options: (json['options'] as List<dynamic>?)?.cast<String>(),
  );
}

class AddonBehaviorHints {
  final bool adult;
  final bool p2p;
  final bool configurable;
  final bool configurationRequired;

  const AddonBehaviorHints({
    this.adult = false,
    this.p2p = false,
    this.configurable = false,
    this.configurationRequired = false,
  });

  factory AddonBehaviorHints.fromJson(Map<String, dynamic> json) => AddonBehaviorHints(
    adult: json['adult'] as bool? ?? false,
    p2p: json['p2p'] as bool? ?? false,
    configurable: json['configurable'] as bool? ?? false,
    configurationRequired: json['configurationRequired'] as bool? ?? false,
  );
}

/// Installed addon with manifest data
enum AddonType { official, community, subtitle, metadata, custom }

enum RuntimeKind { stremio }

enum AddonInstallSource { directUrl }

class Addon {
  final String id;
  final String name;
  final String version;
  final String description;
  final bool isInstalled;
  final bool isEnabled;
  final AddonType type;
  final RuntimeKind runtimeKind;
  final AddonInstallSource installSource;
  final String? url;
  final String? logo;
  final AddonManifest? manifest;
  final String? transportUrl;
  final String? internalName;
  final String? repoUrl;
  final String? pluginPackageUrl;
  final int? pluginVersionCode;
  final int? apiVersion;
  final String? installedArtifactPath;

  const Addon({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    this.isInstalled = true,
    this.isEnabled = true,
    this.type = AddonType.custom,
    this.runtimeKind = RuntimeKind.stremio,
    this.installSource = AddonInstallSource.directUrl,
    this.url,
    this.logo,
    this.manifest,
    this.transportUrl,
    this.internalName,
    this.repoUrl,
    this.pluginPackageUrl,
    this.pluginVersionCode,
    this.apiVersion,
    this.installedArtifactPath,
  });

  Addon copyWith({
    bool? isEnabled,
    String? name,
    String? description,
    String? version,
    String? logo,
    String? pluginPackageUrl,
    int? pluginVersionCode,
    int? apiVersion,
  }) =>
      Addon(
        id: id,
        name: name ?? this.name,
        version: version ?? this.version,
        description: description ?? this.description,
        isInstalled: isInstalled,
        isEnabled: isEnabled ?? this.isEnabled,
        type: type,
        runtimeKind: runtimeKind,
        installSource: installSource,
        url: url,
        logo: logo ?? this.logo,
        manifest: manifest,
        transportUrl: transportUrl,
        internalName: internalName,
        repoUrl: repoUrl,
        pluginPackageUrl: pluginPackageUrl ?? this.pluginPackageUrl,
        pluginVersionCode: pluginVersionCode ?? this.pluginVersionCode,
        apiVersion: apiVersion ?? this.apiVersion,
        installedArtifactPath: installedArtifactPath,
      );
}

/// Stream fetch result with addon info
class AddonStreamResult {
  final List<StreamSource> streams;
  final String addonId;
  final String addonName;
  final Exception? error;

  const AddonStreamResult({
    required this.streams,
    required this.addonId,
    required this.addonName,
    this.error,
  });
}

/// Progressive stream resolution state
class StreamProgress {
  final int completedAddons;
  final int totalAddons;
  final List<StreamSource> allStreams;
  final List<AddonStreamResult> addonResults;
  final bool isFinal;

  const StreamProgress({
    required this.completedAddons,
    required this.totalAddons,
    this.allStreams = const [],
    this.addonResults = const [],
    this.isFinal = false,
  });

  double get progress => totalAddons > 0 ? completedAddons / totalAddons : 0.0;

  StreamProgress copyWith({
    int? completedAddons,
    int? totalAddons,
    List<StreamSource>? allStreams,
    List<AddonStreamResult>? addonResults,
    bool? isFinal,
  }) {
    return StreamProgress(
      completedAddons: completedAddons ?? this.completedAddons,
      totalAddons: totalAddons ?? this.totalAddons,
      allStreams: allStreams ?? this.allStreams,
      addonResults: addonResults ?? this.addonResults,
      isFinal: isFinal ?? this.isFinal,
    );
  }
}

/// Quality filter entry - device-scoped regex patterns
class QualityFilterConfig {
  final String id;
  final String deviceName;
  final String regexPattern;
  final bool enabled;
  final int createdAt;

  const QualityFilterConfig({
    this.id = '',
    this.deviceName = '',
    this.regexPattern = '',
    this.enabled = true,
    this.createdAt = 0,
  });
}

/// Runtime request models
class MovieRuntimeRequest {
  final String imdbId;
  final String title;
  final int? year;

  const MovieRuntimeRequest({required this.imdbId, required this.title, this.year});
}

class EpisodeRuntimeRequest {
  final String imdbId;
  final int season;
  final int episode;
  final int? tmdbId;
  final int? tvdbId;
  final List<int> genreIds;
  final String? originalLanguage;
  final String title;
  final String? airDate;

  const EpisodeRuntimeRequest({
    required this.imdbId,
    required this.season,
    required this.episode,
    this.tmdbId,
    this.tvdbId,
    this.genreIds = const [],
    this.originalLanguage,
    required this.title,
    this.airDate,
  });
}
