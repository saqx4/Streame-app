class ApiConstants {
  ApiConstants._();

  // Supabase - from --dart-define or env (real project from Kotlin ARVIO)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://klnjebhrpadyizgevaut.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtsbmplYmhycGFkeWl6Z2V2YXV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MTAxNzMsImV4cCI6MjA4ODM4NjE3M30.OTpfDztmF8E1M2CS13LYq7UI1vFC2vP10PDukSjHfY0',
  );

  // API Base URLs - TMDB and Trakt both go direct (no edge function proxies needed)
  // Trakt client secret stays server-side only if you add a proxy later
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3/';
  static const String traktApiUrl = 'https://api.trakt.tv/';

  // API keys (TMDB is public/rate-limited per IP; Trakt Client ID is public)
  // TRAKT_CLIENT_SECRET must NEVER be in the app - stays in Supabase secrets only
  static const String tmdbApiKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: '3308647fabe47a844ab269e6eab19132',
  );
  static const String traktClientId = String.fromEnvironment(
    'TRAKT_CLIENT_ID',
    defaultValue: '39c2a3c092fd244b5dbcceb8dd0cbd85e61ccf98b2ae0b1158be2c11cfcdb986',
  );

  // Image URLs - tuned for TV quality
  static const String tmdbImageBase = 'https://image.tmdb.org/t/p';
  static const String imageBase = 'https://image.tmdb.org/t/p/w780';
  static const String imageBaseLarge = 'https://image.tmdb.org/t/p/w1280';
  static const String backdropBase = 'https://image.tmdb.org/t/p/w1280';
  static const String backdropBaseLarge = 'https://image.tmdb.org/t/p/original';
  static const String logoBase = 'https://image.tmdb.org/t/p/w500';
  static const String logoBaseLarge = 'https://image.tmdb.org/t/p/original';

  // Image sizes
  static const String posterSize = 'w500';
  static const String backdropSize = 'w1280';
  static const String logoSize = 'w500';

  // Google Sign-In
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
}

class AppConstants {
  AppConstants._();

  static const String appName = 'Streame';
  static const String appVersion = '1.0.0';

  // Progress thresholds (matching Kotlin)
  static const int watchedThreshold = 90;
  static const int minProgressThreshold = 3;
  static const int maxProgressEntries = 50;
  static const int maxContinueWatching = 50;

  // Preference keys
  static const String prefsName = 'Streame_prefs';
  static const String prefDefaultSubtitle = 'default_subtitle';
  static const String prefAutoPlayNext = 'auto_play_next';
  static const String prefTraktToken = 'trakt_token';

  // Cache
  static const int imageCacheMaxAge = 7; // days
  static const int apiCacheMaxAge = 60; // minutes

  // UI
  static const double railHeight = 180.0;
  static const double cardWidth = 210.0;
  static const double cardHeight = 315.0;
  static const int homeRailItemCount = 10;

  // Breakpoints (for responsive UI)
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;
}

/// Language code mappings (matching Kotlin LanguageMap)
class LanguageMap {
  LanguageMap._();

  static const Map<String, String> _isoLangMap = {
    'en': 'English', 'eng': 'English',
    'fr': 'French', 'fre': 'French', 'fra': 'French',
    'es': 'Spanish', 'spa': 'Spanish',
    'de': 'German', 'ger': 'German', 'deu': 'German',
    'it': 'Italian', 'ita': 'Italian',
    'pt': 'Portuguese', 'por': 'Portuguese',
    'nl': 'Dutch', 'nld': 'Dutch', 'dut': 'Dutch',
    'ru': 'Russian', 'rus': 'Russian',
    'zh': 'Chinese', 'chi': 'Chinese', 'zho': 'Chinese',
    'ja': 'Japanese', 'jpn': 'Japanese',
    'ko': 'Korean', 'kor': 'Korean',
    'ar': 'Arabic', 'ara': 'Arabic',
    'hi': 'Hindi', 'hin': 'Hindi',
  };

  static String getLanguageName(String code) {
    return _isoLangMap[code.toLowerCase()] ?? code.toUpperCase();
  }
}