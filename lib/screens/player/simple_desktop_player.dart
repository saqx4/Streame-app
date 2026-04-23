import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../../models/movie.dart';
import '../../models/stream_source.dart';
import '../../services/torrent_stream_service.dart';
import '../../api/subtitle_api.dart';
import '../../api/introdb_service.dart';
import '../../api/tmdb_service.dart';
import '../../api/stremio_service.dart';
import '../../services/stream_extractor.dart';
import '../../api/webstreamr_service.dart';
import '../../providers/stream_providers.dart';
import '../../api/debrid_api.dart';
import '../../api/torrent_api.dart';
import '../../services/torrent_filter.dart';
import '../../services/settings_service.dart';
import '../../services/watch_history_service.dart';
import '../player_screen.dart';
import 'utils.dart' show formatDuration;
import 'player_design.dart';

/// Simplified desktop player screen inspired by Stremio's minimal approach.
/// Focus on core playback functionality with minimal UI overhead.
class SimpleDesktopPlayerScreen extends StatefulWidget {
  final String mediaPath;
  final String title;
  final String? audioUrl;
  final Map<String, String>? headers;
  final Movie? movie;
  final int? selectedSeason;
  final int? selectedEpisode;
  final String? magnetLink;
  final String? activeProvider;
  final Duration? startPosition;
  final List<StreamSource>? sources;
  final int? fileIndex;
  final List<Map<String, dynamic>>? externalSubtitles;
  final String? stremioId;
  final String? stremioAddonBaseUrl;
  final Map<String, dynamic>? providers;

  const SimpleDesktopPlayerScreen({
    super.key,
    required this.mediaPath,
    required this.title,
    this.audioUrl,
    this.headers,
    this.movie,
    this.selectedSeason,
    this.selectedEpisode,
    this.magnetLink,
    this.activeProvider,
    this.startPosition,
    this.sources,
    this.fileIndex,
    this.externalSubtitles,
    this.stremioId,
    this.stremioAddonBaseUrl,
    this.providers,
  });

  @override
  State<SimpleDesktopPlayerScreen> createState() => _SimpleDesktopPlayerScreenState();
}

class _SimpleDesktopPlayerScreenState extends State<SimpleDesktopPlayerScreen>
    with WindowListener {
  // Player
  late final Player _player;
  late final VideoController _controller;
  bool _hasError = false;
  String _errorMessage = '';

  // UI State
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isFullscreen = false;

  // Stream Subscriptions
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<String>? _errorSub;

  // State
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _volume = 100.0;

  // Provider switching
  int _currentFallbackSourceIndex = 0;

  // Subtitles
  List<Map<String, dynamic>> _externalSubtitles = [];

  // IntroDB skip segments
  IntroDbResponse? _introDbData;
  String? _activeSkipLabel;
  Duration? _activeSkipTarget;

  // Next episode auto-play
  bool _isLoadingNextEp = false;
  bool _showNextEpOverlay = false;
  int _autoPlayCountdown = 5;
  Timer? _autoPlayTimer;
  bool _nearEndOfEpisode = false;

  // Buffering / reconnect
  bool _isBuffering = false;
  Timer? _stallCheckTimer;
  Timer? _reconnectTimer;
  bool _isRetrying = false; // true while trying next source after stall
  DateTime? _playbackStartTime; // track when playback started for 3-min timeout
  int _stallRetryCount = 0; // how many stall retries we've done

  // Aspect ratio
  BoxFit _videoFit = BoxFit.contain;

  // Playback speed
  double _playbackSpeed = 1.0;

  // Loop
  bool _isLooping = false;

  // Subtitle settings (Netflix-style defaults)
  int _subtitleDelayMs = 0;
  double _subtitleFontSize = 28.0;
  bool _subtitleBgEnabled = false;

  // Focus node for keyboard capture
  final FocusNode _focusNode = FocusNode();

  // Watch history debouncing
  Timer? _watchHistorySaveTimer;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    // Create player with minimal configuration
    _player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
      ),
    );

    // VideoController with hardware acceleration enabled
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    HardwareKeyboard.instance.addHandler(_hardwareKeyHandler);

    // Subscribe to streams
    _positionSub = _player.stream.position.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
      _saveProgress(pos);
      _updateActiveSkipSegment(pos);
      _checkNearEndOfEpisode(pos);
    });

    _durationSub = _player.stream.duration.listen((dur) {
      if (!mounted) return;
      setState(() => _duration = dur);
    });

    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
      if (playing) {
        _startHideTimer();
      }
    });

    _errorSub = _player.stream.error.listen((err) {
      if (!mounted || err.isEmpty) return;
      debugPrint('[Player] Error: $err');
      // Don't show error overlay if we're already retrying
      if (_isRetrying) return;
      setState(() {
        _hasError = true;
        _errorMessage = err;
      });
    });

    // Buffering state
    _player.stream.buffering.listen((buf) {
      if (!mounted) return;
      setState(() => _isBuffering = buf);
      if (buf) {
        _startStallCheck();
      } else {
        _stallCheckTimer?.cancel();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _externalSubtitles = widget.externalSubtitles ?? [];
      _initPlayback();
      _startHideTimer();
      _configureMpv();
      _fetchSubtitles();
      _fetchIntroDbTimestamps();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_hardwareKeyHandler);
    windowManager.removeListener(this);

    _hideTimer?.cancel();
    _autoPlayTimer?.cancel();
    _stallCheckTimer?.cancel();
    _reconnectTimer?.cancel();
    _watchHistorySaveTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _errorSub?.cancel();
    _focusNode.dispose();

    _player.dispose();

    // Remove torrent from engine
    try {
      final torrentId = widget.magnetLink ?? widget.mediaPath;
      TorrentStreamService().removeTorrent(torrentId);
    } catch (e) {
      debugPrint('[Player] Error removing torrent: $e');
    }

    super.dispose();
  }

  Future<void> _configureMpv() async {
    if (_player.platform is! NativePlayer) return;
    final mpv = _player.platform as NativePlayer;

    // Simple, proven configuration
    await mpv.setProperty('hwdec', 'auto');
    await mpv.setProperty('video-sync', 'display-resample');
    await mpv.setProperty('vsync', 'yes');

    // Cache settings for smooth streaming
    await mpv.setProperty('cache', 'yes');
    await mpv.setProperty('cache-secs', '300');
    await mpv.setProperty('demuxer-max-bytes', '1GiB');
    await mpv.setProperty('demuxer-readahead-secs', '300');
    await mpv.setProperty('cache-pause-initial', 'yes');
    await mpv.setProperty('cache-pause-wait', '15');
    await mpv.setProperty('cache-pause-done', '5');

    // Disable heavy filters
    await mpv.setProperty('interpolation', 'no');
    await mpv.setProperty('deband', 'no');

    // Network settings
    await mpv.setProperty('network-timeout', '30');
    await mpv.setProperty('tls-verify', 'no');

    // Volume
    await mpv.setProperty('volume-max', '150');

    // Resume position
    if (widget.startPosition != null) {
      final secs = widget.startPosition!.inMilliseconds / 1000.0;
      await mpv.setProperty('start', '+${secs.toStringAsFixed(3)}');
    }
  }

  Future<void> _initPlayback() async {
    _playbackStartTime = DateTime.now();
    _stallRetryCount = 0;
    setState(() => _currentFallbackSourceIndex = -1);
    await _trySource(widget.mediaPath, widget.headers);
  }

  Future<void> _trySource(String url, [Map<String, String>? headers]) async {
    debugPrint('[Player] Trying source: $url');
    _isRetrying = _currentFallbackSourceIndex >= 0;
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    try {
      await _player.open(
        Media(url, httpHeaders: headers ?? widget.headers),
      );
      // Give the player a moment to validate the source
      await Future.delayed(const Duration(seconds: 3));
      if (_hasError) {
        debugPrint('[Player] Source failed after open, trying next...');
        await _tryNextSource();
      } else {
        debugPrint('[Player] Opened successfully: $url');
        _isRetrying = false;
      }
    } catch (e) {
      debugPrint('[Player] Error opening source: $e');
      await _tryNextSource();
    }
  }

  Future<void> _tryNextSource() async {
    _currentFallbackSourceIndex++;
    if (widget.sources != null && _currentFallbackSourceIndex < widget.sources!.length) {
      final source = widget.sources![_currentFallbackSourceIndex];
      await _trySource(source.url, source.headers ?? widget.headers);
    } else if (widget.sources != null && widget.sources!.isNotEmpty) {
      // All sources tried — cycle back to first source and keep retrying
      // (the 3-min timeout in _attemptReconnect will eventually give up)
      debugPrint('[Player] All sources tried, cycling back to first...');
      _currentFallbackSourceIndex = 0;
      final source = widget.sources![_currentFallbackSourceIndex];
      await _trySource(source.url, source.headers ?? widget.headers);
    } else {
      // No fallback sources at all — check 3-min timeout
      final elapsed = _playbackStartTime != null
          ? DateTime.now().difference(_playbackStartTime!)
          : Duration.zero;
      if (elapsed.inSeconds >= 180) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to play: No working source found';
        });
      } else {
        // Retry the primary URL after a delay
        debugPrint('[Player] Retrying primary source in 10s...');
        await Future.delayed(const Duration(seconds: 10));
        if (!mounted) return;
        await _trySource(widget.mediaPath, widget.headers);
      }
    }
  }

  void _saveProgress(Duration pos) {
    if (widget.movie == null) return;
    if (pos.inMilliseconds < 10000) return;
    if (_duration.inMilliseconds == 0) return;

    // Debounce: only save every 5 seconds
    _watchHistorySaveTimer?.cancel();
    _watchHistorySaveTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      WatchHistoryService().saveProgress(
        tmdbId: widget.movie!.id,
        title: widget.title,
        posterPath: widget.movie?.posterPath ?? '',
        method: widget.magnetLink != null ? 'torrent' : 'stream',
        sourceId: widget.magnetLink ?? widget.mediaPath,
        position: pos.inMilliseconds,
        duration: _duration.inMilliseconds,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
        mediaType: widget.movie!.mediaType,
        magnetLink: widget.magnetLink,
        fileIndex: widget.fileIndex,
      );
    });
  }

  Future<void> _fetchSubtitles() async {
    final initial = widget.externalSubtitles ?? [];
    if (initial.isNotEmpty) {
      if (mounted) setState(() => _externalSubtitles = List<Map<String, dynamic>>.from(initial));
    }

    if (widget.movie == null) return;

    final stream = SubtitleApi.fetchSubtitlesStream(
      tmdbId: widget.movie!.id,
      imdbId: widget.movie!.imdbId,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );

    stream.listen(
      (subs) {
        if (!mounted) return;
        setState(() => _externalSubtitles = [...initial, ...subs]);
      },
    );
  }

  Future<void> _fetchIntroDbTimestamps() async {
    if (widget.movie == null) return;
    final data = await IntroDbService().getTimestamps(
      tmdbId: widget.movie!.id,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      imdbId: widget.movie!.imdbId,
    );
    if (mounted && data != null && data.hasAnySegments) {
      setState(() => _introDbData = data);
    }
  }

  void _showSubtitlesMenu() {
    final embeddedTracks = _player.state.tracks.subtitle.where((t) => t.id != 'no').toList();
    final currentSubId = _player.state.track.subtitle.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        const Text(
                          'Subtitles',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 22),
                          onPressed: () {
                            Navigator.pop(context);
                            _showSubtitleSettingsMenu();
                          },
                          tooltip: 'Subtitle Settings',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  // Content
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        // Off option
                        _buildSubtitleTile(
                          title: 'Off',
                          isActive: currentSubId == 'no',
                          icon: Icons.subtitles_off_outlined,
                          onTap: () {
                            _player.setSubtitleTrack(SubtitleTrack.no());
                            Navigator.pop(context);
                          },
                        ),
                        // Embedded section
                        if (embeddedTracks.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Text(
                              'Embedded',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...embeddedTracks.map((t) => _buildSubtitleTile(
                            title: t.title ?? t.language ?? 'Track ${t.id}',
                            isActive: currentSubId == t.id,
                            icon: Icons.subtitles_outlined,
                            onTap: () {
                              _player.setSubtitleTrack(t);
                              Navigator.pop(context);
                            },
                          )),
                        ],
                        // External section
                        if (_externalSubtitles.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Text(
                              'Online',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ..._externalSubtitles.map((s) {
                            final url = s['url'];
                            final title = s['display'] ?? s['label'] ?? s['name'] ?? 'Unknown';
                            final lang = s['language'] ?? s['lang'] ?? '';
                            final displayTitle = lang.isEmpty ? title : '$title ($lang)';
                            return _buildSubtitleTile(
                              title: displayTitle,
                              isActive: currentSubId == url,
                              icon: Icons.language_outlined,
                              onTap: url == null
                                  ? null
                                  : () {
                                      _player.setSubtitleTrack(
                                        SubtitleTrack.uri(
                                          url,
                                          title: title,
                                          language: lang.isEmpty ? 'und' : lang,
                                        ),
                                      );
                                      Navigator.pop(context);
                                    },
                            );
                          }),
                        ],
                        if (embeddedTracks.isEmpty && _externalSubtitles.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.subtitles_off_rounded, size: 48, color: Colors.white24),
                                  SizedBox(height: 16),
                                  Text(
                                    'No subtitles available',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildSubtitleTile({
    required String title,
    required bool isActive,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF7C3AED).withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: isActive ? const Color(0xFF7C3AED) : Colors.white70),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isActive ? const Color(0xFF7C3AED) : Colors.white,
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSubtitleSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E0E),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Subtitle Settings',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // Font size
                    Row(
                      children: [
                        const Text('Size', style: TextStyle(color: Colors.white)),
                        Expanded(
                          child: Slider(
                            value: _subtitleFontSize,
                            min: 12,
                            max: 36,
                            onChanged: (v) {
                              setState(() => _subtitleFontSize = v);
                              setSheetState(() {});
                            },
                          ),
                        ),
                        Text('${_subtitleFontSize.round()}', style: const TextStyle(color: Color(0xFF7C3AED))),
                      ],
                    ),
                    // Background
                    SwitchListTile(
                      title: const Text('Background', style: TextStyle(color: Colors.white)),
                      value: _subtitleBgEnabled,
                      activeTrackColor: const Color(0xFF7C3AED),
                      onChanged: (v) {
                        setState(() => _subtitleBgEnabled = v);
                        setSheetState(() {});
                      },
                    ),
                    // Delay
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text('Delay', style: TextStyle(color: Colors.white)),
                          const SizedBox(width: 8),
                          Text('${_subtitleDelayMs}ms', style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.white),
                            onPressed: () { _adjustSubtitleDelay(-50); setSheetState(() {}); },
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () { _adjustSubtitleDelay(50); setSheetState(() {}); },
                          ),
                          TextButton(
                            onPressed: () { setState(() => _subtitleDelayMs = 0); _adjustSubtitleDelay(0); setSheetState(() {}); },
                            child: const Text('Reset', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAudioMenu() {
    final tracks = _player.state.tracks.audio.where((t) => t.id != 'no').toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E0E),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Audio Tracks',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: tracks.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No audio tracks found', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        itemCount: tracks.length,
                        itemBuilder: (context, index) {
                          final t = tracks[index];
                          return ListTile(
                            title: Text(t.title ?? t.language ?? 'Track ${t.id}', style: const TextStyle(color: Colors.white)),
                            onTap: () {
                              _player.setAudioTrack(t);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSourcesMenu() {
    if (widget.sources == null || widget.sources!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sources available')),
      );
      return;
    }

    // Sort sources by title for better navigation
    final sorted = List<StreamSource>.from(widget.sources!)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    // Group by provider name (extracted from title before newline)
    final groups = <String, List<StreamSource>>{};
    for (final s in sorted) {
      final providerName = s.title.split('\n').first.trim();
      final key = providerName.isEmpty ? 'Other' : providerName;
      groups.putIfAbsent(key, () => []).add(s);
    }

    final groupKeys = groups.keys.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E0E),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('Video Sources',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${sorted.length} sources', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: groupKeys.length,
                  itemBuilder: (context, gIdx) {
                    final key = groupKeys[gIdx];
                    final items = groups[key]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (groups.length > 1)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(key,
                                style: const TextStyle(
                                    color: Color(0xFF7C3AED), fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ...items.map((source) {
                          final displayTitle = source.title.contains('\n')
                              ? source.title.split('\n').skip(1).join('\n').trim()
                              : source.title;
                          final isActive = _currentFallbackSourceIndex >= 0 &&
                              widget.sources![_currentFallbackSourceIndex].url == source.url;
                          return ListTile(
                            dense: true,
                            title: Text(displayTitle.isEmpty ? source.title : displayTitle,
                                style: TextStyle(
                                    color: isActive ? const Color(0xFF7C3AED) : Colors.white,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                            trailing: isActive
                                ? const Icon(Icons.play_circle_filled, color: Color(0xFF7C3AED), size: 20)
                                : null,
                            onTap: () async {
                              Navigator.pop(context);
                              setState(() {
                                _hasError = false;
                                _errorMessage = '';
                              });
                              await _player.open(Media(source.url, httpHeaders: source.headers ?? widget.headers));
                            },
                          );
                        }),
                        if (gIdx < groupKeys.length - 1)
                          const Divider(height: 1, color: Colors.white12),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateActiveSkipSegment(Duration pos) {
    if (_introDbData == null) return;

    final posMs = pos.inMilliseconds;
    String? label;
    Duration? target;

    // Check each segment type
    for (final seg in _introDbData!.recap) {
      final s = seg.startMs ?? 0;
      final e = seg.endMs;
      if (e != null && posMs >= s && posMs < e) {
        label = 'Skip Recap';
        target = Duration(milliseconds: e);
        break;
      }
    }
    if (label == null) {
      for (final seg in _introDbData!.intro) {
        final s = seg.startMs ?? 0;
        final e = seg.endMs;
        if (e != null && posMs >= s && posMs < e) {
          label = 'Skip Intro';
          target = Duration(milliseconds: e);
          break;
        }
      }
    }

    if (label != _activeSkipLabel) {
      setState(() {
        _activeSkipLabel = label;
        _activeSkipTarget = target;
      });
    }
  }

  void _performSkip() {
    if (_activeSkipTarget == null) return;
    _player.seek(_activeSkipTarget!);
    setState(() {
      _activeSkipLabel = null;
      _activeSkipTarget = null;
    });
  }

  bool get _isNextEpisodeAvailable =>
      widget.movie != null &&
      widget.movie!.mediaType == 'tv' &&
      widget.selectedSeason != null &&
      widget.selectedEpisode != null;

  void _checkNearEndOfEpisode(Duration pos) {
    if (!_isNextEpisodeAvailable || _duration.inMilliseconds == 0) return;
    final watchedPercent = pos.inMilliseconds / _duration.inMilliseconds;
    final nearEnd = watchedPercent >= 0.85 && watchedPercent < 1.0;
    if (nearEnd != _nearEndOfEpisode) {
      setState(() => _nearEndOfEpisode = nearEnd);
      if (nearEnd && !_showNextEpOverlay) {
        _startAutoPlayCountdown();
      }
    }
  }

  void _startAutoPlayCountdown() {
    _autoPlayTimer?.cancel();
    setState(() {
      _showNextEpOverlay = true;
      _autoPlayCountdown = 5;
    });
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _autoPlayCountdown--);
      if (_autoPlayCountdown <= 0) {
        timer.cancel();
        _nextEpisode();
      }
    });
  }

  void _cancelAutoPlay() {
    _autoPlayTimer?.cancel();
    setState(() {
      _showNextEpOverlay = false;
      _autoPlayCountdown = 5;
    });
  }

  Future<void> _nextEpisode() async {
    if (!_isNextEpisodeAvailable || _isLoadingNextEp) return;
    _autoPlayTimer?.cancel();
    setState(() {
      _isLoadingNextEp = true;
      _showNextEpOverlay = false;
    });

    try {
      final tmdb = TmdbService();
      final tvId = widget.movie!.id;
      int nextSeason = widget.selectedSeason!;
      int nextEpisode = widget.selectedEpisode! + 1;

      final seasonData = await tmdb.getTvSeasonDetails(tvId, nextSeason);
      final episodes = seasonData['episodes'] as List<dynamic>? ?? [];
      final maxEp = episodes.isNotEmpty
          ? episodes.map((e) => e['episode_number'] as int).reduce((a, b) => a > b ? a : b)
          : 0;

      if (nextEpisode > maxEp) {
        final totalSeasons = await tmdb.getTvSeasonCount(tvId);
        if (nextSeason < totalSeasons) {
          nextSeason++;
          nextEpisode = 1;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No more episodes available')),
            );
          }
          setState(() => _isLoadingNextEp = false);
          return;
        }
      }

      debugPrint('[NextEp] Playing S${nextSeason}E$nextEpisode');
      _saveProgress(_position);

      String? streamUrl;
      String? magnetLink;
      int? fileIndex;
      Map<String, String>? headers;
      String? activeProvider = widget.activeProvider;

      final isTorrent = widget.magnetLink != null && widget.activeProvider != 'stremio_direct';
      final isStremioDirect = widget.activeProvider == 'stremio_direct';
      final isWebStreamr = widget.activeProvider == 'webstreamr';

      if (isStremioDirect && widget.stremioAddonBaseUrl != null) {
        final stremio = StremioService();
        final stremioId = widget.stremioId ?? widget.movie!.imdbId;
        if (stremioId == null) throw Exception('No Stremio ID available');
        final epId = '$stremioId:$nextSeason:$nextEpisode';
        final streams = await stremio.getStreams(
          baseUrl: widget.stremioAddonBaseUrl!, type: 'series', id: epId,
        );
        if (streams.isEmpty) throw Exception('No streams found for S${nextSeason}E$nextEpisode');
        final stream = streams.first as Map<String, dynamic>;
        if (stream['url'] != null) {
          streamUrl = stream['url'] as String;
          final proxyHeaders = stream['behaviorHints']?['proxyHeaders']?['request'];
          if (proxyHeaders is Map) headers = Map<String, String>.from(proxyHeaders);
        } else if (stream['infoHash'] != null) {
          final infoHash = stream['infoHash'] as String;
          final streamTitle = (stream['title'] ?? stream['name'] ?? '').toString();
          final dn = streamTitle.isNotEmpty ? '&dn=${Uri.encodeComponent(streamTitle)}' : '';
          magnetLink = 'magnet:?xt=urn:btih:$infoHash$dn';
          final settings = SettingsService();
          final useDebrid = await settings.useDebridForStreams();
          final debridService = await settings.getDebridService();
          if (useDebrid && debridService != 'None') {
            final debrid = DebridApi();
            final files = debridService == 'Real-Debrid'
                ? await debrid.resolveRealDebrid(magnetLink)
                : await debrid.resolveTorBox(magnetLink);
            if (files.isNotEmpty) {
              final s = 'S${nextSeason.toString().padLeft(2, '0')}';
              final e = 'E${nextEpisode.toString().padLeft(2, '0')}';
              final match = files.where((f) =>
                  f.filename.toUpperCase().contains(s) &&
                  f.filename.toUpperCase().contains(e)).toList();
              if (match.isNotEmpty) {
                fileIndex = files.indexOf(match.first);
                streamUrl = match.first.downloadUrl;
              } else {
                files.sort((a, b) => b.filesize.compareTo(a.filesize));
                streamUrl = files.first.downloadUrl;
              }
            }
          } else {
            streamUrl = await TorrentStreamService().streamTorrent(magnetLink, season: nextSeason, episode: nextEpisode);
            if (streamUrl != null) {
              final idx = Uri.parse(streamUrl).queryParameters['index'];
              if (idx != null) fileIndex = int.tryParse(idx);
            }
          }
          activeProvider = 'torrent';
        }
      } else if (isTorrent) {
        final s = nextSeason.toString().padLeft(2, '0');
        final e = nextEpisode.toString().padLeft(2, '0');
        final query = '${widget.movie!.title} S${s}E$e';
        final torrentApi = TorrentApi();
        final results = await torrentApi.searchTorrents(query);
        final filtered = await TorrentFilter.filterTorrentsAsync(
          results, widget.movie!.title, requiredSeason: nextSeason, requiredEpisode: nextEpisode,
        );
        if (filtered.isEmpty) throw Exception('No torrents found for S${s}E$e');
        filtered.sort((a, b) => b.seeders.compareTo(a.seeders));
        magnetLink = filtered.first.magnet;
        final settings = SettingsService();
        final useDebrid = await settings.useDebridForStreams();
        final debridService = await settings.getDebridService();
        if (useDebrid && debridService != 'None') {
          final debrid = DebridApi();
          final files = debridService == 'Real-Debrid'
              ? await debrid.resolveRealDebrid(magnetLink)
              : await debrid.resolveTorBox(magnetLink);
          if (files.isNotEmpty) {
            final match = files.where((f) =>
                f.filename.toUpperCase().contains('S$s') &&
                f.filename.toUpperCase().contains('E$e')).toList();
            if (match.isNotEmpty) {
              fileIndex = files.indexOf(match.first);
              streamUrl = match.first.downloadUrl;
            } else {
              files.sort((a, b) => b.filesize.compareTo(a.filesize));
              streamUrl = files.first.downloadUrl;
            }
          }
        } else {
          streamUrl = await TorrentStreamService().streamTorrent(magnetLink, season: nextSeason, episode: nextEpisode);
          if (streamUrl != null) {
            final idx = Uri.parse(streamUrl).queryParameters['index'];
            if (idx != null) fileIndex = int.tryParse(idx);
          }
        }
      } else if (isWebStreamr) {
        final imdbId = widget.movie!.imdbId;
        if (imdbId == null || imdbId.isEmpty) throw Exception('No IMDB ID for WebStreamr');
        final webStreamr = WebStreamrService();
        final sources = await webStreamr.getStreams(imdbId: imdbId, isMovie: false, season: nextSeason, episode: nextEpisode);
        if (sources.isEmpty) throw Exception('No WebStreamr sources for S${nextSeason}E$nextEpisode');
        streamUrl = sources.first.url;
      } else if (widget.activeProvider != null) {
        final provider = StreamProviders.providers[widget.activeProvider];
        if (provider == null || provider['tv'] == null) {
          throw Exception('Provider ${widget.activeProvider} does not support TV');
        }
        final providerUrl = provider['tv']!(widget.movie!.id.toString(), nextSeason, nextEpisode);
        final extractor = StreamExtractor();
        final result = await extractor.extract(providerUrl, timeout: const Duration(seconds: 20));
        if (result == null) throw Exception('Extraction failed for S${nextSeason}E$nextEpisode');
        streamUrl = result.url;
        headers = result.headers.isNotEmpty ? result.headers : null;
      }

      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('Could not find stream for S${nextSeason}E$nextEpisode');
      }

      if (!mounted) return;

      final nextTitle = '${widget.movie!.title} - S$nextSeason E$nextEpisode';
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            streamUrl: streamUrl!,
            title: nextTitle,
            headers: headers,
            movie: widget.movie,
            selectedSeason: nextSeason,
            selectedEpisode: nextEpisode,
            magnetLink: magnetLink,
            fileIndex: fileIndex,
            activeProvider: activeProvider,
            stremioId: widget.stremioId,
            stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
            providers: widget.providers,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[NextEp] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Next episode error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingNextEp = false);
    }
  }

  // ── Buffering / Reconnect ──────────────────────────────────────────────

  void _startStallCheck() {
    _stallCheckTimer?.cancel();
    _stallCheckTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted || !_isBuffering) return;
      debugPrint('[Player] Stall detected, attempting reconnect...');
      _attemptReconnect();
    });
  }

  void _attemptReconnect() {
    if (!mounted) return;
    _isRetrying = true;
    _stallRetryCount++;

    // Check if 3 minutes have passed since playback started
    final elapsed = _playbackStartTime != null
        ? DateTime.now().difference(_playbackStartTime!)
        : Duration.zero;
    if (elapsed.inSeconds >= 180) {
      debugPrint('[Player] 3 minutes elapsed, giving up');
      _isRetrying = false;
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to play: No working source found after 3 minutes';
      });
      return;
    }

    // Try seek +1s first
    _player.seek(_position + const Duration(seconds: 1));
    _reconnectTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || !_isBuffering) {
        _isRetrying = false;
        return;
      }
      // Still stalled, try next source (will cycle back if all tried)
      debugPrint('[Player] Still stalled (attempt $_stallRetryCount), trying next source...');
      _tryNextSource();
    });
  }

  // ── Aspect Ratio ──────────────────────────────────────────────────────

  String get _videoFitLabel => switch (_videoFit) {
    BoxFit.contain => 'FIT',
    BoxFit.cover => 'CROP',
    BoxFit.fill => 'FILL',
    _ => 'FIT',
  };

  void _cycleAspectRatio() {
    setState(() {
      if (_videoFit == BoxFit.contain) {
        _videoFit = BoxFit.cover;
      } else if (_videoFit == BoxFit.cover) {
        _videoFit = BoxFit.fill;
      } else {
        _videoFit = BoxFit.contain;
      }
    });
  }

  // ── Playback Speed ────────────────────────────────────────────────────

  void _showSpeedMenu() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E0E),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Playback Speed',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: speeds.map((s) {
                      final selected = (s - _playbackSpeed).abs() < 0.01;
                      return ChoiceChip(
                        label: Text('${s}x'),
                        selected: selected,
                        onSelected: (_) {
                          _player.setRate(s);
                          setState(() => _playbackSpeed = s);
                          Navigator.pop(context);
                        },
                        selectedColor: const Color(0xFF7C3AED),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Loop ──────────────────────────────────────────────────────────────

  void _toggleLoop() {
    setState(() => _isLooping = !_isLooping);
    _player.setPlaylistMode(_isLooping ? PlaylistMode.loop : PlaylistMode.none);
  }

  // ── Subtitle Delay ────────────────────────────────────────────────────

  void _adjustSubtitleDelay(int ms) async {
    setState(() => _subtitleDelayMs += ms);
    if (_player.platform is NativePlayer) {
      final mpv = _player.platform as NativePlayer;
      await mpv.setProperty('sub-delay', '${_subtitleDelayMs}ms');
    }
  }

  void _showSubtitleDelayMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E0E),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Subtitle Delay',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('${_subtitleDelayMs}ms',
                style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () { _adjustSubtitleDelay(-500); Navigator.pop(context); },
                    child: const Text('-500ms'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () { _adjustSubtitleDelay(-50); Navigator.pop(context); },
                    child: const Text('-50ms'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () { setState(() => _subtitleDelayMs = 0); _adjustSubtitleDelay(0); Navigator.pop(context); },
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () { _adjustSubtitleDelay(50); Navigator.pop(context); },
                    child: const Text('+50ms'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () { _adjustSubtitleDelay(500); Navigator.pop(context); },
                    child: const Text('+500ms'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (_isPlaying && mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onMouseMove() {
    if (!mounted) return;
    setState(() => _showControls = true);
    _startHideTimer();
  }

  /// Global hardware keyboard handler — reliable regardless of focus.
  bool _hardwareKeyHandler(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (!mounted) return false;
    _onMouseMove();

    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final ctrl = HardwareKeyboard.instance.isControlPressed;

    // Play / Pause
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      _togglePlayPause();
      return true;
    }
    // Seek forward
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyL) {
      final secs = ctrl ? 60 : (shift ? 30 : 10);
      _seek(Duration(seconds: secs));
      return true;
    }
    // Seek backward
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
      final secs = ctrl ? -60 : (shift ? -30 : -10);
      _seek(Duration(seconds: secs));
      return true;
    }
    // Volume up
    if (key == LogicalKeyboardKey.arrowUp) {
      _setVolume((_volume + 5).clamp(0, 150));
      return true;
    }
    // Volume down
    if (key == LogicalKeyboardKey.arrowDown) {
      _setVolume((_volume - 5).clamp(0, 150));
      return true;
    }
    // Fullscreen
    if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
      return true;
    }
    // Escape — exit fullscreen or close player
    if (key == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        _toggleFullscreen();
      } else {
        Navigator.of(context).pop();
      }
      return true;
    }
    // Mute toggle
    if (key == LogicalKeyboardKey.keyM) {
      _setVolume(_volume > 0 ? 0 : 100);
      return true;
    }
    // Subtitle delay
    if (key == LogicalKeyboardKey.bracketLeft) {
      _adjustSubtitleDelay(-50);
      return true;
    }
    if (key == LogicalKeyboardKey.bracketRight) {
      _adjustSubtitleDelay(50);
      return true;
    }
    // Cycle audio / subtitle tracks
    if (key == LogicalKeyboardKey.keyA) {
      _cycleAudioTrack();
      return true;
    }
    if (key == LogicalKeyboardKey.keyS) {
      _cycleSubtitleTrack();
      return true;
    }
    // Number keys 0-9 → seek to 0%-90%
    if (key == LogicalKeyboardKey.digit0) { _seekToPercent(0); return true; }
    if (key == LogicalKeyboardKey.digit1) { _seekToPercent(10); return true; }
    if (key == LogicalKeyboardKey.digit2) { _seekToPercent(20); return true; }
    if (key == LogicalKeyboardKey.digit3) { _seekToPercent(30); return true; }
    if (key == LogicalKeyboardKey.digit4) { _seekToPercent(40); return true; }
    if (key == LogicalKeyboardKey.digit5) { _seekToPercent(50); return true; }
    if (key == LogicalKeyboardKey.digit6) { _seekToPercent(60); return true; }
    if (key == LogicalKeyboardKey.digit7) { _seekToPercent(70); return true; }
    if (key == LogicalKeyboardKey.digit8) { _seekToPercent(80); return true; }
    if (key == LogicalKeyboardKey.digit9) { _seekToPercent(90); return true; }
    // Frame step
    if (key == LogicalKeyboardKey.comma) {
      _player.seek(_position - const Duration(milliseconds: 41));
      return true;
    }
    if (key == LogicalKeyboardKey.period) {
      _player.seek(_position + const Duration(milliseconds: 41));
      return true;
    }
    return false;
  }

  void _seekToPercent(int pct) {
    if (_duration.inMilliseconds <= 0) return;
    final target = Duration(milliseconds: (_duration.inMilliseconds * pct / 100).round());
    _player.seek(target);
  }

  void _cycleAudioTrack() {
    final tracks = _player.state.tracks.audio.where((t) => t.id != 'no').toList();
    if (tracks.isEmpty) return;
    final current = _player.state.track.audio;
    int idx = tracks.indexWhere((t) => t.id == current.id);
    idx = (idx + 1) % tracks.length;
    _player.setAudioTrack(tracks[idx]);
  }

  void _cycleSubtitleTrack() {
    final tracks = _player.state.tracks.subtitle.where((t) => t.id != 'no').toList();
    if (tracks.isEmpty) return;
    final current = _player.state.track.subtitle;
    if (current.id == 'no') {
      _player.setSubtitleTrack(tracks.first);
    } else {
      int idx = tracks.indexWhere((t) => t.id == current.id);
      if (idx < 0 || idx >= tracks.length - 1) {
        _player.setSubtitleTrack(SubtitleTrack.no());
      } else {
        _player.setSubtitleTrack(tracks[idx + 1]);
      }
    }
  }

  void _togglePlayPause() {
    _player.playOrPause();
  }

  void _seek(Duration offset) {
    final newPos = _position + offset;
    if (newPos.inMilliseconds >= 0 && newPos <= _duration) {
      _player.seek(newPos);
    }
  }

  void _toggleFullscreen() async {
    _isFullscreen = !_isFullscreen;
    if (_isFullscreen) {
      await windowManager.setFullScreen(true);
    } else {
      await windowManager.setFullScreen(false);
    }
    setState(() {});
  }

  void _setVolume(double value) {
    _player.setVolume(value);
    setState(() => _volume = value);
  }

  void _onSeek(double fraction) {
    final position = Duration(milliseconds: (_duration.inMilliseconds * fraction).round());
    _player.seek(position);
  }

  @override
  void onWindowClose() {
    _saveProgress(_position);
    Navigator.of(context).pop();
  }

  @override
  void onWindowFocus() {
    // Don't trigger UI rebuild on focus change to reduce tab switching lag
    // The controls will auto-hide/play based on playing state anyway
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        canRequestFocus: true,
        descendantsAreFocusable: false,
        // Keyboard handled globally via HardwareKeyboard in initState;
        // Focus node kept for focus-scope management only.
        child: MouseRegion(
          onHover: (_) => _onMouseMove(),
          cursor: _showControls ? SystemMouseCursors.basic : SystemMouseCursors.none,
          child: Listener(
            onPointerSignal: (signal) {
              if (signal is PointerScrollEvent) {
                final dy = signal.scrollDelta.dy;
                if (dy != 0) {
                  final step = (dy > 0 ? -2.0 : 2.0);
                  _setVolume((_volume + step).clamp(0, 150));
                }
              }
            },
            child: GestureDetector(
              onTap: () {
                _focusNode.requestFocus();
                _onMouseMove();
              },
              onDoubleTap: _toggleFullscreen,
              child: Stack(
                fit: StackFit.expand,
                children: [
                // Video player - fill entire screen with no built-in controls
                Video(
                  controller: _controller,
                  controls: NoVideoControls,
                  fit: _videoFit,
                  fill: Colors.black,
                  subtitleViewConfiguration: const SubtitleViewConfiguration(
                    visible: false,
                  ),
                ),

                // Custom subtitle overlay (Netflix-style)
                StreamBuilder<List<String>>(
                  stream: _player.stream.subtitle,
                  initialData: _player.state.subtitle,
                  builder: (context, snap) {
                    final lines = snap.data ?? [];
                    final text = lines.where((l) => l.trim().isNotEmpty).join('\n');
                    if (text.isEmpty) return const SizedBox.shrink();
                    return Positioned(
                      left: 24,
                      right: 24,
                      bottom: 110,
                      child: IgnorePointer(
                        child: Container(
                          padding: _subtitleBgEnabled
                              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                              : EdgeInsets.zero,
                          decoration: _subtitleBgEnabled
                              ? BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(4),
                                )
                              : null,
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _subtitleFontSize,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                              letterSpacing: 0.5,
                              shadows: _subtitleBgEnabled
                                  ? null
                                  : const [
                                      // Netflix-style outline: multiple shadows for thick outline
                                      Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 0)),
                                      Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 0)),
                                      Shadow(color: Colors.black, blurRadius: 2, offset: Offset(-1, 0)),
                                      Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 1)),
                                      Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, -1)),
                                      Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2)),
                                    ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Buffering indicator
                if (_isBuffering)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7C3AED),
                      strokeWidth: 3,
                    ),
                  ),

                // Auto-play next episode overlay
                if (_showNextEpOverlay)
                  Positioned(
                    right: 24,
                    bottom: 160,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF7C3AED), width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Next Episode', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Playing in $_autoPlayCountdown...', style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 14)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: _cancelAutoPlay,
                                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _nextEpisode,
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
                                  child: const Text('Play Now'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          // Error overlay
          if (_hasError)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _hasError = false);
                        _tryNextSource();
                      },
                      child: const Text('Try Next Source'),
                    ),
                  ],
                ),
              ),
            ),
          // Controls overlay
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Stack(children: [
                // Gradients
                const PlayerTopGradient(height: 90),
                const PlayerBottomGradient(height: 160),

                // ── TOP BAR ──────────────────────────────────────────────
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(children: [
                        PlayerBtn(
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => Navigator.of(context).pop(),
                          size: 38, iconSize: 20,
                          tooltip: 'Back',
                        ),
                        const SizedBox(width: 12),
                        if (widget.selectedSeason != null && widget.selectedEpisode != null)
                          PlayerPill(
                            text: 'S${widget.selectedSeason} E${widget.selectedEpisode}',
                            fontSize: 11,
                          ),
                        if (widget.selectedSeason != null && widget.selectedEpisode != null)
                          const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PlayerBtn(icon: Icons.subtitles_outlined, onPressed: _showSubtitlesMenu, size: 34, iconSize: 17, tooltip: 'Subtitles'),
                        const SizedBox(width: 4),
                        PlayerBtn(icon: Icons.audiotrack_outlined, onPressed: _showAudioMenu, size: 34, iconSize: 17, tooltip: 'Audio'),
                        if (widget.sources != null && widget.sources!.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          PlayerBtn(icon: Icons.playlist_play_rounded, onPressed: _showSourcesMenu, size: 34, iconSize: 17, tooltip: 'Sources'),
                        ],
                        const SizedBox(width: 4),
                        PlayerPill(text: _videoFitLabel, onTap: _cycleAspectRatio, fontSize: 10),
                        const SizedBox(width: 4),
                        PlayerPill(text: '${_playbackSpeed}x', onTap: _showSpeedMenu, fontSize: 10),
                        const SizedBox(width: 4),
                        PlayerBtn(
                          icon: _isLooping ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                          onPressed: _toggleLoop,
                          active: _isLooping,
                          size: 34, iconSize: 17,
                          tooltip: 'Loop',
                        ),
                        const SizedBox(width: 4),
                        PlayerBtn(icon: Icons.access_time_rounded, onPressed: _showSubtitleDelayMenu, size: 34, iconSize: 17, tooltip: 'Sub Delay'),
                        const SizedBox(width: 4),
                        PlayerBtn(
                          icon: _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                          onPressed: _toggleFullscreen,
                          size: 34, iconSize: 17,
                          tooltip: 'Fullscreen',
                        ),
                      ]),
                    ),
                  ),
                ),

                // ── BOTTOM SECTION ────────────────────────────────────────
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // Seekbar
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            activeTrackColor: const Color(0xFF7C3AED),
                            inactiveTrackColor: Colors.white24,
                            thumbColor: const Color(0xFF7C3AED),
                            overlayColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: _duration.inMilliseconds > 0
                                ? _position.inMilliseconds / _duration.inMilliseconds
                                : 0,
                            onChanged: _onSeek,
                          ),
                        ),

                        // Time + controls row
                        Row(
                          children: [
                            PlayerTimeLabel(text: formatDuration(_position), align: TextAlign.right),
                            const SizedBox(width: 4),
                            Text('/', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                            const SizedBox(width: 4),
                            PlayerTimeLabel(text: formatDuration(_duration)),

                            const Spacer(),

                            // Skip segment
                            if (_activeSkipLabel != null)
                              PlayerSkipChip(label: _activeSkipLabel!, onTap: _performSkip),

                            // Next episode
                            if (_isNextEpisodeAvailable) ...[
                              const SizedBox(width: 8),
                              PlayerNextChip(isLoading: _isLoadingNextEp, onTap: _nextEpisode),
                            ],

                            const SizedBox(width: 8),

                            // Play/Pause
                            PlayerBtn(
                              icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              onPressed: _togglePlayPause,
                              size: 40, iconSize: 22,
                            ),

                            const SizedBox(width: 8),

                            // Volume
                            SizedBox(
                              width: 100,
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  activeTrackColor: Colors.white70,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                  overlayColor: Colors.white.withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: _volume,
                                  max: 150,
                                  onChanged: _setVolume,
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Fullscreen
                            PlayerBtn(
                              icon: _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                              onPressed: _toggleFullscreen,
                              size: 34, iconSize: 17,
                              tooltip: 'Fullscreen',
                            ),
                          ],
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          ],
        ),
      ),
    ),
  ),
),
);
  }
}
