# GEMINI.md - Streame Project Context

## Project Overview
**Streame** is a comprehensive, cross-platform streaming application built with Flutter. It serves as a unified hub for Movies, TV shows, and Anime, offering features like direct torrent streaming, Stremio addon support, and integration with debrid services.

### Key Technologies
- **Framework:** Flutter (Dart)
- **Video Playback:** `media_kit` (MPV-based)
- **Torrent Engine:** `libtorrent_flutter`
- **Metadata:** TMDB (Movies/TV), Simkl/Anilist (Anime)
- **Backend/Services:** `shelf` (Local HTTP server), Real-Debrid, TorBox, Prowlarr/Jackett
- **Platform Support:** Android, Windows, Linux, macOS

### Architecture
- `lib/api/`: Specialized services for external API interactions (TMDB, Stremio, Debrid, etc.).
- `lib/models/`: Core data models (Movie, Episode, TorrentResult, StreamSource).
- `lib/screens/`: Feature-specific UI screens (Player, Discover, Details, Settings).
- `lib/services/`: Core logic for app lifecycle, watched history, and background tasks.
- `lib/widgets/`: Modular UI components (Posters, Banners, Overlays).
- `lib/utils/`: Global themes, extensions, and platform-specific helpers.

## Building and Running
The project follows standard Flutter development workflows.

### Commands
- **Install Dependencies:** `flutter pub get`
- **Development Run:** `flutter run`
- **Build Android (APK):** `flutter build apk`
- **Build Windows:** `flutter build windows`
- **Build Linux:** `flutter build linux`

### Initialization Workflow
The app performs a sequence of critical initializations in `main.dart`:
1.  **Platform Bindings:** `WidgetsFlutterBinding.ensureInitialized()`.
2.  **Desktop Management:** `window_manager` configuration for window size and persistence.
3.  **Media Engine:** `MediaKit.ensureInitialized()`.
4.  **Core Services:** Parallel startup of `TorrentStreamService`, `LocalServerService`, and initial TMDB metadata fetching during the splash screen.

## Development Conventions
- **Linting:** Adheres to `package:flutter_lints/flutter.yaml`. Run `flutter analyze` to verify.
- **Service Pattern:** API services (e.g., `TmdbService`, `SettingsService`) are generally stateless or use internal caching.
- **Error Handling:** Service initialization during boot uses timeouts and catch blocks to prevent app-wide failures if a single service (like the torrent engine) fails to start.
- **Platform Sensitivity:** Always check `Platform.isAndroid` or `Platform.isWindows` before using platform-specific plugins (e.g., `InAppWebView` on Android, `window_manager` on Desktop).
- **State Management:** Uses a mix of `StatefulWidget`, `ValueListenableBuilder`, and service-level state.

### Important Notes for AI Agents
- **Metadata:** When searching for movies or TV shows, prioritize TMDB IDs.
- **Streaming:** Torrent streaming is proxied through a local server (`LocalServerService`) to be compatible with `media_kit`.
- **Cleanup:** Ensure `TorrentStreamService().cleanup()` and `PlayerPoolService().dispose()` are considered when modifying app exit logic.
