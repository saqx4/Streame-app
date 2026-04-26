import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../services/torrent_stream_service.dart';
import '../api/tmdb_api.dart';
import '../api/torrent_api.dart';
import '../api/stremio_service.dart';
import '../api/trakt_service.dart';
import '../api/simkl_service.dart';
import '../api/debrid_api.dart';
import '../api/mdblist_service.dart';
import '../services/player_pool_service.dart';
import '../services/watch_history_service.dart';
import '../services/my_list_service.dart';
import '../services/local_server_service.dart';
import '../services/jackett_service.dart';
import '../services/prowlarr_service.dart';
import '../services/link_resolver.dart';
import '../services/episode_watched_service.dart';
import '../services/external_player_service.dart';

// ============================================================================
// Service Providers
//
// All singleton services use factory constructors, so calling the constructor
// always returns the same instance. These providers simply expose that
// singleton through Riverpod for testability and lifecycle management.
//
// IMPORTANT: Always access services via `ref.read(provider)` in widgets
// instead of calling the constructor directly (e.g. `SettingsService()`).
// This ensures Riverpod can track dependencies and swap implementations
// during testing.
// ============================================================================

// Settings Service Provider

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

// ============================================================================
// Additional Service Providers
// ============================================================================

final torrentApiProvider = Provider<TorrentApi>((ref) {
  return TorrentApi();
});

final stremioServiceProvider = Provider<StremioService>((ref) {
  return StremioService();
});

final traktServiceProvider = Provider<TraktService>((ref) {
  return TraktService();
});

final simklServiceProvider = Provider<SimklService>((ref) {
  return SimklService();
});

final debridApiProvider = Provider<DebridApi>((ref) {
  return DebridApi();
});

final mdblistServiceProvider = Provider<MdblistService>((ref) {
  return MdblistService();
});

final jackettServiceProvider = Provider<JackettService>((ref) {
  return JackettService();
});

final prowlarrServiceProvider = Provider<ProwlarrService>((ref) {
  return ProwlarrService();
});

final linkResolverProvider = Provider<LinkResolver>((ref) {
  return LinkResolver();
});

final episodeWatchedServiceProvider = Provider<EpisodeWatchedService>((ref) {
  return EpisodeWatchedService();
});

final externalPlayerServiceProvider = Provider<ExternalPlayerService>((ref) {
  return ExternalPlayerService();
});
