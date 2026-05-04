// Simplified Catalog Repository
// Manages content catalogs: preinstalled defaults, Trakt lists, MDBList, addon catalogs
// Per-profile visibility and ordering stored in SharedPreferences
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streame/core/models/catalog_models.dart';

class CatalogRepository {
  final SharedPreferences _prefs;
  final String _profileId;

  static const String _catalogsKey = 'catalogs_v2';
  static const String _hiddenPreinstalledKey = 'hidden_preinstalled_v2';
  static const String _hiddenAddonKey = 'hidden_addon_catalogs_v1';

  CatalogRepository({required SharedPreferences prefs, required String profileId})
      : _prefs = prefs,
        _profileId = profileId;

  String get _catalogsPrefKey => '${_catalogsKey}_$_profileId';
  String get _hiddenPreinstalledPrefKey => '${_hiddenPreinstalledKey}_$_profileId';
  String get _hiddenAddonPrefKey => '${_hiddenAddonKey}_$_profileId';

  // ─── Preinstalled defaults ───

  static List<CatalogConfig> defaultCatalogs() => [
    const CatalogConfig(
      id: 'trending_movies',
      title: 'Trending Movies',
      sourceType: CatalogSourceType.preinstalled,
      isPreinstalled: true,
    ),
    const CatalogConfig(
      id: 'trending_tv',
      title: 'Trending TV',
      sourceType: CatalogSourceType.preinstalled,
      isPreinstalled: true,
    ),
    const CatalogConfig(
      id: 'top_rated_movies',
      title: 'Top Rated Movies',
      sourceType: CatalogSourceType.preinstalled,
      isPreinstalled: true,
    ),
    const CatalogConfig(
      id: 'popular_tv',
      title: 'Popular TV',
      sourceType: CatalogSourceType.preinstalled,
      isPreinstalled: true,
    ),
    const CatalogConfig(
      id: 'upcoming_movies',
      title: 'Upcoming Movies',
      sourceType: CatalogSourceType.preinstalled,
      isPreinstalled: true,
    ),
    const CatalogConfig(
      id: 'airing_tv',
      title: 'Airing Today',
      sourceType: CatalogSourceType.preinstalled,
      isPreinstalled: true,
    ),
  ];

  // ─── Get all catalogs (visible, in order) ───

  Future<List<CatalogConfig>> getCatalogs() async {
    final hiddenPreinstalled = await _getHiddenPreinstalled();
    final hiddenAddon = await _getHiddenAddonCatalogs();
    final customCatalogs = await _loadCustomCatalogs();

    final all = <CatalogConfig>[];

    // Add preinstalled (not hidden)
    for (final c in defaultCatalogs()) {
      if (!hiddenPreinstalled.contains(c.id)) {
        all.add(c);
      }
    }

    // Add custom catalogs (Trakt, MDBList, addon) not hidden
    for (final c in customCatalogs) {
      if (c.sourceType == CatalogSourceType.addon) {
        if (!hiddenAddon.contains(c.id)) all.add(c);
      } else {
        all.add(c);
      }
    }

    return all;
  }

  // ─── Custom catalog management ───

  Future<List<CatalogConfig>> _loadCustomCatalogs() async {
    final raw = _prefs.getString(_catalogsPrefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => CatalogConfig.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCustomCatalogs(List<CatalogConfig> catalogs) async {
    final json = jsonEncode(catalogs.map((c) => c.toJson()).toList());
    await _prefs.setString(_catalogsPrefKey, json);
  }

  Future<void> addCatalog(CatalogConfig catalog) async {
    final catalogs = await _loadCustomCatalogs();
    if (catalogs.any((c) => c.id == catalog.id)) return;
    catalogs.add(catalog);
    await _saveCustomCatalogs(catalogs);
  }

  Future<void> removeCatalog(String catalogId) async {
    final catalogs = await _loadCustomCatalogs();
    catalogs.removeWhere((c) => c.id == catalogId);
    await _saveCustomCatalogs(catalogs);
  }

  Future<void> reorderCatalogs(List<String> orderedIds) async {
    final catalogs = await _loadCustomCatalogs();
    final reordered = <CatalogConfig>[];
    for (final id in orderedIds) {
      final match = catalogs.where((c) => c.id == id).firstOrNull;
      if (match != null) reordered.add(match);
    }
    // Add any remaining not in the ordered list
    for (final c in catalogs) {
      if (!orderedIds.contains(c.id)) reordered.add(c);
    }
    await _saveCustomCatalogs(reordered);
  }

  // ─── Visibility ───

  Future<Set<String>> _getHiddenPreinstalled() async {
    final raw = _prefs.getString(_hiddenPreinstalledPrefKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<Set<String>> _getHiddenAddonCatalogs() async {
    final raw = _prefs.getString(_hiddenAddonPrefKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> hidePreinstalled(String catalogId) async {
    final hidden = await _getHiddenPreinstalled();
    hidden.add(catalogId);
    await _prefs.setString(_hiddenPreinstalledPrefKey, jsonEncode(hidden.toList()));
  }

  Future<void> showPreinstalled(String catalogId) async {
    final hidden = await _getHiddenPreinstalled();
    hidden.remove(catalogId);
    await _prefs.setString(_hiddenPreinstalledPrefKey, jsonEncode(hidden.toList()));
  }

  Future<void> hideAddonCatalog(String catalogId) async {
    final hidden = await _getHiddenAddonCatalogs();
    hidden.add(catalogId);
    await _prefs.setString(_hiddenAddonPrefKey, jsonEncode(hidden.toList()));
  }

  Future<void> showAddonCatalog(String catalogId) async {
    final hidden = await _getHiddenAddonCatalogs();
    hidden.remove(catalogId);
    await _prefs.setString(_hiddenAddonPrefKey, jsonEncode(hidden.toList()));
  }

  // ─── Add catalogs from addon manifest catalogs ───

  Future<void> syncAddonCatalogs(List<Map<String, dynamic>> addonCatalogs, String addonId) async {
    final existing = await _loadCustomCatalogs();
    // Remove old catalogs from this addon
    existing.removeWhere((c) =>
        c.sourceType == CatalogSourceType.addon && c.id.startsWith('${addonId}_'));
    // Add new ones
    for (final cat in addonCatalogs) {
      final config = CatalogConfig(
        id: '${addonId}_${cat['id'] ?? ''}',
        title: cat['name'] as String? ?? cat['id'] as String? ?? '',
        sourceType: CatalogSourceType.addon,
        addonId: addonId,
        addonCatalogType: cat['type'] as String?,
        addonCatalogId: cat['id'] as String?,
        collectionSources: [
          CollectionSourceConfig(
            kind: CollectionSourceKind.addonCatalog,
            addonId: addonId,
            addonCatalogId: cat['id'] as String?,
          ),
        ],
      );
      existing.add(config);
    }
    await _saveCustomCatalogs(existing);
  }
}

final catalogRepositoryProvider = Provider.family<CatalogRepository, String>((ref, profileId) {
  throw UnimplementedError('Initialize with SharedPreferences');
});

final catalogsProvider = FutureProvider.family<List<CatalogConfig>, String>((ref, profileId) async {
  final repo = ref.watch(catalogRepositoryProvider(profileId));
  return repo.getCatalogs();
});
