import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/models/stream_models.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:streame/core/repositories/addon_repository.dart';
import 'package:streame/core/repositories/profile_repository.dart';
import 'package:streame/core/repositories/home_cache_repository.dart';
import 'package:streame/core/repositories/trakt_repository.dart';
import 'package:streame/core/repositories/tmdb_repository.dart';
import 'package:streame/core/services/torrent_stream_service.dart';
import 'package:streame/features/home/data/models/media_item.dart';
import 'package:streame/core/repositories/skip_intro_repository.dart';
import 'package:streame/shared/widgets/next_episode_overlay.dart';
import 'package:streame/shared/widgets/player_loading_screen.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';
import 'package:streame/core/providers/shared_providers.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String mediaType;
  final int mediaId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? imdbId;
  final String? streamUrl;
  final String? preferredAddonId;
  final String? preferredSourceName;
  final String? preferredBingeGroup;
  final int? startPositionMs;

  const PlayerScreen({
    super.key,
    required this.mediaType,
    required this.mediaId,
    this.seasonNumber,
    this.episodeNumber,
    this.imdbId,
    this.streamUrl,
    this.preferredAddonId,
    this.preferredSourceName,
    this.preferredBingeGroup,
    this.startPositionMs,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  Player? _player;
  VideoController? _videoController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _hasStartedPlayback = false;
  bool _showControls = true;
  bool _showSourceSelector = false;
  String? _sourceFilter; // null = All, addon name = filtered
  TorrentStats? _torrentStats;
  String? _activeMagnet; // Track active magnet for stats lookup
  Timer? _torrentStatsTimer;
  Timer? _playbackStartTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  String _streamPhase = 'idle';
  String _streamStatusText = '';
  double _streamProgress = 0.0;
  int _selectedSourceIndex = 0;
  String? _mediaTitle;
  String? _backdropUrl;
  String? _logoUrl;
  String? _posterPath;
  Timer? _controlsTimer;

  // Track selection state
  List<AudioTrack> _audioTracks = [];
  List<SubtitleTrack> _subtitleTracks = [];
  AudioTrack _selectedAudioTrack = AudioTrack.auto();
  SubtitleTrack _selectedSubtitleTrack = SubtitleTrack.no();
  bool _preferredAudioApplied = false;
  bool _preferredSubtitleApplied = false;
  // External (addon) subtitles
  List<Map<String, dynamic>> _externalSubtitles = [];
  bool _isFetchingSubs = false;
  String? _selectedExternalSubUrl;

  double _subtitleFontSize = 32.0;
  double _subtitleBgOpacity = 0.55;
  int _subtitleDelayMs = 0;

  final List<AddonStreamResult> _streamResults = [];
  final List<StreamSubscription> _subscriptions = [];

  /// Ensure player is created lazily (safe on emulators where native init may fail)
  Player get _p => _player!;

  bool get _hasPlayer => _player != null;

  bool _showSkipOverlay = false;
  String _skipDirection = '';

  // Skip intro state
  SkipInterval? _activeSkipInterval;
  List<SkipInterval> _skipIntervals = [];

  // Next episode state
  bool _showNextEpisode = false;
  String? _nextEpisodeTitle;
  int? _nextSeason;
  int? _nextEpisode;

  // Progress saving debounce
  DateTime? _lastSaveTime;
  Duration _lastSavedPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadMediaInfo();
    _loadSkipIntervals();
    _loadSubtitleSettings();
    // Pre-create Player to detect native init failure early (before stream resolution)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _player ??= Player(configuration: const PlayerConfiguration(
          bufferSize: 64 * 1024 * 1024,
        ));
        debugPrint('Player: native Player() created successfully');
        _applyMpvPerformanceProps();
      } catch (e) {
        debugPrint('Player: native Player() creation failed: $e');
        _setPhase('error', 1.0);
        setState(() => _streamPhase = 'Video player failed to initialize. Try on a real device.');
        return;
      }
      _resolveAndPlay();
    });
  }

  /// Single method to load title, backdrop, and logo — avoids 2-3 redundant TMDB calls
  Future<void> _loadMediaInfo() async {
    try {
      final repo = ref.read(tmdbRepositoryProvider);
      final mediaType = widget.mediaType == 'tv' ? MediaType.tv : MediaType.movie;
      MediaItem? details;
      if (mediaType == MediaType.tv) {
        details = await repo.getTvDetails(widget.mediaId);
      } else {
        details = await repo.getMovieDetails(widget.mediaId);
      }
      if (mounted && details != null) {
        final bd = details.backdrop;
        final logoPath = await repo.getLogoPath(widget.mediaId, mediaType: mediaType);
        if (mounted) {
          setState(() {
            _mediaTitle = details!.title;
            _posterPath = details.image.isNotEmpty ? details.image : null;
            _backdropUrl = (bd != null && bd.isNotEmpty)
                ? (bd.startsWith('http') ? bd : 'https://image.tmdb.org/t/p/original$bd')
                : null;
            _logoUrl = (logoPath != null && logoPath.isNotEmpty)
                ? repo.getLogoUrl(logoPath, size: 'w500')
                : null;
          });
        }
      }
    } catch (_) {}
  }

  void _loadSubtitleSettings() {
    final prefs = ref.read(sharedPreferencesProvider);
    _subtitleFontSize = prefs.getDouble('settings_sub_font_size') ?? 32.0;
    _subtitleBgOpacity = prefs.getDouble('settings_sub_bg_opacity') ?? 0.55;
    _subtitleDelayMs = prefs.getInt('settings_sub_delay_ms') ?? 0;
  }

  Future<void> _saveSubtitleSettings({
    double? fontSize,
    double? bgOpacity,
    int? delayMs,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (fontSize != null) {
      _subtitleFontSize = fontSize;
      await prefs.setDouble('settings_sub_font_size', fontSize);
    }
    if (bgOpacity != null) {
      _subtitleBgOpacity = bgOpacity;
      await prefs.setDouble('settings_sub_bg_opacity', bgOpacity);
    }
    if (delayMs != null) {
      _subtitleDelayMs = delayMs;
      await prefs.setInt('settings_sub_delay_ms', delayMs);
    }
    if (mounted) setState(() {});
    await _applySubtitleDelay();
  }

  Future<void> _applySubtitleDelay() async {
    if (!_hasPlayer) return;
    try {
      final platform = _p.platform;
      if (platform is NativePlayer) {
        final seconds = (_subtitleDelayMs / 1000.0).toStringAsFixed(3);
        await platform.setProperty('sub-delay', seconds);
      }
    } catch (_) {}
  }

  void _applyMpvPerformanceProps() {
    if (!_hasPlayer) return;
    try {
      final platform = _p.platform;
      if (platform is NativePlayer) {
        platform.setProperty('hwdec', 'auto');
        platform.setProperty('demuxer-max-bytes', '67108864');
        platform.setProperty('demuxer-max-back-bytes', '33554432');
        platform.setProperty('cache', 'yes');
        platform.setProperty('video-sync', 'audio');
        platform.setProperty('interpolation', 'yes');
      }
    } catch (_) {}
  }

  String _languageDisplayName(String? code) {
    final c = (code ?? '').trim().toLowerCase();
    if (c.isEmpty || c == 'und') return 'Unknown';
    switch (c) {
      case 'ar':
      case 'ara':
        return 'Arabic';
      case 'en':
      case 'eng':
        return 'English';
      case 'fr':
      case 'fra':
      case 'fre':
        return 'French';
      case 'es':
      case 'spa':
        return 'Spanish';
      case 'tr':
      case 'tur':
        return 'Turkish';
      case 'hi':
      case 'hin':
        return 'Hindi';
      case 'ur':
      case 'urd':
        return 'Urdu';
      default:
        return c.length <= 3 ? c.toUpperCase() : c;
    }
  }

  /// Normalize a stream URL (add scheme if missing, handle bare hosts)
  String? _normalizeUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final url = raw.trim();
    // Magnet URIs are handled by TorrentStreamService, not media_kit directly
    if (url.toLowerCase().startsWith('magnet:')) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.contains('.') && !url.contains('://')) return 'https://$url';
    return url;
  }

  /// Build a magnet URI from a StreamSource's infoHash + trackers
  String? _buildMagnet(StreamSource stream) {
    final infoHash = stream.infoHash;
    if (infoHash == null || infoHash.isEmpty) return null;

    final cleanHash = infoHash.toLowerCase().replaceAll('urn:btih:', '').replaceAll('btih:', '');
    if (cleanHash.isEmpty) return null;
    final dn = (stream.behaviorHints?.filename ?? stream.source).isNotEmpty
        ? (stream.behaviorHints?.filename ?? stream.source)
        : 'video';
    final trackers = stream.sources
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => s.replaceFirst('tracker:', ''))
        .where((s) => s.startsWith('http://') || s.startsWith('https://') || s.startsWith('udp://'))
        .toList();

    final magnetBuf = StringBuffer('magnet:?xt=urn:btih:$cleanHash&dn=${Uri.encodeComponent(dn)}');
    for (final tr in trackers) {
      magnetBuf.write('&tr=${Uri.encodeComponent(tr)}');
    }
    return magnetBuf.toString();
  }

  /// Resolve a torrent stream via libtorrent_flutter (built-in engine)
  Future<String?> _resolveViaTorrentEngine(StreamSource stream) async {
    String? magnet;

    // Case 1: stream.url is already a magnet link
    if (stream.url != null && stream.url!.toLowerCase().startsWith('magnet:')) {
      magnet = stream.url!;
    } else {
      // Case 2: stream has infoHash — build magnet
      magnet = _buildMagnet(stream);
    }

    if (magnet == null) return null;

    debugPrint('Player: resolving via torrent engine: ${magnet.substring(0, magnet.length.clamp(0, 80))}');

    // Track active magnet for stats and start polling
    _activeMagnet = magnet;
    _startTorrentStatsPolling();

    final torrent = TorrentStreamService();
    final url = await torrent.streamTorrent(
      magnet,
      season: widget.seasonNumber,
      episode: widget.episodeNumber,
    );

    if (url != null) {
      debugPrint('Player: torrent stream URL: $url');
    } else {
      _stopTorrentStatsPolling();
    }

    return url;
  }

  void _startTorrentStatsPolling() {
    _torrentStatsTimer?.cancel();
    _torrentStatsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeMagnet != null && mounted) {
        final stats = TorrentStreamService().getTorrentStats(_activeMagnet!);
        if (stats != null) {
          setState(() => _torrentStats = stats);
        }
      }
    });
  }

  void _stopTorrentStatsPolling() {
    _torrentStatsTimer?.cancel();
    _torrentStatsTimer = null;
  }

  Future<void> _resolveAndPlay() async {
    // If a direct stream URL was provided, resolve and play
    if (widget.streamUrl != null && widget.streamUrl!.isNotEmpty) {
      final url = widget.streamUrl!;
      // Magnet link — resolve via torrent engine
      if (url.toLowerCase().startsWith('magnet:')) {
        _setPhase('loading', 0.3);
        final torrent = TorrentStreamService();
        final streamUrl = await torrent.streamTorrent(
          url,
          season: widget.seasonNumber,
          episode: widget.episodeNumber,
        );
        if (streamUrl != null && mounted) {
          // Pre-flight: verify the local stream URL is reachable before passing to player
          final reachable = await _checkStreamReachable(streamUrl);
          if (!reachable && mounted) {
            _setPhase('error', 1.0);
            setState(() {
              _streamStatusText = 'Local stream server not reachable. The torrent engine may have failed to start the HTTP server.';
              _showSourceSelector = true;
            });
            return;
          }
          if (mounted) await _initPlayer(streamUrl);
        } else if (mounted) {
          _setPhase('error', 1.0);
          setState(() => _streamStatusText = 'Failed to start torrent stream.');
        }
        return;
      }
      // HTTP URL — normalize and play
      final normalized = _normalizeUrl(url);
      if (normalized == null) {
        _setPhase('error', 1.0);
        setState(() => _streamStatusText = 'Invalid stream URL.');
        return;
      }
      _setPhase('loading', 0.3);
      await _initPlayer(normalized);
      return;
    }

    // Otherwise resolve streams from addon repository progressively
    _setPhase('resolving', 0.1);

    try {
      final addonRepo = ref.read(addonManagerRepositoryProvider);
      final type = widget.mediaType == 'tv' ? 'series' : 'movie';
      final imdbId = widget.imdbId ?? '';

      // Use progressive resolution
      final progressStream = addonRepo.resolveStreamsProgressive(
        type: type,
        imdbId: imdbId,
        tmdbId: widget.mediaId.toString(),
        season: widget.seasonNumber,
        episode: widget.episodeNumber,
      );

      StreamSource? bestStream;

      await for (final progress in progressStream) {
        if (!mounted) break;

        _setPhase('resolving', progress.progress);

        // Populate _streamResults for source selector
        if (progress.addonResults.isNotEmpty) {
          setState(() {
            _streamResults.clear();
            _streamResults.addAll(progress.addonResults);
          });
        }

        // Auto-select best stream after 2 addons complete or when final
        if ((progress.isFinal || progress.completedAddons >= 2) && bestStream == null) {
          if (progress.allStreams.isNotEmpty) {
            // Try streams in sorted order until we find a playable one
            final sorted = _sortStreamsForPlayback(progress.allStreams);
            debugPrint('Auto-select: ${sorted.length} candidates, top url=${sorted.first.url?.substring(0, (sorted.first.url?.length ?? 0).clamp(0, 60))}, infoHash=${sorted.first.infoHash?.substring(0, (sorted.first.infoHash?.length ?? 0).clamp(0, 12))}');
            for (final candidate in sorted) {
              final playableUrl = await _resolvePlayableUrl(candidate);
              if (playableUrl != null) {
                bestStream = candidate;
                debugPrint('Auto-select: playing $playableUrl');
                _setPhase('loading', 0.5);
                await _initPlayer(playableUrl);
                break;
              }
            }
            if (bestStream == null) {
              debugPrint('Auto-select: no playable HTTP URL found among ${sorted.length} streams');
            }
          }
        }

        // Update phase label with progress
        if (progress.totalAddons > 0) {
          setState(() {
            _streamStatusText = 'Searching ${progress.completedAddons}/${progress.totalAddons} sources...';
          });
        }
      }

      // If we still haven't found a stream, show error
      if (!mounted || bestStream == null) {
        _setPhase('error', 1.0);
        setState(() {
          _streamStatusText = 'No playable streams found. Torrent streams will be resolved automatically.';
          _showSourceSelector = true;
        });
      }
    } catch (e) {
      if (mounted) _setPhase('error', 1.0);
    }
  }

  /// Resolve a playable HTTP URL from a StreamSource
  /// Handles: direct HTTP URLs, magnet/infoHash via libtorrent_flutter
  Future<String?> _resolvePlayableUrl(StreamSource stream) async {
    // 1. Direct HTTP URL
    final direct = _normalizeUrl(stream.url);
    if (direct != null) return direct;

    // 2. Magnet URL or infoHash — resolve via built-in torrent engine
    if ((stream.url != null && stream.url!.toLowerCase().startsWith('magnet:')) ||
        (stream.infoHash != null && stream.infoHash!.isNotEmpty)) {
      final torrentUrl = await _resolveViaTorrentEngine(stream);
      if (torrentUrl != null) return torrentUrl;
    }

    return null;
  }

  StreamSource? _getBestStream(AddonStreamResult result) {
    if (result.streams.isEmpty) return null;
    // Prefer highest quality
    final sorted = List<StreamSource>.from(result.streams)
      ..sort((a, b) {
        final qA = _qualityScore(a.quality);
        final qB = _qualityScore(b.quality);
        return qB.compareTo(qA);
      });
    return sorted.first;
  }

  int _qualityScore(String q) {
    if (q.contains('4K') || q.contains('2160')) return 40;
    if (q.contains('1080')) return 30;
    if (q.contains('720')) return 20;
    if (q.contains('480')) return 10;
    return 0;
  }

  /// Sort streams for playback: prefer cached/direct HTTP, then quality
  List<StreamSource> _sortStreamsForPlayback(List<StreamSource> streams) {
    final sorted = List<StreamSource>.from(streams)
      ..sort((a, b) {
        final cachedA = a.behaviorHints?.cached == true ? 100 : 0;
        final cachedB = b.behaviorHints?.cached == true ? 100 : 0;
        final directA = (a.url != null && a.url!.startsWith('http')) ? 50 : 0;
        final directB = (b.url != null && b.url!.startsWith('http')) ? 50 : 0;
        final qA = _qualityScore(a.quality) + cachedA + directA;
        final qB = _qualityScore(b.quality) + cachedB + directB;
        return qB.compareTo(qA);
      });
    return sorted;
  }

  Future<void> _initPlayer(String url) async {
    try {
      // Validate URL before passing to native player
      if (url.isEmpty || url.startsWith('magnet:')) {
        debugPrint('Player: rejected invalid URL');
        _setPhase('error', 1.0);
        setState(() => _streamStatusText = 'Invalid stream URL.');
        return;
      }

      // Parse and validate URL structure
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        debugPrint('Player: rejected non-HTTP URL: $url');
        _setPhase('error', 1.0);
        setState(() => _streamStatusText = 'Only HTTP streams are supported. P2P requires TorrServer.');
        return;
      }

      debugPrint('Player: opening $url');

      // Create player lazily — isolate in try-catch since native init may crash
      if (_player == null) {
        try {
          _player = Player(configuration: const PlayerConfiguration(
            bufferSize: 64 * 1024 * 1024,
          ));
        } catch (e) {
          debugPrint('Player: native Player() creation failed: $e');
          _setPhase('error', 1.0);
          setState(() => _streamStatusText = 'Video player failed to initialize. Try on a real device.');
          return;
        }
      }

      // Open with timeout to prevent hanging forever on bad URLs
      try {
        await _p.open(Media(url)).timeout(const Duration(seconds: 15));
      } on TimeoutException {
        debugPrint('Player: open() timed out for $url');
        rethrow;
      } catch (e) {
        debugPrint('Player: open() failed: $e');
        rethrow;
      }
      _setPhase('ready', 1.0);
      if (mounted) setState(() => _streamStatusText = '');

      if (widget.startPositionMs != null && widget.startPositionMs! > 0) {
        await _p.seek(Duration(milliseconds: widget.startPositionMs!));
      }

      // Create video controller
      _videoController = VideoController(_p);

      // Apply subtitle settings to mpv (e.g. subtitle delay) as soon as the player is ready.
      await _applySubtitleDelay();
      _applyMpvPerformanceProps();

      setState(() {
        _isInitialized = true;
        _hasStartedPlayback = false;
        _duration = _p.state.duration;
        _torrentStats = null; // Clear stats once video starts
      });
      _stopTorrentStatsPolling();

      _subscriptions.add(_p.stream.position.listen((position) {
        if (mounted && _hasPlayer) {
          setState(() {
            _position = position;
            _isPlaying = _p.state.playing;
            // Nuvio parity: mark initial load complete only when video is actually
            // playing (not buffering) and position has advanced past zero
            if (!_hasStartedPlayback && _isPlaying && !_isBuffering) {
              _hasStartedPlayback = true;
            }
          });
          _checkSkipIntervals();
          _checkNextEpisode();
          if (position.inSeconds % 10 == 0 && position.inSeconds > 0) {
            _saveProgress();
          }
        }
      }));

      _subscriptions.add(_p.stream.duration.listen((duration) {
        if (mounted && _hasPlayer) {
          setState(() => _duration = duration);
        }
      }));

      _subscriptions.add(_p.stream.playing.listen((playing) {
        if (mounted && _hasPlayer) {
          setState(() {
            _isPlaying = playing;
            // Don't set _hasStartedPlayback here — wait for position to advance
            // while not buffering (Nuvio parity: initialLoadCompleted = !isLoading)
          });
        }
        if (playing) {
          _playbackStartTimer?.cancel();
          _playbackStartTimer = null;
        }
      }));

      _subscriptions.add(_p.stream.buffering.listen((buffering) {
        if (mounted && _hasPlayer) {
          setState(() {
            _isBuffering = buffering;
            // Nuvio parity: when buffering ends and position > 0, mark load complete
            if (!buffering && !_hasStartedPlayback && _isPlaying) {
              _hasStartedPlayback = true;
            }
          });
        }
      }));

      // Listen for track changes (audio/subtitle tracks become available)
      _subscriptions.add(_p.stream.tracks.listen((tracks) {
        if (!mounted || !_hasPlayer) return;
        final audioList = tracks.audio.where((t) => t.id != 'no' && t.id != 'auto').toList();
        final subList = tracks.subtitle.where((t) => t.id != 'no' && t.id != 'auto').toList();
        setState(() {
          _audioTracks = audioList;
          _subtitleTracks = subList;
          _selectedAudioTrack = _p.state.track.audio;
          _selectedSubtitleTrack = _p.state.track.subtitle;
        });
        _applyPreferredTracks();
      }));

      await _p.play();

      // Watchdog: on emulator / unsupported codecs, mpv may open but never start playback.
      // If we don't start within a short window, show a useful error & open source selector.
      _playbackStartTimer?.cancel();
      _playbackStartTimer = Timer(const Duration(seconds: 12), () {
        if (!mounted) return;
        final stillNotPlaying = !_p.state.playing;
        final stillAtStart = _position == Duration.zero;
        if (stillNotPlaying && stillAtStart) {
          _setPhase('error', 1.0);
          setState(() {
            _streamStatusText =
                'Playback did not start. This stream may be unsupported on the emulator (REMUX/HEVC) — try another source or a real device.';
            _showSourceSelector = true;
          });
        }
      });

      _startControlsTimer();
    } catch (e) {
      debugPrint('Player init error: $e');
      _setPhase('error', 1.0);
      setState(() {
        _streamStatusText = e is TimeoutException
            ? 'Stream took too long to load. Try another source.'
            : 'Failed to play stream. Try another source.';
        if (_streamResults.isNotEmpty) _showSourceSelector = true;
      });
    }
  }

  void _setPhase(String phase, double progress) {
    setState(() {
      _streamPhase = phase;
      _streamProgress = progress;
    });
  }

  /// Pre-flight check: verify a local stream URL is actually reachable.
  /// The libtorrent engine may report a URL before its HTTP server is ready.
  Future<bool> _checkStreamReachable(String url) async {
    if (!url.contains('127.0.0.1') && !url.contains('localhost')) return true;
    try {
      final uri = Uri.parse(url);
      final socket = await Socket.connect(
        uri.host,
        uri.port,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy();
      debugPrint('Player: pre-flight OK — ${uri.host}:${uri.port} is reachable');
      return true;
    } catch (e) {
      debugPrint('Player: pre-flight FAIL — $url not reachable: $e');
      return false;
    }
  }

  Future<void> _saveProgress() async {
    try {
      // Debounce: skip if saved less than 8 seconds ago and position hasn't changed significantly
      final now = DateTime.now();
      if (_lastSaveTime != null &&
          now.difference(_lastSaveTime!).inSeconds < 8 &&
          (_position - _lastSavedPosition).abs().inSeconds < 5) {
        return;
      }

      final cacheRepo = ref.read(homeCacheRepositoryProvider);
      final progress = _duration.inSeconds > 0 ? _position.inSeconds / _duration.inSeconds : 0.0;

      await cacheRepo.updateContinueWatching(ContinueWatchingItem(
        tmdbId: widget.mediaId,
        mediaType: widget.mediaType,
        title: _mediaTitle ?? '',
        posterPath: _posterPath,
        backdropPath: _backdropUrl,
        season: widget.seasonNumber ?? 1,
        episode: widget.episodeNumber ?? 1,
        episodeTitle: _nextEpisodeTitle, // available if TV
        position: _position,
        totalDuration: _duration,
        imdbId: widget.imdbId,
      ));

      // Auto-remove completed items and add next episode for TV
      if (progress >= 0.90) {
        await cacheRepo.removeCompleted(
          widget.mediaId,
          widget.mediaType,
          widget.seasonNumber ?? 1,
          widget.episodeNumber ?? 1,
        );
        // If TV and we know the next episode, add it as "up next"
        if (widget.mediaType == 'tv' && _nextSeason != null && _nextEpisode != null) {
          await cacheRepo.addUpNext(ContinueWatchingItem(
            tmdbId: widget.mediaId,
            mediaType: widget.mediaType,
            title: _mediaTitle ?? '',
            posterPath: _posterPath,
            backdropPath: _backdropUrl,
            season: _nextSeason!,
            episode: _nextEpisode!,
            episodeTitle: _nextEpisodeTitle,
            imdbId: widget.imdbId,
          ));
        }
      }

      _lastSaveTime = now;
      _lastSavedPosition = _position;
    } catch (_) {}
  }

  Future<void> _scrobbleToTrakt() async {
    try {
      final traktRepo = ref.read(traktRepositoryProvider);
      if (!traktRepo.isLinked()) return;
      final imdbId = widget.imdbId;
      if (imdbId == null || imdbId.isEmpty) return;

      // Scrobble progress
      final progress = _duration.inSeconds > 0 ? (_position.inSeconds / _duration.inSeconds * 100).round() : 0;
      if (progress >= 90) {
        // Mark as watched
        await traktRepo.addToHistory(
          imdbId: imdbId,
          mediaType: widget.mediaType,
          season: widget.seasonNumber,
          episode: widget.episodeNumber,
        );
      }
    } catch (_) {}
  }

  // ─── Skip Intro ───

  Future<void> _loadSkipIntervals() async {
    if (widget.mediaType != 'tv' || widget.seasonNumber == null || widget.episodeNumber == null) return;
    final repo = ref.read(skipIntroRepositoryProvider);
    final intervals = await repo.getSkipIntervals(
      imdbId: widget.imdbId,
      season: widget.seasonNumber!,
      episode: widget.episodeNumber!,
    );
    if (mounted) setState(() => _skipIntervals = intervals);
  }

  void _checkSkipIntervals() {
    if (_skipIntervals.isEmpty) return;
    final posMs = _position.inMilliseconds;
    SkipInterval? active;
    for (final interval in _skipIntervals) {
      if (posMs >= interval.startMs && posMs < interval.endMs) {
        active = interval;
        break;
      }
    }
    if (active != _activeSkipInterval) {
      setState(() => _activeSkipInterval = active);
    }
  }

  void _onSkipIntro() {
    if (_activeSkipInterval == null || !_hasPlayer) return;
    _p.seek(Duration(milliseconds: _activeSkipInterval!.endMs));
    setState(() => _activeSkipInterval = null);
  }

  // ─── Next Episode ───

  void _checkNextEpisode() {
    if (widget.mediaType != 'tv') return;
    if (_duration.inSeconds == 0) return;

    // Show next episode overlay when 30 seconds from end
    final remaining = _duration - _position;
    if (remaining.inSeconds <= 30 && !_showNextEpisode) {
      setState(() => _showNextEpisode = true);
      _loadNextEpisodeInfo();
    } else if (remaining.inSeconds > 30 && _showNextEpisode) {
      setState(() => _showNextEpisode = false);
    }
  }

  Future<void> _loadNextEpisodeInfo() async {
    if (widget.seasonNumber == null || widget.episodeNumber == null) return;
    try {
      final repo = ref.read(tmdbRepositoryProvider);
      final nextEp = widget.episodeNumber! + 1;
      final seasonData = await repo.getSeasonDetails(widget.mediaId, widget.seasonNumber!);
      if (seasonData != null && mounted) {
        final episodes = seasonData['episodes'] as List? ?? [];
        final next = episodes.where((e) => (e as Map)['episode_number'] == nextEp).firstOrNull;
        if (next != null) {
          setState(() {
            _nextEpisodeTitle = next['name'] as String?;
            _nextSeason = widget.seasonNumber;
            _nextEpisode = nextEp;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _saveProgress();
    _scrobbleToTrakt();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _controlsTimer?.cancel();
    _torrentStatsTimer?.cancel();
    _playbackStartTimer?.cancel();
    _player?.dispose();
    // Cleanup active torrent stream (keep engine alive for next play)
    TorrentStreamService().stop();
    super.dispose();
  }

  /// Safely exit the player — dispose native resources first to prevent
  /// the FlutterJNI crash when the video surface outlives the activity.
  void _exitPlayer() {
    _controlsTimer?.cancel();
    _torrentStatsTimer?.cancel();
    _playbackStartTimer?.cancel();
    // Cancel stream subscriptions BEFORE disposing player to prevent null crashes
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _player?.dispose();
    _player = null;
    _videoController = null;
    _isInitialized = false;
    TorrentStreamService().stop();
    // The player is opened via context.go() from details, so there's nothing
    // to pop back to. Navigate directly to the details screen.
    context.go('/details/${widget.mediaType}/${widget.mediaId}'
        '${widget.seasonNumber != null ? '?initialSeason=${widget.seasonNumber}' : ''}'
        '${widget.episodeNumber != null ? '&initialEpisode=${widget.episodeNumber}' : ''}');
  }

  void _togglePlay() async {
    if (!_hasPlayer || !_isInitialized) return;
    if (_isPlaying) {
      await _p.pause();
      _saveProgress(); // Save progress when user pauses
    } else {
      await _p.play();
    }
  }

  void _seekForward() async {
    if (!_hasPlayer || !_isInitialized) return;
    await _p.seek(_position + const Duration(seconds: 10));
    _showSkip('forward');
  }

  void _seekBackward() async {
    if (!_hasPlayer || !_isInitialized) return;
    final newPos = _position - const Duration(seconds: 10);
    await _p.seek(newPos < Duration.zero ? Duration.zero : newPos);
    _showSkip('backward');
  }

  void _showSkip(String direction) {
    setState(() { _showSkipOverlay = true; _skipDirection = direction; });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showSkipOverlay = false);
    });
  }

  void _applyPreferredTracks() {
    if (!_hasPlayer || !_isInitialized) return;
    final prefs = ref.read(sharedPreferencesProvider);
    if (!_preferredAudioApplied && _audioTracks.isNotEmpty) {
      final lang = prefs.getString('settings_audio_lang') ?? 'en';
      if (lang != 'default') {
        final match = _audioTracks.firstWhere(
          (t) => t.language?.toLowerCase() == lang.toLowerCase(),
          orElse: () => _audioTracks.firstWhere(
            (t) => t.language?.toLowerCase().startsWith(lang.toLowerCase()) == true,
            orElse: () => AudioTrack.no(),
          ),
        );
        if (match.id != 'no' && match.id != _selectedAudioTrack.id) {
          _p.setAudioTrack(match);
          setState(() => _selectedAudioTrack = match);
        }
      }
      _preferredAudioApplied = true;
    }
    if (!_preferredSubtitleApplied && _subtitleTracks.isNotEmpty) {
      final lang = prefs.getString('settings_subtitle_lang') ?? '';
      if (lang.isNotEmpty && lang != 'none') {
        final match = _subtitleTracks.firstWhere(
          (t) => t.language?.toLowerCase() == lang.toLowerCase(),
          orElse: () => _subtitleTracks.firstWhere(
            (t) => t.language?.toLowerCase().startsWith(lang.toLowerCase()) == true,
            orElse: () => SubtitleTrack.no(),
          ),
        );
        if (match.id != 'no') {
          _p.setSubtitleTrack(match);
          setState(() => _selectedSubtitleTrack = match);
        }
      }
      _preferredSubtitleApplied = true;
    }
  }

  void _showSubtitlesMenu() {
    if (!_hasPlayer || !_isInitialized) return;
    setState(() {
      _subtitleTracks = _p.state.tracks.subtitle.where((t) => t.id != 'no' && t.id != 'auto').toList();
      _selectedSubtitleTrack = _p.state.track.subtitle;
    });
    // Fetch online subtitles but update the bottom sheet state (avoid rebuilding the whole player).
    _fetchAddonSubtitles(
      onFetching: (fetching) => setState(() => _isFetchingSubs = fetching),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      builder: (ctx) {
        var requestedOnline = false;
        return StatefulBuilder(builder: (ctx, setModalState) {
        final currentSub = _p.state.track.subtitle;
        final embedded = _subtitleTracks.where((t) => !_isExternalSub(t)).toList();
        final online = _externalSubtitles;

        // Re-fetch when sheet opens, but update modal state only.
        if (!requestedOnline) {
          requestedOnline = true;
          Future.microtask(() {
            _fetchAddonSubtitles(
              onFetching: (fetching) => setModalState(() => _isFetchingSubs = fetching),
              onResults: (r) => setModalState(() => _externalSubtitles = r),
            );
          });
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Subtitles',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showSubtitleSettingsSheet();
                    },
                    child: const Text('Settings', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
              if (_isFetchingSubs)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: LinearProgressIndicator(
                      color: Colors.white24, backgroundColor: Colors.white10),
                ),
              Expanded(
                child: ListView(children: [
                  _SubTile(
                    icon: Icons.close,
                    label: 'Off',
                    selected: currentSub.id == 'no' && _selectedExternalSubUrl == null,
                    onTap: () {
                      _selectedExternalSubUrl = null;
                      _p.setSubtitleTrack(SubtitleTrack.no());
                      setState(() => _selectedSubtitleTrack = SubtitleTrack.no());
                      Navigator.pop(ctx);
                    },
                  ),
                  if (embedded.isNotEmpty) ...[
                    const _SectionHeader('EMBEDDED'),
                    ...embedded.map((t) => _SubTile(
                      label: t.title ?? t.language ?? 'Track ${t.id}',
                      selected: t.id == currentSub.id && _selectedExternalSubUrl == null,
                      onTap: () {
                        _selectedExternalSubUrl = null;
                        _p.setSubtitleTrack(t);
                        setState(() => _selectedSubtitleTrack = t);
                        Navigator.pop(ctx);
                      },
                    )),
                  ],
                  if (online.isNotEmpty) ...[
                    const _SectionHeader('ONLINE'),
                    ...online.map((s) {
                      final url = s['url'] as String?;
                      final sel = url == _selectedExternalSubUrl;
                      final addonName = s['addon'] as String?;
                      return _SubTile(
                        label: s['display'] ?? 'Unknown',
                        subtitle: addonName ?? '',
                        selected: sel,
                        onTap: () {
                          if (url == null) return;
                          _selectedExternalSubUrl = url;
                          _p.setSubtitleTrack(SubtitleTrack.uri(
                            url,
                            title: s['display'],
                            language: s['language'] ?? 'und',
                          ));
                          setState(() => _selectedSubtitleTrack = SubtitleTrack.uri(
                            url,
                            title: s['display'],
                            language: s['language'] ?? 'und',
                          ));
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                  if (embedded.isEmpty && online.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                          child: Text('No subtitles found',
                              style: TextStyle(color: Colors.white38))),
                    ),
                ]),
              ),
            ],
          ),
        );
      });
      },
    );
  }

  bool _isExternalSub(SubtitleTrack t) {
    if (t.id.startsWith('http')) return true;
    return _externalSubtitles.any(
        (s) => s['display'] == t.title && s['language'] == t.language);
  }

  void _showAudioMenu() {
    if (!_hasPlayer || !_isInitialized) return;
    setState(() {
      _audioTracks = _p.state.tracks.audio.where((t) => t.id != 'no' && t.id != 'auto').toList();
      _selectedAudioTrack = _p.state.track.audio;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Audio Tracks',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            if (_audioTracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No audio tracks found',
                    style: TextStyle(color: Colors.white38)),
              )
            else
              ..._audioTracks.map((t) => _SubTile(
                icon: Icons.audiotrack,
                label: t.title ?? t.language ?? 'Track ${t.id}',
                selected: t.id == _selectedAudioTrack.id,
                onTap: () {
                  _p.setAudioTrack(t);
                  setState(() => _selectedAudioTrack = t);
                  Navigator.pop(ctx);
                },
              )),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchAddonSubtitles({
    void Function(List<Map<String, dynamic>> results)? onResults,
    void Function(bool fetching)? onFetching,
  }) async {
    if (_isFetchingSubs) return;
    _isFetchingSubs = true;
    if (mounted) setState(() {});
    onFetching?.call(true);

    try {
      final profileId = ref.read(activeProfileIdProvider);
      if (profileId == null) { setState(() => _isFetchingSubs = false); return; }
      final addonRepo = ref.read(addonRepositoryProvider(profileId));
      final imdbId = widget.imdbId;
      if (imdbId == null || imdbId.isEmpty) { setState(() => _isFetchingSubs = false); return; }

      final results = <Map<String, dynamic>>[];
      final type = widget.mediaType == 'tv' ? 'series' : 'movie';
      final addons = await addonRepo.getInstalledAddons();
      final http.Client httpClient = http.Client();

      // Only query addons that declare 'subtitles' in their resources
      final subtitleAddons = addons.where((addon) {
        if (!addon.isEnabled || addon.url == null) return false;
        final resNames = addon.manifest?.resources.map((r) => r.name).toSet();
        // If manifest resources are known, only include if 'subtitles' is listed
        // If unknown (legacy), include anyway as fallback
        return resNames == null || resNames.contains('subtitles');
      }).toList();

      await Future.wait(subtitleAddons.map((addon) async {
        try {
          final uri = Uri.parse(addon.url!);
          final segs = List<String>.from(uri.pathSegments)
            ..removeWhere((s) => s == 'manifest.json');
          final base = uri.replace(pathSegments: segs).toString().replaceAll(RegExp(r'/+$'), '');
          var subUrl = '$base/subtitles/$type/$imdbId.json';
          if (type == 'series' && widget.seasonNumber != null && widget.episodeNumber != null) {
            subUrl = '$base/subtitles/$type/$imdbId:${widget.seasonNumber}:${widget.episodeNumber}.json';
          }
          final response = await httpClient
              .get(Uri.parse(subUrl))
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            // Stremio addon protocol: response is { "subtitles": [...] } or just a list
            final subs = json is List ? json : (json['subtitles'] as List? ?? []);
            for (final sub in subs) {
              if (sub is Map<String, dynamic>) {
                final url = sub['url'] as String? ?? sub['Src'] as String?;
                final lang = sub['lang'] as String? ?? sub['language'] as String? ?? 'und';
                if (url != null && url.isNotEmpty) {
                  results.add({
                    'url': url,
                    'language': lang,
                    'display': _languageDisplayName(lang),
                    'addon': addon.name,
                  });
                }
              }
            }
          }
        } catch (_) {}
      }));

      httpClient.close();

      // Sort for stable UI.
      results.sort((a, b) {
        final la = (a['display'] as String? ?? '');
        final lb = (b['display'] as String? ?? '');
        final aa = (a['addon'] as String? ?? '');
        final ab = (b['addon'] as String? ?? '');
        final c = la.compareTo(lb);
        if (c != 0) return c;
        return aa.compareTo(ab);
      });

      _externalSubtitles = results;
      _isFetchingSubs = false;
      if (mounted) setState(() {});
      onResults?.call(results);
      onFetching?.call(false);
    } catch (_) {
      _isFetchingSubs = false;
      if (mounted) setState(() {});
      onFetching?.call(false);
    }
  }

  void _showSubtitleSettingsSheet() {
    if (!_hasPlayer || !_isInitialized) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E0E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        double fontSize = _subtitleFontSize;
        double bgOpacity = _subtitleBgOpacity;
        int delayMs = _subtitleDelayMs;
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Text(
                      'Subtitle settings',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Size
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Size', style: TextStyle(color: Colors.white70)),
                        Text(fontSize.toStringAsFixed(0), style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    Slider(
                      value: fontSize,
                      min: 16,
                      max: 48,
                      divisions: 32,
                      onChanged: (v) => setModalState(() => fontSize = v),
                      onChangeEnd: (v) => _saveSubtitleSettings(fontSize: v),
                    ),

                    // Background opacity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Background', style: TextStyle(color: Colors.white70)),
                        Text('${(bgOpacity * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    Slider(
                      value: bgOpacity,
                      min: 0.0,
                      max: 0.8,
                      divisions: 16,
                      onChanged: (v) => setModalState(() => bgOpacity = v),
                      onChangeEnd: (v) => _saveSubtitleSettings(bgOpacity: v),
                    ),

                    // Delay
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delay', style: TextStyle(color: Colors.white70)),
                        Text('${delayMs}ms', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    Slider(
                      value: delayMs.toDouble(),
                      min: -5000,
                      max: 5000,
                      divisions: 100,
                      onChanged: (v) => setModalState(() => delayMs = v.round()),
                      onChangeEnd: (v) => _saveSubtitleSettings(delayMs: v.round()),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'Netflix-like default: size 32, background 55%, delay 0ms',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _setSpeed(double speed) async {
    if (!_hasPlayer || !_isInitialized) return;
    await _p.setRate(speed);
    setState(() => _playbackSpeed = speed);
  }

  void _changeSource(int index) async {
    setState(() {
      _selectedSourceIndex = index;
      _showSourceSelector = false;
    });

    if (_hasPlayer) {
      await _p.pause();
      await _p.stop();
    }
    setState(() => _isInitialized = false);

    final stream = _getBestStream(_streamResults[index]);
    if (stream != null) {
      final playableUrl = await _resolvePlayableUrl(stream);
      if (playableUrl != null) {
        _setPhase('loading', 0.5);
        await _initPlayer(playableUrl);
      } else {
        _setPhase('error', 1.0);
        setState(() => _streamStatusText = 'P2P stream requires TorrServer. Configure it in Settings > Addons.');
      }
    } else {
      _setPhase('error', 1.0);
    }
  }

  void _playNextEpisode() {
    final nextEp = (widget.episodeNumber ?? 0) + 1;
    context.push(
      '/player/${widget.mediaType}/${widget.mediaId}?seasonNumber=${widget.seasonNumber}&episodeNumber=$nextEp',
    );
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Nuvio parity: opening overlay stays until first frame plays
    final initialLoadCompleted = _hasStartedPlayback;
    final showOpeningOverlay = !initialLoadCompleted && _streamPhase != 'error';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video surface — always present once initialized, but covered by opening overlay
            if (_isInitialized && _videoController != null)
              Video(
                controller: _videoController!,
                fit: BoxFit.cover,
                controls: NoVideoControls,
                subtitleViewConfiguration: SubtitleViewConfiguration(
                  style: TextStyle(
                    height: 1.25,
                    fontSize: _subtitleFontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: _subtitleBgOpacity),
                    shadows: const [
                      Shadow(offset: Offset(0, 2), blurRadius: 6, color: Colors.black),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Tap layer — sits above video, below controls so empty-area taps toggle controls
            // and button taps go to the controls
            if (initialLoadCompleted)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleControls,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
              ),

            if (_showSkipOverlay) _buildSkipOverlay(),
            if (_showNextEpisode)
              NextEpisodeOverlay(
                title: _nextEpisodeTitle ?? 'Next Episode',
                season: _nextSeason ?? (widget.seasonNumber ?? 1),
                episode: _nextEpisode ?? ((widget.episodeNumber ?? 0) + 1),
                onPlay: _playNextEpisode,
                onCancel: () => setState(() => _showNextEpisode = false),
              ),

            // Controls overlay — only after initial load completes; absorbs taps on buttons
            if (initialLoadCompleted && _showControls) _buildControls(),
            // Pause metadata overlay (matches Nuvio's PauseMetadataOverlay)
            if (initialLoadCompleted && !_showControls && _isInitialized && !_isPlaying && !_isBuffering)
              _buildPauseMetadataOverlay(),
            // Loading screen already has its own back button — no duplicate overlay needed
            if (_showSourceSelector) _buildSourceSelector(),
            // Opening overlay covers everything until first frame plays (Nuvio parity: AnimatedVisibility visible = !initialLoadCompleted)
            if (showOpeningOverlay) _buildLoader(),
          ],
        ),
      ),
    );
  }


  Widget _buildLoader() {
    return PlayerLoadingScreen(
      backdropUrl: _backdropUrl,
      logoUrl: _logoUrl,
      title: _mediaTitle ?? '',
      subtitle: widget.seasonNumber != null
          ? 'S${widget.seasonNumber} E${widget.episodeNumber}'
          : null,
      loadingMessage: _streamPhase == 'error' ? _phaseLabel() : '',
      progress: _streamProgress > 0 ? _streamProgress : null,
      isError: _streamPhase == 'error',
      onRetry: _resolveAndPlay,
      onBack: _exitPlayer,
      torrentStats: _torrentStats,
    );
  }

  String _phaseLabel() {
    if (_streamStatusText.isNotEmpty) return _streamStatusText;
    switch (_streamPhase) {
      case 'resolving': return 'Resolving streams...';
      case 'loading': return 'Loading stream...';
      case 'decoding': return 'Decoding...';
      case 'ready': return 'Ready';
      case 'error': return 'Stream unavailable';
      default: return _streamPhase;
    }
  }

  Widget _buildSkipOverlay() {
    final isForward = _skipDirection == 'forward';
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isForward ? Icons.forward_10 : Icons.replay_10, color: AppTheme.textPrimary, size: 32),
            const SizedBox(width: 8),
            Text(isForward ? '+10s' : '-10s', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    // Matches Nuvio's PlayerControlsShell: top gradient, bottom gradient, header, center, bottom
    // Gradients and decorative areas use IgnorePointer so taps pass through to the toggle layer
    return Stack(
      children: [
        // Top gradient (160dp, black 0.7 → transparent)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: IgnorePointer(child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
              ),
            ),
          )),
        ),
        // Bottom gradient (220dp, transparent → black 0.7)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 220,
          child: IgnorePointer(child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
              ),
            ),
          )),
        ),
        // Content
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildHeader(),
            _buildCenterControls(),
            _buildBottomControls(),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    // Matches Nuvio's PlayerHeader: title + episode info + provider left, lock + back right
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_logoUrl != null && _logoUrl!.isNotEmpty)
                    IgnorePointer(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120, maxHeight: 30),
                        child: ResilientNetworkImage(
                          imageUrl: _logoUrl!,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Text(
                            _mediaTitle ?? '${widget.mediaType} ${widget.mediaId}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              height: 1.16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      _mediaTitle ?? '${widget.mediaType} ${widget.mediaId}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (widget.seasonNumber != null && widget.episodeNumber != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'S${widget.seasonNumber} E${widget.episodeNumber}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (_streamResults.isNotEmpty) ...[
                        Text(
                          _streamResults[_selectedSourceIndex].addonName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Lock button (placeholder — matches Nuvio's lock/unlock)
            _HeaderCircleButton(
              icon: Icons.lock_open,
              size: 20,
              onPressed: () {},
            ),
            const SizedBox(width: 10),
            // Back button
            _HeaderCircleButton(
              icon: Icons.arrow_back,
              size: 20,
              onPressed: _exitPlayer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    // Matches Nuvio's CenterControls: [Replay10] [Play/Pause] [Forward10]
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Seek back 10s
        GestureDetector(
          onTap: _seekBackward,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: const Icon(Icons.replay_10, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(width: 56),
        // Play/Pause or buffering
        GestureDetector(
          onTap: _togglePlay,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: _isBuffering
                ? SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
          ),
        ),
        const SizedBox(width: 56),
        // Seek forward 10s
        GestureDetector(
          onTap: _seekForward,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: const Icon(Icons.forward_10, color: Colors.white, size: 34),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    // Matches Nuvio's ProgressControls: slider + time pills + action pill bar
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
      child: Column(
        children: [
          // Slider (thin, matches Nuvio's scaleY approach)
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
              thumbColor: Colors.white,
              trackHeight: 3,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) async {
                if (_hasPlayer) await _p.seek(Duration(milliseconds: (value * _duration.inMilliseconds).round()));
              },
            ),
          ),
          // Time pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TimePill(text: _formatDuration(_position)),
                _TimePill(text: _formatDuration(_duration)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Action pill bar (matches Nuvio's rounded rect with icon+label buttons)
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionPillButton(icon: Icons.aspect_ratio, label: 'Fit', onPressed: () {}),
                  _ActionPillButton(
                    icon: Icons.speed,
                    label: '${_playbackSpeed.toString().replaceAll(RegExp(r'\.?0+$'), '')}x',
                    onPressed: () => _setSpeed(_playbackSpeed >= 2.0 ? 0.5 : _playbackSpeed + 0.25),
                  ),
                  _ActionPillButton(icon: Icons.subtitles, label: 'Subs', onPressed: () => _showSubtitlesMenu()),
                  _ActionPillButton(icon: Icons.audiotrack, label: 'Audio', onPressed: () => _showAudioMenu()),
                  if (_streamResults.isNotEmpty)
                    _ActionPillButton(
                      icon: Icons.swap_horiz,
                      label: 'Sources',
                      onPressed: () => setState(() { _sourceFilter = null; _showSourceSelector = true; }),
                    ),
                  if (widget.seasonNumber != null)
                    _ActionPillButton(
                      icon: Icons.video_library,
                      label: 'Episodes',
                      onPressed: () => setState(() { _sourceFilter = null; _showSourceSelector = true; }),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseMetadataOverlay() {
    // Matches Nuvio's PauseMetadataOverlay: horizontal gradient, "You're watching", logo/title, episode info
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
        children: [
          // Horizontal gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Text content
          Positioned(
            left: 40,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're watching",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                if (_logoUrl != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240, maxHeight: 80),
                    child: ResilientNetworkImage(
                      imageUrl: _logoUrl!,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => _pauseTitleFallback(),
                    ),
                  )
                else
                  _pauseTitleFallback(),
                if (widget.seasonNumber != null && widget.episodeNumber != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'S${widget.seasonNumber} E${widget.episodeNumber}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _pauseTitleFallback() {
    return Text(
      _mediaTitle ?? '',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSourceSelector() {
    // Group streams by addon (Nuvio: AddonStreamGroup)
    final groups = <String, List<int>>{}; // addonName → list of indices
    for (var i = 0; i < _streamResults.length; i++) {
      final name = _streamResults[i].addonName;
      groups.putIfAbsent(name, () => []).add(i);
    }

    // Filtered groups based on _sourceFilter
    final filteredGroups = _sourceFilter == null
        ? groups
        : Map.fromEntries(groups.entries.where((e) => e.key == _sourceFilter));

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Blurred backdrop
          if (_backdropUrl != null)
            Positioned.fill(
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: ResilientNetworkImage(
                    imageUrl: _backdropUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          // Dark overlay
          Positioned.fill(child: ColoredBox(color: Colors.black)),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Top bar: back + close
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 8, right: 12),
                  child: Row(
                    children: [
                      _HeaderCircleButton(
                        icon: Icons.arrow_back,
                        size: 20,
                        onPressed: () => setState(() => _showSourceSelector = false),
                      ),
                      const Spacer(),
                      _HeaderCircleButton(
                        icon: Icons.close,
                        size: 20,
                        onPressed: () => setState(() => _showSourceSelector = false),
                      ),
                    ],
                  ),
                ),
                // Hero: logo or title (Nuvio: MovieHeroBlock)
                if (_logoUrl != null || _mediaTitle != null)
                  Container(
                    height: 100,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _logoUrl != null
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 80, maxWidth: 300),
                            child: ResilientNetworkImage(
                              imageUrl: _logoUrl!,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => _sourceSelectorTitleFallback(),
                            ),
                          )
                        : _sourceSelectorTitleFallback(),
                  ),
                // ─── Provider filter row (Nuvio: ProviderFilterRow) ───
                if (groups.length > 1)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        // "All" chip
                        _SourceFilterChip(
                          label: 'All',
                          isSelected: _sourceFilter == null,
                          onTap: () => setState(() => _sourceFilter = null),
                        ),
                        const SizedBox(width: 8),
                        // Per-addon chips
                        ...groups.keys.map((name) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _SourceFilterChip(
                            label: name,
                            isSelected: _sourceFilter == name,
                            onTap: () => setState(() => _sourceFilter = name),
                          ),
                        )),
                      ],
                    ),
                  ),
                // ─── Stream list (grouped by addon, Nuvio: StreamList) ───
                Expanded(
                  child: filteredGroups.isEmpty
                      ? _SourceEmptyState()
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          children: [
                            for (final entry in filteredGroups.entries) ...[
                              // Section header (Nuvio: shows when filter = null)
                              if (_sourceFilter == null && filteredGroups.length > 1)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              // Stream cards for this group
                              for (final index in entry.value)
                                _StreamCard(
                                  addonName: _streamResults[index].addonName,
                                  stream: _getBestStream(_streamResults[index]),
                                  isSelected: index == _selectedSourceIndex,
                                  onTap: () => _changeSource(index),
                                ),
                            ],
                            if (_streamResults.isEmpty)
                              _SourceEmptyState(),
                            const SizedBox(height: 32),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceSelectorTitleFallback() {
    return Text(
      _mediaTitle ?? 'Select Source',
      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---------------------------------------------------------------------------
// Nuvio-style helper widgets (outside _PlayerScreenState so they're reusable)
// ---------------------------------------------------------------------------

/// Circle button matching Nuvio's NuvioBackButton / PlayerHeaderIconButton
class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  const _HeaderCircleButton({required this.icon, required this.size, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final buttonSize = size + 24;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

/// Time pill matching Nuvio's TimePill composable
class _TimePill extends StatelessWidget {
  final String text;
  const _TimePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Action pill button matching Nuvio's PlayerActionPillButton
class _ActionPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionPillButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// Stream card matching Nuvio's StreamCard composable
/// Shows: title, addon name, quality, size, transport type, codec, release, language badges
class _StreamCard extends StatelessWidget {
  final String addonName;
  final StreamSource? stream;
  final bool isSelected;
  final VoidCallback onTap;

  const _StreamCard({
    required this.addonName,
    this.stream,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = stream;
    final sizeLabel = _formatSize(s?.sizeBytes ?? 0);
    final title = s?.behaviorHints?.filename ?? s?.source ?? addonName;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(minHeight: 68),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    addonName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Quality
                      if (s?.quality != null && s!.quality.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0C0C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            s.quality,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      // Size
                      if (sizeLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0C0C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            sizeLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      // Transport type
                      if (s != null && s.infoHash != null && s.infoHash!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0C0C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            s.behaviorHints?.cached == true ? 'Cached' : 'Torrent',
                            style: TextStyle(
                              color: s.behaviorHints?.cached == true ? AppTheme.accentGreen : Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (s != null && s.url != null && s.url!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0C0C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Direct',
                            style: TextStyle(color: AppTheme.accentYellow, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  String? _formatSize(int bytes) {
    if (bytes <= 0) return null;
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(0)} MB';
    return null;
  }
}

class _SubTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SubTile({
    this.icon = Icons.subtitles,
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(label,
          style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14)),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(subtitle!,
              style: TextStyle(
                  color: selected ? Colors.white54 : Colors.white38,
                  fontSize: 12))
          : null,
      trailing: selected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2)),
    );
  }
}

/// Provider filter chip (Nuvio: FilterChip in ProviderFilterRow)
class _SourceFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SourceFilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
          maxLines: 1,
        ),
      ),
    );
  }
}

/// Empty state for source selector (Nuvio: EmptyStateBlock)
class _SourceEmptyState extends StatelessWidget {
  const _SourceEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.search_off, color: Colors.white.withValues(alpha: 0.4), size: 48),
          const SizedBox(height: 12),
          Text('No sources available', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Try adding more addons in Settings', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}