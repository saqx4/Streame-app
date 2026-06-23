import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/shared/widgets/media_card.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';
import 'package:streame/shared/widgets/streame_toast.dart';
import 'package:streame/shared/widgets/streame_modal.dart';
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
  bool _isWatched = false;
  bool _isSyncing = false;
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
    _checkWatched();
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
      StreameToast.show(
        context,
        message: _isInWatchlist ? 'Added to My List' : 'Removed from My List',
        type: StreameToastType.success,
      );
    } catch (_) {
      // Provider not initialized — skip
    }
  }

  Future<void> _checkWatched() async {
    try {
      final traktRepo = ref.read(traktRepositoryProvider);
      if (!traktRepo.isLinked()) return;

      bool watched = false;
      if (widget.mediaType == 'tv') {
        watched = await ref.read(traktFullyWatchedProvider(widget.mediaId).future);
      } else {
        final watchedItems = await ref.read(traktWatchedProvider.future);
        watched = watchedItems.any((w) => w.tmdbId == widget.mediaId.toString());
      }

      if (mounted) setState(() => _isWatched = watched);
    } catch (_) {}
  }

  Future<void> _toggleWatched() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final traktRepo = ref.read(traktRepositoryProvider);
      if (!traktRepo.isLinked()) {
        if (mounted) {
          StreameToast.show(
            context,
            message: 'Connect Trakt first',
            type: StreameToastType.info,
          );
        }
        return;
      }
      
      final bool wasWatched = _isWatched;
      
      // Optimistic update
      if (mounted) setState(() => _isWatched = !wasWatched);

      if (!wasWatched) {
        try {
          final success = await traktRepo.markAsWatched(
            mediaType: widget.mediaType,
            tmdbId: widget.mediaId,
          );
          if (success && mounted) {
            _onWatchedUpdateSuccess(true, removeFromWatchlist: widget.mediaType == 'movie');
            StreameToast.show(
              context,
              message: 'Marked ${widget.mediaType == 'tv' ? 'show' : 'movie'} as watched',
              type: StreameToastType.success,
            );
          } else if (!success) {
            throw Exception('Request failed');
          }
        } catch (e) {
          if (mounted) setState(() => _isWatched = wasWatched);
          _showTraktError(e);
        }
      } else {
        try {
          final success = await traktRepo.unmarkAsWatched(
            mediaType: widget.mediaType,
            tmdbId: widget.mediaId,
          );
          if (success && mounted) {
            _onWatchedUpdateSuccess(false);
            StreameToast.show(context, message: 'Removed from history', type: StreameToastType.info);
          } else if (!success) {
            throw Exception('Request failed');
          }
        } catch (e) {
          if (mounted) setState(() => _isWatched = wasWatched);
          _showTraktError(e);
        }
      }
    } catch (e) {
      debugPrint('Error in _toggleWatched: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _onWatchedUpdateSuccess(bool isWatched, {bool removeFromWatchlist = true}) {
    ref.invalidate(traktWatchedProvider);
    if (widget.mediaType == 'tv') {
      ref.invalidate(traktFullyWatchedProvider(widget.mediaId));
      ref.invalidate(traktShowProgressProvider(widget.mediaId));
    }
    
    if (isWatched && removeFromWatchlist) {
      final profileId = ref.read(activeProfileIdProvider);
      if (profileId != null) {
        final wlRepo = ref.read(watchlistRepositoryProvider(profileId));
        wlRepo.removeFromWatchlist(widget.mediaId, widget.mediaType).then((_) {
          ref.invalidate(watchlistProvider(profileId));
          ref.invalidate(userWatchlistProvider);
          _checkWatchlist();
        });
      }
    }
  }

  void _showTraktError(dynamic e) {
    if (!mounted) return;
    String message = 'Sync failed';
    if (e is TraktException) {
      message = e.message;
    }
    StreameToast.show(context, message: message, type: StreameToastType.error);
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
                      Text('Not found', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
                      SizedBox(height: 16),
                      TextButton(onPressed: () => context.canPop() ? context.pop() : context.go('/home'), child: Text('Go Back', style: TextStyle(color: AppTheme.accentYellow))),
                    ],
                  ))
                : _buildContent(data),
            loading: () => Center(child: CircularProgressIndicator(color: AppTheme.textPrimary)),
            error: (e, _) => Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $e', style: TextStyle(color: AppTheme.textPrimary)),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(mediaDetailsProvider((mediaType: widget.mediaType, mediaId: widget.mediaId))),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentYellow, foregroundColor: AppTheme.backgroundDark),
                  child: Text('Retry'),
                ),
              ],
            )),
          ),
          if (_showStreamSelector) _buildStreamSelectorOverlay(),
          if (_isSyncing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: AppTheme.accentYellow,
                minHeight: 3,
              ),
            ),
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
                            style: TextStyle(color: AppTheme.accentGreen, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                          SizedBox(height: 2),
                        ],
                        Text(
                          'Select Source',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
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
                        child: Icon(Icons.close, color: AppTheme.textPrimary, size: 20),
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
                          CircularProgressIndicator(color: AppTheme.accentRed, strokeWidth: 2.5),
                          SizedBox(height: 12),
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
                                SizedBox(height: 12),
                                Text(
                                  imdbId.isEmpty ? 'No Streaming Addons' : 'No sources found',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  imdbId.isEmpty ? 'Go to Settings → Addons to add a streaming addon' : 'Try adding more addons',
                                  style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    _closeStreamSelector();
                                    final router = GoRouter.of(context);
                                    Future.microtask(() {
                                      if (mounted) router.go('/settings');
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentGreen,
                                    foregroundColor: AppTheme.backgroundDark,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text('Manage Addons'),
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
                                  separatorBuilder: (_, __) => SizedBox(width: 10),
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
                            SizedBox(height: 10),
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
                      decoration: BoxDecoration(
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
                          SizedBox(height: 10),
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
                                    child: Text('IMDb', style: TextStyle(color: AppTheme.backgroundDark, fontWeight: FontWeight.w900, fontSize: 10)),
                                  ),
                                  SizedBox(width: 6),
                                  Text(item.tmdbRating, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13, shadows: [Shadow(color: AppTheme.backgroundDark, blurRadius: 4)])),
                                  SizedBox(width: 10),
                                  Text('•', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
                                  SizedBox(width: 10),
                                ],
                                Consumer(builder: (context, ref, _) {
                                  final traktRatingAsync = ref.watch(_traktRatingProvider((mediaType: widget.mediaType, mediaId: widget.mediaId)));
                                  final traktRating = traktRatingAsync.valueOrNull;
                                  if (traktRating == null || traktRating <= 0) return const SizedBox.shrink();
                                  return Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppTheme.accentRed, borderRadius: BorderRadius.circular(4)),
                                      child: Text('Trakt', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 10)),
                                    ),
                                    SizedBox(width: 6),
                                    Text(traktRating.toStringAsFixed(1), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13, shadows: [Shadow(color: AppTheme.backgroundDark, blurRadius: 4)])),
                                    SizedBox(width: 10),
                                    Text('•', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
                                    SizedBox(width: 10),
                                  ]);
                                }),
                                if (item.year.isNotEmpty)
                                  Text(item.year, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, shadows: [Shadow(color: AppTheme.backgroundDark, blurRadius: 4)])),
                                if (item.year.isNotEmpty && data.genres.isNotEmpty) ...[
                                  SizedBox(width: 10),
                                  Text('•', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
                                  SizedBox(width: 10),
                                ],
                                if (data.genres.isNotEmpty)
                                  Text(data.genres.take(2).join(' / '), style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, shadows: [Shadow(color: AppTheme.backgroundDark, blurRadius: 4)])),
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
                    SizedBox(height: 12),
                    SizedBox(height: 4),
                    // ─── Action row: circular icon buttons + Play ───
                    Row(
                      children: [
                        _ActionBarIcon(
                          icon: _isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                          color: _isInWatchlist ? AppTheme.accentYellow : AppTheme.textPrimary,
                          onTap: () async => await _toggleWatchlist(item),
                        ),
                        SizedBox(width: 10),
                        _ActionBarIcon(
                          icon: Icons.favorite_border,
                          color: AppTheme.textSecondary,
                          onTap: () {},
                        ),
                        SizedBox(width: 10),
                        _WatchedButton(
                          isWatched: _isWatched,
                          onTap: _toggleWatched,
                          onLongPress: () {
                            if (_isWatched) {
                              _toggleWatched(); // Long press unmarks if already watched
                            }
                          },
                        ),
                        Spacer(),
                        StreameFocusable(
                          onTap: () {
                            if (widget.mediaType == 'tv') {
                              _openStreamSelector(season: _selectedSeason, episode: 1);
                            } else {
                              _openStreamSelector();
                            }
                          },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            decoration: BoxDecoration(
                              color: AppTheme.textPrimary,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded, color: AppTheme.backgroundDark, size: 26),
                                SizedBox(width: 4),
                                Text(
                                  widget.mediaType == 'tv' ? 'Play S${_selectedSeason}E1' : 'Play',
                                  style: TextStyle(color: AppTheme.backgroundDark, fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18),
                    if (item.overview.isNotEmpty) ...[
                      Text(
                        item.overview,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.6),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 20),
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
                  SizedBox(height: 100),
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
                child: Icon(Icons.arrow_back, color: AppTheme.textPrimary, size: 20),
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
            Text('Cast', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cast.length,
                separatorBuilder: (_, __) => SizedBox(width: 12),
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
                                  errorWidget: (_, __, ___) => Icon(Icons.person, color: AppTheme.textTertiary),
                                ))
                              : Center(
                                  child: Text(
                                    initials,
                                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w800, fontSize: 18),
                                  ),
                                ),
                        ),
                        SizedBox(height: 6),
                        SizedBox(width: 92, child: Text(name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                        SizedBox(width: 92, child: Text(character, style: TextStyle(color: AppTheme.textTertiary, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 24),
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
        
        final prefs = ref.watch(sharedPreferencesProvider);
        final cardSize = prefs.getDouble('settings_card_size') ?? 0.5;
        final double cardWidth = (0.5 + cardSize * 0.5) * 126;
        final double cardHeight = (0.5 + cardSize * 0.5) * 189;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'More Like This',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final mt = item.mediaType == MediaType.tv ? 'tv' : 'movie';
                  
                  return MediaCard(
                    item: item,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    onTap: () => context.push('/details/$mt/${item.id}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
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
    final traktProgress = ref.watch(traktShowProgressProvider(widget.mediaId)).valueOrNull;

    // Helper to check if an episode is watched via Trakt progress
    bool isEpisodeWatched(int season, int episode) {
      if (traktProgress == null) return false;
      final seasons = traktProgress['seasons'] as List<dynamic>? ?? [];
      final s = seasons.firstWhere((s) => s['number'] == season, orElse: () => null);
      if (s == null) return false;
      final episodes = s['episodes'] as List<dynamic>? ?? [];
      return episodes.any((e) => e['number'] == episode);
    }

    // Clamp selected season to valid range
    if (seasons.isNotEmpty && _selectedSeason > seasons.last.seasonNumber) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSeason = seasons.first.seasonNumber);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seasons',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 12),
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
                child: _SeasonChip(
                  name: season.name ?? 'Season $sn',
                  seasonNumber: sn,
                  episodeCount: season.episodeCount,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedSeason = sn),
                  onMarkAllWatched: () async {
                    if (_isSyncing) return;
                    try {
                      final traktRepo = ref.read(traktRepositoryProvider);
                      if (!traktRepo.isLinked()) {
                        StreameToast.show(context, message: 'Connect Trakt first', type: StreameToastType.info);
                        return;
                      }
                      setState(() => _isSyncing = true);
                      final success = await traktRepo.markAsWatched(
                        mediaType: 'tv',
                        tmdbId: widget.mediaId,
                        season: sn,
                      );
                      if (success && mounted) {
                        StreameToast.show(context, message: 'Season $sn marked as watched', type: StreameToastType.success);
                        _onWatchedUpdateSuccess(true);
                      }
                    } catch (e) {
                      _showTraktError(e);
                    } finally {
                      if (mounted) setState(() => _isSyncing = false);
                    }
                  },
                ),
              );
            }),
          ),
        ),
        SizedBox(height: 24),
        Text(
          'Episodes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 12),
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
                height: 240,
                child: ListView.separated(
                  key: PageStorageKey('episodes_s$_selectedSeason'),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: episodes.length,
                  separatorBuilder: (_, __) => SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final ep = episodes[index];
                    return SizedBox(
                      width: 300,
                      child: _EpisodeTile(
                        episodeNumber: ep.episodeNumber,
                        seasonNumber: ep.seasonNumber,
                        name: ep.name,
                        overview: ep.overview,
                        stillPath: ep.stillPath,
                        rating: ep.rating,
                        airDate: ep.airDate,
                        isWatched: isEpisodeWatched(ep.seasonNumber, ep.episodeNumber),
                        onTap: () => _openStreamSelector(season: ep.seasonNumber, episode: ep.episodeNumber),
                        onMarkAsWatched: () async {
                          if (_isSyncing) return;
                          try {
                            final traktRepo = ref.read(traktRepositoryProvider);
                            if (!traktRepo.isLinked()) {
                              if (mounted) {
                                StreameToast.show(
                                  context,
                                  message: 'Connect Trakt first',
                                  type: StreameToastType.info,
                                );
                              }
                              return;
                            }

                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => _isSyncing = true);
                            final bool wasWatched = isEpisodeWatched(ep.seasonNumber, ep.episodeNumber);

                            if (wasWatched) {
                              final success = await traktRepo.unmarkAsWatched(
                                mediaType: 'tv',
                                tmdbId: widget.mediaId,
                                season: ep.seasonNumber,
                                episode: ep.episodeNumber,
                              );
                              if (success && mounted) {
                                StreameToast.show(
                                  context,
                                  message: 'Removed S${ep.seasonNumber}E${ep.episodeNumber} from history',
                                  type: StreameToastType.info,
                                );
                                _onWatchedUpdateSuccess(false);
                              }
                            } else {
                              final success = await traktRepo.markAsWatched(
                                mediaType: 'tv',
                                tmdbId: widget.mediaId,
                                season: ep.seasonNumber,
                                episode: ep.episodeNumber,
                              );
                              if (success && mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('S${ep.seasonNumber}E${ep.episodeNumber.toString().padLeft(2, '0')} marked as watched'),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () async {
                                        await traktRepo.unmarkAsWatched(
                                          mediaType: 'tv',
                                          tmdbId: widget.mediaId,
                                          season: ep.seasonNumber,
                                          episode: ep.episodeNumber,
                                        );
                                        _onWatchedUpdateSuccess(false);
                                      },
                                    ),
                                  ),
                                );
                                _onWatchedUpdateSuccess(true);
                              }
                            }
                          } catch (e) {
                            _showTraktError(e);
                          } finally {
                            if (mounted) setState(() => _isSyncing = false);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              loading: () => Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppTheme.textTertiary),
                ),
              ),
              error: (_, __) => Center(
                child: Column(
                  children: [
                    Text('Failed to load episodes', style: TextStyle(color: AppTheme.textTertiary)),
                    TextButton(
                      onPressed: () => ref.invalidate(seasonEpisodesProvider((tvId: widget.mediaId, seasonNumber: _selectedSeason))),
                      child: Text('Retry', style: TextStyle(color: AppTheme.accentYellow)),
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

// ─── Circular action bar icon ───
class _ActionBarIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionBarIcon({required this.icon, required this.color, this.onTap});

  @override
  State<_ActionBarIcon> createState() => _ActionBarIconState();
}

class _ActionBarIconState extends State<_ActionBarIcon> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          );
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.backgroundCard,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderLight.withValues(alpha: 0.4)),
          ),
          child: Icon(widget.icon, color: widget.color, size: 20),
        ),
      ),
    );
  }
}

// ─── Watched button with glassmorphism expanding animation ───
class _WatchedButton extends StatefulWidget {
  final bool isWatched;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _WatchedButton({required this.isWatched, this.onTap, this.onLongPress});

  @override
  State<_WatchedButton> createState() => _WatchedButtonState();
}

class _WatchedButtonState extends State<_WatchedButton> with TickerProviderStateMixin {
  late AnimationController _expandCtrl;
  late AnimationController _iconCtrl;
  late Animation<double> _expandAnim;
  late Animation<double> _iconScaleAnim;
  late Animation<double> _iconRotateAnim;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _iconCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _expandAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic),
    );
    _iconScaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    _iconRotateAnim = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.easeOutCubic),
    );

    if (widget.isWatched) {
      _expandCtrl.value = 1.0;
      _iconCtrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_WatchedButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWatched && !oldWidget.isWatched && !_isAnimating) {
      _animateForward();
    } else if (!widget.isWatched && oldWidget.isWatched && !_isAnimating) {
      _animateReverse();
    }
  }

  void _animateForward() {
    _isAnimating = true;
    _expandCtrl.forward().then((_) => _iconCtrl.forward()).then((_) => _isAnimating = false);
  }

  void _animateReverse() {
    _isAnimating = true;
    _iconCtrl.reverse().then((_) => _expandCtrl.reverse()).then((_) => _isAnimating = false);
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: Listenable.merge([_expandAnim, _iconScaleAnim, _iconRotateAnim]),
        builder: (context, child) {
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Color.lerp(
                  AppTheme.borderLight.withValues(alpha: 0.4),
                  AppTheme.accentGreen.withValues(alpha: 0.8),
                  _expandAnim.value,
                )!,
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        AppTheme.backgroundCard,
                        AppTheme.accentGreen.withValues(alpha: 0.3),
                        _expandAnim.value,
                      ),
                    ),
                  ),
                  if (_expandAnim.value > 0)
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 4.0 * _expandAnim.value,
                        sigmaY: 4.0 * _expandAnim.value,
                      ),
                      child: Container(color: Colors.transparent),
                    ),
                  if (_expandAnim.value > 0 && _expandAnim.value < 1.0)
                    Transform.scale(
                      scale: 0.8 + (_expandAnim.value * 0.6),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.accentGreen.withValues(alpha: 0.4 * (1.0 - _expandAnim.value)),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  Transform.scale(
                    scale: _iconScaleAnim.value,
                    child: Transform.rotate(
                      angle: _iconRotateAnim.value,
                      child: Icon(
                        Icons.check_rounded,
                        color: Color.lerp(
                          AppTheme.textSecondary,
                          AppTheme.textPrimary,
                          _expandAnim.value,
                        ),
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 10),
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
                    SizedBox(height: 8),
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

class _EpisodeTile extends StatefulWidget {
  final int episodeNumber;
  final int seasonNumber;
  final String? name;
  final String? overview;
  final String? stillPath;
  final double rating;
  final DateTime? airDate;
  final bool isWatched;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsWatched;

  const _EpisodeTile({
    required this.episodeNumber,
    required this.seasonNumber,
    this.name,
    this.overview,
    this.stillPath,
    this.rating = 0,
    this.airDate,
    this.isWatched = false,
    this.onTap,
    this.onMarkAsWatched,
  });

  @override
  State<_EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<_EpisodeTile> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails _) {
    _animCtrl.forward();
    _showActionModal();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _animCtrl.reverse();
  }

  void _showActionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => EpisodeActionModal(
        episodeNumber: widget.episodeNumber,
        seasonNumber: widget.seasonNumber,
        name: widget.name,
        isWatched: widget.isWatched,
        onMarkAsWatched: () => widget.onMarkAsWatched?.call(),
        onPlay: () => widget.onTap?.call(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.name?.trim().isNotEmpty == true ? widget.name!.trim() : 'Episode ${widget.episodeNumber}';
    final badge = 'E${widget.episodeNumber.toString().padLeft(2, '0')}';
    final hasImage = widget.stillPath != null && widget.stillPath!.isNotEmpty;

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPressStart: _onLongPressStart,
            onLongPressEnd: _onLongPressEnd,
            onLongPressCancel: () => _animCtrl.reverse(),
            child: Container(
              height: 240,
              decoration: BoxDecoration(
                color: AppTheme.backgroundCard,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Thumbnail ───
                  SizedBox(
                    height: 168,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasImage)
                          ResilientNetworkImage(
                            imageUrl: 'https://image.tmdb.org/t/p/w500${widget.stillPath}',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _PlaceholderThumb(episode: widget.episodeNumber),
                          )
                        else
                          _PlaceholderThumb(episode: widget.episodeNumber),
                        // Gradient scrim
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppTheme.backgroundDark.withValues(alpha: 0.85),
                                ],
                                stops: [0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Episode badge — top-left
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundDark.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        // Watched indicator — top-right
                        if (widget.isWatched)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: AppTheme.backgroundDark,
                                size: 14,
                              ),
                            ),
                          ),
                        // Play icon — bottom-right
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: widget.isWatched 
                                  ? AppTheme.accentGreen.withValues(alpha: 0.85)
                                  : AppTheme.textPrimary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isWatched ? Icons.check_rounded : Icons.play_arrow_rounded,
                              color: widget.isWatched ? AppTheme.backgroundDark : AppTheme.textPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ─── Content ───
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Spacer(),
                          Row(
                            children: [
                              if (widget.rating > 0) ...[
                                Icon(Icons.star_rounded, size: 15, color: AppTheme.accentYellow),
                                SizedBox(width: 3),
                                Text(
                                  widget.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: AppTheme.textPrimary.withValues(alpha: 0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 12),
                              ],
                              if (widget.airDate != null)
                                Text(
                                  _formatAirDate(widget.airDate!),
                                  style: TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
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

  String _formatAirDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}

// ─── Placeholder thumbnail when no still image ───
class _PlaceholderThumb extends StatelessWidget {
  final int episode;
  const _PlaceholderThumb({required this.episode});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundElevated,
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: AppTheme.textTertiary.withValues(alpha: 0.3),
          size: 40,
        ),
      ),
    );
  }
}

// ─── Season chip with long-press expanding animation ───
class _SeasonChip extends StatefulWidget {
  final String name;
  final int seasonNumber;
  final int episodeCount;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAllWatched;

  const _SeasonChip({
    required this.name,
    required this.seasonNumber,
    this.episodeCount = 0,
    required this.isSelected,
    this.onTap,
    this.onMarkAllWatched,
  });

  @override
  State<_SeasonChip> createState() => _SeasonChipState();
}

class _SeasonChipState extends State<_SeasonChip> with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _borderAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic),
    );
    _borderAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails _) {
    _pressCtrl.forward();
    setState(() => _isPressed = true);
    _showActionModal();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _pressCtrl.reverse();
    setState(() => _isPressed = false);
  }

  void _showActionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SeasonActionModal(
        seasonNumber: widget.seasonNumber,
        name: widget.name,
        episodeCount: widget.episodeCount,
        onMarkAllWatched: () => widget.onMarkAllWatched?.call(),
        onSelect: () => widget.onTap?.call(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnim, _borderAnim]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPressStart: _onLongPressStart,
            onLongPressEnd: _onLongPressEnd,
            onLongPressCancel: () {
              _pressCtrl.reverse();
              setState(() => _isPressed = false);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isSelected || _isPressed
                    ? AppTheme.backgroundCard
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Color.lerp(
                    AppTheme.borderLight.withValues(alpha: 0.25),
                    _isPressed
                        ? AppTheme.accentYellow
                        : (widget.isSelected ? AppTheme.accentGreen : AppTheme.borderLight.withValues(alpha: 0.35)),
                    _isPressed ? _borderAnim.value : 1.0,
                  )!,
                  width: _isPressed ? 1.5 : 1.0,
                ),
                boxShadow: (widget.isSelected || _isPressed)
                    ? [
                        BoxShadow(
                          color: (_isPressed ? AppTheme.accentYellow : AppTheme.backgroundDark).withValues(alpha: 0.35),
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
                  color: widget.isSelected || _isPressed ? AppTheme.textPrimary : AppTheme.textTertiary,
                  fontWeight: widget.isSelected || _isPressed ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(widget.name),
              ),
            ),
          ),
        );
      },
    );
  }
}