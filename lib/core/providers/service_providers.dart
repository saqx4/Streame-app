import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/settings_service.dart';
import '../../api/torrent_stream_service.dart';
import '../../api/tmdb_api.dart';
import '../../services/player_pool_service.dart';
import '../../services/watch_history_service.dart';
import '../../services/my_list_service.dart';
import '../../api/local_server_service.dart';

// ============================================================================
// Settings Service Provider
// ============================================================================

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

// ============================================================================
// Torrent Stream Service Provider
// ============================================================================

final torrentStreamServiceProvider = Provider<TorrentStreamService>((ref) {
  return TorrentStreamService();
});

// ============================================================================
// Player Pool Service Provider
// ============================================================================

final playerPoolServiceProvider = Provider<PlayerPoolService>((ref) {
  return PlayerPoolService();
});

// ============================================================================
// TMDB API Provider
// ============================================================================

final tmdbApiProvider = Provider<TmdbApi>((ref) {
  return TmdbApi();
});

// ============================================================================
// Watch History Service Provider
// ============================================================================

final watchHistoryServiceProvider = Provider<WatchHistoryService>((ref) {
  return WatchHistoryService();
});

// ============================================================================
// My List Service Provider
// ============================================================================

final myListServiceProvider = Provider<MyListService>((ref) {
  return MyListService();
});

// ============================================================================
// Local Server Service Provider
// ============================================================================

final localServerServiceProvider = Provider<LocalServerService>((ref) {
  return LocalServerService();
});

// ============================================================================
// Async Notifier Providers for Reactive State
// ============================================================================

/// Light mode state
final lightModeProvider = FutureProvider<bool>((ref) async {
  final settings = ref.watch(settingsServiceProvider);
  return await settings.isLightModeEnabled();
});

/// Theme preset state
final themePresetProvider = FutureProvider<String>((ref) async {
  final settings = ref.watch(settingsServiceProvider);
  return await settings.getThemePreset();
});

/// Navbar configuration state
final navbarConfigProvider = FutureProvider<List<String>>((ref) async {
  final settings = ref.watch(settingsServiceProvider);
  return await settings.getNavbarConfig();
});
