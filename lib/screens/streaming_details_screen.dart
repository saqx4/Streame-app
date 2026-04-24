import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/movie.dart';
import '../api/tmdb_api.dart';
import '../services/stream_extractor.dart';
import '../api/stremio_service.dart';
import '../providers/stream_providers.dart';
import '../api/webstreamr_service.dart';
import '../widgets/loading_overlay.dart';
import '../services/episode_watched_service.dart';
import '../widgets/movie_atmosphere.dart';
import 'player_screen.dart';
import 'streaming/streaming_widgets.dart';

class StreamingDetailsScreen extends StatefulWidget {
  final Movie movie;
  final int? initialSeason;
  final int? initialEpisode;
  final Duration? startPosition;

  const StreamingDetailsScreen({
    super.key,
    required this.movie,
    this.initialSeason,
    this.initialEpisode,
    this.startPosition,
  });

  @override
  State<StreamingDetailsScreen> createState() => _StreamingDetailsScreenState();
}

class _StreamingDetailsScreenState extends State<StreamingDetailsScreen> with AtmosphereMixin {
  bool _isExtracting = false;
  bool _extractionCancelled = false;
  String? _statusMessage;
  final StreamExtractor _extractor = StreamExtractor();
  final StremioService _stremio = StremioService();
  final WebStreamrService _webStreamr = WebStreamrService();
  final TmdbApi _api = TmdbApi();
  late Movie _movie;
  bool _isLoading = true;
  bool _showFullSynopsis = false;
  List<Movie> _similarContent = [];

  // Source Selection
  final String _selectedSourceId = 'streame';
  List<Map<String, dynamic>> _streamAddons = [];

  // TV State
  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  Map<String, dynamic>? _seasonData;
  bool _isLoadingSeason = false;

  // Episode watched tracking
  final EpisodeWatchedService _episodeWatchedService = EpisodeWatchedService();
  Set<String> _watchedEpisodes = {};
  
  final ScrollController _similarScrollController = ScrollController();
  final ScrollController _screenshotsScrollController = ScrollController();
  final ScrollController _episodeScrollController = ScrollController();

  final Map<String, dynamic> _providers = StreamProviders.providers;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    if (widget.initialSeason != null) _selectedSeason = widget.initialSeason!;
    if (widget.initialEpisode != null) _selectedEpisode = widget.initialEpisode!;
    // Start atmosphere color extraction
    final url = (_movie.posterPath.isNotEmpty ? _movie.posterPath : _movie.backdropPath);
    loadAtmosphere(url.startsWith('http') ? url : TmdbApi.getImageUrl(url));
    _loadWatchedEpisodes();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final Movie fullDetails;
      if (_movie.mediaType == 'tv') {
        fullDetails = await _api.getTvDetails(widget.movie.id);
        await _fetchSeason(widget.initialSeason ?? 1);
      } else {
        fullDetails = await _api.getMovieDetails(widget.movie.id);
      }

      final streamAddons = await _stremio.getAddonsForResource('stream');
      
      // Fetch similar content
      final similar = _movie.mediaType == 'tv' 
          ? await _api.getSimilarTvShows(_movie.id)
          : await _api.getSimilarMovies(_movie.id);
      
      if (mounted) {
        setState(() {
          _movie = fullDetails;
          _streamAddons = streamAddons;
          _similarContent = similar;
          _isLoading = false;
        });

        // Auto-start extraction when opened with a start position (e.g. from Continue Watching / Trakt)
        if (widget.startPosition != null) {
          _startExtraction();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSeason(int seasonNumber) async {
    setState(() => _isLoadingSeason = true);
    try {
      final data = await _api.getTvSeasonDetails(_movie.id, seasonNumber);
      if (mounted) {
        setState(() {
          _seasonData = data;
          _isLoadingSeason = false;
          _selectedSeason = seasonNumber;
        });
        _loadWatchedEpisodes();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSeason = false);
    }
  }

  @override
  void dispose() {
    _extractor.dispose();
    _similarScrollController.dispose();
    _screenshotsScrollController.dispose();
    _episodeScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWatchedEpisodes() async {
    final set = await _episodeWatchedService.getWatchedSet(_movie.id);
    if (mounted) setState(() => _watchedEpisodes = set);
  }

  Future<void> _toggleEpisodeWatched(int season, int episode) async {
    await _episodeWatchedService.toggle(_movie.id, season, episode);
    await _loadWatchedEpisodes();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXTRACTION LOGIC - PRESERVED FROM ORIGINAL
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startExtraction() async {
    if (_selectedSourceId == 'streame') {
      _startStreameExtraction();
    } else {
      _startStremioExtraction();
    }
  }

  Future<void> _startStremioExtraction() async {
    final addon = _streamAddons.firstWhere((a) => a['baseUrl'] == _selectedSourceId);
    final baseUrl = addon['baseUrl'];
    
    setState(() {
      _statusMessage = 'Fetching from ${addon['name']}...';
    });

    try {
      String stremioId = _movie.imdbId ?? '';
      if (_movie.mediaType == 'tv') {
        stremioId = '$stremioId:$_selectedSeason:$_selectedEpisode';
      }

      final type = _movie.mediaType == 'tv' ? 'series' : 'movie';
      final streams = await _stremio.getStreams(baseUrl: baseUrl, type: type, id: stremioId);

      if (mounted) {
        setState(() {
          if (streams.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No streams found for this content.')));
          }
        });
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _statusMessage = null);
    }
  }

  Future<void> _startStreameExtraction() async {
    _extractionCancelled = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder: (context) => LoadingOverlay(
        movie: _movie,
        onCancel: () {
          _extractionCancelled = true;
          Navigator.of(context).pop();
        },
      ),
    );

    setState(() {
      _isExtracting = true;
      _statusMessage = 'Initializing Stream Extractor...';
    });

    bool found = false;

    // 1. Try WebStreamr first if IMDB ID is available
    if (_movie.imdbId != null && _movie.imdbId!.isNotEmpty) {
      setState(() => _statusMessage = 'Searching WebStreamr...');
      try {
        final webStreamrSources = await _webStreamr.getStreams(
          imdbId: _movie.imdbId!,
          isMovie: _movie.mediaType == 'movie',
          season: _selectedSeason,
          episode: _selectedEpisode,
        );

        if (_extractionCancelled) return;
        if (webStreamrSources.isNotEmpty) {
          found = true;
          if (mounted && !_extractionCancelled) {
            if (Navigator.canPop(context)) Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerScreen(
                  streamUrl: webStreamrSources.first.url,
                  title: _movie.mediaType == 'tv' 
                      ? '${_movie.title} - S$_selectedSeason E$_selectedEpisode' 
                      : _movie.title,
                  movie: _movie,
                  providers: _providers,
                  activeProvider: 'webstreamr',
                  selectedSeason: _movie.mediaType == 'tv' ? _selectedSeason : null,
                  selectedEpisode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
                  startPosition: widget.startPosition,
                  sources: webStreamrSources,
                ),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error fetching from WebStreamr: $e');
      }
    }

    if (!found) {
      final providerKeys = _providers.keys.toList();

      for (var key in providerKeys) {
        if (!mounted || _extractionCancelled) break;
        if (key == 'webstreamr') continue; // Already tried directly
        
        final provider = _providers[key];
        
        final String url;
        if (_movie.mediaType == 'tv') {
          url = provider['tv'](
            widget.movie.id.toString(),
            _selectedSeason.toString(),
            _selectedEpisode.toString(),
          );
        } else {
          url = provider['movie'](widget.movie.id.toString());
        }
        
        setState(() => _statusMessage = 'Searching ${provider['name']}...');
        debugPrint('[StreamExtractor] Trying ${provider['name']} source: $url');

        try {
          var result = await _extractor.extract(url, timeout: const Duration(seconds: 5));
          if (_extractionCancelled) break;
          if (result != null) {
            found = true;
            if (mounted && !_extractionCancelled) {
              if (Navigator.canPop(context)) Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                    streamUrl: result.url,
                    audioUrl: result.audioUrl,
                    title: _movie.mediaType == 'tv' 
                        ? '${_movie.title} - S$_selectedSeason E$_selectedEpisode' 
                        : _movie.title,
                    headers: result.headers,
                    movie: _movie,
                    providers: _providers,
                    activeProvider: key,
                    selectedSeason: _movie.mediaType == 'tv' ? _selectedSeason : null,
                    selectedEpisode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
                    startPosition: widget.startPosition,
                    sources: result.sources,
                  ),
                ),
              );
            }
            break;
          }
        } catch (e) {
          debugPrint('Error extracting from $key: $e');
        }
      }
    }

    if (mounted) {
      if (_extractionCancelled) {
        setState(() { _isExtracting = false; _statusMessage = null; });
        return;
      }
      if (!found && Navigator.canPop(context)) Navigator.pop(context);
      setState(() {
        _isExtracting = false;
        _statusMessage = found ? null : 'No streams found. Try again later.';
      });
      if (!found) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to find a working stream.')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD METHOD - NEW DESIGN
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1565C0))),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Fixed background
          Positioned.fill(
            child: _buildFixedBackground(),
          ),
          // Scrollable content
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 40),
                  _buildHeroSection(isTablet),
                  const SizedBox(height: 32),
                  _buildAboutSection(),
                  const SizedBox(height: 32),
                  if (_movie.mediaType == 'tv') ...[
                    _buildSeasonsAndEpisodes(),
                    const SizedBox(height: 32),
                  ],
                  if (_movie.screenshots.isNotEmpty) ...[
                    _buildScreenshotsSection(),
                    const SizedBox(height: 32),
                  ],
                  _buildSimilarContent(),
                  const SizedBox(height: 32),
                  _buildDetailsSection(),
                  const SizedBox(height: 48),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFixedBackground() {
    final url = _movie.backdropPath.isNotEmpty
        ? TmdbApi.getBackdropUrl(_movie.backdropPath)
        : (_movie.posterPath.isNotEmpty ? TmdbApi.getImageUrl(_movie.posterPath) : '');
    if (url.isEmpty) return Container(color: const Color(0xFF0A0A0A));
    // Strip the Positioned.fill from buildAtmosphereBackdrop — we're already inside one
    return Stack(
      fit: StackFit.expand,
      children: [
        KenBurnsBackdrop(
          imageUrl: url,
          colors: atmosphereColors,
          blurSigma: 4,
        ),
        IgnorePointer(
          child: GenreParticles(
            genres: _movie.genres,
            colors: atmosphereColors,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection(bool isTablet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: isTablet
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPoster(),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMovieInfo(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildPoster(),
                const SizedBox(height: 24),
                _buildMovieInfo(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
    );
  }

  Widget _buildPoster() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final posterWidth = isMobile ? screenWidth * 0.5 : 180.0;
    final posterHeight = posterWidth * 1.5;
    
    return wrapPosterGlow(
      width: posterWidth,
      height: posterHeight,
      borderRadius: 12,
      genres: _movie.genres,
      child: Hero(
        tag: 'movie-poster-${_movie.id}',
        child: Container(
          width: posterWidth,
          height: posterHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: TmdbApi.getImageUrl(_movie.posterPath),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMovieInfo() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final logoHeight = isTablet ? 100.0 : 80.0;
    
    return Column(
      crossAxisAlignment: isTablet ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // Logo or Text Title
        if (_movie.logoPath.isNotEmpty)
          SizedBox(
            height: logoHeight,
            child: Row(
              mainAxisAlignment: isTablet ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Flexible(
                  child: CachedNetworkImage(
                    imageUrl: TmdbApi.getImageUrl(_movie.logoPath),
                    height: logoHeight,
                    fit: BoxFit.contain,
                    alignment: isTablet ? Alignment.centerLeft : Alignment.center,
                    fadeInDuration: const Duration(milliseconds: 0),
                    fadeOutDuration: const Duration(milliseconds: 0),
                    placeholder: (context, url) => SizedBox(
                      height: logoHeight,
                      width: double.infinity,
                    ),
                    errorWidget: (context, url, error) => Text(
                      _movie.title,
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            _movie.title,
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              _movie.releaseDate.isNotEmpty ? _movie.releaseDate.split('-').first : 'N/A',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(width: 8),
            const Text('·', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1565C0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _movie.voteAverage.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (_movie.runtime > 0) ...[
              const SizedBox(width: 8),
              const Text('·', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              Text(
                '${_movie.runtime}m',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (_movie.genres.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _movie.genres.take(4).map((genre) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text(
                  genre,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;
    
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isExtracting)
            Column(
              children: [
                const CircularProgressIndicator(color: Color(0xFF1565C0)),
                const SizedBox(height: 16),
                Text(
                  _statusMessage ?? 'Processing...',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            )
          else
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _startExtraction,
                child: Container(
                  width: isDesktop ? 300 : double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Play Now',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            firstChild: Text(
              _movie.overview.isNotEmpty ? _movie.overview : 'No synopsis available.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
            ),
            secondChild: Text(
              _movie.overview.isNotEmpty ? _movie.overview : 'No synopsis available.',
              style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
            ),
            crossFadeState: _showFullSynopsis ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
          if (_movie.overview.isNotEmpty && _movie.overview.length > 150)
            TextButton(
              onPressed: () => setState(() => _showFullSynopsis = !_showFullSynopsis),
              child: Text(
                _showFullSynopsis ? 'Show less' : 'Show more',
                style: const TextStyle(color: Color(0xFF1565C0)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeasonsAndEpisodes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Episodes',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _movie.numberOfSeasons,
            itemBuilder: (context, index) {
              final seasonNum = index + 1;
              final isSelected = _selectedSeason == seasonNum;
              return SeasonChip(
                seasonNumber: seasonNum,
                isSelected: isSelected,
                onTap: () => _fetchSeason(seasonNum),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        if (_isLoadingSeason)
          const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
        else if (_seasonData != null && _seasonData!['episodes'] != null)
          _buildEpisodeList(),
      ],
    );
  }

  Widget _buildEpisodeList() {
    final episodes = _seasonData!['episodes'] as List;

    void scrollBy(double delta) {
      if (!_episodeScrollController.hasClients) return;
      final target = (_episodeScrollController.offset + delta)
          .clamp(0.0, _episodeScrollController.position.maxScrollExtent);
      _episodeScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── arrow row ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: Colors.white70),
                onPressed: () => scrollBy(-400),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.white70),
                onPressed: () => scrollBy(400),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── horizontal list ────────────────────────────────────────────────
          SizedBox(
            height: 190,
            child: ListView.separated(
              controller: _episodeScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: episodes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final episode = episodes[index];
                final epNum = episode['episode_number'] as int;
                final title = (episode['name'] ?? 'Episode $epNum').toString();
                final still = episode['still_path'] as String?;
                final isSelected = _selectedEpisode == epNum;
                final isWatched = _watchedEpisodes.contains('${_movie.id}_S${_selectedSeason}_E$epNum');

                return HorizontalEpisodeCard(
                  epNum: epNum,
                  title: title,
                  stillPath: still,
                  isSelected: isSelected,
                  isWatched: isWatched,
                  onToggleWatched: () => _toggleEpisodeWatched(_selectedSeason, epNum),
                  onTap: () {
                    setState(() => _selectedEpisode = epNum);
                    _startExtraction();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarContent() {
    if (_similarContent.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'More Like This',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
                    onPressed: () {
                      _similarScrollController.animateTo(
                        _similarScrollController.offset - 300,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 20),
                    onPressed: () {
                      _similarScrollController.animateTo(
                        _similarScrollController.offset + 300,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: ListView.builder(
            controller: _similarScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            itemCount: _similarContent.length,
            itemBuilder: (context, index) {
              final movie = _similarContent[index];
              return SimilarMovieCard(movie: movie);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Screenshots',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
                    onPressed: () {
                      _screenshotsScrollController.animateTo(
                        _screenshotsScrollController.offset - 300,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 20),
                    onPressed: () {
                      _screenshotsScrollController.animateTo(
                        _screenshotsScrollController.offset + 300,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            controller: _screenshotsScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _movie.screenshots.take(10).length,
            itemBuilder: (context, index) {
              final screenshot = _movie.screenshots[index];
              return Container(
                width: 320,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: TmdbApi.getStillUrl(screenshot),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _buildDetailRow('Type', _movie.mediaType == 'tv' ? 'TV Series' : 'Movie'),
                const SizedBox(height: 12),
                _buildDetailRow('Release Date', _movie.releaseDate.isNotEmpty ? _movie.releaseDate : 'N/A'),
                const SizedBox(height: 12),
                _buildDetailRow('Rating', '${_movie.voteAverage.toStringAsFixed(1)}/10'),
                if (_movie.runtime > 0) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Runtime', '${_movie.runtime} minutes'),
                ],
                if (_movie.mediaType == 'tv' && _movie.numberOfSeasons > 0) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Seasons', _movie.numberOfSeasons.toString()),
                ],
                if (_movie.genres.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Genres', _movie.genres.join(', ')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}