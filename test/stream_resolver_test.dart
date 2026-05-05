import 'package:flutter_test/flutter_test.dart';
import 'package:streame/core/models/stream_models.dart';
import 'package:streame/core/services/stream_resolver.dart';

void main() {
  group('StreamResolver.normalizeUrl', () {
    test('returns null for null input', () {
      expect(StreamResolver.normalizeUrl(null), isNull);
    });

    test('returns null for empty string', () {
      expect(StreamResolver.normalizeUrl(''), isNull);
    });

    test('returns null for magnet URIs', () {
      expect(StreamResolver.normalizeUrl('magnet:?xt=urn:btih:abc123'), isNull);
    });

    test('returns http URLs unchanged', () {
      expect(StreamResolver.normalizeUrl('http://example.com/video.mp4'), 'http://example.com/video.mp4');
    });

    test('returns https URLs unchanged', () {
      expect(StreamResolver.normalizeUrl('https://example.com/video.mp4'), 'https://example.com/video.mp4');
    });

    test('adds https: prefix to protocol-relative URLs', () {
      expect(StreamResolver.normalizeUrl('//example.com/video.mp4'), 'https://example.com/video.mp4');
    });

    test('adds https:// prefix to bare host URLs', () {
      expect(StreamResolver.normalizeUrl('example.com/video.mp4'), 'https://example.com/video.mp4');
    });

    test('trims whitespace', () {
      expect(StreamResolver.normalizeUrl('  https://example.com/video.mp4  '), 'https://example.com/video.mp4');
    });
  });

  group('StreamResolver.buildMagnet', () {
    test('returns null when infoHash is null', () {
      final stream = StreamSource(source: 'test', addonName: 'addon', quality: '');
      expect(StreamResolver.buildMagnet(stream), isNull);
    });

    test('returns null when infoHash is empty', () {
      final stream = StreamSource(source: 'test', addonName: 'addon', quality: '', infoHash: '');
      expect(StreamResolver.buildMagnet(stream), isNull);
    });

    test('constructs basic magnet from infoHash', () {
      final stream = StreamSource(source: 'test', addonName: 'addon', quality: '', infoHash: 'abc123');
      final magnet = StreamResolver.buildMagnet(stream);
      expect(magnet, isNotNull);
      expect(magnet!, startsWith('magnet:?xt=urn:btih:abc123'));
      expect(magnet, contains('dn='));
    });

    test('strips urn:btih: prefix from infoHash', () {
      final stream = StreamSource(source: 'test', addonName: 'addon', quality: '', infoHash: 'urn:btih:ABC123');
      final magnet = StreamResolver.buildMagnet(stream);
      expect(magnet, isNotNull);
      expect(magnet!, contains('urn:btih:abc123'));
    });

    test('includes tracker URLs from sources', () {
      final stream = StreamSource(
        source: 'test',
        addonName: 'addon',
        quality: '',
        infoHash: 'abc123',
        sources: ['tracker:http://tracker1.com/announce', 'http://tracker2.com/announce'],
      );
      final magnet = StreamResolver.buildMagnet(stream);
      expect(magnet, isNotNull);
      expect(magnet!, contains('tr='));
    });

    test('uses filename from behaviorHints for dn', () {
      final stream = StreamSource(
        source: 'test',
        addonName: 'addon',
        quality: '',
        infoHash: 'abc123',
        behaviorHints: StreamBehaviorHints(filename: 'Movie.2024.1080p.mkv'),
      );
      final magnet = StreamResolver.buildMagnet(stream);
      expect(magnet, isNotNull);
      expect(magnet!, contains(Uri.encodeComponent('Movie.2024.1080p.mkv')));
    });
  });

  group('StreamResolver.qualityScore', () {
    test('4K gets highest score', () {
      expect(StreamResolver.qualityScore('4K'), 40);
    });

    test('2160p gets 4K score', () {
      expect(StreamResolver.qualityScore('2160p'), 40);
    });

    test('1080p gets second highest', () {
      expect(StreamResolver.qualityScore('1080p'), 30);
    });

    test('720p gets third', () {
      expect(StreamResolver.qualityScore('720p'), 20);
    });

    test('480p gets low score', () {
      expect(StreamResolver.qualityScore('480p'), 10);
    });

    test('unknown quality gets 0', () {
      expect(StreamResolver.qualityScore('SD'), 0);
    });
  });

  group('StreamResolver.sortForPlayback', () {
    test('cached streams come first', () {
      final cached = StreamSource(
        source: 'cached',
        addonName: 'addon',
        quality: '720p',
        url: 'http://example.com/cached.mp4',
        behaviorHints: StreamBehaviorHints(cached: true),
      );
      final uncached = StreamSource(
        source: 'uncached',
        addonName: 'addon',
        quality: '4K',
        url: 'http://example.com/uncached.mp4',
      );
      final result = StreamResolver.sortForPlayback([uncached, cached]);
      expect(result.first.source, 'cached');
    });

    test('direct HTTP comes before torrent', () {
      final direct = StreamSource(
        source: 'direct',
        addonName: 'addon',
        quality: '720p',
        url: 'http://example.com/video.mp4',
      );
      final torrent = StreamSource(
        source: 'torrent',
        addonName: 'addon',
        quality: '4K',
        infoHash: 'abc123',
      );
      final result = StreamResolver.sortForPlayback([torrent, direct]);
      expect(result.first.source, 'direct');
    });

    test('higher quality preferred among same transport', () {
      final low = StreamSource(
        source: 'low',
        addonName: 'addon',
        quality: '720p',
        url: 'http://example.com/low.mp4',
      );
      final high = StreamSource(
        source: 'high',
        addonName: 'addon',
        quality: '1080p',
        url: 'http://example.com/high.mp4',
      );
      final result = StreamResolver.sortForPlayback([low, high]);
      expect(result.first.source, 'high');
    });

    test('larger size preferred when quality is equal', () {
      final small = StreamSource(
        source: 'small',
        addonName: 'addon',
        quality: '1080p',
        url: 'http://example.com/small.mp4',
        sizeBytes: 1000,
      );
      final large = StreamSource(
        source: 'large',
        addonName: 'addon',
        quality: '1080p',
        url: 'http://example.com/large.mp4',
        sizeBytes: 2000,
      );
      final result = StreamResolver.sortForPlayback([small, large]);
      expect(result.first.source, 'large');
    });

    test('name tie-breaker when all else is equal', () {
      final b = StreamSource(
        source: 'B-stream',
        addonName: 'addon',
        quality: '1080p',
        url: 'http://example.com/b.mp4',
      );
      final a = StreamSource(
        source: 'A-stream',
        addonName: 'addon',
        quality: '1080p',
        url: 'http://example.com/a.mp4',
      );
      final result = StreamResolver.sortForPlayback([b, a]);
      expect(result.first.source, 'A-stream');
    });

    test('sort is stable — preserves original order for equal items', () {
      final s1 = StreamSource(source: 'same', addonName: 'addon', quality: '1080p', url: 'http://a.com');
      final s2 = StreamSource(source: 'same', addonName: 'addon', quality: '1080p', url: 'http://b.com');
      final result = StreamResolver.sortForPlayback([s1, s2]);
      // Both have same source name and quality, so original order is preserved
      expect(result[0].url, 'http://a.com');
      expect(result[1].url, 'http://b.com');
    });

    test('empty list returns empty', () {
      expect(StreamResolver.sortForPlayback([]), isEmpty);
    });
  });
}
