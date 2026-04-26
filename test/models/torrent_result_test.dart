import 'package:flutter_test/flutter_test.dart';
import 'package:streame_core/models/torrent_result.dart';

void main() {
  group('TorrentResult.fromJson', () {
    test('parses all fields', () {
      final json = {
        'name': 'Movie.2024.1080p.BluRay.x264',
        'magnet': 'magnet:?xt=urn:btih:abc123',
        'seeders': 42,
        'size': '2.5 GB',
        'source': 'Jackett',
      };

      final result = TorrentResult.fromJson(json);

      expect(result.name, 'Movie.2024.1080p.BluRay.x264');
      expect(result.magnet, 'magnet:?xt=urn:btih:abc123');
      expect(result.seeders, '42');
      expect(result.size, '2.5 GB');
      expect(result.source, 'Jackett');
    });

    test('handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final result = TorrentResult.fromJson(json);

      expect(result.name, 'Unknown');
      expect(result.magnet, '');
      expect(result.seeders, '0');
      expect(result.size, 'Unknown');
      expect(result.source, 'Unknown');
    });
  });

  group('TorrentResult.sizeInBytes', () {
    test('parses GB', () {
      final result = TorrentResult(
        name: 'test',
        magnet: '',
        seeders: '1',
        size: '2.5 GB',
        source: '',
      );
      expect(result.sizeInBytes, closeTo(2.5 * 1024 * 1024 * 1024, 1));
    });

    test('parses MB', () {
      final result = TorrentResult(
        name: 'test',
        magnet: '',
        seeders: '1',
        size: '500 MB',
        source: '',
      );
      expect(result.sizeInBytes, closeTo(500 * 1024 * 1024, 1));
    });

    test('parses KB', () {
      final result = TorrentResult(
        name: 'test',
        magnet: '',
        seeders: '1',
        size: '1024 KB',
        source: '',
      );
      expect(result.sizeInBytes, closeTo(1024 * 1024, 1));
    });

    test('returns raw number when no unit', () {
      final result = TorrentResult(
        name: 'test',
        magnet: '',
        seeders: '1',
        size: '12345',
        source: '',
      );
      expect(result.sizeInBytes, 12345.0);
    });
  });

  group('TorrentResult.qualityScore', () {
    test('returns 2160 for 4K', () {
      final result = TorrentResult(
        name: 'Movie.2024.2160p.UHD.BluRay',
        magnet: '',
        seeders: '1',
        size: '10 GB',
        source: '',
      );
      expect(result.qualityScore, 2160);
    });

    test('returns 1080 for 1080p', () {
      final result = TorrentResult(
        name: 'Movie.2024.1080p.BluRay',
        magnet: '',
        seeders: '1',
        size: '2 GB',
        source: '',
      );
      expect(result.qualityScore, 1080);
    });

    test('returns 720 for 720p', () {
      final result = TorrentResult(
        name: 'Movie.2024.720p.WEBRip',
        magnet: '',
        seeders: '1',
        size: '1 GB',
        source: '',
      );
      expect(result.qualityScore, 720);
    });

    test('returns 0 for unknown quality', () {
      final result = TorrentResult(
        name: 'Movie.2024.CAM',
        magnet: '',
        seeders: '1',
        size: '700 MB',
        source: '',
      );
      expect(result.qualityScore, 0);
    });
  });

  group('TorrentResult.seedersCount', () {
    test('parses numeric seeders', () {
      final result = TorrentResult(
        name: 'test',
        magnet: '',
        seeders: '42',
        size: '1 GB',
        source: '',
      );
      expect(result.seedersCount, 42);
    });

    test('parses seeders with commas', () {
      final result = TorrentResult(
        name: 'test',
        magnet: '',
        seeders: '1,234',
        size: '1 GB',
        source: '',
      );
      expect(result.seedersCount, 1234);
    });

    test('returns 0 for non-numeric', () {
      final result = TorrentResult(
        name: 'test',
        magnet: '',
        seeders: 'N/A',
        size: '1 GB',
        source: '',
      );
      expect(result.seedersCount, 0);
    });
  });
}
