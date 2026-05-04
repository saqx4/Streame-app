// Simplified Anime Score repository
// Resolves MAL community scores for anime titles via ARM + Jikan APIs
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class AnimeScoreRepository {
  final http.Client _http;

  AnimeScoreRepository({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  // Caches: IMDB→MAL ID, MAL ID→score
  final Map<String, int?> _malIdCache = {};
  final Map<int, double?> _scoreCache = {};

  /// Look up the MAL community score for an anime by its IMDB id.
  /// Returns the raw score (0.0-10.0) or null if not available.
  /// Safe to call for non-anime — ARM will just return null.
  Future<double?> getMalScore(String? imdbId) async {
    final trimmed = imdbId?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final malId = await _resolveMalId(trimmed);
    if (malId == null) return null;

    return _resolveScore(malId);
  }

  Future<int?> _resolveMalId(String imdbId) async {
    if (_malIdCache.containsKey(imdbId)) return _malIdCache[imdbId];

    try {
      final url = Uri.parse('https://arm.haglund.dev/api/v2/idtype/imdb'
          '?ids=$imdbId&include=mal');
      final response = await _http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) {
        _malIdCache[imdbId] = null;
        return null;
      }

      final list = jsonDecode(response.body) as List;
      final malId = list.isEmpty ? null : int.tryParse(list.first['mal_id']?.toString() ?? '');
      _malIdCache[imdbId] = malId;
      return malId;
    } catch (e) {
      _malIdCache[imdbId] = null;
      return null;
    }
  }

  Future<double?> _resolveScore(int malId) async {
    if (_scoreCache.containsKey(malId)) return _scoreCache[malId];

    try {
      final url = Uri.parse('https://api.jikan.moe/v4/animes/$malId');
      final response = await _http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) {
        _scoreCache[malId] = null;
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final score = (data['data']?['score'] as num?)?.toDouble();
      _scoreCache[malId] = score;
      return score;
    } catch (e) {
      debugPrint('Jikan score error: $e');
      _scoreCache[malId] = null;
      return null;
    }
  }
}

final animeScoreRepositoryProvider = Provider<AnimeScoreRepository>((ref) {
  return AnimeScoreRepository();
});
