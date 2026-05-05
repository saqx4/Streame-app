import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:streame/core/models/stream_models.dart';
import 'package:streame/core/services/torrent_stream_service.dart';

/// Centralized stream URL resolution and deterministic sorting.
///
/// Single authoritative path for:
/// - URL normalization (add scheme, handle bare hosts)
/// - Magnet URI construction from infoHash + trackers
/// - Playable URL resolution (direct HTTP → torrent engine)
/// - Deterministic stream sorting (cached → direct → quality → release → size → name)
/// - Local stream reachability check with bounded retry
class StreamResolver {
  StreamResolver._();

  // ─── Stream Result Cache ────────────────────────────────────────────────

  /// In-memory cache of stream results keyed by "type:imdbId:season:episode".
  /// Expires after [_cacheTtl] to avoid stale results.
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Build a cache key from stream resolution parameters.
  static String cacheKey(String type, String imdbId, {int? season, int? episode}) =>
      '$type:$imdbId:${season ?? ''}:${episode ?? ''}';

  /// Get cached stream results if still fresh, otherwise null.
  static List<AddonStreamResult>? getCached(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > _cacheTtl) {
      _cache.remove(key);
      return null;
    }
    return entry.results;
  }

  /// Store stream results in cache.
  static void putCached(String key, List<AddonStreamResult> results) {
    _cache[key] = _CacheEntry(results: results, timestamp: DateTime.now());
  }

  /// Clear the entire cache (e.g. when addons change).
  static void clearCache() => _cache.clear();

  // ─── URL Normalization ──────────────────────────────────────────────────

  /// Normalize a raw URL string. Returns null for magnets or invalid URLs.
  /// Magnet URIs are handled by [resolvePlayableUrl], not media_kit directly.
  static String? normalizeUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final url = raw.trim();
    if (url.toLowerCase().startsWith('magnet:')) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.contains('.') && !url.contains('://')) return 'https://$url';
    return url;
  }

  // ─── Magnet Construction ─────────────────────────────────────────────────

  /// Build a magnet URI from a StreamSource's infoHash + tracker sources.
  static String? buildMagnet(StreamSource stream) {
    final infoHash = stream.infoHash;
    if (infoHash == null || infoHash.isEmpty) return null;

    final cleanHash =
        infoHash.toLowerCase().replaceAll('urn:btih:', '').replaceAll('btih:', '');
    if (cleanHash.isEmpty) return null;

    final dn = (stream.behaviorHints?.filename ?? stream.source).isNotEmpty
        ? (stream.behaviorHints?.filename ?? stream.source)
        : 'video';
    final trackers = stream.sources
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => s.replaceFirst('tracker:', ''))
        .where((s) =>
            s.startsWith('http://') ||
            s.startsWith('https://') ||
            s.startsWith('udp://'))
        .toList();

    final buf =
        StringBuffer('magnet:?xt=urn:btih:$cleanHash&dn=${Uri.encodeComponent(dn)}');
    for (final tr in trackers) {
      buf.write('&tr=${Uri.encodeComponent(tr)}');
    }
    return buf.toString();
  }

  // ─── Playable URL Resolution ─────────────────────────────────────────────

  /// Resolve a playable HTTP URL from a [StreamSource].
  /// Order: direct HTTP URL → magnet/infoHash via torrent engine.
  /// [season]/[episode] used for torrent file selection.
  static Future<String?> resolvePlayableUrl(
    StreamSource stream, {
    int? season,
    int? episode,
    void Function(String magnet)? onTorrentStart,
  }) async {
    // 1. Direct HTTP URL
    final direct = normalizeUrl(stream.url);
    if (direct != null) return direct;

    // 2. Magnet URL or infoHash — resolve via built-in torrent engine
    if ((stream.url != null && stream.url!.toLowerCase().startsWith('magnet:')) ||
        (stream.infoHash != null && stream.infoHash!.isNotEmpty)) {
      final url = await _resolveViaTorrentEngine(
        stream,
        season: season,
        episode: episode,
        onTorrentStart: onTorrentStart,
      );
      if (url != null) return url;
    }

    return null;
  }

  static Future<String?> _resolveViaTorrentEngine(
    StreamSource stream, {
    int? season,
    int? episode,
    void Function(String magnet)? onTorrentStart,
  }) async {
    String? magnet;

    if (stream.url != null && stream.url!.toLowerCase().startsWith('magnet:')) {
      magnet = stream.url!;
    } else {
      magnet = buildMagnet(stream);
    }

    if (magnet == null) return null;

    debugPrint(
        'StreamResolver: resolving via torrent engine: ${magnet.substring(0, magnet.length.clamp(0, 80))}');

    onTorrentStart?.call(magnet);

    final torrent = TorrentStreamService();
    final url = await torrent.streamTorrent(
      magnet,
      season: season,
      episode: episode,
    );

    if (url != null) {
      debugPrint('StreamResolver: torrent stream URL: $url');
    }

    return url;
  }

  // ─── Reachability Check with Retry ───────────────────────────────────────

  /// Check if a local stream URL is reachable, with bounded retry.
  /// [maxAttempts] total tries (default 3). [delay] between retries.
  static Future<bool> checkStreamReachable(
    String url, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    if (!url.contains('127.0.0.1') && !url.contains('localhost')) return true;

    for (int i = 0; i < maxAttempts; i++) {
      try {
        final uri = Uri.parse(url);
        final socket = await Socket.connect(
          uri.host,
          uri.port,
          timeout: const Duration(seconds: 5),
        );
        socket.destroy();
        debugPrint('StreamResolver: pre-flight OK — ${uri.host}:${uri.port}');
        return true;
      } catch (e) {
        debugPrint(
            'StreamResolver: pre-flight attempt ${i + 1}/$maxAttempts FAIL — $url: $e');
        if (i < maxAttempts - 1) {
          await Future.delayed(delay);
        }
      }
    }
    return false;
  }

  // ─── Deterministic Stream Sorting ────────────────────────────────────────

  /// Quality score from resolution string. Used for sorting.
  static int qualityScore(String q) {
    if (q.contains('4K') || q.contains('2160')) return 40;
    if (q.contains('1080')) return 30;
    if (q.contains('720')) return 20;
    if (q.contains('480')) return 10;
    return 0;
  }

  /// Sort streams for playback: cached → direct HTTP → quality → release → size → name.
  /// This is stable: equal-scored streams keep their original relative order.
  static List<StreamSource> sortForPlayback(List<StreamSource> streams) {
    final indexed = <int, StreamSource>{};
    for (int i = 0; i < streams.length; i++) {
      indexed[i] = streams[i];
    }

    final entries = indexed.entries.toList()
      ..sort((a, b) {
        final sA = a.value;
        final sB = b.value;

        // 1. Cached streams first
        final cachedA = sA.behaviorHints?.cached == true ? 100 : 0;
        final cachedB = sB.behaviorHints?.cached == true ? 100 : 0;
        if (cachedA != cachedB) return cachedB.compareTo(cachedA);

        // 2. Direct HTTP next
        final directA = (sA.url != null && sA.url!.startsWith('http')) ? 50 : 0;
        final directB = (sB.url != null && sB.url!.startsWith('http')) ? 50 : 0;
        if (directA != directB) return directB.compareTo(directA);

        // 3. Quality score
        final qA = qualityScore(sA.quality);
        final qB = qualityScore(sB.quality);
        if (qA != qB) return qB.compareTo(qA);

        // 4. Size (larger = better, usually higher bitrate)
        final sizeA = sA.sizeBytes ?? 0;
        final sizeB = sB.sizeBytes ?? 0;
        if (sizeA != sizeB) return sizeB.compareTo(sizeA);

        // 5. Name tie-breaker (stable)
        final nameCmp =
            sA.source.toLowerCase().compareTo(sB.source.toLowerCase());
        if (nameCmp != 0) return nameCmp;

        // 6. Original index (guaranteed stable)
        return a.key.compareTo(b.key);
      });

    return entries.map((e) => e.value).toList();
  }
}

class _CacheEntry {
  final List<AddonStreamResult> results;
  final DateTime timestamp;
  const _CacheEntry({required this.results, required this.timestamp});
}
