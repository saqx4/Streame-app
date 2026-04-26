# Streame — Project Guide for AI

> This document describes the full architecture, structure, patterns, and conventions of the Streame app. It is intended for AI coding assistants to quickly understand the project and make correct changes.

---

## 1. Overview

**Streame** is a cross-platform streaming media app built with Flutter. It lets users discover, browse, and stream movies & TV shows from multiple sources: direct web streams, torrent-based playback (via libtorrent), Stremio addon catalogs, and debrid services (Real-Debrid). It targets **Android, iOS, Windows, Linux, and macOS** from a single codebase.

- **Version:** 2.0.2+21
- **SDK:** Dart ^3.11.0
- **License:** GPL-2.0
- **State Management:** Riverpod (`flutter_riverpod`)
- **Video Playback:** media_kit + media_kit_video (libmpv-based)
- **Torrent Engine:** `libtorrent_flutter` (native libtorrent wrapper)
- **Routing:** Manual `Navigator.push` (no router package)
- **Theme:** Custom dark glassmorphic design system (`AppTheme`)

---

## 2. Project Structure

```
Streame-app/
├── lib/                        ← Main application code (single Flutter package)
│   ├── main.dart                ← App entry point, splash, boot sequence
│   ├── api/                     ← External API clients (all singletons)
│   │   ├── api_keys.dart        ← TMDB_API_KEY, RD_CLIENT_ID (from .env or --dart-define)
│   │   ├── tmdb_api.dart        ← TMDB REST client (trending, popular, details, search)
│   │   ├── tmdb_service.dart    ← TMDB logo-fetch helper
│   │   ├── stremio_service.dart ← Stremio addon manifest/catalog/stream fetching
│   │   ├── trakt_service.dart   ← Trakt.tv OAuth, scrobble, watchlist, history sync
│   │   ├── simkl_service.dart   ← Simkl PIN auth, watchlist, history sync
│   │   ├── debrid_api.dart      ← Real-Debrid OAuth + torrent caching/unrestricting
│   │   ├── mdblist_service.dart ← MDBList lists integration
│   │   ├── introdb_service.dart ← IntroDB skip-times integration
│   │   ├── subtitle_api.dart    ← OpenSubtitles subtitle search/download
│   │   ├── torrent_api.dart    ← Torrent search aggregator
│   │   └── webstreamr_service.dart ← WebStreamr direct stream resolver
│   ├── models/
│   │   ├── movie.dart           ← Movie model (id, title, posterPath, backdropPath, mediaType, etc.)
│   │   ├── season_data.dart     ← SeasonData, Episode, CastMember models
│   │   ├── stream_source.dart   ← StreamSource, StreamResult models
│   │   └── torrent_result.dart  ← TorrentResult model (name, magnet, seeders, size, qualityScore)
│   ├── services/                ← Business logic services (all singletons)
│   │   ├── settings_service.dart       ← User preferences (SharedPreferences + FlutterSecureStorage)
│   │   ├── torrent_stream_service.dart ← libtorrent engine wrapper (start/stream/stats/cleanup)
│   │   ├── player_pool_service.dart    ← Pre-warmed media_kit Player pool
│   │   ├── local_server_service.dart   ← Shelf-based HTTP proxy (CORS bypass, HLS rewrite)
│   │   ├── stream_extractor.dart       ← Headless WebView stream URL extraction
│   │   ├── watch_history_service.dart  ← Watch progress persistence + resume
│   │   ├── episode_watched_service.dart← Episode watch-mark tracking
│   │   ├── my_list_service.dart        ← Bookmark/My List persistence + Trakt/Simkl sync
│   │   ├── external_player_service.dart← Launch VLC/MX Player/mpv/etc. externally
│   │   ├── jackett_service.dart        ← Jackett torrent search API
│   │   ├── prowlarr_service.dart       ← Prowlarr torrent indexer API
│   │   ├── torrent_filter.dart         ← Torrent quality/language filtering & sorting
│   │   ├── link_resolver.dart          ← Resolve shortened URLs to direct links
│   │   ├── app_updater_service.dart    ← GitHub release check + OTA update
│   │   └── android_player_launcher.dart← Android intent-based player launch
│   ├── screens/                ← All UI screens
│   │   ├── main_screen.dart     ← Root scaffold: side rail (desktop) / bottom nav (mobile)
│   │   ├── home_screen.dart     ← Hero banner + content rows (TMDB + Stremio catalogs)
│   │   ├── discover_screen.dart ← Genre/category browsing
│   │   ├── search_screen.dart   ← Search TMDB + Stremio addons
│   │   ├── my_list_screen.dart  ← User's bookmarked items
│   │   ├── details_screen.dart  ← Movie/TV details + stream sources + playback launch
│   │   ├── streaming_details_screen.dart ← Alternative details for direct-stream mode
│   │   ├── player_screen.dart   ← Platform-adaptive player router (mobile vs desktop)
│   │   ├── magnet_player_screen.dart ← Paste magnet → browse files → stream
│   │   ├── stream_extractor_screen.dart ← URL-based stream extraction
│   │   ├── stremio_catalog_screen.dart ← Full Stremio addon catalog browser
│   │   ├── lists_screen.dart    ← Trakt/Simkl/MDBList lists browser
│   │   ├── settings_screen.dart ← Settings hub
│   │   ├── details/             ← Part files for details_screen.dart
│   │   ├── player/             ← Player UI components
│   │   │   ├── mobile_player_screen.dart  ← Touch-optimized player (116K)
│   │   │   ├── simple_desktop_player.dart ← Keyboard/mouse player (108K)
│   │   │   ├── mobile_glass_widgets.dart  ← Mobile glassmorphic controls
│   │   │   ├── desktop_glass_widgets.dart ← Desktop glassmorphic controls
│   │   │   ├── mobile_seekbar.dart        ← Mobile seek bar
│   │   │   ├── desktop_seekbar.dart       ← Desktop seek bar
│   │   │   ├── shared_widgets.dart        ← Shared player widgets
│   │   │   ├── player_design.dart         ← Player design tokens
│   │   │   ├── menus.dart                 ← Player menus (audio, subtitle, speed)
│   │   │   └── widgets/                   ← Player sub-widgets
│   │   ├── settings/            ← Settings sections (each is a widget)
│   │   ├── home/                ← Home screen sub-widgets
│   │   ├── streaming/           ← Streaming details sub-widgets
│   │   ├── search/              ← Search sub-widgets
│   │   ├── discover/           ← Discover sub-widgets
│   │   ├── stremio/            ← Stremio catalog sub-widgets
│   │   └── lists/              ← Lists sub-widgets
│   ├── providers/
│   │   ├── service_providers.dart ← Riverpod providers for all services
│   │   └── stream_services.dart   ← Stream provider URL templates (VidLink, VixSrc, etc.)
│   ├── utils/
│   │   ├── app_theme.dart       ← Design tokens, theme data, glassmorphism helpers
│   │   ├── app_logger.dart      ← Logging setup
│   │   ├── device_detector.dart ← GPU/CPU/RAM detection for player optimization
│   │   ├── extensions.dart      ← Dart extension methods
│   │   ├── lazy_video_loader.dart ← Lazy video preloading for lists
│   │   ├── retry_helper.dart    ← Generic retry with exponential backoff
│   │   ├── service_health_checker.dart ← Service health monitoring
│   │   └── webview_cleanup.dart ← WebView cache cleanup on shutdown
│   ├── widgets/                ← Shared UI widgets
│   │   ├── hero_banner.dart     ← Full-width hero carousel
│   │   ├── movie_poster.dart    ← Poster card with hover/focus effects
│   │   ├── movie_section.dart   ← Horizontal scrollable section
│   │   ├── movie_atmosphere.dart← Background color extraction mixin (AtmosphereMixin)
│   │   ├── glass_card.dart      ← Glassmorphic card container
│   │   ├── side_navbar.dart     ← Side navigation rail
│   │   ├── loading_overlay.dart ← Loading spinner overlay
│   │   ├── error_dialog.dart    ← Error dialog widget
│   │   ├── update_dialog.dart   ← App update dialog
│   │   ├── my_list_button.dart  ← Bookmark toggle button
│   │   ├── optimized_image.dart ← CachedNetworkImage wrapper
│   │   ├── streame_logo.dart    ← Animated app logo
│   │   ├── animated_button.dart ← Animated button with glow
│   │   └── smooth_page_transition.dart ← Page route transition
│   └── error/
│       ├── either.dart          ← Either<L,R> type (Left=failure, Right=success)
│       ├── error_boundary.dart  ← Global Flutter error boundary + ProviderLogger
│       ├── error_handler.dart   ← Error logging utility
│       └── failures.dart       ← Failure hierarchy (Network, Server, Cache, Torrent, Auth, Unknown)
├── android/                    ← Android shell (single-app)
├── ios/                        ← iOS shell
├── windows/                    ← Windows shell
├── assets/icon/                ← App icon
├── installer/                  ← Inno Setup installer scripts
├── .env                        ← Local API keys (gitignored)
├── .env.example                ← Template for .env
├── pubspec.yaml                ← Dependencies
└── pubspec.lock
```

---

## 3. Architecture & Patterns

### 3.1 Singleton Services

Nearly all services and API clients use the **singleton pattern**:

```dart
class SomeService {
  static final SomeService _instance = SomeService._internal();
  factory SomeService() => _instance;
  SomeService._internal();
}
```

This means calling `SomeService()` always returns the same instance. Riverpod providers in `service_providers.dart` simply expose these singletons for testability.

### 3.2 Riverpod Providers

`lib/providers/service_providers.dart` defines `Provider` instances for each singleton service. Widgets should access services via `ref.read(provider)` rather than calling constructors directly.

Key providers:
- `settingsServiceProvider` → `SettingsService`
- `torrentStreamServiceProvider` → `TorrentStreamService`
- `playerPoolServiceProvider` → `PlayerPoolService`
- `tmdbApiProvider` → `TmdbApi`
- `watchHistoryServiceProvider` → `WatchHistoryService`
- `myListServiceProvider` → `MyListService`
- `localServerServiceProvider` → `LocalServerService`

Async state providers:
- `lightModeProvider` — `FutureProvider<bool>`
- `themePresetProvider` — `FutureProvider<String>`
- `navbarConfigProvider` — `FutureProvider<List<String>>`

### 3.3 Part Files Pattern (details_screen.dart)

`details_screen.dart` is a large file split using Dart `part`/`part of`:

```dart
// details_screen.dart
library;
part 'details/details_fetch_methods.dart';
part 'details/details_stream_methods.dart';
part 'details/details_playback_methods.dart';
part 'details/details_ui_info.dart';
part 'details/details_ui_layouts.dart';
part 'details/details_ui_streams.dart';
```

The base class `_DetailsScreenBase` (abstract) holds all shared state and methods. `_DetailsScreenState` extends it and implements platform-adaptive layout selection (mobile vs desktop vs TV).

### 3.4 Platform-Adaptive UI

The app adapts its UI based on screen width and platform:

- **Mobile** (width < 600): Bottom navigation bar (`_FloatingBottomNav`), touch-optimized layouts
- **Desktop** (width >= 600 on Windows/Linux/macOS): Side rail navigation (`_GlassSideRail`), mouse/keyboard layouts
- **TV** (Android + large screen): Leanback-style layouts with D-pad focus navigation

Detection is done per-screen using `MediaQuery` and `Platform` checks. `MainScreen` uses `screenWidth < 600` to decide between side rail and bottom nav.

### 3.5 AtmosphereMixin

`MovieAtmosphere` widget + `AtmosphereMixin` provides dynamic background color extraction from movie posters. Screens that show movie details mix in `AtmosphereMixin` and call `loadAtmosphere(imageUrl)` to extract dominant colors via `PaletteGenerator`.

### 3.6 Error Handling

The app uses a custom `Either<L, R>` type and a `Failure` hierarchy:

- `Failure` (abstract) → `NetworkFailure`, `ServerFailure`, `CacheFailure`, `TorrentFailure`, `AuthFailure`, `UnknownFailure`
- `ErrorBoundary` wraps the entire app and catches Flutter framework errors
- `ProviderLogger` (Riverpod observer) logs provider failures

### 3.7 Glassmorphism Design System

The UI follows a dark glassmorphic design language defined in `AppTheme`:

- **Design tokens:** `AppSpacing`, `AppRadius`, `AppDurations`, `AppElevations`, `AppFontSize`
- **Glass helpers:** `GlassColors` (surface, border, blur values)
- **Shadows:** `AppShadows` (primary glow, medium, etc.)
- **Animation presets:** `AnimationPresets` (smoothInOut, etc.)
- **Theme presets:** Multiple color themes selectable by user (stored in `SettingsService`)

---

## 4. App Boot Sequence

`lib/main.dart` → `main()`:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. Load `.env` file (API keys fallback)
3. Warn if `TMDB_API_KEY` or `RD_CLIENT_ID` missing
4. Configure `InAppWebView` (Android only)
5. Set Android orientation to follow system + immersive sticky UI
6. Desktop: Initialize `window_manager`, restore saved window bounds
7. `MediaKit.ensureInitialized()`
8. `SettingsService().initLightMode()` — hydrate light mode before first frame
9. `AppTheme.initTheme()` — hydrate theme preset
10. `PlayerPoolService().warmUp()` — pre-warm a media_kit player
11. `runApp(ProviderScope(child: ErrorBoundary(child: StreameApp())))`

**Splash Screen** (`_SplashScreenState._initEngine()`):
1. Check connectivity via `Connectivity`
2. If offline → navigate to `MainScreen` (offline mode)
3. Start `TorrentStreamService` (with 10s timeout)
4. Start `LocalServerService` (Shelf HTTP proxy)
5. Initialize `WatchHistoryService`
6. Navigate to `MainScreen` with fade transition

---

## 5. Navigation & Screens

### 5.1 MainScreen

Root scaffold with adaptive navigation:
- **Desktop (w >= 600):** `_GlassSideRail` — collapsible side rail (72px collapsed, 220px expanded on hover)
- **Mobile (w < 600):** `_FloatingBottomNav` — glassmorphic floating bottom bar

Nav items (configurable by user via `SettingsService`):
- **Home** — Hero banner + content rows
- **Discover** — Genre/category browsing
- **Search** — TMDB + Stremio search
- **My List** — Bookmarked items
- **Magnet** — Magnet link player
- **Settings** — Always last

Screens are created once in `initState` and held in `_allScreens` map. `IndexedStack` shows the selected screen.

### 5.2 Screen Descriptions

| Screen | Description |
|--------|-------------|
| `HomeScreen` | Hero carousel (auto-rotating), TMDB rows (trending, popular, top rated, now playing, TV), Stremio catalog rows, Continue Watching, Trakt recommendations |
| `DiscoverScreen` | Genre-based browsing with TMDB discovery API |
| `SearchScreen` | Search TMDB movies/TV + Stremio addon search |
| `MyListScreen` | User's bookmarked movies/shows (persisted locally, synced to Trakt/Simkl) |
| `DetailsScreen` | Full details: poster, synopsis, cast, seasons/episodes, stream sources (torrent, direct, Stremio, debrid), playback launch |
| `StreamingDetailsScreen` | Alternative details for "streaming mode" — uses `StreamExtractor` (WebView) to extract direct stream URLs from provider sites |
| `PlayerScreen` | Routes to `MobilePlayerScreen` or `SimpleDesktopPlayer` based on platform |
| `MagnetPlayerScreen` | Paste magnet link → fetch torrent file list → select file → stream via `TorrentStreamService` |
| `StremioCatalogScreen` | Browse installed Stremio addon catalogs with genre filter, search, pagination |
| `ListsScreen` | Browse Trakt/Simkl/MDBList lists |
| `SettingsScreen` | All settings organized into sections |

### 5.3 Deep Links

The app handles:
- `stremio://` URLs → parsed via `StremioService.parseMetaLink()` → search/detail navigation
- `magnet://` URLs → route to `MagnetPlayerScreen`

---

## 6. Streaming & Playback Flow

### 6.1 Stream Source Types

1. **Direct web streams** — Provider URLs (VidLink, VixSrc, etc.) defined in `StreamProviders.providers`. `StreamExtractor` loads them in a headless WebView, intercepts video URLs, and returns `ExtractedMedia`.

2. **Torrent streams** — Magnet links resolved via `TorrentStreamService` (libtorrent). Files are streamed through a local HTTP server provided by `TorrentStreamService`.

3. **Stremio addon streams** — `StremioService` fetches stream resources from addon URLs. Streams may be direct URLs or require further extraction.

4. **Debrid streams** — `DebridApi` handles Real-Debrid OAuth, uploads magnets, unrestricts cached files, returns direct download URLs.

### 6.2 Playback Launch

`DetailsScreen` → user selects a stream source → `_playStream()` or `_playTorrent()`:
- Creates `PlayerScreen` with stream URL, headers, movie metadata
- `PlayerScreen` checks if external player is configured → launches externally or uses built-in player
- Built-in player: `MobilePlayerScreen` (Android/iOS) or `SimpleDesktopPlayer` (desktop)
- Both players use `media_kit` (Player + VideoController) from `PlayerPoolService`

### 6.3 Local Proxy Server

`LocalServerService` runs a Shelf HTTP server on a random port:
- `/proxy?url=...&headers=...` — CORS bypass proxy for cross-origin streams
- `/hls-proxy?url=...` — HLS-aware proxy that rewrites m3u8 segment URLs
- `/health` — Health check endpoint

### 6.4 Player Pool

`PlayerPoolService` pre-warms a `media_kit` Player + VideoController during app startup. When playback starts, it returns the pre-warmed player (eliminating ~500ms cold-start delay) and replenishes the pool in the background.

---

## 7. Settings & Persistence

### 7.1 SettingsService

Singleton backed by `SharedPreferences` + `FlutterSecureStorage`:

| Category | Keys | Description |
|----------|------|-------------|
| Streaming | `streaming_mode` | Toggle between torrent mode and direct-stream mode |
| Sorting | `sort_preference` | Default torrent sort order |
| Debrid | `use_debrid_for_streams`, `debrid_service` | Enable debrid, select service |
| Stremio | `stremio_addons` | JSON list of installed addon URLs |
| External Player | `external_player` | Selected external player name |
| Jackett | `jackett_base_url`, `jackett_api_key` | Jackett connection |
| Prowlarr | `prowlarr_base_url`, `prowlarr_api_key` | Prowlarr connection |
| Light Mode | `light_mode` | Reduced animations/effects for performance |
| Theme | `theme_preset` | Color theme selection |
| Torrent Cache | `torrent_cache_type`, `torrent_ram_cache_mb` | Cache configuration |
| Subtitles | `sub_size`, `sub_color`, `sub_bg_opacity`, `sub_bold`, `sub_bottom_padding`, `sub_font` | Subtitle appearance |
| Desktop Player | `auto_optimize`, `hw_dec_mode`, `video_sync_mode` | Hardware decode / sync settings |
| Navbar | `navbar_config` | Which nav items are visible + order |

Notifiers for reactive updates:
- `SettingsService.navbarChangeNotifier` — fires when navbar config changes
- `SettingsService.addonChangeNotifier` — fires when Stremio addons change
- `SettingsService.lightModeNotifier` — fires when light mode toggles

### 7.2 Watch History

`WatchHistoryService` persists playback progress in `SharedPreferences`:
- Each entry keyed by `uniqueId` (`tmdbId` for movies, `tmdbId_S{n}_E{e}` for episodes)
- Stores: position, duration, method (stream/torrent/stremio_direct), source, magnet link, stream URL
- Broadcasts changes via `StreamController`
- `Continue Watching` row on HomeScreen reads from this service

### 7.3 My List

`MyListService` persists bookmarked items in `SharedPreferences`:
- Unified shape: `uniqueId`, `tmdbId`, `imdbId`, `title`, `posterPath`, `mediaType`, `source` (tmdb/stremio)
- Syncs with Trakt watchlist and Simkl watchlist (two-way)
- Broadcasts via `StreamController` + `ValueNotifier`

---

## 8. API Integrations

### 8.1 TMDB (`TmdbApi`)

Primary metadata source. API key from `.env` or `--dart-define=TMDB_API_KEY`.

Key methods:
- `getTrending()`, `getPopular()`, `getTopRated()`, `getNowPlaying()`
- `getTrendingTv()`, `getPopularTv()`, `getTopRatedTv()`, `getAiringTodayTv()`
- `getMovieDetails()`, `getTvDetails()`, `getSeasonDetails()`
- `getMovieCredits()`, `getTvCredits()`
- `getSimilarMovies()`, `getSimilarTv()`
- `getMovieImages()`, `getTvImages()` (logos, backdrops)
- `searchMovies()`, `searchTv()`
- Static helpers: `getImageUrl()`, `getBackdropUrl()`, `getProfileUrl()`, `getStillUrl()`

### 8.2 Stremio (`StremioService`)

Addon ecosystem integration:
- `fetchManifest(url)` — fetch and validate addon manifest
- `getCatalogItems(addonUrl, catalogId, genre, skip)` — paginated catalog browsing
- `getStreamItems(addonUrl, itemId, type)` — fetch available streams for an item
- `parseMetaLink(url)` — parse `stremio://` deep links
- Addon management: install/remove/list addons (stored in `SettingsService`)

### 8.3 Trakt (`TraktService`)

Full Trakt.tv integration:
- OAuth device-code flow (client ID/secret from secure storage or `--dart-define`)
- Watchlist sync, scrobble, playback progress import/export
- Calendar, recommendations, trending

### 8.4 Simkl (`SimklService`)

Full Simkl integration:
- PIN-based auth
- Watchlist sync, history, ratings

### 8.5 Real-Debrid (`DebridApi`)

OAuth device-code flow + torrent operations:
- `startRDLogin()` / `pollRDCredentials()` — OAuth flow
- `checkCachedMagnet()` — check if magnet is cached on RD
- `unrestrictLink()` — get direct download URL
- `getTorrentFiles()` — list files in a RD torrent

### 8.6 Other APIs

- **MDBList** (`mdblist_service.dart`) — List aggregation
- **IntroDB** (`introdb_service.dart`) — Skip intro timestamps
- **OpenSubtitles** (`subtitle_api.dart`) — Subtitle search/download
- **Jackett** (`jackett_service.dart`) — Self-hosted torrent indexer
- **Prowlarr** (`prowlarr_service.dart`) — Self-hosted torrent indexer (Servarr)
- **WebStreamr** (`webstreamr_service.dart`) — Direct stream resolver

---

## 9. Key Conventions

### 9.1 Code Style

- **Singleton pattern** for all services/APIs (factory constructor returning static instance)
- **Riverpod** for dependency injection and reactive state
- **Part files** for splitting large screen files (e.g., `details_screen.dart` + `details/*.dart`)
- **Private classes** with underscore prefix (e.g., `_DetailsScreenState`, `_GlassSideRail`)
- **Design tokens** as static constants in dedicated classes (`AppSpacing`, `AppRadius`, etc.)
- **Glassmorphism** via `BackdropFilter` + `GlassColors` constants throughout the UI
- **Logging** via `app_logger.dart` (`log.info()`, `log.warning()`, etc.)

### 9.2 Import Paths

Internal imports use relative paths from the importing file:
```dart
import '../api/tmdb_api.dart';
import '../services/settings_service.dart';
import '../models/movie.dart';
```

Package imports use `package:streame/...` only for cross-package references (e.g., in `player_screen.dart`).

### 9.3 Image URLs

TMDB image paths are relative (e.g., `/abc123.jpg`). Always prefix with the appropriate base URL:
- Posters: `TmdbApi.getImageUrl(path)` → `https://image.tmdb.org/t/p/w500`
- Backdrops: `TmdbApi.getBackdropUrl(path)` → `https://image.tmdb.org/t/p/w1280`
- Cast: `TmdbApi.getProfileUrl(path)` → `https://image.tmdb.org/t/p/w185`
- Stills: `TmdbApi.getStillUrl(path)` → `https://image.tmdb.org/t/p/w300`

### 9.4 API Key Management

Keys are resolved in this order:
1. `.env` file (loaded via `flutter_dotenv` at startup)
2. `--dart-define` compile-time constants
3. Empty string (feature degrades gracefully with logged warning)

Required keys:
- `TMDB_API_KEY` — mandatory for metadata lookups
- `RD_CLIENT_ID` — required for Real-Debrid login
- `TRAKT_CLIENT_ID` / `TRAKT_CLIENT_SECRET` — for Trakt (can be set in settings UI at runtime)
- `SIMKL_CLIENT_ID` / `SIMKL_CLIENT_SECRET` — for Simkl (can be set in settings UI at runtime)

---

## 10. Build & Run

### Development

```bash
# Run with API keys
flutter run --dart-define=TMDB_API_KEY=xxx --dart-define=RD_CLIENT_ID=xxx

# Or create .env file
cp .env.example .env
# Edit .env with your keys
flutter run
```

### Release Builds

```bash
# Android APK
flutter build apk --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

### Windows Installer

Built with Inno Setup. Run `ISCC.exe` with the installer script. Output goes to `installer/windows/Output/`.

---

## 11. Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management + DI |
| `media_kit` / `media_kit_video` | Video playback (libmpv) |
| `libtorrent_flutter` | Native torrent streaming |
| `window_manager` | Desktop window control |
| `flutter_inappwebview` | WebView for stream extraction |
| `cached_network_image` | Image caching |
| `shelf` / `shelf_router` | Local HTTP proxy server |
| `shared_preferences` | Key-value persistence |
| `flutter_secure_storage` | Encrypted storage (tokens) |
| `google_fonts` | Poppins font |
| `shimmer` | Loading placeholders |
| `palette_generator` | Color extraction for atmosphere |
| `connectivity_plus` | Network status detection |
| `url_launcher` | Open external URLs |
| `app_links` | Deep link handling |
| `flutter_dotenv` | .env file loading |
| `youtube_explode_dart` | YouTube stream extraction |
| `ota_update` | Android OTA updates |
| `package_info_plus` | App version info |

---

## 12. Common Tasks Quick Reference

### Adding a new screen
1. Create `lib/screens/new_screen.dart`
2. Add to `_allScreens` map in `main_screen.dart`
3. Add nav metadata to `_navMeta` in `main_screen.dart`
4. Add to `SettingsService.allNavIds` and navbar config

### Adding a new API integration
1. Create `lib/api/new_service.dart` as a singleton
2. Add provider in `lib/providers/service_providers.dart`
3. Add settings keys in `lib/services/settings_service.dart`
4. Add settings UI section in `lib/screens/settings/`

### Adding a new stream provider
1. Add provider definition to `StreamProviders.providers` in `lib/providers/stream_services.dart`
2. It will automatically appear in `StreamingDetailsScreen`'s source picker

### Modifying the details screen
- Shared logic → `details_screen.dart` base class or `details/details_fetch_methods.dart`
- Stream fetching → `details/details_stream_methods.dart`
- Playback logic → `details/details_playback_methods.dart`
- UI info sections → `details/details_ui_info.dart`
- UI layout → `details/details_ui_layouts.dart`
- Stream tiles UI → `details/details_ui_streams.dart`

### Modifying player UI
- Mobile player → `screens/player/mobile_player_screen.dart`
- Desktop player → `screens/player/simple_desktop_player.dart`
- Shared widgets → `screens/player/shared_widgets.dart`
- Design tokens → `screens/player/player_design.dart`
