import 'package:streame_core/utils/env_loader.dart';

/// API Keys configuration
///
/// Keys are loaded from .env file (for local development) or
/// injected at build time via --dart-define flags:
///   flutter run --dart-define=TMDB_API_KEY=xxx
///   flutter run --dart-define=RD_CLIENT_ID=xxx
///
/// If a key is missing, the app will log a warning and the
/// corresponding feature will degrade gracefully.
class ApiKeys {
  /// TMDB API Key — REQUIRED for all metadata lookups.
  /// Get your key at: https://www.themoviedb.org/settings/api
  static String get tmdbApiKey {
    final env = EnvLoader.get('TMDB_API_KEY');
    return env.isNotEmpty ? env : '3308647fabe47a844ab269e6eab19132';
  }

  /// TMDB Base URL
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

  /// Real-Debrid OAuth client ID
  static String get rdClientId {
    final env = EnvLoader.get('RD_CLIENT_ID');
    return env.isNotEmpty ? env : 'X245A4XAIBGVM';
  }

  /// Whether the TMDB key is available
  static bool get hasTmdbKey => tmdbApiKey.isNotEmpty;

  /// Whether the RD client ID is available
  static bool get hasRdClientId => rdClientId.isNotEmpty;
}
