import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streame/core/repositories/trakt_repository.dart';

class ContinueWatchingItem {
  final int tmdbId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final int season;
  final int episode;
  final String? episodeTitle;
  final Duration position;
  final Duration totalDuration;
  final DateTime updatedAt;
  final bool dismissed;
  final String? imdbId;
  final bool isUpNext;

  ContinueWatchingItem({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.season = 1,
    this.episode = 1,
    this.episodeTitle,
    this.position = Duration.zero,
    this.totalDuration = Duration.zero,
    DateTime? updatedAt,
    this.dismissed = false,
    this.imdbId,
    this.isUpNext = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  double get progress {
    if (totalDuration.inSeconds == 0) return 0;
    return position.inSeconds / totalDuration.inSeconds;
  }

  ContinueWatchingItem copyWith({
    int? tmdbId,
    String? mediaType,
    String? title,
    String? posterPath,
    String? backdropPath,
    int? season,
    int? episode,
    String? episodeTitle,
    Duration? position,
    Duration? totalDuration,
    DateTime? updatedAt,
    bool? dismissed,
    String? imdbId,
    bool? isUpNext,
  }) =>
      ContinueWatchingItem(
        tmdbId: tmdbId ?? this.tmdbId,
        mediaType: mediaType ?? this.mediaType,
        title: title ?? this.title,
        posterPath: posterPath ?? this.posterPath,
        backdropPath: backdropPath ?? this.backdropPath,
        season: season ?? this.season,
        episode: episode ?? this.episode,
        episodeTitle: episodeTitle ?? this.episodeTitle,
        position: position ?? this.position,
        totalDuration: totalDuration ?? this.totalDuration,
        updatedAt: updatedAt ?? this.updatedAt,
        dismissed: dismissed ?? this.dismissed,
        imdbId: imdbId ?? this.imdbId,
        isUpNext: isUpNext ?? this.isUpNext,
      );

  Map<String, dynamic> toJson() => {
    'tmdb_id': tmdbId,
    'media_type': mediaType,
    'title': title,
    'poster_path': posterPath,
    'backdrop_path': backdropPath,
    'season': season,
    'episode': episode,
    'episode_title': episodeTitle,
    'position_ms': position.inMilliseconds,
    'total_duration_ms': totalDuration.inMilliseconds,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'dismissed': dismissed,
    'imdb_id': imdbId,
    'is_up_next': isUpNext,
  };

  factory ContinueWatchingItem.fromJson(Map<String, dynamic> json) => ContinueWatchingItem(
    tmdbId: json['tmdb_id'] as int,
    mediaType: json['media_type'] as String? ?? 'movie',
    title: json['title'] as String? ?? '',
    posterPath: json['poster_path'] as String?,
    backdropPath: json['backdrop_path'] as String?,
    season: json['season'] as int? ?? 1,
    episode: json['episode'] as int? ?? 1,
    episodeTitle: json['episode_title'] as String?,
    position: Duration(milliseconds: json['position_ms'] as int? ?? 0),
    totalDuration: Duration(milliseconds: json['total_duration_ms'] as int? ?? 0),
    updatedAt: json['updated_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int)
        : null,
    dismissed: json['dismissed'] as bool? ?? false,
    imdbId: json['imdb_id'] as String?,
    isUpNext: json['is_up_next'] as bool? ?? false,
  );
}

class HomeCacheRepository {
  final SharedPreferences _prefs;
  final TraktRepository _traktRepo;
  final String? _profileId;

  static const String _cwKey = 'continue_watching_v1';
  static const int maxItems = 50;

  HomeCacheRepository({
    required SharedPreferences prefs,
    required TraktRepository traktRepo,
    String? profileId,
  })  : _prefs = prefs,
        _traktRepo = traktRepo,
        _profileId = profileId;

  String get _prefKey => '$_cwKey${_profileId != null ? '_$_profileId' : ''}';

  Future<List<ContinueWatchingItem>> getContinueWatching() async {
    // 1. Load local items
    final localItems = await _loadLocal();

    // 2. Merge with Trakt playback progress if linked
    if (_traktRepo.isLinked()) {
      try {
        final traktItems = await _traktRepo.getPlaybackProgress();
        final merged = <String, ContinueWatchingItem>{};

        // Add local items first
        for (final item in localItems) {
          final key = '${item.mediaType}_${item.tmdbId}_${item.season}_${item.episode}';
          merged[key] = item;
        }

        // Add/update from Trakt
        for (final trakt in traktItems) {
          if (trakt.tmdbId == null) continue;
          final tmdbId = int.tryParse(trakt.tmdbId!) ?? 0;
          if (tmdbId == 0) continue;
          final key = '${trakt.mediaType}_${tmdbId}_${trakt.seasonNumber ?? 1}_${trakt.episodeNumber ?? 1}';
          final existing = merged[key];
          if (existing != null) {
            // Keep the one with more recent progress
            if (trakt.progress != null && trakt.progress! > 0) {
              merged[key] = existing.copyWith(
                position: Duration(seconds: (existing.totalDuration.inSeconds * trakt.progress! / 100).round()),
                updatedAt: trakt.lastUpdatedAt,
              );
            }
          } else {
            merged[key] = ContinueWatchingItem(
              tmdbId: tmdbId,
              mediaType: trakt.mediaType ?? 'movie',
              title: trakt.title ?? '',
              season: trakt.seasonNumber ?? 1,
              episode: trakt.episodeNumber ?? 1,
              position: Duration(seconds: ((trakt.progress ?? 0) * 60 / 100).round()),
              updatedAt: trakt.lastUpdatedAt,
              imdbId: trakt.imdbId,
            );
          }
        }

        final result = _dedupAndFilter(merged.values.toList());
        return result.take(maxItems).toList();
      } catch (_) {
        // Fall back to local only
      }
    }

    return _dedupAndFilter(localItems).take(maxItems).toList();
  }

  /// Show-level dedup: for TV shows, keep only the most recent episode per show.
  /// Filter completed items (progress ≥ 90%) that are not "up next".
  /// Filter stale items older than 30 days.
  /// Sort: in-progress items first, then up-next, then by updatedAt.
  List<ContinueWatchingItem> _dedupAndFilter(List<ContinueWatchingItem> items) {
    final now = DateTime.now();
    final staleThreshold = now.subtract(const Duration(days: 30));

    // Filter: remove dismissed, completed (not up-next), and stale
    var filtered = items.where((i) {
      if (i.dismissed) return false;
      if (!i.isUpNext && i.progress >= 0.90) return false;
      if (i.updatedAt.isBefore(staleThreshold)) return false;
      return true;
    }).toList();

    // Show-level dedup for TV: keep only the latest episode per show
    final showBest = <String, ContinueWatchingItem>{};
    for (final item in filtered) {
      if (item.mediaType == 'tv') {
        final showKey = 'tv_${item.tmdbId}';
        final existing = showBest[showKey];
        if (existing == null || item.updatedAt.isAfter(existing.updatedAt)) {
          showBest[showKey] = item;
        }
      }
    }

    // Rebuild list: replace TV items with deduped versions, keep movies as-is
    final result = <ContinueWatchingItem>[];
    final seenShowKeys = <String>{};
    for (final item in filtered) {
      if (item.mediaType == 'tv') {
        final showKey = 'tv_${item.tmdbId}';
        if (!seenShowKeys.contains(showKey)) {
          result.add(showBest[showKey]!);
          seenShowKeys.add(showKey);
        }
      } else {
        result.add(item);
      }
    }

    // Sort: in-progress first, then up-next, then by updatedAt descending
    result.sort((a, b) {
      // In-progress items come before up-next
      final aInProgress = !a.isUpNext && a.progress > 0.03 ? 0 : 1;
      final bInProgress = !b.isUpNext && b.progress > 0.03 ? 0 : 1;
      final progressCmp = aInProgress.compareTo(bInProgress);
      if (progressCmp != 0) return progressCmp;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return result;
  }

  Future<List<ContinueWatchingItem>> _loadLocal() async {
    final raw = _prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final items = list
          .map((e) => ContinueWatchingItem.fromJson(e as Map<String, dynamic>))
          .where((i) => !i.dismissed)
          .toList();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items.take(maxItems).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateContinueWatching(ContinueWatchingItem item) async {
    final items = await _loadLocal();
    final key = '${item.mediaType}_${item.tmdbId}_${item.season}_${item.episode}';
    final idx = items.indexWhere(
      (i) => '${i.mediaType}_${i.tmdbId}_${i.season}_${i.episode}' == key,
    );
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.insert(0, item);
    }
    // Sort and limit
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final trimmed = items.take(maxItems).toList();
    await _prefs.setString(_prefKey, jsonEncode(trimmed.map((i) => i.toJson()).toList()));
  }

  Future<void> dismissContinueWatching(int tmdbId, String mediaType, int season, int episode) async {
    final items = await _loadLocal();
    final idx = items.indexWhere(
      (i) => i.tmdbId == tmdbId && i.mediaType == mediaType && i.season == season && i.episode == episode,
    );
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(dismissed: true);
      await _prefs.setString(_prefKey, jsonEncode(items.map((i) => i.toJson()).toList()));
    }
  }

  /// Remove a completed item from CW (e.g. when progress ≥ 90%).
  Future<void> removeCompleted(int tmdbId, String mediaType, int season, int episode) async {
    final items = await _loadLocal();
    final filtered = items.where(
      (i) => !(i.tmdbId == tmdbId && i.mediaType == mediaType && i.season == season && i.episode == episode),
    ).toList();
    await _prefs.setString(_prefKey, jsonEncode(filtered.map((i) => i.toJson()).toList()));
  }

  /// Add a "next up" entry for the next episode of a TV show.
  Future<void> addUpNext(ContinueWatchingItem item) async {
    final upNext = item.copyWith(isUpNext: true, position: Duration.zero);
    await updateContinueWatching(upNext);
  }
}

final homeCacheRepositoryProvider = Provider<HomeCacheRepository>((ref) {
  throw UnimplementedError('Initialize in main');
});

final continueWatchingProvider = FutureProvider<List<ContinueWatchingItem>>((ref) async {
  final repo = ref.watch(homeCacheRepositoryProvider);
  return repo.getContinueWatching();
});