// Simplified Skip Intro repository
// Calls IntroDB + AniSkip APIs to detect intro/recap/outro timestamps
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class SkipInterval {
  final int startMs;
  final int endMs;
  final String type; // "intro", "recap", "outro", "op", "ed"
  final String provider; // "introdb" or "aniskip"

  const SkipInterval({
    required this.startMs,
    required this.endMs,
    required this.type,
    required this.provider,
  });

  Duration get duration => Duration(milliseconds: endMs - startMs);
}

class SkipIntroRepository {
  final http.Client _http;

  SkipIntroRepository({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  // In-memory cache: "imdbId:season:episode" -> intervals
  final Map<String, List<SkipInterval>> _cache = {};

  /// Get skip intervals for a given episode.
  /// Tries IntroDB first (for TV shows), then AniSkip (for anime).
  Future<List<SkipInterval>> getSkipIntervals({
    required String? imdbId,
    required int season,
    required int episode,
  }) async {
    if (imdbId == null || imdbId.isEmpty) return [];

    final cacheKey = '$imdbId:$season:$episode';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // 1) IntroDB (TV shows)
    final introDb = await _fetchIntroDb(imdbId, season, episode);
    if (introDb.isNotEmpty) {
      _cache[cacheKey] = introDb;
      return introDb;
    }

    // 2) AniSkip (anime) — needs MAL ID via ARM
    final malId = await _resolveMalId(imdbId);
    if (malId != null) {
      final aniSkip = await _fetchAniSkip(malId, episode);
      if (aniSkip.isNotEmpty) {
        _cache[cacheKey] = aniSkip;
        return aniSkip;
      }
    }

    _cache[cacheKey] = [];
    return [];
  }

  // ─── IntroDB ───

  Future<List<SkipInterval>> _fetchIntroDb(String imdbId, int season, int episode) async {
    try {
      final url = Uri.parse('https://api.introdb.com/v1/segments'
          '?imdb_id=$imdbId&season=$season&episode=$episode');
      final response = await _http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final segments = data is List ? data : (data['segments'] as List? ?? []);
      return segments.map<SkipInterval>((s) {
        final map = s as Map<String, dynamic>;
        return SkipInterval(
          startMs: (map['start'] as num?)?.round() ?? 0,
          endMs: (map['end'] as num?)?.round() ?? 0,
          type: map['type'] as String? ?? 'intro',
          provider: 'introdb',
        );
      }).where((i) => i.endMs > i.startMs).toList();
    } catch (e) {
      debugPrint('IntroDB error: $e');
      return [];
    }
  }

  // ─── AniSkip ───

  Future<List<SkipInterval>> _fetchAniSkip(String malId, int episode) async {
    try {
      final url = Uri.parse('https://api.aniskip.com/v2/skip-times'
          '/$malId/$episode?types=op&types=ed&types=recap&types=mixed-op&types=mixed-ed');
      final response = await _http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List? ?? [];
      return results.map<SkipInterval>((r) {
        final map = r as Map<String, dynamic>;
        final interval = map['interval'] as Map<String, dynamic>? ?? {};
        return SkipInterval(
          startMs: ((interval['startTime'] as num?)?.toDouble() ?? 0).round() * 1000,
          endMs: ((interval['endTime'] as num?)?.toDouble() ?? 0).round() * 1000,
          type: map['skipType'] as String? ?? 'op',
          provider: 'aniskip',
        );
      }).where((i) => i.endMs > i.startMs).toList();
    } catch (e) {
      debugPrint('AniSkip error: $e');
      return [];
    }
  }

  // ─── ARM (IMDB → MAL ID mapping) ───

  final Map<String, String?> _malIdCache = {};

  Future<String?> _resolveMalId(String imdbId) async {
    if (_malIdCache.containsKey(imdbId)) return _malIdCache[imdbId];

    try {
      final url = Uri.parse('https://arm.haglund.dev/api/v2/idtype/imdb'
          '?ids=$imdbId&include=mal');
      final response = await _http.get(url).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        _malIdCache[imdbId] = null;
        return null;
      }

      final list = jsonDecode(response.body) as List;
      if (list.isEmpty) {
        _malIdCache[imdbId] = null;
        return null;
      }

      final malId = list.first['mal_id']?.toString();
      _malIdCache[imdbId] = malId;
      return malId;
    } catch (e) {
      _malIdCache[imdbId] = null;
      return null;
    }
  }
}

final skipIntroRepositoryProvider = Provider<SkipIntroRepository>((ref) {
  return SkipIntroRepository();
});
