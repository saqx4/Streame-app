// Trakt repository matching Kotlin TraktRepository parity
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streame/core/constants/api_constants.dart';

class TraktTokens {
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final String? tokenType;
  final String? scope;

  const TraktTokens({
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.tokenType,
    this.scope,
  });

  bool get isValid => accessToken != null && accessToken!.isNotEmpty;

  factory TraktTokens.fromJson(Map<String, dynamic> json) => TraktTokens(
    accessToken: json['access_token'] as String?,
    refreshToken: json['refresh_token'] as String?,
    expiresIn: json['expires_in'] as int?,
    tokenType: json['token_type'] as String?,
    scope: json['scope'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_in': expiresIn,
    'token_type': tokenType,
    'scope': scope,
  };
}

class TraktMediaItem {
  final String? traktId;
  final String? tmdbId;
  final String? imdbId;
  final String? title;
  final int? year;
  final String? mediaType;
  final double? rating;
  final int? progress;
  final int? seasonNumber;
  final int? episodeNumber;
  final DateTime? watchedAt;
  final DateTime? lastUpdatedAt;

  const TraktMediaItem({
    this.traktId,
    this.tmdbId,
    this.imdbId,
    this.title,
    this.year,
    this.mediaType,
    this.rating,
    this.progress,
    this.seasonNumber,
    this.episodeNumber,
    this.watchedAt,
    this.lastUpdatedAt,
  });

  factory TraktMediaItem.fromJson(Map<String, dynamic> json) {
    final show = json['show'] as Map<String, dynamic>?;
    final movie = json['movie'] as Map<String, dynamic>?;
    final episode = json['episode'] as Map<String, dynamic>?;
    final media = show ?? movie;
    final ids = media?['ids'] as Map<String, dynamic>?;
    final epIds = episode?['ids'] as Map<String, dynamic>?;
    return TraktMediaItem(
      traktId: (ids?['trakt'] ?? epIds?['trakt'])?.toString(),
      tmdbId: (ids?['tmdb'] ?? epIds?['tmdb'])?.toString(),
      imdbId: (ids?['imdb'] ?? epIds?['imdb']) as String?,
      title: episode?['title'] as String? ?? media?['title'] as String?,
      year: media?['year'] as int?,
      mediaType: show != null ? 'tv' : (movie != null ? 'movie' : null),
      rating: (json['rating'] as num?)?.toDouble(),
      progress: json['progress'] as int?,
      seasonNumber: episode?['season'] as int?,
      episodeNumber: episode?['number'] as int?,
      watchedAt: json['watched_at'] != null
          ? DateTime.tryParse(json['watched_at'] as String)
          : null,
      lastUpdatedAt: json['last_updated_at'] != null
          ? DateTime.tryParse(json['last_updated_at'] as String)
          : null,
    );
  }
}

class TraktRepository {
  final http.Client _http;
  final SharedPreferences _prefs;
  String? _userId;

  static const String _tokenKey = 'trakt_tokens_v1';

  TraktRepository({
    required SharedPreferences prefs,
    http.Client? httpClient,
  })  : _prefs = prefs,
        _http = httpClient ?? http.Client();

  void setUserId(String userId) => _userId = userId;

  String get _tokenPrefKey => '$_tokenKey${_userId != null ? '_$_userId' : ''}';

  Map<String, String> get _traktHeaders => {
    'Content-Type': 'application/json',
    'trakt-api-version': '2',
    'trakt-api-key': ApiConstants.traktClientId,
  };

  // ─── Token management ───

  Future<TraktTokens?> loadTokens() async {
    final raw = _prefs.getString(_tokenPrefKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return TraktTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTokens(TraktTokens tokens) async {
    await _prefs.setString(_tokenPrefKey, jsonEncode(tokens.toJson()));
  }

  Future<void> clearTokens() async {
    await _prefs.remove(_tokenPrefKey);
  }

  bool isLinked() {
    final raw = _prefs.getString(_tokenPrefKey);
    if (raw == null || raw.isEmpty) return false;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json['access_token'] != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isAuthenticated() async => (await loadTokens())?.isValid ?? false;

  Future<void> loadTokensFromProfile(Map<String, dynamic> profileTokens) async {
    final tokens = TraktTokens.fromJson(profileTokens);
    if (tokens.isValid) await saveTokens(tokens);
  }

  // ─── OAuth: Device Code Flow (no client_secret needed) ───

  /// Step 1: Request a device code from Trakt.
  /// Returns a map with: device_code, user_code, verification_url, expires_in, interval
  Future<Map<String, dynamic>?> requestDeviceCode() async {
    try {
      final response = await _http.post(
        Uri.parse('https://api.trakt.tv/oauth/device/code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'client_id': ApiConstants.traktClientId}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('Trakt device code error: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Trakt device code request error: $e');
    }
    return null;
  }

  /// Step 2: Poll Trakt for the device token.
  /// Call this repeatedly every [interval] seconds until the user authorizes.
  /// Returns tokens on success, null if still pending or errored.
  Future<TraktTokens?> pollDeviceToken(String deviceCode) async {
    try {
      final response = await _http.post(
        Uri.parse('https://api.trakt.tv/oauth/device/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': deviceCode,
          'client_id': ApiConstants.traktClientId,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        }),
      );
      if (response.statusCode == 200) {
        final tokens = TraktTokens.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        if (tokens.isValid) {
          await saveTokens(tokens);
          return tokens;
        }
      }
      // 400 = pending / slow down / expired — caller should retry or abort
    } catch (_) {}
    return null;
  }

  /// Legacy: kept for backward compat but Device Code flow is preferred
  String getAuthUrl(String redirectUri) {
    return 'https://api.trakt.tv/oauth/authorize?'
        'response_type=code&'
        'client_id=${ApiConstants.traktClientId}&'
        'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
        'state=${_userId ?? ''}';
  }

  Future<TraktTokens?> exchangeCode(String code) async {
    // This flow requires client_secret which we don't embed — use Device Code flow instead
    debugPrint('Trakt: exchangeCode is deprecated — use Device Code flow');
    return null;
  }

  Future<void> refreshTokens() async {
    final tokens = await loadTokens();
    if (tokens?.refreshToken == null) return;
    try {
      final response = await _http.post(
        Uri.parse('https://api.trakt.tv/oauth/device/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refresh_token': tokens!.refreshToken,
          'client_id': ApiConstants.traktClientId,
          'grant_type': 'refresh_token',
        }),
      );
      if (response.statusCode == 200) {
        final newTokens = TraktTokens.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        if (newTokens.isValid) {
          await saveTokens(newTokens);
        }
      }
    } catch (_) {}
  }

  // Token sync no longer needed — tokens stored locally only

  // ─── Trakt API calls (authenticated) ───

  Future<Map<String, String>> _authHeaders() async {
    final tokens = await loadTokens();
    return {
      ..._traktHeaders,
      if (tokens?.accessToken != null) 'Authorization': 'Bearer ${tokens!.accessToken}',
    };
  }

  Future<List<TraktMediaItem>> getWatched({String? mediaType}) async {
    try {
      final headers = await _authHeaders();
      final type = mediaType == 'movie' ? 'movies' : 'shows';
      final response = await _http.get(
        Uri.parse('https://api.trakt.tv/sync/watched/$type?extended=full'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.map((e) => TraktMediaItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<TraktMediaItem>> getWatchedMovies() => getWatched(mediaType: 'movie');

  Future<List<TraktMediaItem>> getWatchedShows() => getWatched(mediaType: 'tv');

  Future<List<TraktMediaItem>> getWatchlist() async {
    try {
      final headers = await _authHeaders();
      final response = await _http.get(
        Uri.parse('https://api.trakt.tv/sync/watchlist?extended=full'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.map((e) => TraktMediaItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<TraktMediaItem>> getPlaybackProgress() async {
    try {
      final headers = await _authHeaders();
      final response = await _http.get(
        Uri.parse('https://api.trakt.tv/sync/playback?extended=full'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.map((e) => TraktMediaItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<TraktMediaItem?> getProgress({
    required String mediaType,
    required int tmdbId,
    int? season,
    int? episode,
  }) async {
    try {
      final items = await getPlaybackProgress();
      return items.where((i) =>
        i.tmdbId == tmdbId.toString() &&
        i.mediaType == mediaType &&
        (season == null || i.seasonNumber == season) &&
        (episode == null || i.episodeNumber == episode)
      ).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<bool> addToHistory({
    required String imdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = <String, dynamic>{};
      if (mediaType == 'movie') {
        body['movies'] = [{'ids': {'imdb': imdbId}}];
      } else {
        body['episodes'] = [{
          'ids': {'imdb': imdbId},
          if (season != null) 'season': season,
          if (episode != null) 'number': episode,
        }];
      }
      final response = await _http.post(
        Uri.parse('https://api.trakt.tv/sync/history'),
        headers: headers,
        body: jsonEncode(body),
      );
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<void> markWatched({
    required String mediaType,
    required int tmdbId,
    int? season,
    int? episode,
    int? progress,
  }) async {
    // Mark as watched via history endpoint
    await addToHistory(imdbId: 'tt$tmdbId', mediaType: mediaType, season: season, episode: episode);
  }

  Future<bool> addToWatchlist({required String imdbId, required String mediaType}) async {
    try {
      final headers = await _authHeaders();
      final body = <String, dynamic>{};
      if (mediaType == 'movie') {
        body['movies'] = [{'ids': {'imdb': imdbId}}];
      } else {
        body['shows'] = [{'ids': {'imdb': imdbId}}];
      }
      final response = await _http.post(
        Uri.parse('https://api.trakt.tv/sync/watchlist'),
        headers: headers,
        body: jsonEncode(body),
      );
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeFromWatchlist({required String imdbId, required String mediaType}) async {
    try {
      final headers = await _authHeaders();
      final body = <String, dynamic>{};
      if (mediaType == 'movie') {
        body['movies'] = [{'ids': {'imdb': imdbId}}];
      } else {
        body['shows'] = [{'ids': {'imdb': imdbId}}];
      }
      final response = await _http.delete(
        Uri.parse('https://api.trakt.tv/sync/watchlist/remove'),
        headers: headers,
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Scrobbling ───

  /// Scrobble: tell Trakt that playback started, paused, or stopped.
  /// [action] is 'start', 'pause', or 'stop'.
  /// If progress >= 80% on stop, Trakt auto-marks as watched.
  Future<bool> scrobble({
    required String action,
    required String imdbId,
    required String mediaType,
    int? season,
    int? episode,
    double progress = 0.0,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = <String, dynamic>{
        'progress': (progress * 100).round().clamp(0, 100),
      };
      if (mediaType == 'movie') {
        body['movie'] = {'ids': {'imdb': imdbId}};
      } else {
        body['episode'] = {
          'ids': {'imdb': imdbId},
          if (season != null) 'season': season,
          if (episode != null) 'number': episode,
        };
      }
      final response = await _http.post(
        Uri.parse('https://api.trakt.tv/scrobble/$action'),
        headers: headers,
        body: jsonEncode(body),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> scrobbleStart({
    required String imdbId,
    required String mediaType,
    int? season,
    int? episode,
    double progress = 0.0,
  }) => scrobble(action: 'start', imdbId: imdbId, mediaType: mediaType, season: season, episode: episode, progress: progress);

  Future<bool> scrobblePause({
    required String imdbId,
    required String mediaType,
    int? season,
    int? episode,
    double progress = 0.0,
  }) => scrobble(action: 'pause', imdbId: imdbId, mediaType: mediaType, season: season, episode: episode, progress: progress);

  Future<bool> scrobbleStop({
    required String imdbId,
    required String mediaType,
    int? season,
    int? episode,
    double progress = 0.0,
  }) => scrobble(action: 'stop', imdbId: imdbId, mediaType: mediaType, season: season, episode: episode, progress: progress);

  // ─── Ratings ───

  /// Get Trakt rating for a movie or show by TMDB ID.
  /// Uses the Trakt search to resolve TMDB → Trakt ID, then fetches ratings.
  Future<double?> getTraktRating({required String mediaType, required int tmdbId}) async {
    try {
      final headers = _traktHeaders;
      final type = mediaType == 'tv' ? 'show' : 'movie';
      // Search by TMDB ID to get Trakt ID
      final searchResp = await _http.get(
        Uri.parse('https://api.trakt.tv/search/tmdb/$tmdbId?type=$type'),
        headers: headers,
      );
      if (searchResp.statusCode != 200) return null;
      final searchList = jsonDecode(searchResp.body) as List<dynamic>;
      if (searchList.isEmpty) return null;
      final traktId = (searchList.first as Map<String, dynamic>)[type]?['ids']?['trakt'];
      if (traktId == null) return null;
      // Fetch ratings
      final ratingsResp = await _http.get(
        Uri.parse('https://api.trakt.tv/$type/$traktId/ratings'),
        headers: headers,
      );
      if (ratingsResp.statusCode != 200) return null;
      final ratingsData = jsonDecode(ratingsResp.body) as Map<String, dynamic>;
      return (ratingsData['rating'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  /// Logout — clear local tokens and profile
  Future<void> logout() async {
    await clearTokens();
  }
}

final traktRepositoryProvider = Provider<TraktRepository>((ref) {
  throw UnimplementedError('Initialize in main');
});

final traktAuthProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(traktRepositoryProvider);
  return repo.isAuthenticated();
});

final traktWatchlistProvider = FutureProvider<List<TraktMediaItem>>((ref) async {
  final repo = ref.watch(traktRepositoryProvider);
  if (!repo.isLinked()) return [];
  return repo.getWatchlist();
});

final traktPlaybackProvider = FutureProvider<List<TraktMediaItem>>((ref) async {
  final repo = ref.watch(traktRepositoryProvider);
  if (!repo.isLinked()) return [];
  return repo.getPlaybackProgress();
});