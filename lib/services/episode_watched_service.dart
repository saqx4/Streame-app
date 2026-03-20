import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight service to track which episodes the user has manually
/// marked as "done watching". Persisted via SharedPreferences so the
/// state is shared across *all* detail screens (torrent & streaming).
class EpisodeWatchedService {
  static final EpisodeWatchedService _instance = EpisodeWatchedService._();
  factory EpisodeWatchedService() => _instance;
  EpisodeWatchedService._();

  static const String _key = 'episodes_watched';

  // In-memory cache: "tmdbId_S{season}_E{episode}" → true
  Map<String, bool>? _cache;

  Future<Map<String, bool>> _load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _cache = decoded.map((k, v) => MapEntry(k, v == true));
    } else {
      _cache = {};
    }
    return _cache!;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(_cache));
  }

  String _id(int tmdbId, int season, int episode) =>
      '${tmdbId}_S${season}_E$episode';

  Future<bool> isWatched(int tmdbId, int season, int episode) async {
    final map = await _load();
    return map[_id(tmdbId, season, episode)] == true;
  }

  Future<Set<String>> getWatchedSet(int tmdbId) async {
    final map = await _load();
    return map.keys.where((k) => k.startsWith('${tmdbId}_') && map[k] == true).toSet();
  }

  Future<void> toggle(int tmdbId, int season, int episode) async {
    final map = await _load();
    final id = _id(tmdbId, season, episode);
    final current = map[id] == true;
    map[id] = !current;
    await _save();
    debugPrint('[EpisodeWatched] ${!current ? "Marked" : "Unmarked"} $id');
  }

  Future<void> setWatched(int tmdbId, int season, int episode, bool watched) async {
    final map = await _load();
    final id = _id(tmdbId, season, episode);
    map[id] = watched;
    await _save();
  }
}
