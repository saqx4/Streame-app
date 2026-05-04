import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/focus/focusable.dart';
import 'package:streame/core/repositories/tmdb_repository.dart';
import 'package:streame/core/repositories/addon_repository.dart';
import 'package:streame/core/repositories/watchlist_repository.dart';
import 'package:streame/core/repositories/profile_repository.dart';
import 'package:streame/core/models/stream_models.dart';
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
  static const double _heroHeight = 420;

  int _selectedSeason = 1;
  bool _isInWatchlist = false;
  bool _showStreamSelector = false;
  int? _streamSelectorSeason;
  int? _streamSelectorEpisode;
  String _streamSelectorFilterAddonId = 'all';

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
    final type = widget.mediaType == 'tv' ? 'series' : 'movie';
    final season = _streamSelectorSeason;
    final episode = _streamSelectorEpisode;

    final streamsAsync = ref.watch(detailsStreamsProvider((
      type: type, imdbId: imdbId, tmdbId: widget.mediaId.toString(),
      season: season, episode: episode,
    )));

    final title = details?.item.title ?? '';
    final subtitle = widget.mediaType == 'tv' ? (details?.item.subtitle ?? '') : (details?.item.subtitle ?? '');
    final rawBackdrop = details?.item.backdrop ?? (details?.item.image.isNotEmpty == true ? details!.item.image : null);
    final backdropUrl = (rawBackdrop != null && rawBackdrop.isNotEmpty)
        ? (rawBackdrop.startsWith('http') ? rawBackdrop : 'https://image.tmdb.org/t/p/original$rawBackdrop')
        : null;
    final isEpisode = season != null && episode != null;

    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            // Blurred backdrop (matches Nuvio's 22dp blur)
            if (backdropUrl != null && backdropUrl.isNotEmpty)
              Positioned.fill(
                child: ClipRect(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: ResilientNetworkImage(
                      imageUrl: backdropUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            // Dark overlay (0.82 for movies, 0.9 for episodes — matches Nuvio)
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: isEpisode ? 0.9 : 0.82)),
            ),
            Column(
              children: [
                // Top bar: back + refresh (matches Nuvio's back + refresh buttons)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      _NuvioCircleButton(
                        icon: Icons.arrow_back,
                        onPressed: () => setState(() => _showStreamSelector = false),
                      ),
                      const SizedBox(width: 8),
                      _NuvioCircleButton(
                        icon: Icons.refresh,
                        onPressed: () => ref.invalidate(detailsStreamsProvider((
                          type: type, imdbId: imdbId, tmdbId: widget.mediaId.toString(),
                          season: season, episode: episode,
                        ))),
                      ),
                    ],
                  ),
                ),
                // Hero block (matches Nuvio's MovieHeroBlock / EpisodeHeroBlock)
                if (isEpisode) ...[
                  // Episode hero: episode badge + title + show name
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'S$season E$episode',
                          style: TextStyle(
                            color: AppTheme.accentGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  // Movie hero: centered logo or title
                  Container(
                    height: 140,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                // Stream list
                Expanded(
                  child: streamsAsync.when(
                    data: (results) {
                      final filterOptions = <({String id, String name})>[
                        (id: 'all', name: 'All'),
                      ];
                      for (final r in results) {
                        filterOptions.add((id: r.addonId, name: r.addonName));
                      }

                      if (_streamSelectorFilterAddonId != 'all' && !results.any((r) => r.addonId == _streamSelectorFilterAddonId)) {
                        _streamSelectorFilterAddonId = 'all';
                      }

                      final filteredResults = _streamSelectorFilterAddonId == 'all'
                          ? results
                          : results.where((r) => r.addonId == _streamSelectorFilterAddonId).toList();

                      final flat = <({StreamSource s, String addonName, String addonId})>[];
                      for (final r in filteredResults) {
                        for (final s in r.streams) {
                          flat.add((s: s, addonName: r.addonName, addonId: r.addonId));
                        }
                      }

                      flat.sort((a, b) {
                        final pa = presentSource(a.s, a.addonName);
                        final pb = presentSource(b.s, b.addonName);
                        final cached = (pb.sortCached ? 1 : 0) - (pa.sortCached ? 1 : 0);
                        if (cached != 0) return cached;
                        final direct = (pb.sortDirect ? 1 : 0) - (pa.sortDirect ? 1 : 0);
                        if (direct != 0) return direct;
                        final res = pb.resolutionScore.compareTo(pa.resolutionScore);
                        if (res != 0) return res;
                        final rel = pb.releaseScore.compareTo(pa.releaseScore);
                        if (rel != 0) return rel;
                        final size = pb.sizeBytes.compareTo(pa.sizeBytes);
                        if (size != 0) return size;
                        return pa.title.toLowerCase().compareTo(pb.title.toLowerCase());
                      });

                      if (flat.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 48, color: Colors.white.withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                Text('No streams found', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                                const SizedBox(height: 4),
                                Text(
                                  imdbId.isEmpty
                                      ? 'IMDB ID not found — streams require an IMDB ID'
                                      : 'Make sure addons are installed and enabled',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() => _showStreamSelector = false);
                                    Future.microtask(() {
                                      if (mounted) context.go('/settings');
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentGreen,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Manage Addons'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          // Provider filter chips (matches Nuvio's ProviderFilterRow)
                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              scrollDirection: Axis.horizontal,
                              itemCount: filterOptions.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final opt = filterOptions[i];
                                final isSelected = _streamSelectorFilterAddonId == opt.id;
                                return GestureDetector(
                                  onTap: () => setState(() => _streamSelectorFilterAddonId = opt.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      opt.name,
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.9),
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Stream cards (matches Nuvio's StreamCard)
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                              itemCount: flat.length,
                              itemBuilder: (context, idx) {
                                final item = flat[idx];
                                return _NuvioStreamCard(
                                  stream: item.s,
                                  addonName: item.addonName,
                                  addonId: item.addonId,
                                  onTap: () => _playStream(item.s, item.addonName, item.addonId),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          const SizedBox(height: 12),
                          Text('Finding streams...', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.white.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text('Error: $e', style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: ResilientNetworkImage(
                  imageUrl: bgUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: AppTheme.backgroundDark),
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
        SliverAppBar(
          backgroundColor: AppTheme.backgroundDark,
          pinned: true,
          expandedHeight: _heroHeight,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                color: _isInWatchlist ? AppTheme.accentYellow : AppTheme.textPrimary,
              ),
              onPressed: () async {
                await _toggleWatchlist(item);
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            // Avoid showing a second "small title" while expanded. We render the
            // large logo/title inside the background overlay, and only show the
            // collapsed title when the app bar is near-collapsed.
            titlePadding: EdgeInsets.zero,
            title: const SizedBox.shrink(),
            background: LayoutBuilder(
              builder: (context, constraints) {
                final t = ((constraints.maxHeight - kToolbarHeight) / (_heroHeight - kToolbarHeight)).clamp(0.0, 1.0);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (backdropUrl != null && backdropUrl.isNotEmpty)
                      ResilientNetworkImage(
                        imageUrl: backdropUrl.startsWith('http') ? backdropUrl : 'https://image.tmdb.org/t/p/original$backdropUrl',
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppTheme.backgroundElevated),
                        errorWidget: (_, __, ___) => Container(color: AppTheme.backgroundElevated),
                      )
                    else
                      Container(color: AppTheme.backgroundElevated),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.5, 1.0],
                          colors: [
                            Colors.transparent,
                            Color(0x8008090A),
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
                            Transform.translate(
                              offset: Offset(0, (1.0 - t) * -22),
                              child: Opacity(
                                opacity: t,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 92, maxWidth: 340),
                                  child: ResilientNetworkImage(
                                    imageUrl: 'https://image.tmdb.org/t/p/w500$logoPath',
                                    fit: BoxFit.contain,
                                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            )
                          else
                            Opacity(
                              opacity: t,
                              child: Text(
                                item.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          // Genre subtitle (3 genres only, no type or year)
                          Builder(
                            builder: (context) {
                              final genreStr = data.genres.take(3).join('  •  ');
                              if (genreStr.isEmpty) return const SizedBox.shrink();
                              return Text(
                                genreStr,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: StreameFocusable(
                                  onTap: () {
                                    if (widget.mediaType == 'tv') {
                                      _openStreamSelector(season: _selectedSeason, episode: 1);
                                    } else {
                                      _openStreamSelector();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.textPrimary,
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.play_arrow, color: AppTheme.backgroundDark),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.mediaType == 'tv' ? 'Play S1E1' : 'Play',
                                          style: const TextStyle(
                                            color: AppTheme.backgroundDark,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: StreameFocusable(
                                  onTap: () async {
                                    await _toggleWatchlist(item);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.backgroundCard,
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(color: AppTheme.borderLight),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add, color: AppTheme.textPrimary),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isInWatchlist ? 'Saved' : 'Save',
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Collapsed logo/title (only visible near collapsed state)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 72,
                      right: 72,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: (1.0 - t).clamp(0.0, 1.0),
                          child: Center(
                            child: logoPath != null && logoPath.isNotEmpty
                                ? SizedBox(
                                    height: 24,
                                    child: ResilientNetworkImage(
                                      imageUrl: 'https://image.tmdb.org/t/p/w300$logoPath',
                                      fit: BoxFit.contain,
                                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                    ),
                                  )
                                : Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.tmdbRatingDouble > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentYellow,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'IMDb',
                                style: TextStyle(
                                  color: AppTheme.backgroundDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.tmdbRating,
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    if (item.year.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text(
                        item.year,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                    if (data.genres.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(child: Text(
                        data.genres.take(3).join(' · '),
                        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                if (item.overview.isNotEmpty) ...[
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.overview,
                    style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                ],
                _buildCastSection(),
                if (widget.mediaType == 'tv') ...[
                  _buildSeasonsList(),
                ],
                _buildSimilarSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
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
    final episodesAsync = ref.watch(seasonEpisodesProvider((tvId: widget.mediaId, seasonNumber: _selectedSeason)));

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
            children: List.generate(5, (index) {
              final sn = index + 1;
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
                                color: Colors.black.withValues(alpha: 0.35),
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
                      child: Text('Season $sn'),
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

/// Nuvio-style circle button matching NuvioBackButton
class _NuvioCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _NuvioCircleButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

/// Nuvio-style stream card matching Nuvio's StreamCard composable
/// Shows: title, addon name, quality, size, transport type, codec, release, language, metadata chips
class _NuvioStreamCard extends StatelessWidget {
  final StreamSource stream;
  final String addonName;
  final String addonId;
  final VoidCallback onTap;

  const _NuvioStreamCard({
    required this.stream,
    required this.addonName,
    required this.addonId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = presentSource(stream, addonName);
    final sizeLabel = _formatSize(p.sizeBytes);
    final topRight = p.resolutionLabel;
    final subLine = <String?>[
      p.releaseLabel,
      p.codecLabel,
      p.audioLabel,
      p.languageLabel,
      p.transportLabel,
    ].where((e) => e != null && e.trim().isNotEmpty).map((e) => e!).join(' • ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(minHeight: 92),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0D0F),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 10)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.addonLabel.isNotEmpty ? p.addonLabel : addonName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    topRight,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              p.title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.90),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subLine.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subLine,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (sizeLabel != null)
                  _BottomPill(text: sizeLabel),
                if (stream.size.isNotEmpty) _BottomPill(text: 'SIZE ${stream.size}'),
              ],
            ),
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

class _BottomPill extends StatelessWidget {
  final String text;
  const _BottomPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Parsed source presentation matching Kotlin's SourcePresentation
class _SourcePresentation {
  final StreamSource stream;
  final String title;
  final String addonLabel;
  final String resolutionLabel;
  final int resolutionScore;
  final String? releaseLabel;
  final int releaseScore;
  final String? codecLabel;
  final String? audioLabel;
  final String? transportLabel;
  final String? multiSourceLabel;
  final String? languageLabel;
  final List<({String label, Color color})> chips;
  final Color qualityColor;
  final int sizeBytes;
  final bool sortCached;
  final bool sortDirect;

  const _SourcePresentation({
    required this.stream,
    required this.title,
    required this.addonLabel,
    required this.resolutionLabel,
    required this.resolutionScore,
    this.releaseLabel,
    required this.releaseScore,
    this.codecLabel,
    this.audioLabel,
    this.transportLabel,
    this.multiSourceLabel,
    this.languageLabel,
    required this.chips,
    required this.qualityColor,
    required this.sizeBytes,
    required this.sortCached,
    required this.sortDirect,
  });
}

// Regex patterns matching Kotlin app
final _av1Re = RegExp(r'\bAV1\b', caseSensitive: false);
final _hevcRe = RegExp(r'\b(HEVC|X265|H265)\b', caseSensitive: false);
final _h264Re = RegExp(r'\b(H264|X264|AVC)\b', caseSensitive: false);
final _remuxRe = RegExp(r'\bREMUX\b', caseSensitive: false);
final _blurayRe = RegExp(r'\b(BLURAY|BDRIP|BDREMUX)\b', caseSensitive: false);
final _webdlRe = RegExp(r'\b(WEB[- .]?DL|WEBDL)\b', caseSensitive: false);
final _webripRe = RegExp(r'\bWEB[- .]?RIP\b', caseSensitive: false);
final _hdtvRe = RegExp(r'\bHDTV\b', caseSensitive: false);
final _camRe = RegExp(r'\b(CAM|TS|TELESYNC|HDCAM)\b', caseSensitive: false);
final _atmosRe = RegExp(r'\bATMOS\b', caseSensitive: false);
final _truehdRe = RegExp(r'\bTRUEHD\b', caseSensitive: false);
final _dtsRe = RegExp(r'\b(DTS[- .]?HD|DTS|DDP|EAC3|AC3|AAC)\b', caseSensitive: false);
final _ch71Re = RegExp(r'\b7[ .]?1\b', caseSensitive: false);
final _ch51Re = RegExp(r'\b5[ .]?1\b', caseSensitive: false);
final _multiAudioRe = RegExp(r'\b(MULTI|DUAL[ .-]?AUDIO|MULTI[ .-]?AUDIO)\b', caseSensitive: false);
final _langHintRe = RegExp(r'\b(ENG|ENGLISH|HIN|HINDI|TAM|TAMIL|TEL|TELUGU|JPN|JAPANESE|KOR|KOREAN|SPA|SPANISH|FRE|FRENCH|GER|GERMAN|ITA|ITALIAN)\b', caseSensitive: false);
final _dvRe = RegExp(r'\b(DV|DoVi|Dolby[\s._-]*Vision)\b', caseSensitive: false);
final _hdrRe = RegExp(r'\bHDR(10\+?|10)?\b', caseSensitive: false);
final _imaxRe = RegExp(r'\bIMAX\b', caseSensitive: false);

/// Present a stream source with full metadata parsing — matches Kotlin's presentSource()
_SourcePresentation presentSource(StreamSource stream, String addonName) {
  final title = (stream.behaviorHints?.filename?.isNotEmpty == true)
      ? stream.behaviorHints!.filename!
      : stream.source;
  final addonLabel = addonName.split(' - ').first.trim();

  final searchBlob = '${stream.quality} ${stream.source} ${stream.behaviorHints?.filename ?? ''}';

  // Resolution
  final resolutionLabel = _detectResolution(searchBlob, stream.quality);
  final resolutionScore = _resolutionScore(resolutionLabel);
  final qualityColor = _qualityColor(resolutionLabel);

  // Release type
  final releaseLabel = _detectRelease(searchBlob);
  final releaseScore = _releaseScore(releaseLabel);

  // Codec
  final codecLabel = _detectCodec(searchBlob);

  // Audio
  final audioLabel = _detectAudio(searchBlob);

  // Transport
  final addonLower = addonLabel.toLowerCase();
  final isTorrentProvider = addonLower.contains('torrentio') ||
      addonLower.contains('torrent') ||
      addonLower.contains('debrid') ||
      addonLower.contains('realdebrid') ||
      addonLower.contains('premiumize') ||
      addonLower.contains('alldebrid') ||
      searchBlob.toLowerCase().contains('magnet:');
  final hasDirectHttp = stream.url != null && stream.url!.isNotEmpty && stream.url!.startsWith('http');

  final transportLabel = stream.behaviorHints?.cached == true
      ? 'Cached'
      : (stream.infoHash != null && stream.infoHash!.isNotEmpty) || stream.sources.isNotEmpty || isTorrentProvider
          ? 'Torrent'
          : hasDirectHttp
              ? 'Direct'
              : null;

  // Multi-source
  final multiSourceLabel = stream.sources.length > 1
      ? '${stream.sources.length} sources'
      : stream.sources.length == 1
          ? '1 source'
          : null;

  // Language
  final subtitleLangs = stream.subtitles.map((s) => s.lang).where((l) => l.isNotEmpty).toList();
  String? languageLabel;
  if (_multiAudioRe.hasMatch(searchBlob)) {
    languageLabel = 'Multi-audio';
  } else if (subtitleLangs.length > 1) {
    languageLabel = '${subtitleLangs.length} langs';
  } else if (subtitleLangs.length == 1) {
    languageLabel = subtitleLangs.first.toUpperCase();
  } else {
    final m = _langHintRe.firstMatch(searchBlob);
    if (m != null) languageLabel = m.group(0)!.toUpperCase();
  }

  // Build chips with colors
  final chips = <({String label, Color color})>[];
  chips.add((label: addonLabel, color: AppTheme.textSecondary));
  if (transportLabel != null) {
    chips.add((label: transportLabel, color: transportLabel == 'Cached' ? Colors.green : AppTheme.textSecondary));
  }
  if (multiSourceLabel != null) chips.add((label: multiSourceLabel, color: AppTheme.textSecondary));
  if (languageLabel != null) chips.add((label: languageLabel, color: AppTheme.textSecondary));
  if (releaseLabel != null) {
    final c = (releaseLabel == 'REMUX' || releaseLabel == 'BluRay') ? AppTheme.accentYellow : AppTheme.textSecondary;
    chips.add((label: releaseLabel, color: c));
  }
  if (codecLabel != null) chips.add((label: codecLabel, color: AppTheme.textSecondary));
  if (_hdrRe.hasMatch(searchBlob)) chips.add((label: 'HDR', color: const Color(0xFFA855F7)));
  if (_dvRe.hasMatch(searchBlob)) chips.add((label: 'DV', color: const Color(0xFFEC4899)));
  if (_imaxRe.hasMatch(searchBlob)) chips.add((label: 'IMAX', color: const Color(0xFF06B6D4)));
  if (audioLabel != null) chips.add((label: audioLabel, color: AppTheme.textSecondary));
  if (stream.size.isNotEmpty) chips.add((label: stream.size, color: AppTheme.textSecondary));

  final sizeBytes = _parseSizeBytes(stream.size);

  return _SourcePresentation(
    stream: stream,
    title: title,
    addonLabel: addonLabel,
    resolutionLabel: resolutionLabel,
    resolutionScore: resolutionScore,
    releaseLabel: releaseLabel,
    releaseScore: releaseScore,
    codecLabel: codecLabel,
    audioLabel: audioLabel,
    transportLabel: transportLabel,
    multiSourceLabel: multiSourceLabel,
    languageLabel: languageLabel,
    chips: chips,
    qualityColor: qualityColor,
    sizeBytes: sizeBytes,
    sortCached: stream.behaviorHints?.cached == true,
    sortDirect: hasDirectHttp,
  );
}

String _detectResolution(String blob, String quality) {
  if (blob.contains('2160p') || blob.contains('4K')) return '4K';
  if (blob.contains('1080p')) return '1080p';
  if (blob.contains('720p')) return '720p';
  if (_camRe.hasMatch(blob)) return 'CAM';
  final first = quality.split(' ').firstOrNull;
  return (first != null && first.length <= 8) ? first : 'SD';
}

int _resolutionScore(String r) => switch (r) { '4K' => 4, '1080p' => 3, '720p' => 2, 'CAM' => 0, _ => 1 };

Color _qualityColor(String r) => switch (r) {
  '4K' => AppTheme.accentYellow,
  '1080p' => const Color(0xFF3B82F6),
  '720p' => const Color(0xFF06B6D4),
  'CAM' => const Color(0xFFEF4444),
  _ => AppTheme.textSecondary,
};

String? _detectRelease(String blob) {
  if (_remuxRe.hasMatch(blob)) return 'REMUX';
  if (_blurayRe.hasMatch(blob)) return 'BluRay';
  if (_webdlRe.hasMatch(blob)) return 'WEB-DL';
  if (_webripRe.hasMatch(blob)) return 'WEBRip';
  if (_hdtvRe.hasMatch(blob)) return 'HDTV';
  if (_camRe.hasMatch(blob)) return 'CAM';
  return null;
}

int _releaseScore(String? r) => switch (r) { 'REMUX' => 5, 'BluRay' => 4, 'WEB-DL' => 3, 'WEBRip' => 2, 'HDTV' => 1, _ => 0 };

String? _detectCodec(String blob) {
  if (_av1Re.hasMatch(blob)) return 'AV1';
  if (_hevcRe.hasMatch(blob)) return 'HEVC';
  if (_h264Re.hasMatch(blob)) return 'H.264';
  return null;
}

String? _detectAudio(String blob) {
  if (_atmosRe.hasMatch(blob)) return 'Atmos';
  if (_truehdRe.hasMatch(blob)) return 'TrueHD';
  if (_ch71Re.hasMatch(blob)) return '7.1';
  if (_ch51Re.hasMatch(blob)) return '5.1';
  final m = _dtsRe.firstMatch(blob);
  if (m != null) return m.group(0)!.toUpperCase();
  return null;
}

int _parseSizeBytes(String sizeStr) {
  if (sizeStr.isEmpty) return 0;
  final normalized = sizeStr.toUpperCase().replaceAll(',', '.').replaceAll(RegExp(r'\s+'), ' ').trim();
  final p1 = RegExp(r'(\d+(?:\.\d+)?)\s*(TB|GB|MB|KB)');
  final m1 = p1.firstMatch(normalized);
  if (m1 != null) {
    final n = double.tryParse(m1.group(1)!) ?? 0;
    return _calcBytes(n, m1.group(2)!);
  }
  final p2 = RegExp(r'(\d+(?:\.\d+)?)\s*(TIB|GIB|MIB|KIB)');
  final m2 = p2.firstMatch(normalized);
  if (m2 != null) {
    final n = double.tryParse(m2.group(1)!) ?? 0;
    return _calcBytes(n, m2.group(2)!.replaceAll('IB', 'B'));
  }
  return 0;
}

int _calcBytes(double n, String unit) => switch (unit) {
  'TB' => (n * 1024 * 1024 * 1024 * 1024).round(),
  'GB' => (n * 1024 * 1024 * 1024).round(),
  'MB' => (n * 1024 * 1024).round(),
  'KB' => (n * 1024).round(),
  _ => n.round(),
};

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
              color: Colors.black.withValues(alpha: 0.35),
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
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.20),
                        Colors.black.withValues(alpha: 0.78),
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
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
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
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.80), fontSize: 12, height: 1.25),
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
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          'Tap to play',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                        ),
                        const Spacer(),
                        const Icon(Icons.play_circle_fill, color: Colors.white, size: 22),
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