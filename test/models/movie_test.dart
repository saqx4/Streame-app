import 'package:flutter_test/flutter_test.dart';
import 'package:streame_core/models/movie.dart';

void main() {
  group('Movie.fromJson', () {
    test('parses movie with all fields', () {
      final json = {
        'id': 123,
        'imdb_id': 'tt1234567',
        'title': 'Inception',
        'poster_path': '/poster.jpg',
        'backdrop_path': '/backdrop.jpg',
        'vote_average': 8.5,
        'release_date': '2010-07-16',
        'overview': 'A thief who steals corporate secrets...',
        'genres': [
          {'id': 28, 'name': 'Action'},
          {'id': 878, 'name': 'Science Fiction'},
        ],
        'runtime': 148,
      };

      final movie = Movie.fromJson(json);

      expect(movie.id, 123);
      expect(movie.imdbId, 'tt1234567');
      expect(movie.title, 'Inception');
      expect(movie.posterPath, '/poster.jpg');
      expect(movie.backdropPath, '/backdrop.jpg');
      expect(movie.voteAverage, 8.5);
      expect(movie.releaseDate, '2010-07-16');
      expect(movie.overview, 'A thief who steals corporate secrets...');
      expect(movie.genres, ['Action', 'Science Fiction']);
      expect(movie.runtime, 148);
      expect(movie.mediaType, 'movie');
    });

    test('parses TV show using name and first_air_date', () {
      final json = {
        'id': 456,
        'name': 'Breaking Bad',
        'poster_path': '/poster.jpg',
        'backdrop_path': '/backdrop.jpg',
        'vote_average': 9.5,
        'first_air_date': '2008-01-20',
        'overview': 'A chemistry teacher...',
        'number_of_seasons': 5,
      };

      final movie = Movie.fromJson(json);

      expect(movie.id, 456);
      expect(movie.title, 'Breaking Bad');
      expect(movie.releaseDate, '2008-01-20');
      expect(movie.mediaType, 'tv');
      expect(movie.numberOfSeasons, 5);
    });

    test('extracts imdb_id from external_ids fallback', () {
      final json = {
        'id': 789,
        'title': 'Test Movie',
        'poster_path': '/p.jpg',
        'backdrop_path': '/b.jpg',
        'vote_average': 7.0,
        'release_date': '2020-01-01',
        'external_ids': {
          'imdb_id': 'tt9876543',
        },
      };

      final movie = Movie.fromJson(json);

      expect(movie.imdbId, 'tt9876543');
    });

    test('handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final movie = Movie.fromJson(json);

      expect(movie.id, 0);
      expect(movie.title, 'Unknown');
      expect(movie.posterPath, '');
      expect(movie.voteAverage, 0.0);
      expect(movie.genres, []);
      expect(movie.runtime, 0);
      expect(movie.mediaType, 'tv'); // no 'title' key → defaults to 'tv'
    });

    test('mediaType override takes precedence', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'poster_path': '/p.jpg',
        'backdrop_path': '/b.jpg',
        'vote_average': 5.0,
        'release_date': '2020-01-01',
        'media_type': 'movie',
      };

      final movie = Movie.fromJson(json, mediaType: 'tv');

      expect(movie.mediaType, 'tv');
    });
  });

  group('Movie.copyWith', () {
    test('copies with new values', () {
      final original = Movie(
        id: 1,
        title: 'Original',
        posterPath: '/original.jpg',
        backdropPath: '/original_bg.jpg',
        voteAverage: 7.0,
        releaseDate: '2020-01-01',
      );

      final copy = original.copyWith(title: 'Updated', voteAverage: 9.0);

      expect(copy.id, 1);
      expect(copy.title, 'Updated');
      expect(copy.voteAverage, 9.0);
      expect(copy.posterPath, '/original.jpg');
    });

    test('returns identical movie when no changes', () {
      final original = Movie(
        id: 1,
        title: 'Original',
        posterPath: '/p.jpg',
        backdropPath: '/b.jpg',
        voteAverage: 7.0,
        releaseDate: '2020-01-01',
      );

      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.title, original.title);
      expect(copy.voteAverage, original.voteAverage);
    });
  });
}
