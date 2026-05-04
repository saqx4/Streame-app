import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';
import 'core/constants/api_constants.dart';
import 'core/repositories/tmdb_repository.dart';
import 'core/repositories/trakt_repository.dart';
import 'core/repositories/profile_repository.dart';
import 'core/repositories/auth_repository_simple.dart';
import 'core/repositories/home_cache_repository.dart';
import 'core/repositories/watchlist_repository.dart';
import 'core/repositories/addon_repository.dart';
import 'core/repositories/catalog_repository.dart';
import 'core/services/torrent_stream_service.dart';
import 'core/providers/shared_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit native engine (libmpv) — may fail on some emulators
  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    debugPrint('MediaKit init failed: $e — video playback may not work');
  }

  // Initialize torrent engine (libtorrent_flutter) — non-blocking, lazy start on first use
  try {
    TorrentStreamService().start();
  } catch (e) {
    debugPrint('Torrent engine init failed: $e — torrent streaming may not work');
  }

  final prefs = await SharedPreferences.getInstance();
  final traktRepo = TraktRepository(prefs: prefs);

  runApp(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        AuthRepository(prefs),
      ),
      sharedPreferencesProvider.overrideWithValue(prefs),
      tmdbRepositoryProvider.overrideWithValue(
        TmdbRepositoryImpl(apiKey: ApiConstants.tmdbApiKey),
      ),
      profileRepositoryProvider.overrideWithValue(
        ProfileRepository(prefs: prefs),
      ),
      traktRepositoryProvider.overrideWithValue(traktRepo),
      homeCacheRepositoryProvider.overrideWithValue(
        HomeCacheRepository(prefs: prefs, traktRepo: traktRepo),
      ),
      watchlistRepositoryProvider.overrideWith((ref, profileId) =>
        WatchlistRepository(prefs: prefs, profileId: profileId, traktRepo: traktRepo),
      ),
      addonRepositoryProvider.overrideWith((ref, profileId) =>
        AddonRepository(prefs: prefs, profileId: profileId),
      ),
      addonManagerProvider.overrideWith((ref, profileId) =>
        AddonManagerRepository(
          prefs: prefs,
          profileId: profileId,
          addonRepo: ref.watch(addonRepositoryProvider(profileId)),
        ),
      ),
      catalogRepositoryProvider.overrideWith((ref, profileId) =>
        CatalogRepository(prefs: prefs, profileId: profileId),
      ),
      // Non-family alias used by player screen — reads active profile's manager
      addonManagerRepositoryProvider.overrideWith((ref) {
        final profileId = ref.watch(activeProfileIdProvider);
        if (profileId == null) throw StateError('No active profile');
        return ref.watch(addonManagerProvider(profileId));
      }),
    ],
    child: const StreameApp(),
  ));
}

class StreameApp extends ConsumerWidget {
  const StreameApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Streame',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}