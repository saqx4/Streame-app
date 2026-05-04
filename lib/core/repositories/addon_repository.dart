import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streame/core/models/stream_models.dart';

class AddonRepository {
  final http.Client _http;
  final SharedPreferences _prefs;
  final String _profileId;

  static const String _installedKey = 'installed_addons_v1';

  AddonRepository({
    http.Client? httpClient,
    required SharedPreferences prefs,
    required String profileId,
  })  : _http = httpClient ?? http.Client(),
        _prefs = prefs,
        _profileId = profileId;

  String get _prefKey => '${_installedKey}_$_profileId';

  Future<List<Addon>> getInstalledAddons() async {
    final raw = _prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return _defaultAddons;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => _addonFromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaultAddons;
    }
  }

  Future<void> saveInstalledAddons(List<Addon> addons) async {
    final json = jsonEncode(addons.map(_addonToJson).toList());
    await _prefs.setString(_prefKey, json);
  }

  Future<bool> testAddonManifest(String url) async {
    try {
      final response = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      return data['id'] != null && data['name'] != null;
    } catch (e) {
      return false;
    }
  }

  Future<AddonManifest?> loadManifest(String url) async {
    try {
      debugPrint('loadManifest: fetching $url');
      final response = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      debugPrint('loadManifest: response status ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('loadManifest: failed with status ${response.statusCode}, body: ${response.body}');
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('loadManifest: parsed manifest, id=${json['id']}, name=${json['name']}');
      return AddonManifest.fromJson(json);
    } catch (e, st) {
      debugPrint('loadManifest error: $e\n$st');
      return null;
    }
  }

  Future<void> addCustomAddon(String url, {AddonType type = AddonType.custom}) async {
    final manifest = await loadManifest(url);
    if (manifest == null) return;
    final addons = await getInstalledAddons();
    final existing = addons.indexWhere((a) => a.id == manifest.id);
    // Auto-detect addon type from manifest resources
    final resourceNames = manifest.resources.map((r) => r.name).toSet();
    final detectedType = type != AddonType.custom
        ? type
        : resourceNames.contains('subtitles') && !resourceNames.contains('stream')
            ? AddonType.subtitle
            : resourceNames.contains('metadata') && !resourceNames.contains('stream')
                ? AddonType.metadata
                : AddonType.custom;
    final addon = Addon(
      id: manifest.id,
      name: manifest.name,
      version: manifest.version,
      description: manifest.description,
      type: detectedType,
      runtimeKind: RuntimeKind.stremio,
      isEnabled: true,
      isInstalled: true,
      url: url,
      logo: manifest.logo,
      manifest: manifest,
    );
    if (existing >= 0) {
      addons[existing] = addon;
    } else {
      addons.add(addon);
    }
    await saveInstalledAddons(addons);
  }

  Future<void> toggleAddon(String addonId, bool enabled) async {
    final addons = await getInstalledAddons();
    final idx = addons.indexWhere((a) => a.id == addonId);
    if (idx >= 0) {
      addons[idx] = addons[idx].copyWith(isEnabled: enabled);
      await saveInstalledAddons(addons);
    }
  }

  Future<void> removeAddon(String addonId) async {
    final addons = await getInstalledAddons();
    addons.removeWhere((a) => a.id == addonId);
    await saveInstalledAddons(addons);
  }

  // Default addons (matching Kotlin defaults)
  List<Addon> get _defaultAddons => [
    const Addon(
      id: 'community.stremio.watchhub',
      name: 'WatchHub',
      version: '1.0.0',
      description: 'Find where to stream',
      type: AddonType.official,
      runtimeKind: RuntimeKind.stremio,
      isEnabled: true,
      isInstalled: true,
      url: 'https://watchhub.strem.io/manifest.json',
    ),
  ];

  Addon _addonFromJson(Map<String, dynamic> json) => Addon(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    version: json['version'] as String? ?? '',
    description: json['description'] as String? ?? '',
    isInstalled: json['is_installed'] as bool? ?? true,
    isEnabled: json['is_enabled'] as bool? ?? true,
    type: AddonType.values.byName(json['type'] as String? ?? 'custom'),
    runtimeKind: RuntimeKind.values.byName(json['runtime_kind'] as String? ?? 'stremio'),
    installSource: AddonInstallSource.values.byName(json['install_source'] as String? ?? 'directUrl'),
    url: json['url'] as String?,
    logo: json['logo'] as String?,
    manifest: (json['resource_names'] as List<dynamic>?) != null
        ? AddonManifest(
            id: json['id'] as String? ?? '',
            name: json['name'] as String? ?? '',
            version: json['version'] as String? ?? '',
            description: json['description'] as String? ?? '',
            logo: json['logo'] as String?,
            resources: (json['resource_names'] as List<dynamic>)
                .map((e) => AddonResource(name: e.toString()))
                .toList(),
          )
        : null,
  );

  Map<String, dynamic> _addonToJson(Addon a) => {
    'id': a.id,
    'name': a.name,
    'version': a.version,
    'description': a.description,
    'is_installed': a.isInstalled,
    'is_enabled': a.isEnabled,
    'type': a.type.name,
    'runtime_kind': a.runtimeKind.name,
    'install_source': a.installSource.name,
    'url': a.url,
    'logo': a.logo,
    'resource_names': a.manifest?.resources.map((r) => r.name).toList(),
  };
}

class TorrServerEntry {
  final String url;
  final String name;

  const TorrServerEntry({required this.url, required this.name});
}

class AddonManagerRepository {
  final SharedPreferences _prefs;
  final String _profileId;
  final http.Client _http;
  final AddonRepository _addonRepo;

  static const String _torrServersKey = 'torr_servers_v1';
  static const String _qualityFiltersKey = 'quality_filters_v1';

  AddonManagerRepository({
    required SharedPreferences prefs,
    required String profileId,
    required AddonRepository addonRepo,
    http.Client? httpClient,
  })  : _prefs = prefs,
        _profileId = profileId,
        _addonRepo = addonRepo,
        _http = httpClient ?? http.Client();

  String get _torrPrefKey => '${_torrServersKey}_$_profileId';
  String get _qfPrefKey => '${_qualityFiltersKey}_$_profileId';

  Future<List<TorrServerEntry>> getTorrServers() async {
    final raw = _prefs.getString(_torrPrefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => TorrServerEntry(
        url: e['url'] as String,
        name: e['name'] as String? ?? '',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addTorrServer(String url, String name) async {
    final servers = await getTorrServers();
    if (servers.any((s) => s.url == url)) return;
    servers.add(TorrServerEntry(url: url, name: name));
    await _prefs.setString(_torrPrefKey, jsonEncode(servers.map((s) => {
      'url': s.url, 'name': s.name,
    }).toList()));
  }

  Future<void> removeTorrServer(String url) async {
    final servers = await getTorrServers();
    servers.removeWhere((s) => s.url == url);
    await _prefs.setString(_torrPrefKey, jsonEncode(servers.map((s) => {
      'url': s.url, 'name': s.name,
    }).toList()));
  }

  Future<List<QualityFilterConfig>> getQualityFilters() async {
    final raw = _prefs.getString(_qfPrefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => QualityFilterConfig(
        id: e['id'] as String? ?? '',
        deviceName: e['device_name'] as String? ?? '',
        regexPattern: e['regex_pattern'] as String? ?? '',
        enabled: e['enabled'] as bool? ?? true,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveQualityFilters(List<QualityFilterConfig> filters) async {
    await _prefs.setString(_qfPrefKey, jsonEncode(filters.map((f) => {
      'id': f.id, 'device_name': f.deviceName,
      'regex_pattern': f.regexPattern, 'enabled': f.enabled,
    }).toList()));
  }

  /// Resolve streams from all enabled Stremio addons for a given item
  Future<List<AddonStreamResult>> resolveStreams({
    required String type,
    required String imdbId,
    required String tmdbId,
    int? season,
    int? episode,
  }) async {
    // If no IMDB ID, try to resolve via Cinemeta (Stremio's official catalog addon)
    var resolvedImdbId = imdbId;
    if (resolvedImdbId.isEmpty) {
      debugPrint('resolveStreams: no IMDB ID provided, trying Cinemeta for TMDB $tmdbId');
      resolvedImdbId = await _resolveImdbFromCinemeta(type, tmdbId);
      debugPrint('resolveStreams: Cinemeta returned IMDB ID = $resolvedImdbId');
    }

    final addons = await _addonRepo.getInstalledAddons();
    final enabled = addons.where((a) {
      if (!a.isEnabled || a.runtimeKind != RuntimeKind.stremio || a.url == null) return false;
      final resNames = a.manifest?.resources.map((r) => r.name).toSet();
      // Only include if 'stream' resource is declared, or unknown (legacy fallback)
      return resNames == null || resNames.contains('stream');
    });
    debugPrint('resolveStreams: ${enabled.length} enabled stream addons, IMDB=$resolvedImdbId, type=$type');

    if (resolvedImdbId.isEmpty) return [];

    final results = <AddonStreamResult>[];

    await Future.wait(enabled.map((addon) async {
      try {
        final manifestUrl = addon.url!;
        // Construct the stream URL from the addon manifest base using Uri parsing for robustness
        final uri = Uri.parse(manifestUrl);
        final pathSegments = List<String>.from(uri.pathSegments);
        // Remove 'manifest.json' from path if present
        if (pathSegments.contains('manifest.json')) {
          pathSegments.removeLast();
        }
        final base = uri.replace(pathSegments: pathSegments).toString().replaceAll(RegExp(r'/+$'), '');
        var streamUrl = '$base/stream/$type/$resolvedImdbId.json';
        if (type == 'series' && season != null && episode != null) {
          streamUrl = '$base/stream/$type/$resolvedImdbId:$season:$episode.json';
        }

        debugPrint('resolveStreams: fetching $streamUrl');
        final response = await _http.get(Uri.parse(streamUrl)).timeout(const Duration(seconds: 15));
        debugPrint('resolveStreams: ${addon.name} -> ${response.statusCode}');
        if (response.statusCode != 200) return;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final streams = (data['streams'] as List<dynamic>? ?? [])
            .map((s) => StreamSource.fromJson(s as Map<String, dynamic>))
            .where((s) {
              // Include streams with a direct URL or an infoHash (torrent)
              final u = s.url;
              final h = s.infoHash;
              return (u != null && u.isNotEmpty) || (h != null && h.isNotEmpty);
            })
            .map((s) {
              // Convert infoHash-only streams to magnet URI so player can handle them
              if ((s.url == null || s.url!.isEmpty) && s.infoHash != null && s.infoHash!.isNotEmpty) {
                var magnet = 'magnet:?xt=urn:btih:${s.infoHash}';
                if (s.fileIdx != null) magnet += '&dn=file${s.fileIdx}';
                return s.copyWith(url: magnet);
              }
              return s;
            })
            .toList();

        debugPrint('resolveStreams: ${addon.name} returned ${streams.length} streams');
        if (streams.isNotEmpty) {
          results.add(AddonStreamResult(
            addonId: addon.id,
            addonName: addon.name,
            streams: streams,
          ));
        }
      } catch (e) {
        debugPrint('Stream resolution error for ${addon.name}: $e');
      }
    }));

    debugPrint('resolveStreams: total ${results.length} addon results');
    return results;
  }

  /// Resolve IMDB ID from TMDB ID using Cinemeta (Stremio's official metadata addon)
  Future<String> _resolveImdbFromCinemeta(String type, String tmdbId) async {
    try {
      final stremioType = type == 'movie' ? 'movie' : 'series';
      // Cinemeta supports looking up by tmdb ID: /meta/{type}/tmdb={id}.json
      final metaUrl = 'https://v3-cinemeta.strem.io/meta/$stremioType/tmdb=$tmdbId.json';
      debugPrint('Cinemeta lookup: $metaUrl');
      final response = await _http.get(Uri.parse(metaUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('Cinemeta lookup failed: ${response.statusCode}');
        return '';
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final meta = data['meta'] as Map<String, dynamic>?;
      if (meta == null) return '';
      final id = meta['id'] as String? ?? '';
      // Stremio/Cinemeta IDs are IMDB IDs like "tt1234567"
      if (id.startsWith('tt')) return id;
      return '';
    } catch (e) {
      debugPrint('Cinemeta lookup failed: $e');
      return '';
    }
  }

  /// Progressive stream resolution - emits progress as each addon completes
  Stream<StreamProgress> resolveStreamsProgressive({
    required String type,
    required String imdbId,
    required String tmdbId,
    int? season,
    int? episode,
  }) async* {
    var resolvedImdbId = imdbId;
    if (resolvedImdbId.isEmpty) {
      resolvedImdbId = await _resolveImdbFromCinemeta(type, tmdbId);
    }
    if (resolvedImdbId.isEmpty) {
      yield StreamProgress(completedAddons: 0, totalAddons: 0, allStreams: [], addonResults: [], isFinal: true);
      return;
    }

    final addons = await _addonRepo.getInstalledAddons();
    final enabled = addons.where((a) => a.isEnabled && a.runtimeKind == RuntimeKind.stremio && a.url != null).toList();

    final allStreams = <StreamSource>[];
    final addonResults = <AddonStreamResult>[];
    int completed = 0;

    yield StreamProgress(
      completedAddons: 0,
      totalAddons: enabled.length,
      allStreams: [],
      addonResults: [],
      isFinal: false,
    );

    for (final addon in enabled) {
      try {
        final manifestUrl = addon.url!;
        final uri = Uri.parse(manifestUrl);
        final pathSegments = List<String>.from(uri.pathSegments);
        if (pathSegments.contains('manifest.json')) {
          pathSegments.removeLast();
        }
        final base = uri.replace(pathSegments: pathSegments).toString().replaceAll(RegExp(r'/+$'), '');
        var streamUrl = '$base/stream/$type/$resolvedImdbId.json';
        if (type == 'series' && season != null && episode != null) {
          streamUrl = '$base/stream/$type/$resolvedImdbId:$season:$episode.json';
        }

        final response = await _http.get(Uri.parse(streamUrl)).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final streams = (data['streams'] as List<dynamic>? ?? [])
              .map((s) => StreamSource.fromJson(s as Map<String, dynamic>))
              .where((s) {
                final u = s.url;
                final h = s.infoHash;
                return (u != null && u.isNotEmpty) || (h != null && h.isNotEmpty);
              })
              .map((s) {
                if ((s.url == null || s.url!.isEmpty) && s.infoHash != null && s.infoHash!.isNotEmpty) {
                  var magnet = 'magnet:?xt=urn:btih:${s.infoHash}';
                  if (s.fileIdx != null) magnet += '&dn=file${s.fileIdx}';
                  return s.copyWith(url: magnet);
                }
                return s;
              })
              .toList();

          allStreams.addAll(streams);
          if (streams.isNotEmpty) {
            addonResults.add(AddonStreamResult(
              addonId: addon.id,
              addonName: addon.name,
              streams: streams,
            ));
          }
        }
      } catch (e) {
        debugPrint('Stream resolution error for ${addon.name}: $e');
      }

      completed++;
      yield StreamProgress(
        completedAddons: completed,
        totalAddons: enabled.length,
        allStreams: List.from(allStreams),
        addonResults: List.from(addonResults),
        isFinal: completed == enabled.length,
      );
    }
  }
}

final addonRepositoryProvider = Provider.family<AddonRepository, String>((ref, profileId) {
  throw UnimplementedError('Initialize with SharedPreferences');
});

final addonManagerProvider = Provider.family<AddonManagerRepository, String>((ref, profileId) {
  throw UnimplementedError('Initialize with SharedPreferences');
});

/// Alias used by player and other screens
final addonManagerRepositoryProvider = Provider<AddonManagerRepository>((ref) {
  throw UnimplementedError('Initialize with SharedPreferences');
});