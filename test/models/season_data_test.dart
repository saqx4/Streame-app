import 'package:flutter_test/flutter_test.dart';
import 'package:streame_core/models/season_data.dart';

void main() {
  group('CastMember', () {
    test('fromTmdbMap parses all fields', () {
      final member = CastMember.fromTmdbMap({
        'name': 'Bryan Cranston',
        'character': 'Walter White',
        'profile_path': '/profile.jpg',
      });

      expect(member.name, 'Bryan Cranston');
      expect(member.character, 'Walter White');
      expect(member.profilePath, '/profile.jpg');
    });

    test('toMap returns backwards-compatible map', () {
      final member = CastMember(
        name: 'Test',
        character: 'Role',
        profilePath: '/path.jpg',
      );

      final map = member.toMap();
      expect(map['name'], 'Test');
      expect(map['character'], 'Role');
      expect(map['profilePath'], '/path.jpg');
    });

    test('handles missing fields', () {
      final member = CastMember.fromTmdbMap({});

      expect(member.name, '');
      expect(member.character, '');
      expect(member.profilePath, '');
    });
  });

  group('Episode', () {
    test('fromTmdbMap parses all fields', () {
      final ep = Episode.fromTmdbMap({
        'id': 123,
        'name': 'Pilot',
        'overview': 'Walter White discovers...',
        'still_path': '/still.jpg',
        'episode_number': 1,
        'air_date': '2008-01-20',
        'vote_average': 8.5,
      });

      expect(ep.id, 123);
      expect(ep.name, 'Pilot');
      expect(ep.episodeNumber, 1);
      expect(ep.airDate, '2008-01-20');
      expect(ep.voteAverage, 8.5);
    });

    test('handles missing fields with defaults', () {
      final ep = Episode.fromTmdbMap({'id': 1, 'episode_number': 5});

      expect(ep.name, '');
      expect(ep.overview, '');
      expect(ep.stillPath, '');
      expect(ep.voteAverage, 0.0);
    });
  });

  group('SeasonData', () {
    test('fromTmdbResponse parses episodes', () {
      final data = SeasonData.fromTmdbResponse({
        'episodes': [
          {'id': 1, 'name': 'Ep1', 'episode_number': 1},
          {'id': 2, 'name': 'Ep2', 'episode_number': 2},
        ],
      });

      expect(data.episodes!.length, 2);
      expect(data.isCustomIdFormat, false);
      expect(data.seasonCount, 1);
    });

    test('fromCustomIdFormat parses episodes by season', () {
      final data = SeasonData.fromCustomIdFormat(
        [1, 2],
        {
          1: [
            {'id': 1, 'episode_number': 1},
            {'id': 2, 'episode_number': 2},
          ],
          2: [
            {'id': 3, 'episode_number': 1},
          ],
        },
      );

      expect(data.isCustomIdFormat, true);
      expect(data.seasonCount, 2);
      expect(data.seasons, [1, 2]);
      expect(data.episodesForSeason(1).length, 2);
      expect(data.episodesForSeason(2).length, 1);
    });

    test('episodesForSeason returns empty for missing season', () {
      final data = SeasonData.fromCustomIdFormat([1], {
        1: [{'id': 1, 'episode_number': 1}],
      });

      expect(data.episodesForSeason(99), isEmpty);
    });

    test('empty SeasonData returns safe defaults', () {
      const data = SeasonData();

      expect(data.seasonCount, 1);
      expect(data.episodesForSeason(1), isEmpty);
      expect(data.isCustomIdFormat, false);
    });
  });
}
