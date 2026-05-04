import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streame/features/profile/presentation/profile_selection_screen.dart';
import 'package:streame/features/home/presentation/home_screen.dart';
import 'package:streame/features/search/presentation/search_screen.dart';
import 'package:streame/features/watchlist/presentation/watchlist_screen.dart';
import 'package:streame/features/settings/presentation/settings_screen.dart';
import 'package:streame/features/details/presentation/details_screen.dart';
import 'package:streame/features/player/presentation/player_screen.dart';
import 'package:streame/features/collections/presentation/collection_details_screen.dart';
import 'package:streame/shared/widgets/app_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/profile-select',
    routes: [
      GoRoute(
        path: '/profile-select',
        name: 'profile-select',
        builder: (context, state) => const ProfileSelectionScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/watchlist',
            name: 'watchlist',
            builder: (context, state) => const WatchlistScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) {
              final autoCloudAuth = state.uri.queryParameters['autoCloudAuth'];
              return SettingsScreen(autoCloudAuth: autoCloudAuth == 'true');
            },
          ),
        ],
      ),
      // Full-screen routes (outside ShellRoute — no bottom nav)
      GoRoute(
        path: '/details/:mediaType/:mediaId',
        name: 'details',
        builder: (context, state) {
          final mediaType = state.pathParameters['mediaType']!;
          final mediaId = int.tryParse(state.pathParameters['mediaId'] ?? '') ?? 0;
          final initialSeason = state.uri.queryParameters['initialSeason'];
          final initialEpisode = state.uri.queryParameters['initialEpisode'];
          return DetailsScreen(
            mediaType: mediaType,
            mediaId: mediaId,
            initialSeason: initialSeason != null ? int.tryParse(initialSeason) : null,
            initialEpisode: initialEpisode != null ? int.tryParse(initialEpisode) : null,
          );
        },
      ),
      GoRoute(
        path: '/collections/:catalogId',
        name: 'collection',
        builder: (context, state) {
          final catalogId = state.pathParameters['catalogId']!;
          return CollectionDetailsScreen(catalogId: catalogId);
        },
      ),
      GoRoute(
        path: '/player/:mediaType/:mediaId',
        name: 'player',
        builder: (context, state) {
          final mediaType = state.pathParameters['mediaType']!;
          final mediaId = int.tryParse(state.pathParameters['mediaId'] ?? '') ?? 0;
          final params = state.uri.queryParameters;
          return PlayerScreen(
            mediaType: mediaType,
            mediaId: mediaId,
            seasonNumber: params['seasonNumber'] != null ? int.tryParse(params['seasonNumber']!) : null,
            episodeNumber: params['episodeNumber'] != null ? int.tryParse(params['episodeNumber']!) : null,
            imdbId: params['imdbId'],
            streamUrl: params['streamUrl'],
            preferredAddonId: params['preferredAddonId'],
            preferredSourceName: params['preferredSourceName'],
            preferredBingeGroup: params['preferredBingeGroup'],
            startPositionMs: params['startPositionMs'] != null ? int.tryParse(params['startPositionMs']!) : null,
          );
        },
      ),
    ],
  );
});