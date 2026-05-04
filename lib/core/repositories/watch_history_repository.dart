// Local Watch History Repository
// Uses SharedPreferences + Trakt for cloud sync
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streame/core/repositories/trakt_repository.dart';
import 'package:streame/core/providers/shared_providers.dart';

class WatchHistoryEntry {
  final int tmdbId;
  final String mediaType;
  final String? title;
  final String? posterPath;
  final String? backdropPath;
  final String? imdbId;
  final int season;
  final int episode;
  final double progress; // 0.0-1.0
  final int positionSeconds;
  final int durationSeconds;
  final DateTime updatedAt;

  WatchHistoryEntry({
    required this.tmdbId,
    required this.mediaType,
    this.title,
    this.posterPath,
    this.backdropPath,
    this.imdbId,
    this.season = 0,
    this.episode = 0,
    this.progress = 0,
    this.positionSeconds = 0,
    this.durationSeconds = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  bool get isContinueWatching => progress > 0.03 && progress < 0.95;

  Map<String, dynamic> toJson() => {
    'tmdb_id': tmdbId,
    'media_type': mediaType,
    'title': title,
    'poster_path': posterPath,
    'backdrop_path': backdropPath,
    'imdb_id': imdbId,
    'season': season,
    'episode': episode,
    'progress': progress,
    'position_seconds': positionSeconds,
    'duration_seconds': durationSeconds,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory WatchHistoryEntry.fromJson(Map<String, dynamic> json) => WatchHistoryEntry(
    tmdbId: json['tmdb_id'] as int? ?? 0,
    mediaType: json['media_type'] as String? ?? 'movie',
    title: json['title'] as String?,
    posterPath: json['poster_path'] as String?,
    backdropPath: json['backdrop_path'] as String?,
    imdbId: json['imdb_id'] as String?,
    season: json['season'] as int? ?? 0,
    episode: json['episode'] as int? ?? 0,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    positionSeconds: json['position_seconds'] as int? ?? 0,
    durationSeconds: json['duration_seconds'] as int? ?? 0,
    updatedAt: json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
        : null,
  );
}

class WatchHistoryRepository {
  final SharedPreferences _prefs;
  final TraktRepository? _traktRepo;
  final String _profileId;

  static const String _localKey = 'watch_history_local_v1';
  static const int maxEntries = 50;

  WatchHistoryRepository({
    required SharedPreferences prefs,
    required String profileId,
    TraktRepository? traktRepo,
  })  : _prefs = prefs,
        _profileId = profileId,
        _traktRepo = traktRepo;

  String get _prefKey => '${_localKey}_$_profileId';

  // ─── Continue Watching ───

  Future<List<WatchHistoryEntry>> getContinueWatching() async {
    // Load local first
    final local = await _loadLocal();

    // Merge with Trakt playback progress if linked
    if (_traktRepo != null && _traktRepo.isLinked()) {
      try {
        final traktItems = await _traktRepo.getPlaybackProgress();
        final merged = <String, WatchHistoryEntry>{};

        for (final item in local) {
          final key = '${item.mediaType}_${item.tmdbId}_${item.season}_${item.episode}';
          merged[key] = item;
        }

        for (final trakt in traktItems) {
          if (trakt.tmdbId == null) continue;
          final tmdbId = int.tryParse(trakt.tmdbId!) ?? 0;
          if (tmdbId == 0) continue;
          final key = '${trakt.mediaType}_${tmdbId}_${trakt.seasonNumber ?? 1}_${trakt.episodeNumber ?? 1}';
          final existing = merged[key];
          if (existing != null) {
            if (trakt.progress != null && trakt.progress! > 0) {
              merged[key] = WatchHistoryEntry(
                tmdbId: existing.tmdbId,
                mediaType: existing.mediaType,
                title: existing.title ?? trakt.title,
                posterPath: existing.posterPath,
                backdropPath: existing.backdropPath,
                imdbId: existing.imdbId ?? trakt.imdbId,
                season: existing.season,
                episode: existing.episode,
                progress: trakt.progress! / 100.0,
                positionSeconds: (existing.durationSeconds * trakt.progress! / 100).round(),
                durationSeconds: existing.durationSeconds,
                updatedAt: trakt.lastUpdatedAt,
              );
            }
          } else {
            final progress = (trakt.progress ?? 0) / 100.0;
            if (progress > 0.03 && progress < 0.95) {
              merged[key] = WatchHistoryEntry(
                tmdbId: tmdbId,
                mediaType: trakt.mediaType ?? 'movie',
                title: trakt.title,
                imdbId: trakt.imdbId,
                season: trakt.seasonNumber ?? 1,
                episode: trakt.episodeNumber ?? 1,
                progress: progress,
                updatedAt: trakt.lastUpdatedAt,
              );
            }
          }
        }

        final result = merged.values.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return result.take(maxEntries).toList();
      } catch (e) {
        debugPrint('Trakt CW merge failed, using local cache: $e');
      }
    }

    return local;
  }

  // ─── Update progress ───

  Future<void> updateProgress(WatchHistoryEntry entry) async {
    // Update local immediately
    final items = await _loadLocal();
    final key = '${entry.mediaType}_${entry.tmdbId}_${entry.season}_${entry.episode}';
    final idx = items.indexWhere(
      (i) => '${i.mediaType}_${i.tmdbId}_${i.season}_${i.episode}' == key,
    );
    if (idx >= 0) {
      items[idx] = entry;
    } else {
      items.insert(0, entry);
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _saveLocal(items.take(maxEntries).toList());

    // Push to Trakt if linked
    if (_traktRepo != null && _traktRepo.isLinked() && entry.imdbId != null) {
      try {
        await _traktRepo.addToHistory(
          imdbId: entry.imdbId!,
          mediaType: entry.mediaType,
          season: entry.season > 0 ? entry.season : null,
          episode: entry.episode > 0 ? entry.episode : null,
        );
      } catch (e) {
        debugPrint('Trakt progress update failed: $e');
      }
    }
  }

  // ─── Dismiss from Continue Watching ───

  Future<void> dismiss(int tmdbId, String mediaType, {int? season, int? episode}) async {
    // Local
    final items = await _loadLocal();
    items.removeWhere((i) =>
        i.tmdbId == tmdbId && i.mediaType == mediaType &&
        (season == null || i.season == season) &&
        (episode == null || i.episode == episode));
    await _saveLocal(items);

    // No Trakt dismiss needed — local only for dismiss
  }

  // ─── Local storage ───

  Future<List<WatchHistoryEntry>> _loadLocal() async {
    final raw = _prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final entries = list
          .map((e) => WatchHistoryEntry.fromJson(e as Map<String, dynamic>))
          .where((e) => e.isContinueWatching)
          .toList();
      entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return entries.take(maxEntries).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocal(Iterable<WatchHistoryEntry> entries) async {
    final json = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _prefs.setString(_prefKey, json);
  }
}

final watchHistoryRepositoryProvider = Provider.family<WatchHistoryRepository, String>((ref, profileId) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return WatchHistoryRepository(
    prefs: prefs,
    profileId: profileId,
  );
});

final continueWatchingEntriesProvider = FutureProvider.family<List<WatchHistoryEntry>, String>((ref, profileId) async {
  final repo = ref.watch(watchHistoryRepositoryProvider(profileId));
  return repo.getContinueWatching();
});
