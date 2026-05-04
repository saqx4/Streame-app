import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';

/// Rich torrent statistics for UI display.
class TorrentStats {
  final double speedMbps;
  final int activePeers;
  final int totalPeers;
  final double cachePercent;
  final int loadedBytes;
  final int totalBytes;
  final String hash;
  final bool isConnected;
  final double bufferPct;

  const TorrentStats({
    required this.speedMbps,
    required this.activePeers,
    required this.totalPeers,
    required this.cachePercent,
    required this.loadedBytes,
    required this.totalBytes,
    required this.hash,
    required this.isConnected,
    this.bufferPct = 0,
  });

  double get speedKiBps => speedMbps * 1024;
  String get speedLabel => speedMbps >= 1.0
      ? '${speedMbps.toStringAsFixed(2)} MB/s'
      : '${speedKiBps.toStringAsFixed(0)} KB/s';
  String get peersLabel => '$activePeers / $totalPeers';
  String get cacheLabel => '${cachePercent.toStringAsFixed(1)}%';
  String get bufferLabel => '${bufferPct.toStringAsFixed(0)}%';
}

/// Engine lifecycle states.
enum EngineState { stopped, starting, ready, error }

/// Singleton service that wraps libtorrent_flutter for direct torrent streaming.
///
/// Flow: addMagnet → wait metadata → selectFile → startStream → local HTTP URL
/// No TorrServer or debrid needed — the engine runs inside the app.
class TorrentStreamService {
  static final TorrentStreamService _instance = TorrentStreamService._internal();
  factory TorrentStreamService() => _instance;
  TorrentStreamService._internal();

  EngineState _state = EngineState.stopped;
  EngineState get state => _state;

  void Function(EngineState state)? onStateChanged;

  /// Active torrent IDs keyed by info-hash for cleanup.
  final Map<String, int> _activeTorrents = {};

  /// Active stream IDs keyed by info-hash for cleanup.
  final Map<String, int> _activeStreams = {};

  /// Track disposed IDs to prevent double-dispose native crash.
  final Set<int> _disposedTorrentIds = {};
  final Set<int> _disposedStreamIds = {};

  StreamSubscription? _torrentUpdatesSub;
  StreamSubscription? _streamUpdatesSub;

  /// Latest torrent update snapshots keyed by torrent ID.
  final Map<int, TorrentInfo> _latestUpdates = {};

  /// Latest stream info snapshots keyed by stream ID.
  final Map<int, StreamInfo> _latestStreamUpdates = {};

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  /// Initializes the libtorrent engine. Safe to call multiple times.
  Future<bool> start() async {
    if (_state == EngineState.ready) return true;
    if (_state == EngineState.starting) {
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_state == EngineState.ready) return true;
        if (_state == EngineState.error) return false;
      }
      return false;
    }

    _setState(EngineState.starting);
    try {
      await LibtorrentFlutter.init();
      _torrentUpdatesSub = LibtorrentFlutter.instance.torrentUpdates.listen((updates) {
        _latestUpdates.addAll(updates);
      });
      _streamUpdatesSub = LibtorrentFlutter.instance.streamUpdates.listen((updates) {
        _latestStreamUpdates.addAll(updates);
      });
      _setState(EngineState.ready);
      debugPrint('[TorrentStream] Engine ready');
      return true;
    } catch (e) {
      debugPrint('[TorrentStream] Failed to start engine: $e');
      _setState(EngineState.error);
      return false;
    }
  }

  // ─── Stream a torrent — main entry point ────────────────────────────────

  /// Adds a magnet, waits for metadata, selects the right file, starts an
  /// HTTP stream, and returns the local stream URL.
  Future<String?> streamTorrent(
    String magnetLink, {
    int? season,
    int? episode,
    int? fileIdx,
  }) async {
    if (_state != EngineState.ready) {
      final started = await start();
      if (!started) {
        debugPrint('[TorrentStream] Cannot stream: engine failed to start.');
        return null;
      }
    }

    final hash = _extractHash(magnetLink);

    // Dispose previous torrent with same hash if any
    if (hash != null && _activeTorrents.containsKey(hash)) {
      try {
        final oldId = _activeTorrents[hash]!;
        if (_activeStreams.containsKey(hash)) {
          _safeStopStream(_activeStreams[hash]!);
          _activeStreams.remove(hash);
        }
        _safeDisposeTorrent(oldId);
        _activeTorrents.remove(hash);
      } catch (e) {
        debugPrint('[TorrentStream] Cleanup old torrent error: $e');
      }
    }

    try {
      // Step 1: Add the magnet (save to RAM for streaming)
      final torrentId = LibtorrentFlutter.instance.addMagnet(magnetLink, null, true);
      if (hash != null) {
        _activeTorrents[hash] = torrentId;
      }
      debugPrint('[TorrentStream] Added magnet, torrentId=$torrentId');

      // Step 2: Wait for metadata
      final files = await _waitForMetadata(torrentId);
      if (files == null || files.isEmpty) {
        debugPrint('[TorrentStream] No files found in torrent');
        return null;
      }

      // Step 3: Select the right file
      final selectedIndex = _selectFile(files, season: season, episode: episode, preferredIdx: fileIdx);
      if (selectedIndex == null) {
        debugPrint('[TorrentStream] No suitable video file found');
        return null;
      }

      debugPrint('[TorrentStream] Selected file index $selectedIndex: ${files.firstWhere((f) => f.index == selectedIndex).name}');

      // Step 4: Start the stream (500MB RAM cache for smooth playback)
      final streamInfo = LibtorrentFlutter.instance.startStream(
        torrentId,
        fileIndex: selectedIndex,
        maxCacheBytes: 500 * 1024 * 1024,
      );

      if (hash != null) {
        _activeStreams[hash] = streamInfo.id;
      }

      debugPrint('[TorrentStream] Stream started: ${streamInfo.url}');
      return streamInfo.url;
    } catch (e) {
      debugPrint('[TorrentStream] streamTorrent error: $e');
      return null;
    }
  }

  // ─── Metadata polling ───────────────────────────────────────────────────

  Future<List<FileInfo>?> _waitForMetadata(int torrentId, {Duration timeout = const Duration(seconds: 45)}) async {
    final completer = Completer<List<FileInfo>?>();
    StreamSubscription? sub;

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        debugPrint('[TorrentStream] Metadata timeout after ${timeout.inSeconds}s');
        sub?.cancel();
        completer.complete(null);
      }
    });

    sub = LibtorrentFlutter.instance.torrentUpdates.listen((updates) {
      if (completer.isCompleted) return;
      if (updates.containsKey(torrentId)) {
        final info = updates[torrentId]!;
        if (info.hasMetadata) {
          timer.cancel();
          sub?.cancel();
          final files = LibtorrentFlutter.instance.getFiles(torrentId);
          if (!completer.isCompleted) completer.complete(files);
        }
      }
    });

    // Also check if metadata is already available
    try {
      final files = LibtorrentFlutter.instance.getFiles(torrentId);
      if (files.isNotEmpty) {
        timer.cancel();
        sub.cancel();
        if (!completer.isCompleted) completer.complete(files);
      }
    } catch (_) {
      // Not ready yet, wait for updates
    }

    return completer.future;
  }

  // ─── File selection ─────────────────────────────────────────────────────

  int? _selectFile(List<FileInfo> files, {int? season, int? episode, int? preferredIdx}) {
    // Filter to streamable video files
    final videoFiles = files.where((f) => f.isStreamable && _isVideoFile(f.name)).toList();
    if (videoFiles.isEmpty) {
      // Fallback: any streamable file
      final streamable = files.where((f) => f.isStreamable).toList();
      if (streamable.isEmpty) return null;
      streamable.sort((a, b) => b.size.compareTo(a.size));
      return streamable.first.index;
    }

    // 1. Season/episode match
    if (season != null && episode != null) {
      final s = 'S${season.toString().padLeft(2, '0')}';
      final e = 'E${episode.toString().padLeft(2, '0')}';
      final episodeMatches = videoFiles
          .where((f) => f.name.toUpperCase().contains(s) && f.name.toUpperCase().contains(e))
          .toList();
      if (episodeMatches.isNotEmpty) {
        episodeMatches.sort((a, b) => b.size.compareTo(a.size));
        return episodeMatches.first.index;
      }
    }

    // 2. Preferred index (from Stremio addon)
    if (preferredIdx != null) {
      final match = videoFiles.where((f) => f.index == preferredIdx).toList();
      if (match.isNotEmpty) return match.first.index;
    }

    // 3. Largest video file
    videoFiles.sort((a, b) => b.size.compareTo(a.size));
    return videoFiles.first.index;
  }

  bool _isVideoFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.mkv') || lower.endsWith('.mp4') || lower.endsWith('.avi') ||
        lower.endsWith('.webm') || lower.endsWith('.mov') || lower.endsWith('.wmv') ||
        lower.endsWith('.flv') || lower.endsWith('.m4v') || lower.endsWith('.ts');
  }

  // ─── Torrent management ──────────────────────────────────────────────────

  /// Removes/disposes a torrent and stops its streams.
  void removeTorrent(String magnetOrHash) {
    final hash = _extractHash(magnetOrHash);
    final key = hash ?? magnetOrHash;

    if (_activeStreams.containsKey(key)) {
      _safeStopStream(_activeStreams[key]!);
      _activeStreams.remove(key);
    }

    if (_activeTorrents.containsKey(key)) {
      final torrentId = _activeTorrents[key]!;
      _safeDisposeTorrent(torrentId);
      _activeTorrents.remove(key);
      _latestUpdates.remove(torrentId);
      debugPrint('[TorrentStream] Removed torrent $key');
    }
  }

  // ─── Statistics ──────────────────────────────────────────────────────────

  /// Returns stats for a torrent, or null if unavailable.
  TorrentStats? getTorrentStats(String magnetOrHash) {
    final hash = _extractHash(magnetOrHash);
    final key = hash ?? magnetOrHash;
    final torrentId = _activeTorrents[key];
    if (torrentId == null) return null;

    final info = _latestUpdates[torrentId];
    if (info == null) return null;

    final speedMbps = info.downloadRate / 1024 / 1024;

    // Get buffer from stream info
    double bufferPct = 0;
    final streamId = _activeStreams[key];
    if (streamId != null) {
      final streamInfo = _latestStreamUpdates[streamId];
      if (streamInfo != null) {
        bufferPct = streamInfo.bufferPct;
      }
    }

    return TorrentStats(
      speedMbps: speedMbps,
      activePeers: info.numPeers,
      totalPeers: info.numPeers + info.numSeeds,
      cachePercent: info.progress * 100,
      loadedBytes: info.totalDone,
      totalBytes: info.totalWanted,
      hash: key,
      isConnected: info.numPeers > 0,
      bufferPct: bufferPct,
    );
  }

  /// Streams stats at regular interval for a torrent.
  Stream<TorrentStats> statsStream(
    String magnetOrHash, {
    Duration interval = const Duration(seconds: 1),
  }) {
    final controller = StreamController<TorrentStats>();
    Timer? timer;

    controller.onListen = () {
      timer = Timer.periodic(interval, (_) {
        final stats = getTorrentStats(magnetOrHash);
        if (stats != null && !controller.isClosed) {
          controller.add(stats);
        }
      });
    };

    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // ─── Stop / cleanup ─────────────────────────────────────────────────────

  Future<void> stop() async {
    for (final streamId in _activeStreams.values) {
      _safeStopStream(streamId);
    }
    _activeStreams.clear();

    for (final torrentId in _activeTorrents.values) {
      _safeDisposeTorrent(torrentId);
    }
    _activeTorrents.clear();
    _latestUpdates.clear();
    _latestStreamUpdates.clear();

    debugPrint('[TorrentStream] All torrents stopped.');
  }

  Future<void> cleanup() async {
    await stop();
    _torrentUpdatesSub?.cancel();
    _torrentUpdatesSub = null;
    _streamUpdatesSub?.cancel();
    _streamUpdatesSub = null;
    _disposedTorrentIds.clear();
    _disposedStreamIds.clear();
    _setState(EngineState.stopped);
    debugPrint('[TorrentStream] Engine cleaned up.');
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void _safeStopStream(int streamId) {
    if (_disposedStreamIds.contains(streamId)) return;
    _disposedStreamIds.add(streamId);
    try {
      LibtorrentFlutter.instance.stopStream(streamId);
    } catch (e) {
      debugPrint('[TorrentStream] Stop stream error: $e');
    }
  }

  void _safeDisposeTorrent(int torrentId) {
    if (_disposedTorrentIds.contains(torrentId)) return;
    _disposedTorrentIds.add(torrentId);
    try {
      LibtorrentFlutter.instance.disposeTorrent(torrentId);
    } catch (e) {
      debugPrint('[TorrentStream] Dispose torrent error: $e');
    }
  }

  static final _hashRegExp = RegExp(r'[0-9a-fA-F]{40}');

  String? _extractHash(String magnetOrHash) {
    final match = _hashRegExp.firstMatch(magnetOrHash);
    return match?.group(0)?.toLowerCase();
  }

  void _setState(EngineState s) {
    if (_state == s) return;
    _state = s;
    onStateChanged?.call(s);
  }
}
