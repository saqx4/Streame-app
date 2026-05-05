import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/focus/focusable.dart';
import 'package:streame/core/repositories/tmdb_repository.dart';
import 'package:streame/core/repositories/trakt_repository.dart';
import 'dart:async';
import 'package:streame/core/repositories/addon_repository.dart';
import 'package:streame/core/repositories/watchlist_repository.dart';
import 'package:streame/core/repositories/profile_repository.dart';
import 'package:streame/core/models/stream_models.dart';
import 'package:streame/core/models/source_presentation.dart';
import 'package:streame/core/services/stream_resolver.dart';
import 'package:streame/features/home/data/models/media_item.dart';
import 'package:streame/core/providers/shared_providers.dart';

class Season {
  final int seasonNumber;
  final String? name;
  final String? overview;
  final String? posterPath;
  final int episodeCount;
  final DateTime? airDate;

  const Season({
    required this.seasonNumber,
    this.name,
    this.overview,
    this.posterPath,
    this.episodeCount = 0,
    this.airDate,
  });

  factory Season.fromJson(Map<String, dynamic> json) => Season(
    seasonNumber: json['season_number'] as int? ?? 0,
    name: json['name'] as String?,
    overview: json['overview'] as String?,
    posterPath: json['poster_path'] as String?,
    episodeCount: json['episode_count'] as int? ?? 0,
    airDate: json['air_date'] != null ? DateTime.tryParse(json['air_date'] as String) : null,
  );
}

class Episode {
  final int seasonNumber;
  final int episodeNumber;
  final String? name;
  final String? overview;
  final String? stillPath;
  final Duration runtime;
  final DateTime? airDate;
  final double rating;

  const Episode({
    required this.seasonNumber,
    required this.episodeNumber,
    this.name,
    this.overview,
    this.stillPath,
    this.runtime = Duration.zero,
    this.airDate,
    this.rating = 0,
  });

  factory Episode.fromJson(Map<String, dynamic> json, int seasonNum) => Episode(
    seasonNumber: seasonNum,
    episodeNumber: json['episode_number'] as int? ?? 0,
    name: json['name'] as String?,
    overview: json['overview'] as String?,
    stillPath: json['still_path'] as String?,
    runtime: Duration(minutes: json['runtime'] as int? ?? 0),
    airDate: json['air_date'] != null ? DateTime.tryParse(json['air_date'] as String) : null,
    rating: (json['vote_average'] as num?)?.toDouble() ?? 0,
  );
}

class MediaDetails {
  final MediaItem item;
  final List<Season> seasons;
  final List<Episode> episodes;
  final String? imdbId;
  final String? logoPath;
  final int? budget;
  final int? revenue;
  final List<String> genres;

  const MediaDetails({
    required this.item,
    this.seasons = const [],
    this.episodes = const [],
    this.imdbId,
    this.logoPath,
    this.budget,
    this.revenue,
    this.genres = const [],
  });
}

final _detailsLogoProvider = FutureProvider.family<String?, ({int id, String mediaType})>((ref, p) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  return repo.getLogoPath(p.id, mediaType: p.mediaType == 'tv' ? MediaType.tv : MediaType.movie);
});

final _traktRatingProvider = FutureProvider.family<double?, ({String mediaType, int mediaId})>((ref, p) async {
  final repo = ref.watch(traktRepositoryProvider);
  if (!repo.isLinked()) return null;
  return repo.getTraktRating(mediaType: p.mediaType, tmdbId: p.mediaId);
});

final mediaDetailsProvider = FutureProvider.family<MediaDetails?, ({String mediaType, int mediaId})>((ref, params) async {
  final repo = ref.watch(tmdbRepositoryProvider);

  MediaItem? item;
  if (params.mediaType == 'movie') {
    item = await repo.getMovieDetails(params.mediaId);
  } else {
    item = await repo.getTvDetails(params.mediaId);
  }

  if (item == null) return null;

  List<Season> seasons = [];
  String? imdbId;
  List<String> genres = [];

  if (params.mediaType == 'tv') {
    // Fetch seasons from TV details
    final seasonsData = await repo.getTvSeasonsList(params.mediaId);
    seasons = seasonsData.map((s) => Season.fromJson(s)).toList();
    // Fetch external IDs for IMDB
    final extIds = await repo.getTvExternalIds(params.mediaId);
    imdbId = extIds?['imdb_id'] as String?;
  } else {
    final extIds = await repo.getMovieExternalIds(params.mediaId);
    imdbId = extIds?['imdb_id'] as String?;
  }

  try {
    genres = await repo.getGenreNames(params.mediaId, mediaType: params.mediaType == 'tv' ? MediaType.tv : MediaType.movie);
  } catch (_) {
    genres = [];
  }

  return MediaDetails(
    item: item,
    seasons: seasons,
    imdbId: imdbId,
    genres: genres,
  );
});

final seasonEpisodesProvider = FutureProvider.family<List<Episode>, ({int tvId, int seasonNumber})>((ref, params) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  final data = await repo.getSeasonDetails(params.tvId, params.seasonNumber);
  if (data == null) return [];
  final episodes = data['episodes'] as List<dynamic>? ?? [];
  return episodes
      .map((e) => Episode.fromJson(e as Map<String, dynamic>, params.seasonNumber))
      .toList();
});

final detailsStreamsProvider = FutureProvider.family<List<AddonStreamResult>, ({String type, String imdbId, String tmdbId, int? season, int? episode})>((ref, params) async {
  final addonRepo = ref.watch(addonManagerRepositoryProvider);
  return addonRepo.resolveStreams(
    type: params.type,
    imdbId: params.imdbId,
    tmdbId: params.tmdbId,
    season: params.season,
    episode: params.episode,
  );
});

final creditsProvider = FutureProvider.family<Map<String, dynamic>?, ({String mediaType, int mediaId})>((ref, params) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  if (params.mediaType == 'tv') {
    return repo.getTvCredits(params.mediaId);
  }
  return repo.getMovieCredits(params.mediaId);
});

final similarProvider = FutureProvider.family<List<MediaItem>, ({String mediaType, int mediaId})>((ref, params) async {
  final repo = ref.watch(tmdbRepositoryProvider);
  final data = await repo.search('', mediaType: params.mediaType == 'tv' ? MediaType.tv : MediaType.movie);
  return data.take(20).toList();
});

class DetailsScreen extends ConsumerStatefulWidget {
  final String mediaType;
  final int mediaId;
  final int? initialSeason;
  final int? initialEpisode;

  const DetailsScreen({
    super.key,
    required this.mediaType,
    required this.mediaId,
    this.initialSeason,
    this.initialEpisode,
  });

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {

  int _selectedSeason = 1;
  bool _isInWatchlist = false;
  bool _showStreamSelector = false;
  int? _streamSelectorSeason;
  int? _streamSelectorEpisode;
  String _streamSelectorFilterAddonId = 'all';

  // Progressive stream resolution state
  List<AddonStreamResult> _progressiveStreamResults = [];
  bool _isResolvingStreams = false;
  int _resolvedAddonCount = 0;
  int _totalAddonCount = 0;
  StreamSubscription<StreamProgress>? _streamResolutionSub;

  @override
  void dispose() {
    _streamResolutionSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.initialSeason ?? 1;
    _checkWatchlist();
  }

  Future<void> _checkWatchlist() async {
    try {
      final profileId = ref.read(activeProfileIdProvider);
      if (profileId == null) return;
      final repo = ref.read(watchlistRepositoryProvider(profileId));
      final isIn = await repo.isInWatchlist(widget.mediaId, widget.mediaType);
      if (mounted) setState(() => _isInWatchlist = isIn);
    } catch (_) {
      // Provider not initialized or no profile — skip watchlist check
    }
  }

  Future<void> _toggleWatchlist(MediaItem item) async {
    try {
      final profileId = ref.read(activeProfileIdProvider);
      if (profileId == null) return;
      final repo = ref.read(watchlistRepositoryProvider(profileId));
      if (_isInWatchlist) {
        await repo.removeFromWatchlist(widget.mediaId, widget.mediaType);
      } else {
        await repo.addToWatchlist(
          tmdbId: widget.mediaId,
          mediaType: widget.mediaType,
          title: item.title,
          posterPath: item.image.isNotEmpty ? item.image : null,
        );
      }
      if (!mounted) return;
      setState(() => _isInWatchlist = !_isInWatchlist);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isInWatchlist ? 'Added to My List' : 'Removed from My List'),
          backgroundColor: AppTheme.backgroundCard,
        ),
      );
    } catch (_) {
      // Provider not initialized — skip
    }
  }

  void _openStreamSelector({int? season, int? episode}) {
    setState(() {
      _streamSelectorSeason = season;
      _streamSelectorEpisode = episode;
      _showStreamSelector = true;
    });
    _startProgressiveStreamResolution();
  }

  void _closeStreamSelector() {
    _streamResolutionSub?.cancel();
    _streamResolutionSub = null;
    setState(() {
      _showStreamSelector = false;
      _isResolvingStreams = false;
    });
  }

  void _startProgressiveStreamResolution() {
    _streamResolutionSub?.cancel();
    _streamResolutionSub = null;

    final details = ref.read(mediaDetailsProvider((mediaType: widget.mediaType, mediaId: widget.mediaId))).valueOrNull;
    final imdbId = details?.imdbId ?? '';
    final type = widget.mediaType == 'tv' ? 'series' : 'movie';

    // Check cache first — skip addon calls if fresh results exist
    final key = StreamResolver.cacheKey(type, imdbId, season: _streamSelectorSeason, episode: _streamSelectorEpisode);
    final cached = StreamResolver.getCached(key);
    if (cached != null) {
      setState(() {
        _progressiveStreamResults = cached;
        _isResolvingStreams = false;
        _resolvedAddonCount = cached.length;
        _totalAddonCount = cached.length;
      });
      return;
    }

    setState(() {
      _progressiveStreamResults = [];
      _isResolvingStreams = true;
      _resolvedAddonCount = 0;
      _totalAddonCount = 0;
    });

    final addonRepo = ref.read(addonManagerRepositoryProvider);
    final progressStream = addonRepo.resolveStreamsProgressive(
      type: type,
      imdbId: imdbId,
      tmdbId: widget.mediaId.toString(),
      season: _streamSelectorSeason,
      episode: _streamSelectorEpisode,
    );

    _streamResolutionSub = progressStream.listen((progress) {
      if (!mounted || !_showStreamSelector) return;
      setState(() {
        _progressiveStreamResults = List.from(progress.addonResults);
        _resolvedAddonCount = progress.completedAddons;
        _totalAddonCount = progress.totalAddons;
        _isResolvingStreams = !progress.isFinal;
      });
      // Cache final results
      if (progress.isFinal && progress.addonResults.isNotEmpty) {
        StreamResolver.putCached(key, progress.addonResults);
      }
    }, onDone: () {
      if (mounted) setState(() => _isResolvingStreams = false);
    }, onError: (_) {
      if (mounted) setState(() => _isResolvingStreams = false);
    });
  }

  void _playStream(StreamSource stream, String addonName, String addonId) {
    setState(() => _showStreamSelector = false);
    final imdbId = ref.read(mediaDetailsProvider((mediaType: widget.mediaType, mediaId: widget.mediaId))).valueOrNull?.imdbId;
    // Use go() instead of push() to avoid GlobalKey conflict when called from overlay
    Future.microtask(() {
      if (!mounted) return;
      context.go(
        '/player/${widget.mediaType}/${widget.mediaId}'
        '?streamUrl=${Uri.encodeComponent(stream.url ?? '')}'
        '&imdbId=${Uri.encodeComponent(imdbId ?? '')}'
        '&preferredAddonId=${Uri.encodeComponent(addonId)}'
        '&preferredSourceName=${Uri.encodeComponent(stream.source)}'
        '${widget.mediaType == 'tv' ? '&seasonNumber=${_streamSelectorSeason ?? _selectedSeason}&episodeNumber=${_streamSelectorEpisode ?? 1}' : ''}'
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(mediaDetailsProvider((mediaType: widget.mediaType, mediaId: widget.mediaId)));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          details.when(
            data: (data) => data == null
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Not found', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
                      const SizedBox(height: 16),
                      TextButton(onPressed: () => context.canPop() ? context.pop() : context.go('/home'), child: const Text('Go Back', style: TextStyle(color: AppTheme.accentYellow))),
                    ],
                  ))
                : _buildContent(data),
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.textPrimary)),
            error: (e, _) => Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $e', style: const TextStyle(color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(mediaDetailsProvider((mediaType: widget.mediaType, mediaId: widget.mediaId))),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentYellow, foregroundColor: AppTheme.backgroundDark),
                  child: const Text('Retry'),
                ),
              ],
            )),
          ),
          if (_showStreamSelector) _buildStreamSelectorOverlay(),
        ],
      ),
    );
  }

  Widget _buildStreamSelectorOverlay() {
    final details = ref.read(mediaDetailsProvider((mediaType: widget.mediaType, mediaId: widget.mediaId))).valueOrNull;
    final imdbId = details?.imdbId ?? '';
    final season = _streamSelectorSeason;
    final episode = _streamSelectorEpisode;
    final isEpisode = season != null && episode != null;

    final results = _progressiveStreamResults;

    // Build addon tabs
    final addonTabs = <({String id, String name})>[];
    final seenIds = <String>{};
    for (final r in results) {
      final baseName = r.addonName.split(' - ').first.trim();
      final id = r.addonId.isNotEmpty ? r.addonId : baseName;
      if (seenIds.add(id)) {
        addonTabs.add((id: id, name: baseName));
      }
    }

    if (_streamSelectorFilterAddonId != 'all' && !results.any((r) => r.addonId == _streamSelectorFilterAddonId)) {
      _streamSelectorFilterAddonId = 'all';
    }

    final filteredResults = _streamSelectorFilterAddonId == 'all'
        ? results
        : results.where((r) => r.addonId == _streamSelectorFilterAddonId).toList();

    // Use StreamResolver for deterministic sorting
    final flat = <({StreamSource s, String addonName, String addonId})>[];
    for (final r in filteredResults) {
      final sorted = StreamResolver.sortForPlayback(r.streams);
      for (final s in sorted) {
        flat.add((s: s, addonName: r.addonName, addonId: r.addonId));
      }
    }

    return Material(
      color: AppTheme.backgroundDark.withValues(alpha: 0.92),
      child: SafeArea(
        child: Column(
          children: [
            // ─── Header: title + count + close ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isEpisode) ...[
                          Text(
                            'S$season E$episode',
                            style: const TextStyle(color: AppTheme.accentGreen, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          'Select Source',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Close button
                  Semantics(
                    button: true,
                    label: 'Close',
                    child: GestureDetector(
                      onTap: _closeStreamSelector,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.textPrimary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.close, color: AppTheme.textPrimary, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Stream list ───
            Expanded(
              child: _isResolvingStreams && flat.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppTheme.accentRed, strokeWidth: 2.5),
                          const SizedBox(height: 12),
                          Text(
                            'Finding sources... ($_resolvedAddonCount/$_totalAddonCount)',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  : flat.isEmpty && !_isResolvingStreams
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AppTheme.textSecondary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    imdbId.isEmpty ? Icons.settings : Icons.cloud_outlined,
                                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  imdbId.isEmpty ? 'No Streaming Addons' : 'No sources found',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  imdbId.isEmpty ? 'Go to Settings → Addons to add a streaming addon' : 'Try adding more addons',
                                  style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    _closeStreamSelector();
                                    Future.microtask(() {
                                      if (mounted) context.go('/settings');
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentGreen,
                                    foregroundColor: AppTheme.backgroundDark,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Manage Addons'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _isResolvingStreams
                                      ? 'Finding sources... ($_resolvedAddonCount/$_totalAddonCount)'
                                      : '${flat.length} sources available',
                                  style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                            // Horizontal filter tabs
                            if (addonTabs.length > 1)
                              SizedBox(
                                height: 40,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: addonTabs.length + 1,
                                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                                  itemBuilder: (context, i) {
                                    final isAll = i == 0;
                                    final opt = isAll ? null : addonTabs[i - 1];
                                    final id = isAll ? 'all' : opt!.id;
                                    final name = isAll ? 'All sources' : opt!.name;
                                    final isSelected = _streamSelectorFilterAddonId == id;
                                    return Semantics(
                                      button: true,
                                      label: name,
                                      selected: isSelected,
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          _streamSelectorFilterAddonId = id;
                                        }),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppTheme.textPrimary.withValues(alpha: 0.18) : AppTheme.textPrimary.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                          child: Center(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                color: isSelected ? AppTheme.textPrimary : AppTheme.textPrimary.withValues(alpha: 0.78),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 10),
                            // Stream cards
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: flat.length,
                                itemBuilder: (context, idx) {
                                  final item = flat[idx];
                                  return _ArvioStreamCard(
                                    stream: item.s,
                                    addonName: item.addonName,
                                    addonId: item.addonId,
                                    onTap: () => _playStream(item.s, item.addonName, item.addonId),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(MediaDetails data) {
    final item = data.item;
    final backdropUrl = item.backdrop ?? (item.image.isNotEmpty ? item.image : null);
    final prefs = ref.read(sharedPreferencesProvider);
    final cinematicEnabled = prefs.getBool('settings_cinematic_background') ?? false;
    // Use dedicated logo provider (same pattern as home hero) instead of data.logoPath
    final logoAsync = ref.watch(_detailsLogoProvider((id: item.id, mediaType: widget.mediaType)));
    final logoPath = logoAsync.valueOrNull;

    final bgUrl = (backdropUrl != null && backdropUrl.isNotEmpty)
        ? (backdropUrl.startsWith('http') ? backdropUrl : 'https://image.tmdb.org/t/p/original$backdropUrl')
        : null;

    return Stack(
      children: [
        if (cinematicEnabled && bgUrl != null)
          Positioned.fill(
            child: RepaintBoundary(
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: ResilientNetworkImage(
                    imageUrl: bgUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: AppTheme.backgroundDark),
                  ),
                ),
              ),
            ),
          ),
        if (cinematicEnabled)
          Positioned.fill(
            child: Container(color: AppTheme.backgroundDark.withValues(alpha: 0.92)),
          ),
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Stack(
                  children: [
                    Container(
                      height: 420,
                      width: double.infinity,
                      color: AppTheme.backgroundElevated,
                      child: backdropUrl != null && backdropUrl.isNotEmpty
                          ? ResilientNetworkImage(
                              imageUrl: backdropUrl.startsWith('http') ? backdropUrl : 'https://image.tmdb.org/t/p/original$backdropUrl',
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: AppTheme.backgroundElevated),
                              errorWidget: (_, __, ___) => Container(color: AppTheme.backgroundElevated),
                            )
                          : null,
                    ),
                    Container(
                      height: 420,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.45, 0.8, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Color(0xD008090A),
                            AppTheme.backgroundDark,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 24,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (logoPath != null && logoPath.isNotEmpty)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 86, maxWidth: 300),
                              child: ResilientNetworkImage(
                                imageUrl: 'https://image.tmdb.org/t/p/w500$logoPath',
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            )
                          else
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                shadows: [Shadow(color: AppTheme.backgroundDark.withValues(alpha: 0.87), blurRadius: 12)],
                              ),
                            ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (item.tmdbRatingDouble > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentYellow,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('IMDb', style: TextStyle(color: AppTheme.backgroundDark, fontWeight: FontWeight.w900, fontSize: 10)),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(item.tmdbRating, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13, shadows: [Shadow(color: AppTheme.backgroundDark, blurRadius: 4)])),
                                  const SizedBox(width: 10),
                                  Text('•', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
                                  const SizedBox(width: 10),
                                ],
                                Consumer(builder: (context, ref, _) {
                                  final traktRatingAsync = ref.watch(_traktRatingProvider((mediaType: widget.mediaType, mediaId: widget.mediaId)));
                                  final traktRating = traktRatingAsync.valueOrNull;
                                  if (traktRating == null || traktRating <= 0) return const SizedBox.shrink();
                                  return Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppTheme.accentRed, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Trakt', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 10)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(traktRating.toStringAsFixed(1), style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13, shadows: [Shadow(color: AppTheme.backgroundDark, blurRadius: 4)])),
                                    const SizedBox(width: 10),
                                    Text('•', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
                                    const SizedBox(width: 10),
                                  ]);
                                }),
                                if (item.year.isNotEmpty)
                                  Text(item.year, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, shadows: [Shadow(color: AppTheme.backgroundDark, blurRadius: 4)])),
                                if (item.year.isNotEmpty && data.genres.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Text('•', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
                                  const SizedBox(width: 10),
                                ],
                                if (data.genres.isNotEmpty)
                                  Text(data.genres.take(2).join(' / '), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, shadows: [Shadow(color: AppTheme.backgroundDark, blurRadius: 4)])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: AppTheme.backgroundDark,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    StreameFocusable(
                      onTap: () {
                        if (widget.mediaType == 'tv') {
                          _openStreamSelector(season: _selectedSeason, episode: 1);
                        } else {
                          _openStreamSelector();
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppTheme.textPrimary,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow, color: AppTheme.backgroundDark, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              widget.mediaType == 'tv' ? 'Play S${_selectedSeason}E1' : 'Play',
                              style: const TextStyle(color: AppTheme.backgroundDark, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StreameFocusable(
                            onTap: () => _openStreamSelector(),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.list, color: AppTheme.textPrimary, size: 18),
                                  SizedBox(width: 6),
                                  Text('Sources', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StreameFocusable(
                            onTap: () async => await _toggleWatchlist(item),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _isInWatchlist ? AppTheme.accentYellow : AppTheme.borderLight,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                                    color: _isInWatchlist ? AppTheme.accentYellow : AppTheme.textPrimary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isInWatchlist ? 'Saved' : 'Save',
                                    style: TextStyle(
                                      color: _isInWatchlist ? AppTheme.accentYellow : AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (item.overview.isNotEmpty) ...[
                      Text(
                        item.overview,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.6),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildCastSection(),
                  if (widget.mediaType == 'tv') _buildSeasonsList(),
                  _buildSimilarSection(),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),

        // ─── Floating back button (ARVIO style) ───
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          child: Semantics(
            button: true,
            label: 'Go back',
            child: GestureDetector(
              onTap: () => context.canPop() ? context.pop() : context.go('/home'),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: AppTheme.textPrimary, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCastSection() {
    final creditsAsync = ref.watch(creditsProvider((mediaType: widget.mediaType, mediaId: widget.mediaId)));
    return creditsAsync.when(
      data: (credits) {
        if (credits == null) return const SizedBox.shrink();
        final cast = (credits['cast'] as List<dynamic>? ?? []).take(15).toList();
        if (cast.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cast', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cast.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final person = cast[index] as Map<String, dynamic>;
                  final name = person['name'] as String? ?? '';
                  final character = person['character'] as String? ?? '';
                  final profilePath = person['profile_path'] as String?;
                  final initials = name.trim().isEmpty
                      ? ''
                      : name
                          .trim()
                          .split(RegExp(r'\s+'))
                          .where((p) => p.isNotEmpty)
                          .take(2)
                          .map((p) => p[0])
                          .join()
                          .toUpperCase();
                  return StreameFocusable(
                    onTap: () {},
                    child: Column(
                      children: [
                        Container(
                          width: 86, height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.backgroundElevated,
                          ),
                          child: profilePath != null
                              ? ClipOval(child: ResilientNetworkImage(
                                  imageUrl: 'https://image.tmdb.org/t/p/w185$profilePath',
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(Icons.person, color: AppTheme.textTertiary),
                                ))
                              : Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w800, fontSize: 18),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(width: 92, child: Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                        SizedBox(width: 92, child: Text(character, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSimilarSection() {
    final similarAsync = ref.watch(similarProvider((mediaType: widget.mediaType, mediaId: widget.mediaId)));
    return similarAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('More Like This', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final mt = item.mediaType == MediaType.tv ? 'tv' : 'movie';
                  return StreameFocusable(
                    onTap: () => context.push('/details/$mt/${item.id}'),
                    child: Container(
                      width: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundCard,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              child: item.image.isNotEmpty
                                  ? ResilientNetworkImage(
                                      imageUrl: 'https://image.tmdb.org/t/p/w300${item.image}',
                                      fit: BoxFit.cover, width: 120,
                                      errorWidget: (_, __, ___) => Container(color: AppTheme.backgroundElevated, child: const Icon(Icons.movie, color: AppTheme.textTertiary)),
                                    )
                                  : Container(color: AppTheme.backgroundElevated, child: const Icon(Icons.movie, color: AppTheme.textTertiary)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(item.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSeasonsList() {
    final details = ref.read(mediaDetailsProvider((mediaType: widget.mediaType, mediaId: widget.mediaId))).valueOrNull;
    final seasons = details?.seasons ?? [];
    final episodesAsync = ref.watch(seasonEpisodesProvider((tvId: widget.mediaId, seasonNumber: _selectedSeason)));

    // Clamp selected season to valid range
    if (seasons.isNotEmpty && _selectedSeason > seasons.last.seasonNumber) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSeason = seasons.first.seasonNumber);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seasons',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(seasons.length, (index) {
              final season = seasons[index];
              final sn = season.seasonNumber;
              final isSelected = sn == _selectedSeason;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: StreameFocusable(
                  onTap: () => setState(() => _selectedSeason = sn),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.backgroundCard : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderLight.withValues(alpha: isSelected ? 0.35 : 0.25)),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.backgroundDark.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textTertiary,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                      child: Text(season.name ?? 'Season $sn'),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Episodes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) {
            final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(fade),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_selectedSeason),
            child: episodesAsync.when(
              data: (episodes) => SizedBox(
                height: 190,
                child: ListView.separated(
                  key: PageStorageKey('episodes_s$_selectedSeason'),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: episodes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final ep = episodes[index];
                    return SizedBox(
                      width: 320,
                      child: _EpisodeTile(
                        episodeNumber: ep.episodeNumber,
                        seasonNumber: ep.seasonNumber,
                        name: ep.name,
                        overview: ep.overview,
                        stillPath: ep.stillPath,
                        rating: ep.rating,
                        onTap: () => _openStreamSelector(season: ep.seasonNumber, episode: ep.episodeNumber),
                      ),
                    );
                  },
                ),
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppTheme.textTertiary),
                ),
              ),
              error: (_, __) => Center(
                child: Column(
                  children: [
                    const Text('Failed to load episodes', style: TextStyle(color: AppTheme.textTertiary)),
                    TextButton(
                      onPressed: () => ref.invalidate(seasonEpisodesProvider((tvId: widget.mediaId, seasonNumber: _selectedSeason))),
                      child: const Text('Retry', style: TextStyle(color: AppTheme.accentYellow)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ARVIO-style stream card with quality pill and metadata chips
class _ArvioStreamCard extends StatelessWidget {
  final StreamSource stream;
  final String addonName;
  final String addonId;
  final VoidCallback onTap;

  const _ArvioStreamCard({
    required this.stream,
    required this.addonName,
    required this.addonId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = presentSource(stream, addonName);
    final sizeLabel = stream.size.isNotEmpty
        ? stream.size
        : (stream.sizeBytes != null && stream.sizeBytes! > 0)
            ? formatSizeBytes(stream.sizeBytes!) ?? ''
            : '';

    return Semantics(
      button: true,
      label: p.title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.textPrimary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row + quality pill
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.title,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: p.qualityColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            p.resolutionLabel,
                            style: TextStyle(color: p.qualityColor, fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Metadata chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...p.chips.take(10).map((chip) {
                          final chipColor = _chipColor(chip.label);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.textPrimary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                chip.label,
                                style: TextStyle(
                                  color: chipColor == AppTheme.textSecondary
                                      ? AppTheme.textPrimary.withValues(alpha: 0.78)
                                      : chipColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          );
                        }),
                          if (sizeLabel.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.textPrimary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  sizeLabel,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary.withValues(alpha: 0.78),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                        ],
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
  }

  Color _chipColor(String label) {
    return switch (label) {
      'Cached' || 'Best Match' => AppTheme.accentGreen,
      'VOD' => const Color(0xFF3B82F6),
      'REMUX' || 'BluRay' => AppTheme.accentYellow,
      'DV' || 'IMAX' => const Color(0xFFEC4899),
      'HDR' => const Color(0xFFA855F7),
      _ => AppTheme.textSecondary,
    };
  }

}

class _EpisodeTile extends StatelessWidget {
  final int episodeNumber;
  final int seasonNumber;
  final String? name;
  final String? overview;
  final String? stillPath;
  final double rating;
  final VoidCallback? onTap;

  const _EpisodeTile({
    required this.episodeNumber,
    required this.seasonNumber,
    this.name,
    this.overview,
    this.stillPath,
    this.rating = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = name?.trim().isNotEmpty == true ? name!.trim() : 'Episode $episodeNumber';
    final subtitle = overview?.trim().isNotEmpty == true ? overview!.trim() : null;
    final badge = 'S${seasonNumber}E${episodeNumber.toString().padLeft(2, '0')}';

    return StreameFocusable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.backgroundDark.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              SizedBox(
                height: 190,
                width: double.infinity,
                child: (stillPath != null && stillPath!.isNotEmpty)
                    ? ResilientNetworkImage(
                        imageUrl: 'https://image.tmdb.org/t/p/w780$stillPath',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: AppTheme.backgroundElevated),
                      )
                    : Container(color: AppTheme.backgroundElevated),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.backgroundDark.withValues(alpha: 0.10),
                        AppTheme.backgroundDark.withValues(alpha: 0.20),
                        AppTheme.backgroundDark.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundDark.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.12)),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: 0.80), fontSize: 12, height: 1.25),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (rating > 0) ...[
                          const Icon(Icons.star, size: 14, color: AppTheme.accentYellow),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          'Tap to play',
                          style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: 0.75), fontSize: 12),
                        ),
                        const Spacer(),
                        const Icon(Icons.play_circle_fill, color: AppTheme.textPrimary, size: 22),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}