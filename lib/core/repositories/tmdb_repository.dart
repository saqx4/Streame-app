import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:streame/features/home/data/models/media_item.dart';

abstract class TmdbRepository {
  Future<List<MediaItem>> getTrendingMovies({int page = 1});
  Future<List<MediaItem>> getTrendingTv({int page = 1});
  Future<List<MediaItem>> getTrendingAll({int page = 1});
  Future<List<MediaItem>> getTopRatedMovies({int page = 1});
  Future<List<MediaItem>> getPopularTv({int page = 1});
  Future<List<MediaItem>> discoverMovies({String? sortBy, int? genreId, int? year, String? region, int page = 1});
  Future<List<MediaItem>> discoverTv({String? sortBy, int? genreId, int? year, String? region, int page = 1});
  Future<MediaItem?> getMovieDetails(int tmdbId);
  Future<MediaItem?> getTvDetails(int tmdbId);
  Future<Map<String, dynamic>?> getMovieCredits(int tmdbId);
  Future<Map<String, dynamic>?> getTvCredits(int tmdbId);
  Future<Map<String, dynamic>?> getMovieExternalIds(int tmdbId);
  Future<Map<String, dynamic>?> getTvExternalIds(int tmdbId);
  Future<Map<String, dynamic>?> getSeasonDetails(int tvId, int seasonNumber);
  Future<List<Map<String, dynamic>>> getTvSeasonsList(int tvId);
  Future<List<MediaItem>> search(String query, {MediaType? mediaType, int page = 1});
  Future<List<MediaItem>> getSimilar(int tmdbId, {required MediaType mediaType, int page = 1});
  Future<String?> getLogoPath(int tmdbId, {required MediaType mediaType});
  Future<List<String>> getGenreNames(int tmdbId, {required MediaType mediaType});
  String getPosterUrl(String? path, {String size = 'w500'});
  String getBackdropUrl(String? path, {String size = 'w1280'});
  String getLogoUrl(String? path, {String size = 'w500'});
}

class TmdbRepositoryImpl implements TmdbRepository {
  final String _apiKey;
  final String _baseUrl;
  final String _imageBase;
  final http.Client _httpClient;

  TmdbRepositoryImpl({
    required String apiKey,
    String baseUrl = 'https://api.themoviedb.org/3/',
    String imageBase = 'https://image.tmdb.org/t/p',
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl,
        _imageBase = imageBase,
        _httpClient = httpClient ?? http.Client();

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_apiKey',
    'Accept': 'application/json',
  };

  Future<dynamic> _get(String path) async {
    final sep = path.contains('?') ? '&' : '?';
    final uri = Uri.parse('$_baseUrl${path}${sep}api_key=$_apiKey');
    try {
      final response = await _httpClient.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  List<MediaItem> _parseResults(dynamic data, MediaType type) {
    if (data == null) return [];
    final results = data['results'] as List<dynamic>? ?? [];
    return results.map((r) => MediaItem.fromJson({
      ...r as Map<String, dynamic>,
      'media_type': type == MediaType.tv ? 'tv' : 'movie',
    })).toList();
  }

  @override
  Future<List<MediaItem>> getTrendingMovies({int page = 1}) async {
    final data = await _get('trending/movie/week?page=$page');
    return _parseResults(data, MediaType.movie);
  }

  @override
  Future<List<MediaItem>> getTrendingTv({int page = 1}) async {
    final data = await _get('trending/tv/week?page=$page');
    return _parseResults(data, MediaType.tv);
  }

  @override
  Future<List<MediaItem>> getTrendingAll({int page = 1}) async {
    final data = await _get('trending/all/week?page=$page');
    if (data == null) return [];
    final results = data['results'] as List<dynamic>? ?? [];
    return results.map((r) {
      final map = r as Map<String, dynamic>;
      final mt = (map['media_type'] as String?) == 'tv' ? MediaType.tv : MediaType.movie;
      return MediaItem.fromJson({...map, 'media_type': mt == MediaType.tv ? 'tv' : 'movie'});
    }).toList();
  }

  @override
  Future<List<MediaItem>> getTopRatedMovies({int page = 1}) async {
    final data = await _get('movie/top_rated?page=$page');
    return _parseResults(data, MediaType.movie);
  }

  @override
  Future<List<MediaItem>> getPopularTv({int page = 1}) async {
    final data = await _get('tv/popular?page=$page');
    return _parseResults(data, MediaType.tv);
  }

  @override
  Future<List<MediaItem>> discoverMovies({String? sortBy, int? genreId, int? year, String? region, int page = 1}) async {
    var path = 'discover/movie?page=$page';
    if (sortBy != null) path += '&sort_by=$sortBy';
    if (genreId != null) path += '&with_genres=$genreId';
    if (year != null) path += '&primary_release_year=$year';
    if (region != null) path += '&region=$region';
    final data = await _get(path);
    return _parseResults(data, MediaType.movie);
  }

  @override
  Future<List<MediaItem>> discoverTv({String? sortBy, int? genreId, int? year, String? region, int page = 1}) async {
    var path = 'discover/tv?page=$page';
    if (sortBy != null) path += '&sort_by=$sortBy';
    if (genreId != null) path += '&with_genres=$genreId';
    if (year != null) path += '&first_air_date_year=$year';
    if (region != null) path += '&watch_region=$region';
    final data = await _get(path);
    return _parseResults(data, MediaType.tv);
  }

  @override
  Future<MediaItem?> getMovieDetails(int tmdbId) async {
    final data = await _get('movie/$tmdbId');
    if (data == null) return null;
    return MediaItem.fromJson({...data, 'media_type': 'movie'});
  }

  @override
  Future<MediaItem?> getTvDetails(int tmdbId) async {
    final data = await _get('tv/$tmdbId');
    if (data == null) return null;
    return MediaItem.fromJson({...data, 'media_type': 'tv'});
  }

  @override
  Future<Map<String, dynamic>?> getMovieCredits(int tmdbId) async {
    return await _get('movie/$tmdbId/credits');
  }

  @override
  Future<Map<String, dynamic>?> getTvCredits(int tmdbId) async {
    return await _get('tv/$tmdbId/credits');
  }

  @override
  Future<Map<String, dynamic>?> getMovieExternalIds(int tmdbId) async {
    return await _get('movie/$tmdbId/external_ids');
  }

  @override
  Future<Map<String, dynamic>?> getTvExternalIds(int tmdbId) async {
    return await _get('tv/$tmdbId/external_ids');
  }

  @override
  Future<Map<String, dynamic>?> getSeasonDetails(int tvId, int seasonNumber) async {
    return await _get('tv/$tvId/season/$seasonNumber');
  }

  @override
  Future<List<Map<String, dynamic>>> getTvSeasonsList(int tvId) async {
    final data = await _get('tv/$tvId');
    if (data == null) return [];
    final seasons = data['seasons'] as List<dynamic>? ?? [];
    return seasons.where((s) {
      final sn = (s as Map<String, dynamic>)['season_number'] as int? ?? 0;
      return sn > 0; // Exclude specials (season 0)
    }).map((s) => s as Map<String, dynamic>).toList();
  }

  @override
  Future<List<MediaItem>> search(String query, {MediaType? mediaType, int page = 1}) async {
    final encoded = Uri.encodeComponent(query);
    if (mediaType == MediaType.movie) {
      final data = await _get('search/movie?query=$encoded&page=$page');
      return _parseResults(data, MediaType.movie);
    }
    if (mediaType == MediaType.tv) {
      final data = await _get('search/tv?query=$encoded&page=$page');
      return _parseResults(data, MediaType.tv);
    }
    // Multi search
    final data = await _get('search/multi?query=$encoded&page=$page');
    if (data == null) return [];
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .where((r) {
          final mt = r['media_type'] as String?;
          return mt == 'movie' || mt == 'tv';
        })
        .map((r) {
          final map = r as Map<String, dynamic>;
          return MediaItem.fromJson(map);
        })
        .toList();
  }

  @override
  Future<List<MediaItem>> getSimilar(int tmdbId, {required MediaType mediaType, int page = 1}) async {
    final type = mediaType == MediaType.tv ? 'tv' : 'movie';
    final data = await _get('$type/$tmdbId/similar?page=$page');
    return _parseResults(data, mediaType);
  }

  @override
  Future<String?> getLogoPath(int tmdbId, {required MediaType mediaType}) async {
    final type = mediaType == MediaType.tv ? 'tv' : 'movie';
    Future<List<Map<String, dynamic>>> fetchUsable({String? query}) async {
      final path = query == null || query.isEmpty
          ? '$type/$tmdbId/images'
          : '$type/$tmdbId/images?$query';
      final data = await _get(path);
      if (data == null) return [];
      final logos = data['logos'] as List<dynamic>?;
      if (logos == null || logos.isEmpty) return [];
      return logos
          .whereType<Map<String, dynamic>>()
          .where((m) {
            final fp = m['file_path'] as String?;
            return fp != null && fp.trim().isNotEmpty;
          })
          .toList();
    }

    var usable = await fetchUsable(query: 'include_image_language=en,en-US,null');
    if (usable.isEmpty) {
      // Retry without restricting language. Some titles only have non-English logos.
      usable = await fetchUsable();
    }
    if (usable.isEmpty) return null;

    // Prefer English logos when possible.
    final english = usable.where((m) {
      final lang = (m['iso_639_1'] as String?)?.toLowerCase();
      return lang == 'en';
    }).toList();
    final pool = english.isNotEmpty ? english : usable;

    // Prefer the highest vote_average, then the widest image.
    pool.sort((a, b) {
      final va = (a['vote_average'] as num?)?.toDouble() ?? 0.0;
      final vb = (b['vote_average'] as num?)?.toDouble() ?? 0.0;
      if (va != vb) return vb.compareTo(va);
      final wa = (a['width'] as num?)?.toInt() ?? 0;
      final wb = (b['width'] as num?)?.toInt() ?? 0;
      return wb.compareTo(wa);
    });

    return pool.first['file_path'] as String?;
  }

  @override
  Future<List<String>> getGenreNames(int tmdbId, {required MediaType mediaType}) async {
    final type = mediaType == MediaType.tv ? 'tv' : 'movie';
    final data = await _get('$type/$tmdbId');
    if (data == null) return [];
    final genres = data['genres'] as List<dynamic>? ?? [];
    return genres
        .map((g) => (g as Map<String, dynamic>)['name'] as String?)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  @override
  String getPosterUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    return '$_imageBase/$size$path';
  }

  @override
  String getBackdropUrl(String? path, {String size = 'w1280'}) {
    if (path == null || path.isEmpty) return '';
    return '$_imageBase/$size$path';
  }

  @override
  String getLogoUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    return '$_imageBase/$size$path';
  }
}

final tmdbRepositoryProvider = Provider<TmdbRepository>((ref) {
  throw UnimplementedError('Initialize in main');
});

final trendingMoviesProvider = FutureProvider.family<List<MediaItem>, int>((ref, page) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  return repo.getTrendingMovies(page: page);
});

final trendingTvProvider = FutureProvider.family<List<MediaItem>, int>((ref, page) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  return repo.getTrendingTv(page: page);
});

final trendingAllProvider = FutureProvider.family<List<MediaItem>, int>((ref, page) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  return repo.getTrendingAll(page: page);
});

final topRatedMoviesProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  return repo.getTopRatedMovies();
});

final popularTvProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  return repo.getPopularTv();
});