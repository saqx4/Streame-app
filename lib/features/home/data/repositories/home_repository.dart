import '../models/category.dart';

class HomeRepository {
  // Simplified home repository that will be connected to TMDB and Supabase
  Future<List<Category>> fetchCategories() async {
    // In the full implementation, this will call:
    // 1. TMDB API for trending movies/TV
    // 2. Supabase for user's continue watching
    // 3. Trakt API for sync
    return [];
  }
}