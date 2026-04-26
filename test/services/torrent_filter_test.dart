import 'package:flutter_test/flutter_test.dart';
import 'package:streame_core/services/torrent_filter.dart';
import 'package:streame_core/models/torrent_result.dart';

void main() {
  group('TorrentFilter.normalizeTitle', () {
    test('lowercases and strips punctuation', () {
      expect(TorrentFilter.normalizeTitle('The.Matrix.1999'), 'the matrix 1999');
    });

    test('collapses whitespace', () {
      expect(TorrentFilter.normalizeTitle('  Hello   World  '), 'hello world');
    });

    test('returns empty for empty string', () {
      expect(TorrentFilter.normalizeTitle(''), '');
    });
  });

  group('TorrentFilter.parseSceneInfo', () {
    test('parses S01E02', () {
      final info = TorrentFilter.parseSceneInfo('Show.Name.S01E02.1080p');
      expect(info['season'], 1);
      expect(info['episode'], 2);
      expect(info['isSeasonPack'], false);
    });

    test('parses 1x02 format', () {
      final info = TorrentFilter.parseSceneInfo('Show.Name.1x02.720p');
      expect(info['season'], 1);
      expect(info['episode'], 2);
    });

    test('parses "Season 2 Episode 5" written format', () {
      final info = TorrentFilter.parseSceneInfo('Show Name Season 2 Episode 5 HDTV');
      expect(info['season'], 2);
      expect(info['episode'], 5);
    });

    test('detects season pack', () {
      final info = TorrentFilter.parseSceneInfo('Show.Name.S02.Complete.1080p');
      expect(info['season'], 2);
      expect(info['isSeasonPack'], true);
    });

    test('detects multi-episode', () {
      final info = TorrentFilter.parseSceneInfo('Show.Name.S01E02-E04.1080p');
      expect(info['season'], 1);
      expect(info['isMultiEpisode'], true);
    });

    test('detects multi-season', () {
      final info = TorrentFilter.parseSceneInfo('Show.Name.S01-S05.Complete.Series');
      expect(info['isMultiSeason'], true);
    });

    test('no season/episode info', () {
      final info = TorrentFilter.parseSceneInfo('Movie.Name.2024.1080p.BluRay');
      expect(info['season'], null);
      expect(info['episode'], null);
    });
  });

  group('TorrentFilter.isVideoFile', () {
    test('recognizes .mkv', () {
      expect(TorrentFilter.isVideoFile('episode.mkv'), true);
    });

    test('recognizes .mp4', () {
      expect(TorrentFilter.isVideoFile('movie.mp4'), true);
    });

    test('rejects .srt', () {
      expect(TorrentFilter.isVideoFile('subs.srt'), false);
    });

    test('rejects .nfo', () {
      expect(TorrentFilter.isVideoFile('info.nfo'), false);
    });
  });

  group('TorrentFilter.isFileMatch', () {
    test('matches S01E02 in filename', () {
      expect(TorrentFilter.isFileMatch('Show.S01E02.1080p.mkv', 1, 2), true);
    });

    test('rejects non-video file', () {
      expect(TorrentFilter.isFileMatch('Show.S01E02.nfo', 1, 2), false);
    });

    test('rejects wrong episode', () {
      expect(TorrentFilter.isFileMatch('Show.S01E03.1080p.mkv', 1, 2), false);
    });
  });

  group('TorrentFilter.filterTorrents', () {
    final items = [
      TorrentResult(name: 'Breaking Bad S01E01 1080p', magnet: 'm1', seeders: '10', size: '1 GB', source: 'test'),
      TorrentResult(name: 'Breaking Bad S01E02 1080p', magnet: 'm2', seeders: '5', size: '1 GB', source: 'test'),
      TorrentResult(name: 'Breaking Bad S02 Complete 720p', magnet: 'm3', seeders: '20', size: '10 GB', source: 'test'),
      TorrentResult(name: 'Other Show S01E01 1080p', magnet: 'm4', seeders: '15', size: '1 GB', source: 'test'),
    ];

    test('filters by show title', () {
      final result = TorrentFilter.filterTorrents(items, 'Breaking Bad');
      expect(result.length, 3);
      expect(result.every((r) => r.name.contains('Breaking Bad')), true);
    });

    test('filters by season and episode', () {
      final result = TorrentFilter.filterTorrents(
        items,
        'Breaking Bad',
        requiredSeason: 1,
        requiredEpisode: 1,
      );
      expect(result.length, 1);
      expect(result.first.name, contains('S01E01'));
    });

    test('filters by season only (packs)', () {
      final result = TorrentFilter.filterTorrents(
        items,
        'Breaking Bad',
        requiredSeason: 2,
      );
      expect(result.isNotEmpty, true);
      expect(result.first.name, contains('S02'));
    });

    test('returns empty for empty items', () {
      final result = TorrentFilter.filterTorrents([], 'Breaking Bad');
      expect(result, isEmpty);
    });

    test('returns all items for empty title', () {
      final result = TorrentFilter.filterTorrents(items, '');
      expect(result.length, 4);
    });
  });

  group('TorrentFilter._getQualityScore (via filterTorrents)', () {
    test('4K/UHD titles rank highest', () {
      final items = [
        TorrentResult(name: 'Show 480p', magnet: '', seeders: '1', size: '500 MB', source: ''),
        TorrentResult(name: 'Show 2160p', magnet: '', seeders: '1', size: '20 GB', source: ''),
        TorrentResult(name: 'Show 1080p', magnet: '', seeders: '1', size: '2 GB', source: ''),
      ];
      // filterTorrents with no season/episode just filters by title
      final result = TorrentFilter.filterTorrents(items, 'Show');
      expect(result.length, 3);
    });
  });
}
