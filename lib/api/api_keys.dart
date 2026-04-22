/// API Keys configuration
/// 
/// NOTE: In production, these should be loaded from environment variables
/// or a secure storage mechanism. For development purposes, they are defined here.
/// 
/// To use environment variables in production:
/// 1. Create a .env file in your project root
/// 2. Add: TMDB_API_KEY=your_key_here
/// 3. Use flutter_dotenv package to load it
class ApiKeys {
  /// TMDB API Key
  /// Get your key at: https://www.themoviedb.org/settings/api
  static const String tmdbApiKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: '3308647fabe47a844ab269e6eab19132',
  );

  /// TMDB Base URL
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
}
