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
      progress: (json['progress'] as num?)?.round(),
      seasonNumber: episode?['season'] as int?,
      episodeNumber: episode?['number'] as int?,
      watchedAt: json['watched_at'] != null
          ? DateTime.tryParse(json['watched_at'] as String)
          : null,
      lastUpdatedAt: json['last_updated_at'] != null
          ? DateTime.tryParse(json['last_updated_at'] as String)
          : (json['paused_at'] != null ? DateTime.tryParse(json['paused_at'] as String) : null),
    );
  }
}

class TraktException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  TraktException(this.message, {this.statusCode, this.body});

  @override
  String toString() => 'TraktException: $message ${statusCode != null ? '($statusCode)' : ''}';
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
    } catch (e) {
      debugPrint('Trakt: Error loading tokens: $e');
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
    } catch (e) {
      debugPrint('Trakt: Error refreshing tokens: $e');
    }
  }

  // Token sync no longer needed — tokens stored locally only

  // ─── Trakt API calls (authenticated) ───

  /// Automatically refresh token if expired before making authenticated calls.
  Future<void> _ensureValidToken() async {
    final tokens = await loadTokens();
    if (tokens == null || !tokens.isValid) {
       throw TraktException('Not authenticated');
    }
    // If no refresh token, nothing to refresh
    if (tokens.refreshToken == null) return;
    // Refresh if token is close to expiry (Trakt tokens last 30 days)
    // We refresh proactively to avoid silent failures
    await refreshTokens();
  }

  Future<Map<String, String>> _authHeaders() async {
    await _ensureValidToken();
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
      } else {
        throw TraktException('Failed to fetch watched items', statusCode: response.statusCode, body: response.body);
      }
    } catch (e) {
      debugPrint('Trakt: Error getting watched: $e');
      if (e is TraktException) rethrow;
      return [];
    }
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
      } else {
        throw TraktException('Failed to fetch watchlist', statusCode: response.statusCode, body: response.body);
      }
    } catch (e) {
      debugPrint('Trakt: Error getting watchlist: $e');
      if (e is TraktException) rethrow;
      return [];
    }
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
      } else {
        throw TraktException('Failed to fetch playback progress', statusCode: response.statusCode, body: response.body);
      }
    } catch (e) {
      debugPrint('Trakt: Error getting playback progress: $e');
      if (e is TraktException) rethrow;
      return [];
    }
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
    } catch (e) {
      debugPrint('Trakt: Error matching progress: $e');
      return null;
    }
  }

  /// Add items to Trakt history. Supply either [imdbId] or [tmdbId].
  Future<bool> addToHistory({
    String? imdbId,
    int? tmdbId,
    required String mediaType,
    int? season,
    int? episode,
    List<Map<String, dynamic>>? batchEpisodes,
  }) async {
    if (imdbId == null && tmdbId == null && batchEpisodes == null) return false;
    try {
      final headers = await _authHeaders();
      final body = <String, dynamic>{};
      
      if (batchEpisodes != null) {
        body['episodes'] = batchEpisodes;
      } else {
        final ids = <String, dynamic>{};
        if (imdbId != null && imdbId.isNotEmpty) ids['imdb'] = imdbId;
        if (tmdbId != null && tmdbId > 0) ids['tmdb'] = tmdbId;

        if (mediaType == 'movie') {
          body['movies'] = [{'ids': ids}];
        } else if (mediaType == 'tv') {
          // Using show-nested structure is more reliable for Trakt
          if (season != null && episode != null) {
            body['shows'] = [{
              'ids': ids,
              'seasons': [{
                'number': season,
                'episodes': [{'number': episode}]
              }]
            }];
          } else if (season != null) {
            body['shows'] = [{
              'ids': ids,
              'seasons': [{'number': season}]
            }];
          } else {
            body['shows'] = [{'ids': ids}];
          }
        }
      }

      final response = await _http.post(
        Uri.parse('https://api.trakt.tv/sync/history'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        final errorMsg = _parseError(response);
        throw TraktException('Failed to add to history: $errorMsg', statusCode: response.statusCode, body: response.body);
      }
    } catch (e) {
      debugPrint('Trakt: Error adding to history: $e');
      if (e is TraktException) rethrow;
      throw TraktException(e.toString());
    }
  }

  /// Remove items from Trakt history.
  Future<bool> removeFromHistory({
    String? imdbId,
    int? tmdbId,
    required String mediaType,
    int? season,
    int? episode,
  }) async {
    if (imdbId == null && tmdbId == null) return false;
    try {
      final headers = await _authHeaders();
      final ids = <String, dynamic>{};
      if (imdbId != null && imdbId.isNotEmpty) ids['imdb'] = imdbId;
      if (tmdbId != null && tmdbId > 0) ids['tmdb'] = tmdbId;

      final body = <String, dynamic>{};
      if (mediaType == 'movie') {
        body['movies'] = [{'ids': ids}];
      } else if (mediaType == 'tv') {
        if (season != null && episode != null) {
          body['shows'] = [{
            'ids': ids,
            'seasons': [{
              'number': season,
              'episodes': [{'number': episode}]
            }]
          }];
        } else if (season != null) {
          body['shows'] = [{
            'ids': ids,
            'seasons': [{'number': season}]
          }];
        } else {
          body['shows'] = [{'ids': ids}];
        }
      }
      final response = await _http.post(
        Uri.parse('https://api.trakt.tv/sync/history/remove'),
        headers: headers,
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        return true;
      } else {
        final errorMsg = _parseError(response);
        throw TraktException('Failed to remove from history: $errorMsg', statusCode: response.statusCode, body: response.body);
      }
    } catch (e) {
      debugPrint('Trakt: Error removing from history: $e');
      if (e is TraktException) rethrow;
      throw TraktException(e.toString());
    }
  }

  String _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('error')) return data['error'].toString();
      if (data is Map && data.containsKey('message')) return data['message'].toString();
    } catch (_) {}
    return 'Status ${response.statusCode}';
  }

  /// Mark as watched — resolves IDs properly.
  /// Watchlist removal is handled by the UI, not here.
  Future<bool> markAsWatched({
    required String mediaType,
    required int tmdbId,
    String? imdbId,
    int? season,
    int? episode,
  }) async {
    return addToHistory(
      imdbId: imdbId,
      tmdbId: tmdbId,
      mediaType: mediaType,
      season: season,
      episode: episode,
    );
  }

  /// Remove from history.
  Future<bool> unmarkAsWatched({
    required String mediaType,
    required int tmdbId,
    String? imdbId,
    int? season,
    int? episode,
  }) async {
    return removeFromHistory(
      imdbId: imdbId,
      tmdbId: tmdbId,
      mediaType: mediaType,
      season: season,
      episode: episode,
    );
  }

  /// Mark multiple episodes as watched in one request.
  Future<bool> markEpisodesAsWatched({
    required int tmdbId,
    required List<({int season, int episode})> episodes,
  }) async {
    if (episodes.isEmpty) return true;
    
    final batch = episodes.map((e) => {
      'ids': {'tmdb': tmdbId},
      'season': e.season,
      'number': e.episode,
    }).toList();

    return addToHistory(mediaType: 'tv', tmdbId: tmdbId, batchEpisodes: batch);
  }

  /// Remove multiple episodes from history.
  Future<bool> unmarkEpisodesAsWatched({
    required int tmdbId,
    required List<({int season, int episode})> episodes,
  }) async {
    if (episodes.isEmpty) return true;
    
    final headers = await _authHeaders();
    final body = {
      'episodes': episodes.map((e) => {
        'ids': {'tmdb': tmdbId},
        'season': e.season,
        'number': e.episode,
      }).toList(),
    };

    final response = await _http.post(
      Uri.parse('https://api.trakt.tv/sync/history/remove'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final errorMsg = _parseError(response);
      throw TraktException('Failed to remove episodes: $errorMsg', statusCode: response.statusCode, body: response.body);
    }
  }

  /// Add to watchlist. Supply either [imdbId] or [tmdbId].
  Future<bool> addToWatchlist({String? imdbId, int? tmdbId, required String mediaType}) async {
    if (imdbId == null && tmdbId == null) return false;
    try {
      final headers = await _authHeaders();
      final ids = <String, dynamic>{};
      if (imdbId != null && imdbId.isNotEmpty) ids['imdb'] = imdbId;
      if (tmdbId != null && tmdbId > 0) ids['tmdb'] = tmdbId;

      final body = <String, dynamic>{};
      if (mediaType == 'movie') {
        body['movies'] = [{'ids': ids}];
      } else {
        body['shows'] = [{'ids': ids}];
      }
      final response = await _http.post(
        Uri.parse('https://api.trakt.tv/sync/watchlist'),
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 201) {
        return true;
      } else {
        final errorMsg = _parseError(response);
        throw TraktException('Failed to add to watchlist: $errorMsg', statusCode: response.statusCode, body: response.body);
      }
    } catch (e) {
      debugPrint('Trakt: Error adding to watchlist: $e');
      if (e is TraktException) rethrow;
      throw TraktException(e.toString());
    }
  }

  /// Remove from watchlist. Supply either [imdbId] or [tmdbId].
  Future<bool> removeFromWatchlist({String? imdbId, int? tmdbId, required String mediaType}) async {
    if (imdbId == null && tmdbId == null) return false;
    try {
      final headers = await _authHeaders();
      final ids = <String, dynamic>{};
      if (imdbId != null && imdbId.isNotEmpty) ids['imdb'] = imdbId;
      if (tmdbId != null && tmdbId > 0) ids['tmdb'] = tmdbId;

      final body = <String, dynamic>{};
      if (mediaType == 'movie') {
        body['movies'] = [{'ids': ids}];
      } else {
        body['shows'] = [{'ids': ids}];
      }
      final response = await _http.post(
        Uri.parse('https://api.trakt.tv/sync/watchlist/remove'),
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        final errorMsg = _parseError(response);
        throw TraktException('Failed to remove from watchlist: $errorMsg', statusCode: response.statusCode, body: response.body);
      }
    } catch (e) {
      debugPrint('Trakt: Error removing from watchlist: $e');
      if (e is TraktException) rethrow;
      throw TraktException(e.toString());
    }
  }

  // ─── Scrobbling ───

  /// Scrobble: tell Trakt that playback started, paused, or stopped.
  /// Supply either [imdbId] or [tmdbId].
  Future<bool> scrobble({
    required String action,
    String? imdbId,
    int? tmdbId,
    required String mediaType,
    int? season,
    int? episode,
    double progress = 0.0,
  }) async {
    if (imdbId == null && tmdbId == null) return false;
    try {
      final headers = await _authHeaders();
      final body = <String, dynamic>{
        'progress': (progress * 100).round().clamp(0, 100),
      };
      final ids = <String, dynamic>{};
      if (imdbId != null && imdbId.isNotEmpty) ids['imdb'] = imdbId;
      if (tmdbId != null && tmdbId > 0) ids['tmdb'] = tmdbId;

      if (mediaType == 'movie') {
        body['movie'] = {'ids': ids};
      } else {
        body['episode'] = {
          'ids': ids,
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
    String? imdbId,
    int? tmdbId,
    required String mediaType,
    int? season,
    int? episode,
    double progress = 0.0,
  }) => scrobble(action: 'start', imdbId: imdbId, tmdbId: tmdbId, mediaType: mediaType, season: season, episode: episode, progress: progress);

  Future<bool> scrobblePause({
    String? imdbId,
    int? tmdbId,
    required String mediaType,
    int? season,
    int? episode,
    double progress = 0.0,
  }) => scrobble(action: 'pause', imdbId: imdbId, tmdbId: tmdbId, mediaType: mediaType, season: season, episode: episode, progress: progress);

  Future<bool> scrobbleStop({
    String? imdbId,
    int? tmdbId,
    required String mediaType,
    int? season,
    int? episode,
    double progress = 0.0,
  }) => scrobble(action: 'stop', imdbId: imdbId, tmdbId: tmdbId, mediaType: mediaType, season: season, episode: episode, progress: progress);

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

  /// Get watched shows with episode counts for progress tracking.
  /// Returns list of maps with: tmdbId, title, totalEpisodes, watchedEpisodes, lastWatchedAt
  Future<List<Map<String, dynamic>>> getWatchedShowsProgress() async {
    try {
      final headers = await _authHeaders();
      final response = await _http.get(
        Uri.parse('https://api.trakt.tv/sync/watched/shows?extended=count'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.map((item) {
          final show = item['show'] as Map<String, dynamic>;
          final ids = show['ids'] as Map<String, dynamic>;
          
          // Trakt returns 'plays', 'last_watched_at', and optionally 'seasons'
          // If we want total progress, we might need a different endpoint or use 'completed' from progress
          return {
            'tmdbId': ids['tmdb'],
            'traktId': ids['trakt'],
            'title': show['title'],
            'plays': item['plays'],
            'lastWatchedAt': item['last_watched_at'],
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get progress for a specific show including watched episodes.
  Future<Map<String, dynamic>?> getShowProgress(int tmdbId) async {
    try {
      final headers = await _authHeaders();
      final type = 'show';
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

      final progressResp = await _http.get(
        Uri.parse('https://api.trakt.tv/shows/$traktId/progress/watched'),
        headers: headers,
      );
      if (progressResp.statusCode == 200) {
        return jsonDecode(progressResp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Get progress for a specific show to see if it's fully watched.
  Future<bool> isShowFullyWatched(int tmdbId) async {
    final data = await getShowProgress(tmdbId);
    if (data != null) {
      final aired = data['aired'] as int? ?? 0;
      final completed = data['completed'] as int? ?? 0;
      return aired > 0 && completed >= aired;
    }
    return false;
  }

  // ─── User Profile ───

  /// Get Trakt user profile info.
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final headers = await _authHeaders();
      final response = await _http.get(
        Uri.parse('https://api.trakt.tv/users/me'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Get Trakt user stats (watched count, hours, etc.).
  Future<Map<String, dynamic>?> getUserStats() async {
    try {
      final headers = await _authHeaders();
      final response = await _http.get(
        Uri.parse('https://api.trakt.tv/users/me/stats'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
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

final traktWatchedProvider = FutureProvider<List<TraktMediaItem>>((ref) async {
  final repo = ref.watch(traktRepositoryProvider);
  if (!repo.isLinked()) return [];
  // Run both in parallel for better performance
  final results = await Future.wait([
    repo.getWatchedMovies(),
    repo.getWatchedShows(),
  ]);
  return [...results[0], ...results[1]];
});

final traktFullyWatchedProvider = FutureProvider.family<bool, int>((ref, tmdbId) async {
  final repo = ref.watch(traktRepositoryProvider);
  if (!repo.isLinked()) return false;
  return repo.isShowFullyWatched(tmdbId);
});

final traktShowProgressProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, tmdbId) async {
  final repo = ref.watch(traktRepositoryProvider);
  if (!repo.isLinked()) return null;
  return repo.getShowProgress(tmdbId);
});
