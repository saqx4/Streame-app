import 'dart:async';
import 'package:media_kit/media_kit.dart';
import '../error/either.dart';
import '../error/failures.dart';

/// Lazy loading strategy for video sources
enum LoadStrategy {
  /// Load immediately when source is selected
  immediate,
  /// Load only when user interacts (play/pause)
  onDemand,
  /// Load when source is visible on screen
  onVisible,
  /// Preload next source while current is playing
  preloadNext,
}

/// Video source metadata for lazy loading
class VideoSourceMetadata {
  final String url;
  final String? quality;
  final int? bandwidth;
  final int? size;

  const VideoSourceMetadata({
    required this.url,
    this.quality,
    this.bandwidth,
    this.size,
  });

  /// Calculate load priority based on bandwidth and size
  double get priority {
    if (bandwidth == null && size == null) return 0.5;
    if (bandwidth != null) {
      // Lower bandwidth = higher priority
      return 1.0 - (bandwidth! / 10000000).clamp(0.0, 1.0);
    }
    if (size != null) {
      // Smaller size = higher priority
      return 1.0 - (size! / 1000000000).clamp(0.0, 1.0);
    }
    return 0.5;
  }
}

/// Lazy video loader with configurable loading strategies
class LazyVideoLoader {
  final LoadStrategy strategy;
  final Player player;
  final Map<String, VideoSourceMetadata> _sourceCache = {};
  final Map<String, bool> _loadedSources = {};
  final Map<String, bool> _loadingSources = {};
  String? _currentSourceUrl;
  Timer? _preloadTimer;

  LazyVideoLoader({
    required this.strategy,
    required this.player,
  });

  /// Register a video source for lazy loading
  void registerSource(String url, VideoSourceMetadata metadata) {
    _sourceCache[url] = metadata;
  }

  /// Load a video source based on strategy
  Future<Either<Failure, void>> loadSource(String url) async {
    if (_loadedSources[url] == true) {
      return Either.right(null);
    }

    if (_loadingSources[url] == true) {
      // Already loading, wait for it
      await _waitForLoad(url);
      return _loadedSources[url] == true
          ? Either.right(null)
          : Either.left(NetworkFailure(message: 'Failed to load source'));
    }

    _loadingSources[url] = true;

    try {
      switch (strategy) {
        case LoadStrategy.immediate:
          await _loadImmediately(url);
          break;
        case LoadStrategy.onDemand:
          // Don't load automatically, wait for user interaction
          break;
        case LoadStrategy.onVisible:
          await _loadWhenVisible(url);
          break;
        case LoadStrategy.preloadNext:
          await _loadWithPreload(url);
          break;
      }

      _loadedSources[url] = true;
      _loadingSources[url] = false;
      return Either.right(null);
    } catch (e, st) {
      _loadingSources[url] = false;
      return Either.left(
        NetworkFailure(
          message: 'Failed to load video source',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  /// Set current playing source
  void setCurrentSource(String url) {
    _currentSourceUrl = url;
    _loadedSources[url] = true;

    // Start preloading next source if strategy allows
    if (strategy == LoadStrategy.preloadNext) {
      _schedulePreload();
    }
  }

  /// Preload the next source based on priority
  void _schedulePreload() {
    _preloadTimer?.cancel();
    _preloadTimer = Timer(const Duration(seconds: 5), () {
      _preloadNextSource();
    });
  }

  Future<void> _preloadNextSource() async {
    final candidates = _sourceCache.entries
        .where((entry) =>
            entry.key != _currentSourceUrl &&
            _loadedSources[entry.key] != true &&
            _loadingSources[entry.key] != true)
        .toList();

    if (candidates.isEmpty) return;

    // Sort by priority and preload the highest priority
    candidates.sort((a, b) => b.value.priority.compareTo(a.value.priority));
    final nextSource = candidates.first;

    await loadSource(nextSource.key);
  }

  /// Load source immediately
  Future<void> _loadImmediately(String url) async {
    await player.open(Media(url));
  }

  /// Load when visible (placeholder for visibility detection)
  Future<void> _loadWhenVisible(String url) async {
    // This would integrate with visibility_detector
    // For now, load immediately
    await _loadImmediately(url);
  }

  /// Load with preload strategy
  Future<void> _loadWithPreload(String url) async {
    await _loadImmediately(url);
  }

  /// Wait for a source to finish loading
  Future<void> _waitForLoad(String url) async {
    int attempts = 0;
    while (_loadingSources[url] == true && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
  }

  /// Check if a source is loaded
  bool isLoaded(String url) => _loadedSources[url] == true;

  /// Check if a source is loading
  bool isLoading(String url) => _loadingSources[url] == true;

  /// Clear loaded sources cache
  void clearCache() {
    _loadedSources.clear();
    _loadingSources.clear();
    _preloadTimer?.cancel();
  }

  /// Dispose resources
  void dispose() {
    clearCache();
  }
}

/// Video source quality selector
class VideoQualitySelector {
  final List<VideoSourceMetadata> sources;
  VideoSourceMetadata? _selectedSource;

  VideoQualitySelector({required this.sources});

  /// Select best quality based on device capabilities
  VideoSourceMetadata selectBestQuality() {
    // Sort by bandwidth (ascending) for lower bandwidth = better
    final sorted = List.from(sources)
      ..sort((a, b) => (a.bandwidth ?? 0).compareTo(b.bandwidth ?? 0));

    // Select middle quality for balance
    final index = (sorted.length / 2).floor().clamp(0, sorted.length - 1);
    _selectedSource = sorted[index];
    return _selectedSource!;
  }

  /// Select lowest quality for slow connections
  VideoSourceMetadata selectLowQuality() {
    final sorted = List.from(sources)
      ..sort((a, b) => (a.bandwidth ?? 0).compareTo(b.bandwidth ?? 0));
    _selectedSource = sorted.first;
    return _selectedSource!;
  }

  /// Select highest quality for fast connections
  VideoSourceMetadata selectHighQuality() {
    final sorted = List.from(sources)
      ..sort((a, b) => (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0));
    _selectedSource = sorted.first;
    return _selectedSource!;
  }

  /// Get selected source
  VideoSourceMetadata? get selectedSource => _selectedSource;

  /// Select source by quality label
  VideoSourceMetadata? selectByQuality(String quality) {
    final source = sources.firstWhere(
      (s) => s.quality?.toLowerCase() == quality.toLowerCase(),
      orElse: () => sources.first,
    );
    _selectedSource = source;
    return source;
  }
}

/// Adaptive bitrate streaming simulator
class AdaptiveBitrateStreamer {
  final Player player;
  final List<VideoSourceMetadata> sources;
  VideoSourceMetadata? _currentSource;
  Timer? _qualityCheckTimer;
  int _bufferHealth = 100;

  AdaptiveBitrateStreamer({
    required this.player,
    required this.sources,
  });

  /// Start adaptive streaming
  void start() {
    _qualityCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkAndAdjustQuality();
    });
  }

  /// Check buffer health and adjust quality
  void _checkAndAdjustQuality() {
    final position = player.state.position;
    final duration = player.state.duration;

    final bufferPercent = ((duration - position).inMilliseconds / duration.inMilliseconds * 100);
    _bufferHealth = bufferPercent.toInt();

    if (_bufferHealth < 30 && _currentSource != null) {
      // Buffer low, switch to lower quality
      _switchToLowerQuality();
    } else if (_bufferHealth > 80 && _currentSource != null) {
      // Buffer healthy, try higher quality
      _switchToHigherQuality();
    }
  }

  void _switchToLowerQuality() {
    final currentIndex = sources.indexOf(_currentSource!);
    if (currentIndex < sources.length - 1) {
      final lowerQuality = sources[currentIndex + 1];
      _switchSource(lowerQuality);
    }
  }

  void _switchToHigherQuality() {
    final currentIndex = sources.indexOf(_currentSource!);
    if (currentIndex > 0) {
      final higherQuality = sources[currentIndex - 1];
      _switchSource(higherQuality);
    }
  }

  Future<void> _switchSource(VideoSourceMetadata source) async {
    final currentPosition = player.state.position;
    _currentSource = source;
    await player.open(Media(source.url));
    await player.seek(currentPosition);
  }

  /// Set initial source
  void setInitialSource(VideoSourceMetadata source) {
    _currentSource = source;
  }

  /// Stop adaptive streaming
  void stop() {
    _qualityCheckTimer?.cancel();
  }

  /// Get current buffer health percentage
  int get bufferHealth => _bufferHealth;
}
