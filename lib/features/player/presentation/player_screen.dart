import 'dart:async';
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
import 'package:streame/core/services/stream_resolver.dart';
import 'package:streame/features/home/data/models/media_item.dart';
import 'package:streame/core/repositories/skip_intro_repository.dart';
import 'package:streame/shared/widgets/next_episode_overlay.dart';
import 'package:streame/shared/widgets/player_loading_screen.dart';
import 'package:streame/core/providers/shared_providers.dart';
import 'package:streame/features/player/presentation/widgets/player_source_selector.dart';
import 'package:streame/features/player/presentation/widgets/player_pause_overlay.dart';
import 'package:streame/features/player/presentation/widgets/player_skip_overlays.dart';
import 'package:streame/features/player/presentation/widgets/player_controls_overlay.dart';

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
  bool _preferredAudioApplied = false;
  bool _preferredSubtitleApplied = false;
  // External (addon) subtitles
  List<Map<String, dynamic>> _externalSubtitles = [];
  bool _isFetchingSubs = false;
  String? _selectedExternalSubUrl;

  double _subtitleFontSize = 32.0;
  double _subtitleBgOpacity = 0.55;
  int _subtitleDelayMs = 0;
  double _subtitlePosition = 90.0; // 0=top, 100=bottom (default near bottom)

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

  // Pending resume seek (deferred until player is ready)
  int? _pendingSeekMs;

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
    _subtitlePosition = prefs.getDouble('settings_sub_position') ?? 90.0;
  }

  Future<void> _saveSubtitleSettings({
    double? fontSize,
    double? bgOpacity,
    int? delayMs,
    double? position,
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
    if (position != null) {
      _subtitlePosition = position;
      await prefs.setDouble('settings_sub_position', position);
    }
    if (mounted) setState(() {});
    await _applySubtitleDelay();
    await _applySubtitlePosition();
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

  Future<void> _applySubtitlePosition() async {
    if (!_hasPlayer) return;
    try {
      final platform = _p.platform;
      if (platform is NativePlayer) {
        await platform.setProperty('sub-align-x', 'center');
        await platform.setProperty('sub-align-y', 'bottom');
        await platform.setProperty('sub-pos', _subtitlePosition.round().toString());
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
        // Subtitle defaults: centered horizontally, positioned near bottom
        platform.setProperty('sub-align-x', 'center');
        platform.setProperty('sub-align-y', 'bottom');
        platform.setProperty('sub-pos', _subtitlePosition.round().toString());
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
          final reachable = await StreamResolver.checkStreamReachable(streamUrl);
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
      final normalized = StreamResolver.normalizeUrl(url);
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
            final sorted = StreamResolver.sortForPlayback(progress.allStreams);
            debugPrint('Auto-select: ${sorted.length} candidates, top url=${sorted.first.url?.substring(0, (sorted.first.url?.length ?? 0).clamp(0, 60))}, infoHash=${sorted.first.infoHash?.substring(0, (sorted.first.infoHash?.length ?? 0).clamp(0, 12))}');
            for (final candidate in sorted) {
              final playableUrl = await StreamResolver.resolvePlayableUrl(
                candidate,
                season: widget.seasonNumber,
                episode: widget.episodeNumber,
                onTorrentStart: (magnet) {
                  _activeMagnet = magnet;
                  _startTorrentStatsPolling();
                },
              );
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



  /// Streams that have already been attempted and failed — used for fallback.
  final Set<String> _attemptedStreamKeys = {};

  Future<void> _initPlayer(String url, {StreamSource? failedSource}) async {
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

      // Resume from saved position — defer until player has buffered enough
      if (widget.startPositionMs != null && widget.startPositionMs! > 0) {
        _pendingSeekMs = widget.startPositionMs!;
      }

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
          });
        }
        if (playing) {
          _playbackStartTimer?.cancel();
          _playbackStartTimer = null;
          // Trakt scrobble: start
          _traktScrobbleStart();
        } else if (_hasStartedPlayback) {
          // Trakt scrobble: pause (only after playback has started)
          _traktScrobblePause();
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
          // Execute pending resume seek once buffering ends
          if (!buffering && _pendingSeekMs != null) {
            final seekMs = _pendingSeekMs!;
            _pendingSeekMs = null;
            _p.seek(Duration(milliseconds: seekMs));
          }
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
        });
        _applyPreferredTracks();
      }));

      await _p.play();

      // Watchdog: on emulator / unsupported codecs, mpv may open but never start playback.
      // If we don't start within a short window, try the next source automatically.
      _playbackStartTimer?.cancel();
      _playbackStartTimer = Timer(const Duration(seconds: 12), () async {
        if (!mounted) return;
        final stillNotPlaying = !_p.state.playing;
        final stillAtStart = _position == Duration.zero;
        if (stillNotPlaying && stillAtStart) {
          // Mark current source as failed and try fallback
          if (failedSource != null) {
            final key = failedSource.url ?? failedSource.infoHash ?? '';
            if (key.isNotEmpty) _attemptedStreamKeys.add(key);
          }
          await _tryFallbackStream(
            errorMessage: 'Playback did not start. Trying next source...',
          );
        }
      });

      _startControlsTimer();
    } catch (e) {
      debugPrint('Player init error: $e');
      // Mark this source as failed and try the next best candidate
      if (failedSource != null) {
        final key = failedSource.url ?? failedSource.infoHash ?? '';
        if (key.isNotEmpty) _attemptedStreamKeys.add(key);
      }
      await _tryFallbackStream(
        errorMessage: e is TimeoutException
            ? 'Stream took too long to load. Trying next source...'
            : 'Failed to play stream. Trying next source...',
      );
    }
  }

  /// Try the next best untried stream after a failure.
  /// If no candidates remain, show the source selector or a final error.
  Future<void> _tryFallbackStream({required String errorMessage}) async {
    if (!mounted) return;
    _setPhase('loading', 0.3);
    setState(() => _streamStatusText = errorMessage);

    // Gather all streams from results, sorted deterministically
    final allStreams = <StreamSource>[];
    for (final r in _streamResults) {
      allStreams.addAll(r.streams);
    }
    final sorted = StreamResolver.sortForPlayback(allStreams);

    // Find the first candidate not yet attempted
    StreamSource? nextCandidate;
    for (final s in sorted) {
      final key = s.url ?? s.infoHash ?? '';
      if (key.isNotEmpty && !_attemptedStreamKeys.contains(key)) {
        nextCandidate = s;
        break;
      }
    }

    if (nextCandidate != null) {
      debugPrint('Fallback: trying next candidate: ${nextCandidate.source}');
      final playableUrl = await StreamResolver.resolvePlayableUrl(
        nextCandidate,
        season: widget.seasonNumber,
        episode: widget.episodeNumber,
        onTorrentStart: (magnet) {
          _activeMagnet = magnet;
          _startTorrentStatsPolling();
        },
      );
      if (playableUrl != null && mounted) {
        await _initPlayer(playableUrl, failedSource: nextCandidate);
      } else if (mounted) {
        // Mark as failed and recurse (will try next or show final error)
        final key = nextCandidate.url ?? nextCandidate.infoHash ?? '';
        if (key.isNotEmpty) _attemptedStreamKeys.add(key);
        await _tryFallbackStream(errorMessage: 'Source not playable. Trying next...');
      }
    } else {
      // No more candidates — show final error
      _setPhase('error', 1.0);
      setState(() {
        _streamStatusText = 'All sources failed. Try another source or check your connection.';
        _showSourceSelector = true;
      });
    }
  }

  void _setPhase(String phase, double progress) {
    setState(() {
      _streamPhase = phase;
      _streamProgress = progress;
    });
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

      final progress = _duration.inSeconds > 0 ? _position.inSeconds / _duration.inSeconds : 0.0;
      // Stop scrobble: Trakt auto-marks as watched if progress >= 80%
      await traktRepo.scrobbleStop(
        imdbId: imdbId,
        mediaType: widget.mediaType,
        season: widget.seasonNumber,
        episode: widget.episodeNumber,
        progress: progress,
      );
    } catch (_) {}
  }

  Future<void> _traktScrobbleStart() async {
    try {
      final traktRepo = ref.read(traktRepositoryProvider);
      if (!traktRepo.isLinked()) return;
      final imdbId = widget.imdbId;
      if (imdbId == null || imdbId.isEmpty) return;
      final progress = _duration.inSeconds > 0 ? _position.inSeconds / _duration.inSeconds : 0.0;
      await traktRepo.scrobbleStart(
        imdbId: imdbId,
        mediaType: widget.mediaType,
        season: widget.seasonNumber,
        episode: widget.episodeNumber,
        progress: progress,
      );
    } catch (_) {}
  }

  Future<void> _traktScrobblePause() async {
    try {
      final traktRepo = ref.read(traktRepositoryProvider);
      if (!traktRepo.isLinked()) return;
      final imdbId = widget.imdbId;
      if (imdbId == null || imdbId.isEmpty) return;
      final progress = _duration.inSeconds > 0 ? _position.inSeconds / _duration.inSeconds : 0.0;
      await traktRepo.scrobblePause(
        imdbId: imdbId,
        mediaType: widget.mediaType,
        season: widget.seasonNumber,
        episode: widget.episodeNumber,
        progress: progress,
      );
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
        }
      }
      _preferredSubtitleApplied = true;
    }
  }

  void _showSubtitlesMenu() {
    if (!_hasPlayer || !_isInitialized) return;
    setState(() {
      _subtitleTracks = _p.state.tracks.subtitle.where((t) => t.id != 'no' && t.id != 'auto').toList();
    });
    // Fetch online subtitles but update the bottom sheet state (avoid rebuilding the whole player).
    _fetchAddonSubtitles(
      onFetching: (fetching) => setState(() => _isFetchingSubs = fetching),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundSheet,
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
                  color: AppTheme.arcticWhite12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Subtitles',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
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
                    child: const Text('Settings', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                ),
              ),
              if (_isFetchingSubs)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: LinearProgressIndicator(
                      color: AppTheme.arcticWhite12, backgroundColor: AppTheme.arcticWhite12),
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
                              style: TextStyle(color: AppTheme.textDisabled))),
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
      backgroundColor: AppTheme.backgroundSheet,
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
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            if (_audioTracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No audio tracks found',
                    style: TextStyle(color: AppTheme.textDisabled)),
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
      backgroundColor: AppTheme.backgroundSheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        double fontSize = _subtitleFontSize;
        double bgOpacity = _subtitleBgOpacity;
        int delayMs = _subtitleDelayMs;
        double position = _subtitlePosition;
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.arcticWhite12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Text(
                      'Subtitle settings',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // Size
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Size', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        Text(fontSize.toStringAsFixed(0), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                    Slider(
                      value: fontSize,
                      min: 16,
                      max: 150,
                      divisions: 134,
                      onChanged: (v) => setModalState(() => fontSize = v),
                      onChangeEnd: (v) => _saveSubtitleSettings(fontSize: v),
                    ),

                    // Position
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Position', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        Text('${position.round()}%', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                    Slider(
                      value: position,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: (v) => setModalState(() => position = v),
                      onChangeEnd: (v) => _saveSubtitleSettings(position: v),
                    ),

                    // Background opacity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Background', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        Text('${(bgOpacity * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
                        const Text('Delay', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        Text('${delayMs}ms', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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

                    const SizedBox(height: 4),
                    Text(
                      'Default: size 32, position 90%, background 55%, delay 0ms',
                      style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
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

    final result = _streamResults[index];
    final sorted = StreamResolver.sortForPlayback(result.streams);
    if (sorted.isNotEmpty) {
      final stream = sorted.first;
      final playableUrl = await StreamResolver.resolvePlayableUrl(
        stream,
        season: widget.seasonNumber,
        episode: widget.episodeNumber,
        onTorrentStart: (magnet) {
          _activeMagnet = magnet;
          _startTorrentStatsPolling();
        },
      );
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

  @override
  Widget build(BuildContext context) {
    // Nuvio parity: opening overlay stays until first frame plays
    final initialLoadCompleted = _hasStartedPlayback;
    final showOpeningOverlay = !initialLoadCompleted && _streamPhase != 'error';
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
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
                    color: AppTheme.textPrimary,
                    backgroundColor: AppTheme.backgroundDark.withValues(alpha: _subtitleBgOpacity),
                    shadows: const [
                      Shadow(offset: Offset(0, 2), blurRadius: 6, color: AppTheme.backgroundDark),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Tap layer — sits above video, below controls so empty-area taps toggle controls
            // and button taps go to the controls
            if (initialLoadCompleted)
              Positioned.fill(
                child: Semantics(
                  label: 'Toggle player controls',
                  button: true,
                  child: GestureDetector(
                    onTap: _toggleControls,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),

            if (_showSkipOverlay)
              PlayerSkipOverlay(skipDirection: _skipDirection, onDismiss: () => setState(() => _showSkipOverlay = false)),
            if (_activeSkipInterval != null && initialLoadCompleted)
              PlayerSkipIntroButton(
                type: _activeSkipInterval!.type,
                remaining: Duration(seconds: ((_activeSkipInterval!.endMs - _position.inMilliseconds) / 1000).round()),
                onSkip: _onSkipIntro,
              ),
            if (_showNextEpisode)
              NextEpisodeOverlay(
                title: _nextEpisodeTitle ?? 'Next Episode',
                season: _nextSeason ?? (widget.seasonNumber ?? 1),
                episode: _nextEpisode ?? ((widget.episodeNumber ?? 0) + 1),
                onPlay: _playNextEpisode,
                onCancel: () => setState(() => _showNextEpisode = false),
              ),

            // Controls overlay — only after initial load completes; absorbs taps on buttons
            if (initialLoadCompleted && _showControls)
              PlayerControlsOverlay(data: PlayerControlsData(
                logoUrl: _logoUrl,
                mediaTitle: _mediaTitle,
                mediaType: widget.mediaType,
                mediaId: widget.mediaId,
                seasonNumber: widget.seasonNumber,
                episodeNumber: widget.episodeNumber,
                isPlaying: _isPlaying,
                isBuffering: _isBuffering,
                position: _position,
                duration: _duration,
                playbackSpeed: _playbackSpeed,
                streamResults: _streamResults,
                selectedSourceIndex: _selectedSourceIndex,
                sourceFilter: _sourceFilter,
                showSourceSelector: _showSourceSelector,
              ), callbacks: PlayerControlsCallbacks(
                onExit: _exitPlayer,
                onSeekBackward: _seekBackward,
                onTogglePlay: _togglePlay,
                onSeekForward: _seekForward,
                onSeek: (v) async { if (_hasPlayer) await _p.seek(Duration(milliseconds: (v * _duration.inMilliseconds).round())); },
                onSetSpeed: _setSpeed,
                onShowSubtitles: () => _showSubtitlesMenu(),
                onShowAudio: () => _showAudioMenu(),
                onShowSources: () => setState(() { _sourceFilter = null; _showSourceSelector = true; }),
                onShowEpisodes: () => setState(() { _sourceFilter = null; _showSourceSelector = true; }),
                onFit: () {},
              )),
            if (initialLoadCompleted && !_showControls && _isInitialized && !_isPlaying && !_isBuffering)
              PlayerPauseOverlay(
                logoUrl: _logoUrl,
                mediaTitle: _mediaTitle,
                seasonNumber: widget.seasonNumber,
                episodeNumber: widget.episodeNumber,
              ),
            // Loading screen already has its own back button — no duplicate overlay needed
            if (_showSourceSelector)
              PlayerSourceSelector(
                backdropUrl: _backdropUrl,
                logoUrl: _logoUrl,
                mediaTitle: _mediaTitle,
                mediaType: widget.mediaType,
                mediaId: widget.mediaId,
                streamResults: _streamResults,
                selectedSourceIndex: _selectedSourceIndex,
                sourceFilter: _sourceFilter,
                onSourceChange: _changeSource,
                onFilterChange: (f) => setState(() => _sourceFilter = f),
                onClose: () => setState(() => _showSourceSelector = false),
              ),
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
}

// ---------------------------------------------------------------------------
// Helper widgets still used by subtitle/audio menus
// ---------------------------------------------------------------------------

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
      leading: Icon(icon, color: AppTheme.textSecondary, size: 22),
      title: Text(label,
          style: TextStyle(
              color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14)),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(subtitle!,
              style: TextStyle(
                  color: selected ? AppTheme.textTertiary : AppTheme.textDisabled,
                  fontSize: 12))
          : null,
      trailing: selected ? const Icon(Icons.check, color: AppTheme.textPrimary, size: 20) : null,
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
              color: AppTheme.textDisabled,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2)),
    );
  }
}