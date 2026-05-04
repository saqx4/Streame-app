import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streame/core/repositories/profile_repository.dart';
import 'package:streame/core/repositories/trakt_repository.dart';

class WatchlistItem {
  final int id;
  final int tmdbId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? imdbId;
  final String? year;
  final DateTime addedAt;

  WatchlistItem({
    required this.id,
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.imdbId,
    this.year,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'tmdb_id': tmdbId,
    'media_type': mediaType,
    'title': title,
    'poster_path': posterPath,
    'imdb_id': imdbId,
    'year': year,
    'added_at': addedAt.toIso8601String(),
  };

  factory WatchlistItem.fromJson(Map<String, dynamic> json) => WatchlistItem(
    id: json['id'] as int? ?? 0,
    tmdbId: json['tmdb_id'] as int? ?? 0,
    mediaType: json['media_type'] as String? ?? 'movie',
    title: json['title'] as String? ?? '',
    posterPath: json['poster_path'] as String?,
    imdbId: json['imdb_id'] as String?,
    year: json['year'] as String?,
    addedAt: json['added_at'] != null ? DateTime.tryParse(json['added_at'] as String) ?? DateTime.now() : null,
  );
}

class WatchHistoryItem {
  final int id;
  final int tmdbId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final Duration position;
  final int season;
  final int episode;
  final DateTime updatedAt;

  WatchHistoryItem({
    required this.id,
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.position = Duration.zero,
    this.season = 0,
    this.episode = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}

class WatchlistRepository {
  final SharedPreferences _prefs;
  final TraktRepository? _traktRepo;
  final String _profileId;

  static const String _watchlistKey = 'watchlist_local_v1';
  static const String _historyKey = 'watch_history_local_v1';

  WatchlistRepository({
    required SharedPreferences prefs,
    required String profileId,
    TraktRepository? traktRepo,
  })  : _prefs = prefs,
        _profileId = profileId,
        _traktRepo = traktRepo;

  String get _wlPrefKey => '${_watchlistKey}_$_profileId';
  String get _histPrefKey => '${_historyKey}_$_profileId';

  // ─── Watchlist ───

  Future<List<WatchlistItem>> getWatchlist() async {
    // Load local
    final local = await _loadLocalWatchlist();

    // Merge with Trakt if linked
    if (_traktRepo != null && _traktRepo.isLinked()) {
      try {
        final traktItems = await _traktRepo.getWatchlist();
        final merged = <String, WatchlistItem>{};
        for (final item in local) {
          merged['${item.mediaType}_${item.tmdbId}'] = item;
        }
        for (final trakt in traktItems) {
          if (trakt.tmdbId == null) continue;
          final tmdbId = int.tryParse(trakt.tmdbId!) ?? 0;
          if (tmdbId == 0) continue;
          final key = '${trakt.mediaType}_$tmdbId';
          if (!merged.containsKey(key)) {
            merged[key] = WatchlistItem(
              id: 0,
              tmdbId: tmdbId,
              mediaType: trakt.mediaType ?? 'movie',
              title: trakt.title ?? '',
              imdbId: trakt.imdbId,
              addedAt: trakt.watchedAt,
            );
          }
        }
        return merged.values.toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      } catch (_) {}
    }

    return local;
  }

  Future<void> addToWatchlist({
    required int tmdbId,
    required String mediaType,
    required String title,
    String? posterPath,
    String? imdbId,
  }) async {
    final items = await _loadLocalWatchlist();
    final exists = items.any((i) => i.tmdbId == tmdbId && i.mediaType == mediaType);
    if (!exists) {
      items.insert(0, WatchlistItem(
        id: DateTime.now().millisecondsSinceEpoch,
        tmdbId: tmdbId,
        mediaType: mediaType,
        title: title,
        posterPath: posterPath,
        imdbId: imdbId,
      ));
      await _saveLocalWatchlist(items);
    }

    // Sync to Trakt if linked
    if (_traktRepo != null && _traktRepo.isLinked() && imdbId != null) {
      try {
        await _traktRepo.addToWatchlist(imdbId: imdbId, mediaType: mediaType);
      } catch (_) {}
    }
  }

  Future<void> removeFromWatchlist(int tmdbId, String mediaType, {String? imdbId}) async {
    final items = await _loadLocalWatchlist();
    items.removeWhere((i) => i.tmdbId == tmdbId && i.mediaType == mediaType);
    await _saveLocalWatchlist(items);

    // Sync to Trakt if linked
    if (_traktRepo != null && _traktRepo.isLinked() && imdbId != null) {
      try {
        await _traktRepo.removeFromWatchlist(imdbId: imdbId, mediaType: mediaType);
      } catch (_) {}
    }
  }

  Future<bool> isInWatchlist(int tmdbId, String mediaType) async {
    final items = await _loadLocalWatchlist();
    return items.any((i) => i.tmdbId == tmdbId && i.mediaType == mediaType);
  }

  // ─── Watch History ───

  Future<List<WatchHistoryItem>> getWatchHistory() async {
    final raw = _prefs.getString(_histPrefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map<WatchHistoryItem>((r) => WatchHistoryItem(
        id: r['id'] as int? ?? 0,
        tmdbId: r['tmdb_id'] as int? ?? 0,
        mediaType: r['media_type'] as String? ?? 'movie',
        title: r['title'] as String? ?? '',
        posterPath: r['poster_path'] as String?,
        position: Duration(seconds: r['position_seconds'] as int? ?? 0),
        season: r['season'] as int? ?? 0,
        episode: r['episode'] as int? ?? 0,
        updatedAt: r['updated_at'] != null ? DateTime.tryParse(r['updated_at'] as String) ?? DateTime.now() : null,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateProgress({
    required int tmdbId,
    required String mediaType,
    required Duration position,
    int season = 0,
    int episode = 0,
    String? title,
    String? posterPath,
  }) async {
    final items = await getWatchHistory();
    final idx = items.indexWhere((i) =>
        i.tmdbId == tmdbId && i.mediaType == mediaType && i.season == season && i.episode == episode);
    final item = WatchHistoryItem(
      id: idx >= 0 ? items[idx].id : DateTime.now().millisecondsSinceEpoch,
      tmdbId: tmdbId,
      mediaType: mediaType,
      title: title ?? (idx >= 0 ? items[idx].title : ''),
      posterPath: posterPath ?? (idx >= 0 ? items[idx].posterPath : null),
      position: position,
      season: season,
      episode: episode,
    );
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.insert(0, item);
    }
    final json = items.map((i) => <String, dynamic>{
      'id': i.id,
      'tmdb_id': i.tmdbId,
      'media_type': i.mediaType,
      'title': i.title,
      'poster_path': i.posterPath,
      'position_seconds': i.position.inSeconds,
      'season': i.season,
      'episode': i.episode,
      'updated_at': i.updatedAt.toIso8601String(),
    }).toList();
    await _prefs.setString(_histPrefKey, jsonEncode(json));
  }

  Future<void> markAsWatched(int tmdbId, String mediaType) async {
    final items = await getWatchHistory();
    items.removeWhere((i) => i.tmdbId == tmdbId && i.mediaType == mediaType);
    final json = items.map((i) => <String, dynamic>{
      'id': i.id,
      'tmdb_id': i.tmdbId,
      'media_type': i.mediaType,
      'title': i.title,
      'poster_path': i.posterPath,
      'position_seconds': i.position.inSeconds,
      'season': i.season,
      'episode': i.episode,
      'updated_at': i.updatedAt.toIso8601String(),
    }).toList();
    await _prefs.setString(_histPrefKey, jsonEncode(json));
  }

  // ─── Local storage ───

  Future<List<WatchlistItem>> _loadLocalWatchlist() async {
    final raw = _prefs.getString(_wlPrefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => WatchlistItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalWatchlist(List<WatchlistItem> items) async {
    await _prefs.setString(_wlPrefKey, jsonEncode(items.map((i) => i.toJson()).toList()));
  }
}

final watchlistRepositoryProvider = Provider.family<WatchlistRepository, String>((ref, profileId) {
  throw UnimplementedError('Initialize in main');
});

final watchlistProvider = FutureProvider.family<List<WatchlistItem>, String>((ref, profileId) async {
  final repo = ref.watch(watchlistRepositoryProvider(profileId));
  return repo.getWatchlist();
});

final watchHistoryProvider = FutureProvider.family<List<WatchHistoryItem>, String>((ref, profileId) async {
  final repo = ref.watch(watchlistRepositoryProvider(profileId));
  return repo.getWatchHistory();
});

final _localWatchlistKey = 'local_watchlist_v1';

final userWatchlistProvider = FutureProvider<List<WatchlistItem>>((ref) async {
  final activeId = ref.watch(activeProfileIdProvider);
  if (activeId != null) {
    try {
      final repo = ref.watch(watchlistRepositoryProvider(activeId));
      final items = await repo.getWatchlist();
      if (items.isNotEmpty) return items;
    } catch (_) {}
  }

  // Fallback to local SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_localWatchlistKey);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => WatchlistItem.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});