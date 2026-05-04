// Simplified Catalog Discovery Repository
// Search Trakt and MDBList for public lists that can be added as catalogs
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:streame/core/models/catalog_models.dart';
import 'package:streame/core/constants/api_constants.dart';

class CatalogDiscoveryRepository {
  final http.Client _http;

  CatalogDiscoveryRepository({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  /// Search for catalog lists across Trakt and MDBList
  Future<List<CatalogDiscoveryResult>> searchCatalogLists(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) return [];

    final results = <CatalogDiscoveryResult>[];

    // Search Trakt
    try {
      final trakt = await _searchTraktLists(normalized);
      results.addAll(trakt);
    } catch (e) {
      debugPrint('Trakt list search error: $e');
    }

    // Search MDBList
    try {
      final mdb = await _searchMdblistList(normalized);
      results.addAll(mdb);
    } catch (e) {
      debugPrint('MDBList search error: $e');
    }

    // Deduplicate by URL, sort by relevance/likes
    final seen = <String>{};
    final unique = <CatalogDiscoveryResult>[];
    for (final r in results) {
      final key = r.sourceUrl.toLowerCase();
      if (seen.add(key)) unique.add(r);
    }

    unique.sort((a, b) {
      final aRelevant = _relevanceScore(normalized, a) > 0 ? 1 : 0;
      final bRelevant = _relevanceScore(normalized, b) > 0 ? 1 : 0;
      if (aRelevant != bRelevant) return bRelevant.compareTo(aRelevant);
      return (b.likes ?? 0).compareTo(a.likes ?? 0);
    });

    return unique.take(24).toList();
  }

  Future<List<CatalogDiscoveryResult>> _searchTraktLists(String query) async {
    final url = Uri.parse('https://api.trakt.tv/search/list'
        '?query=${Uri.encodeComponent(query)}&limit=20');
    final response = await _http.get(url, headers: {
      'Content-Type': 'application/json',
      'trakt-api-version': '2',
      'trakt-api-key': ApiConstants.traktClientId,
    });
    if (response.statusCode != 200) return [];

    final list = jsonDecode(response.body) as List;
    return list.map<CatalogDiscoveryResult?>((item) {
      final listData = item['list'] as Map<String, dynamic>?;
      if (listData == null) return null;
      if (listData['privacy'] != 'public') return null;

      return CatalogDiscoveryResult(
        id: 'trakt_${listData['ids']?['trakt'] ?? ''}',
        title: listData['name'] as String? ?? '',
        description: listData['description'] as String?,
        sourceType: CatalogSourceType.trakt,
        sourceUrl: 'https://trakt.tv/lists/${listData['ids']?['slug'] ?? listData['ids']?['trakt'] ?? ''}',
        creatorName: listData['user']?['name'] as String? ?? listData['user']?['username'] as String?,
        itemCount: listData['item_count'] as int?,
        likes: listData['likes'] as int?,
      );
    }).whereType<CatalogDiscoveryResult>().toList();
  }

  Future<List<CatalogDiscoveryResult>> _searchMdblistList(String query) async {
    final url = Uri.parse('https://mdblist.com/api/'
        '?apikey=${Uri.encodeComponent(query)}&limit=20');
    // MDBList public search — simplified, returns JSON
    final response = await _http.get(url).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return [];

    final list = jsonDecode(response.body) as List? ?? [];
    return list.map<CatalogDiscoveryResult?>((item) {
      final map = item as Map<String, dynamic>;
      return CatalogDiscoveryResult(
        id: 'mdblist_${map['id'] ?? ''}',
        title: map['name'] as String? ?? '',
        description: map['description'] as String?,
        sourceType: CatalogSourceType.mdblist,
        sourceUrl: map['url'] as String? ?? 'https://mdblist.com/lists/${map['id'] ?? ''}',
        creatorName: map['user']?['name'] as String?,
        itemCount: map['items'] as int?,
        likes: map['likes'] as int?,
      );
    }).whereType<CatalogDiscoveryResult>().toList();
  }

  int _relevanceScore(String query, CatalogDiscoveryResult result) {
    final lower = query.toLowerCase();
    final title = result.title.toLowerCase();
    if (title.contains(lower)) return 2;
    if (result.description?.toLowerCase().contains(lower) ?? false) return 1;
    return 0;
  }
}

final catalogDiscoveryRepositoryProvider = Provider<CatalogDiscoveryRepository>((ref) {
  return CatalogDiscoveryRepository();
});
