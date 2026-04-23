import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/movie.dart';
import '../api/tmdb_api.dart';
import '../models/torrent_result.dart';
import '../api/torrent_api.dart';
import '../services/torrent_stream_service.dart';
import '../api/stremio_service.dart';
import '../services/torrent_filter.dart';
import '../services/settings_service.dart';
import '../api/debrid_api.dart';
import '../services/jackett_service.dart';
import '../services/prowlarr_service.dart';
import '../services/link_resolver.dart';
import '../services/watch_history_service.dart';
import '../services/episode_watched_service.dart';
import '../api/trakt_service.dart';
import '../api/simkl_service.dart';
import '../api/mdblist_service.dart';
import '../utils/extensions.dart';
import '../utils/app_theme.dart';
import '../widgets/loading_overlay.dart';
import 'player_screen.dart';
import 'stremio_catalog_screen.dart';
import 'main_screen.dart';
import '../widgets/movie_atmosphere.dart';
import 'details/expandable_synopsis.dart';
import 'details/audio_filter_menu.dart';
import 'details/stream_tiles.dart';
import 'details/cast_row.dart';
import 'details/sections.dart';

class DetailsScreen extends StatefulWidget {
  final Movie movie;

  /// Optional: when opened from a Stremio addon search result with a custom ID,
  /// pass the original item so we can auto-select the right addon and use its ID.
  final Map<String, dynamic>? stremioItem;

  /// Optional: pre-select a season (e.g. from Continue Watching / Trakt import).
  final int? initialSeason;

  /// Optional: pre-select an episode (e.g. from Continue Watching / Trakt import).
  final int? initialEpisode;

  /// Optional: resume position from Trakt/Simkl import (used when no local progress matches).
  final Duration? startPosition;
  const DetailsScreen({
    super.key,
    required this.movie,
    this.stremioItem,
    this.initialSeason,
    this.initialEpisode,
    this.startPosition,
  });

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> with AtmosphereMixin {
  late Movie _movie;
  bool _isLoading = true;
  final TmdbApi _api = TmdbApi();
  final TorrentApi _torrentApi = TorrentApi();
  final SettingsService _settings = SettingsService();
  final StremioService _stremio = StremioService();
  final JackettService _jackett = JackettService();
  final ProwlarrService _prowlarr = ProwlarrService();
  final LinkResolver _linkResolver = LinkResolver();

  String _sortPreference = 'Seeders (High to Low)';
  Set<String> _activeAudioFilters = {};
  List<TorrentResult> _allTorrentResults = [];
  bool _isSearching = false;
  String? _errorMessage;
  Map<String, dynamic>? _lastProgress;

  String _selectedSourceId = 'streame';
  List<Map<String, dynamic>> _streamAddons = [];
  List<dynamic> _stremioStreams = [];
  List<Map<String, dynamic>> _allCombinedStremioStreams = [];
  bool _isStremioFetching = false;

  /// Tracks which addon baseUrls have returned results (for dynamic chip display).
  final Set<String> _loadedAddonBaseUrls = {};

  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  Map<String, dynamic>? _seasonData;
  bool _isLoadingSeason = false;

  /// Incremented each time a new stream fetch is triggered; stale async results are discarded.
  int _fetchGeneration = 0;

  // Episode watched tracking
  final EpisodeWatchedService _episodeWatchedService = EpisodeWatchedService();
  Set<String> _watchedEpisodes = {};

  // Collection state
  List<Map<String, dynamic>> _collectionItems = [];
  bool _isCollection = false;

  bool _isJackettConfigured = false;
  bool _isProwlarrConfigured = false;

  // Stremio recommendations from meta links
  List<Map<String, dynamic>> _stremioRecommendations = [];
  bool _isLoadingRecommendations = false;
  final ScrollController _recommendationsScrollController = ScrollController();

  // Stream resolution cancellation
  bool _streamCancelled = false;

  // Desktop cast avatars
  List<Map<String, String>> _castMembers = [];
  final ScrollController _castScrollController = ScrollController();

  final ScrollController _episodeScrollController = ScrollController();
  final ScrollController _seasonScrollController = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();

  // MDBlist aggregated ratings
  Map<String, dynamic>? _mdblistRatings;
  // User's Trakt rating (1-10, null if not rated)
  int? _userTraktRating;
  // User's Simkl rating (1-10, null if not rated)
  int? _userSimklRating;
  // Trakt collection status
  bool _isInTraktCollection = false;

  // â”€â”€â”€ lifecycle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    if (widget.initialSeason != null) _selectedSeason = widget.initialSeason!;
    if (widget.initialEpisode != null)
      _selectedEpisode = widget.initialEpisode!;
    // Start atmosphere color extraction
    final url = (_movie.posterPath.isNotEmpty
        ? _movie.posterPath
        : _movie.backdropPath);
    loadAtmosphere(url.startsWith('http') ? url : TmdbApi.getImageUrl(url));
    _checkHistory();
    _loadSortPreference();
    _checkIndexerConfiguration();
    _loadWatchedEpisodes();
    _fetchDetails();
    _fetchExternalRatings();
    _fetchUserTraktRating();
    _fetchUserSimklRating();
    _fetchTraktCollectionStatus();
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _episodeScrollController.dispose();
    _seasonScrollController.dispose();
    _recommendationsScrollController.dispose();
    _castScrollController.dispose();
    _jackett.dispose();
    _prowlarr.dispose();
    _linkResolver.dispose();
    super.dispose();
  }

  // â”€â”€â”€ data methods â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _checkHistory() async {
    final progress = await WatchHistoryService().getProgress(
      _movie.id,
      season: _movie.mediaType == 'tv' ? _selectedSeason : null,
      episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
    );
    if (mounted) setState(() => _lastProgress = progress);
  }

  Future<void> _loadWatchedEpisodes() async {
    final set = await _episodeWatchedService.getWatchedSet(_movie.id);
    if (mounted) setState(() => _watchedEpisodes = set);
  }

  Future<void> _loadSortPreference() async {
    final pref = await _settings.getSortPreference();
    if (mounted) setState(() => _sortPreference = pref);
  }

  // â”€â”€â”€ audio filter helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static const List<String> _kAudioTags = [
    'Atmos',
    'TrueHD',
    'DTS:X',
    'DTS-HD',
    'DTS',
    'DD+',
    'DD',
    'AAC',
    '7.1',
    '5.1',
    '2.0',
  ];

  /// Returns every audio tag found in [name] (upper-cased for matching).
  static List<String> _detectAudioTags(String name) {
    final n = name.toUpperCase();
    final found = <String>[];
    // Order matters â€“ more specific tags must be checked before their substrings
    if (n.contains('ATMOS')) found.add('Atmos');
    if (n.contains('TRUEHD')) found.add('TrueHD');
    if (n.contains('DTS:X') || n.contains('DTSX')) found.add('DTS:X');
    if (!found.contains('DTS:X') &&
        (n.contains('DTS-HD') || n.contains('DTSHD')))
      found.add('DTS-HD');
    if (!found.contains('DTS:X') &&
        !found.contains('DTS-HD') &&
        n.contains('DTS'))
      found.add('DTS');
    if (n.contains('DD+') ||
        n.contains('EAC3') ||
        n.contains('E-AC-3') ||
        n.contains('DDPLUS'))
      found.add('DD+');
    if (!found.contains('DD+') &&
        (n.contains(' DD ') ||
            n.contains('AC3') ||
            n.contains('DOLBY DIGITAL')))
      found.add('DD');
    if (n.contains('AAC')) found.add('AAC');
    if (n.contains('7.1')) found.add('7.1');
    if (!found.contains('7.1') && n.contains('5.1')) found.add('5.1');
    if (n.contains(' 2.0') || n.contains('.2.0')) found.add('2.0');
    return found;
  }

  /// Torrent results after applying the active audio filters.
  List<TorrentResult> get _filteredTorrentResults {
    if (_activeAudioFilters.isEmpty) return _allTorrentResults;
    return _allTorrentResults.where((r) {
      final tags = _detectAudioTags(r.name);
      // Show the result if it matches ANY of the selected tags
      return tags.any((t) => _activeAudioFilters.contains(t));
    }).toList();
  }

  Future<void> _checkIndexerConfiguration() async {
    final jackettConfigured = await _settings.isJackettConfigured();
    final prowlarrConfigured = await _settings.isProwlarrConfigured();
    if (mounted) {
      setState(() {
        _isJackettConfigured = jackettConfigured;
        _isProwlarrConfigured = prowlarrConfigured;
      });
    }
  }

  String _getHash(String magnet) {
    if (magnet.startsWith('magnet:?xt=urn:btih:')) {
      final parts = magnet.split('magnet:?xt=urn:btih:')[1].split('&');
      if (parts.isNotEmpty) return parts[0].toLowerCase();
    }
    return magnet.toLowerCase();
  }

  Future<void> _sortResults() async {
    if (_allTorrentResults.isEmpty) return;
    final sorted = await TorrentFilter.sortTorrentsAsync(
      _allTorrentResults,
      _sortPreference,
    );
    if (_lastProgress != null && _lastProgress!['method'] == 'torrent') {
      final historyHash = _getHash(_lastProgress!['sourceId']);
      final index = sorted.indexWhere((r) => _getHash(r.magnet) == historyHash);
      if (index != -1) {
        final match = sorted.removeAt(index);
        sorted.insert(0, match);
      }
    }
    if (mounted) setState(() => _allTorrentResults = sorted);
  }

  Future<void> _fetchDetails() async {
    final stremioItem = widget.stremioItem;
    final bool isCustomId =
        stremioItem != null &&
        !(stremioItem['id']?.toString().startsWith('tt') ?? true);

    try {
      final streamAddons = await _stremio.getAddonsForResource('stream');

      // If this is a custom-ID Stremio item, skip TMDB fetch â€” we already
      // have all the info we need from the search result.
      if (isCustomId) {
        debugPrint('[DetailsScreen] Custom ID detected: ${stremioItem['id']}');
        debugPrint(
          '[DetailsScreen] stremioItem keys: ${stremioItem.keys.toList()}',
        );
        debugPrint(
          '[DetailsScreen] _addonBaseUrl: ${stremioItem['_addonBaseUrl']}',
        );
        debugPrint('[DetailsScreen] _addonName: ${stremioItem['_addonName']}');
        debugPrint('[DetailsScreen] type: ${stremioItem['type']}');

        // Update movie mediaType if it's a collection
        if (stremioItem['type'] == 'collections') {
          _movie = Movie(
            id: _movie.id,
            imdbId: _movie.imdbId,
            title: _movie.title,
            posterPath: _movie.posterPath,
            backdropPath: _movie.backdropPath,
            voteAverage: _movie.voteAverage,
            releaseDate: _movie.releaseDate,
            overview: _movie.overview,
            mediaType: 'collections',
            genres: _movie.genres,
            runtime: _movie.runtime,
            numberOfSeasons: _movie.numberOfSeasons,
            logoPath: _movie.logoPath,
            screenshots: _movie.screenshots,
          );
        }

        if (mounted) {
          setState(() {
            _streamAddons = streamAddons;
            _isLoading = false;
            // Auto-select the addon that owns this item
            final addonBaseUrl = stremioItem['_addonBaseUrl']?.toString() ?? '';
            if (addonBaseUrl.isNotEmpty) {
              _selectedSourceId = addonBaseUrl;
            } else if (streamAddons.isNotEmpty) {
              _selectedSourceId = streamAddons.first['baseUrl'];
            }
          });
          _fetchStremioStreamsForCustomId(stremioItem);
        }
        return;
      }

      final Movie fullDetails;
      if (_movie.mediaType == 'tv') {
        fullDetails = await _api.getTvDetails(widget.movie.id);
        await _fetchSeason(widget.initialSeason ?? 1);
      } else {
        fullDetails = await _api.getMovieDetails(widget.movie.id);
      }
      if (mounted) {
        setState(() {
          _movie = fullDetails;
          _streamAddons = streamAddons;
          _isLoading = false;
        });
        _autoSearch();
        _fetchAllStremioStreams();
        _fetchStremioRecommendations();
        _fetchCastMembers();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCastMembers() async {
    try {
      final members = await _api.getCredits(_movie.id, _movie.mediaType);
      if (mounted) setState(() => _castMembers = members);
    } catch (_) {}
  }

  Future<void> _fetchExternalRatings() async {
    try {
      if (!await MdblistService().isConfigured()) return;
      Map<String, dynamic>? ratings;
      if (_movie.imdbId != null && _movie.imdbId!.isNotEmpty) {
        ratings = await MdblistService().getRatingsByImdb(_movie.imdbId!);
      } else {
        ratings = await MdblistService().getRatingsByTmdb(
          _movie.id,
          _movie.mediaType == 'tv' ? 'show' : 'movie',
        );
      }
      if (mounted && ratings != null) setState(() => _mdblistRatings = ratings);
    } catch (_) {}
  }

  Future<void> _fetchUserTraktRating() async {
    try {
      if (!await TraktService().isLoggedIn()) return;
      final type = _movie.mediaType == 'tv' ? 'shows' : 'movies';
      final allRatings = await TraktService().getAllRatings();
      final ratings = allRatings[type] as List? ?? [];
      for (final r in ratings) {
        final show = r['show'] ?? r['movie'];
        if (show != null) {
          final ids = show['ids'] as Map<String, dynamic>?;
          if (ids != null && ids['tmdb'] == _movie.id) {
            if (mounted) setState(() => _userTraktRating = r['rating'] as int?);
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _rateTraktItem(int rating) async {
    final success = await TraktService().rateItem(
      tmdbId: _movie.id,
      mediaType: _movie.mediaType,
      rating: rating,
    );
    if (success && mounted) setState(() => _userTraktRating = rating);
  }

  Future<void> _removeTraktRating() async {
    final success = await TraktService().removeRating(
      tmdbId: _movie.id,
      mediaType: _movie.mediaType,
    );
    if (success && mounted) setState(() => _userTraktRating = null);
  }

  // â”€â”€â”€ Simkl rating â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _fetchUserSimklRating() async {
    try {
      if (!await SimklService().isLoggedIn()) return;
      final ratings = await SimklService().getRatings();
      for (final r in ratings) {
        final ids = r['ids'] as Map<String, dynamic>? ?? {};
        if (ids['tmdb'] == _movie.id) {
          if (mounted) setState(() => _userSimklRating = r['rating'] as int?);
          return;
        }
      }
    } catch (_) {}
  }

  // â”€â”€â”€ Trakt collection â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _fetchTraktCollectionStatus() async {
    try {
      if (!await TraktService().isLoggedIn()) return;
      final collection = await TraktService().getCollection();
      final type = _movie.mediaType == 'tv' ? 'shows' : 'movies';
      final items = collection[type] as List? ?? [];
      for (final item in items) {
        final media = item['show'] ?? item['movie'];
        if (media != null) {
          final ids = media['ids'] as Map<String, dynamic>? ?? {};
          if (ids['tmdb'] == _movie.id) {
            if (mounted) setState(() => _isInTraktCollection = true);
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleTraktCollection() async {
    if (!await TraktService().isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to Trakt first in Settings')),
      );
      return;
    }
    if (_isInTraktCollection) {
      final success = await TraktService().removeFromCollection(
        tmdbId: _movie.id,
        mediaType: _movie.mediaType,
      );
      if (success && mounted) setState(() => _isInTraktCollection = false);
    } else {
      final success = await TraktService().addToCollection(
        tmdbId: _movie.id,
        mediaType: _movie.mediaType,
      );
      if (success && mounted) setState(() => _isInTraktCollection = true);
    }
  }

  // â”€â”€â”€ Trakt check-in â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _traktCheckin() async {
    if (!await TraktService().isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to Trakt first in Settings')),
      );
      return;
    }
    final success = await TraktService().checkin(
      tmdbId: _movie.id,
      mediaType: _movie.mediaType,
      season: _movie.mediaType == 'tv' ? _selectedSeason : null,
      episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Checked in on Trakt!')));
    } else {
      // Offer to cancel existing check-in and retry
      final shouldCancel = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text(
            'Check-in Failed',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Text(
            'You may already have an active check-in.\nCancel existing and retry?',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, retry'),
            ),
          ],
        ),
      );
      if (shouldCancel == true && mounted) {
        final cancelled = await TraktService().cancelCheckin();
        if (cancelled && mounted) {
          final retrySuccess = await TraktService().checkin(
            tmdbId: _movie.id,
            mediaType: _movie.mediaType,
            season: _movie.mediaType == 'tv' ? _selectedSeason : null,
            episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                retrySuccess ? 'Checked in on Trakt!' : 'Check-in failed',
              ),
            ),
          );
        }
      }
    }
  }

  // â”€â”€â”€ Trakt add to list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _addToTraktList() async {
    if (!await TraktService().isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to Trakt first in Settings')),
      );
      return;
    }
    final lists = await TraktService().getUserLists();
    if (!mounted || lists.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No Trakt lists found. Create one in Lists screen.'),
          ),
        );
      }
      return;
    }

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          'Add to Trakt List',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: lists.length,
            itemBuilder: (_, i) {
              final list = lists[i];
              final name = list['name']?.toString() ?? 'Untitled';
              final count = list['item_count'] ?? 0;
              return ListTile(
                title: Text(
                  name,
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  '$count items',
                  style: TextStyle(color: AppTheme.textDisabled, fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, list),
              );
            },
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;

    final slug = selected['ids']?['slug']?.toString() ?? '';
    if (slug.isEmpty) return;

    final type = _movie.mediaType == 'tv' ? 'shows' : 'movies';
    final entry = <String, dynamic>{
      'ids': {'tmdb': _movie.id},
    };
    final success = await TraktService().addToList(
      listId: slug,
      movies: type == 'movies' ? [entry] : [],
      shows: type == 'shows' ? [entry] : [],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Added to "${selected['name']}"' : 'Failed to add to list',
        ),
      ),
    );
  }

  void _showRatingDialog() {
    int selected = _userTraktRating ?? 5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text(
            'Rate on Trakt',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(10, (i) {
                  final val = i + 1;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selected = val),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(
                        val <= selected
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFFFD700),
                        size: 28,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '$selected / 10',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            if (_userTraktRating != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _removeTraktRating();
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textDisabled),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _rateTraktItem(selected);
              },
              child: const Text(
                'Rate',
                style: TextStyle(color: Color(0xFF00E5FF)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fetches recommendations by getting meta from Stremio addons and
  /// collecting meta.links (stremio:///detail/...) items.
  Future<void> _fetchStremioRecommendations() async {
    final stremioId = _movie.imdbId ?? '';
    if (stremioId.isEmpty) return;

    setState(() => _isLoadingRecommendations = true);
    try {
      final type = _movie.mediaType == 'tv' ? 'series' : 'movie';
      final meta = await _stremio.getMetaFromAny(type: type, id: stremioId);
      if (meta == null || !mounted) {
        if (mounted) setState(() => _isLoadingRecommendations = false);
        return;
      }

      final links = meta['links'] as List? ?? [];
      final List<Map<String, dynamic>> recommendations = [];

      for (final link in links) {
        if (link is! Map) continue;
        final url = link['url']?.toString() ?? '';
        final name = link['name']?.toString() ?? '';
        final category = link['category']?.toString() ?? '';

        final parsed = StremioService.parseMetaLink(url);
        if (parsed == null) continue;

        if (parsed['action'] == 'detail') {
          recommendations.add({
            'name': name,
            'category': category,
            'type': parsed['type'],
            'id': parsed['id'],
            'url': url,
            'poster': null, // Will try to resolve
          });
        }
      }

      // Try to load posters for recommendations by batch-resolving metas
      if (recommendations.isNotEmpty) {
        await Future.wait(
          recommendations.map((rec) async {
            try {
              final recMeta = await _stremio.getMetaFromAny(
                type: rec['type'] ?? type,
                id: rec['id'],
              );
              if (recMeta != null) {
                rec['poster'] = recMeta['poster'];
                rec['name'] = rec['name'].isEmpty
                    ? (recMeta['name'] ?? '')
                    : rec['name'];
              }
            } catch (_) {}
          }),
        );
      }

      if (mounted) {
        setState(() {
          _stremioRecommendations = recommendations;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      debugPrint('[DetailsScreen] Recommendations error: $e');
      if (mounted) setState(() => _isLoadingRecommendations = false);
    }
  }

  Future<void> _openRecommendation(Map<String, dynamic> rec) async {
    final id = rec['id']?.toString() ?? '';
    final type = rec['type']?.toString() ?? 'movie';

    // Try TMDB lookup first for IMDB IDs
    if (id.startsWith('tt')) {
      try {
        final movie = await _api.findByImdbId(
          id,
          mediaType: type == 'series' ? 'tv' : 'movie',
        );
        if (movie != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailsScreen(movie: movie)),
          );
          return;
        }
      } catch (_) {}
    }

    // Fallback: search TMDB by name
    final name = rec['name']?.toString() ?? '';
    if (name.isNotEmpty) {
      try {
        final results = await _api.searchMulti(name);
        if (results.isNotEmpty && mounted) {
          final match = results.firstWhere(
            (m) => m.title.toLowerCase() == name.toLowerCase(),
            orElse: () => results.first,
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailsScreen(movie: match)),
          );
          return;
        }
      } catch (_) {}
    }

    // Last fallback: minimal Movie
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailsScreen(
            movie: Movie(
              id: id.hashCode,
              imdbId: id.startsWith('tt') ? id : null,
              title: name.isNotEmpty ? name : id,
              posterPath: '',
              backdropPath: '',
              voteAverage: 0,
              releaseDate: '',
              overview: '',
              mediaType: type == 'series' ? 'tv' : 'movie',
            ),
          ),
        ),
      );
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
          // Only reset to episode 1 if no initial episode was provided,
          // or if we're navigating to a different season after init.
          if (widget.initialEpisode != null &&
              seasonNumber == widget.initialSeason) {
            _selectedEpisode = widget.initialEpisode!;
          } else {
            _selectedEpisode = 1;
          }
        });
        if (_selectedSourceId == 'streame') {
          _autoSearch();
        } else if (_selectedSourceId == 'jackett') {
          _searchJackett();
        } else if (_selectedSourceId == 'prowlarr') {
          _searchProwlarr();
        } else if (_selectedSourceId == 'all_stremio') {
          _fetchAllStremioStreams();
        } else {
          _fetchStremioStreams();
        }
        _loadWatchedEpisodes();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSeason = false);
    }
  }

  void _autoSearch() {
    _checkHistory();
    final year = _movie.releaseDate.take(4);
    if (_movie.mediaType == 'tv') {
      final s = _selectedSeason.toString().padLeft(2, '0');
      final e = _selectedEpisode.toString().padLeft(2, '0');
      _searchTvTorrents('${_movie.title} S$s', '${_movie.title} S${s}E$e');
    } else {
      _searchTorrents('${_movie.title} $year');
    }
  }

  /// Fetches streams from ALL installed stream addons in parallel,
  /// updating the UI incrementally as each addon responds.
  Future<void> _fetchAllStremioStreams() async {
    if (_streamAddons.isEmpty) return;
    final gen = ++_fetchGeneration;
    setState(() {
      _isStremioFetching = true;
      _errorMessage = null;
      _allCombinedStremioStreams = [];
      _loadedAddonBaseUrls.clear();
      if (!_isTorrentSource) _stremioStreams = [];
    });
    try {
      String stremioId = _movie.imdbId ?? '';
      if (stremioId.isEmpty) {
        if (mounted) setState(() => _isStremioFetching = false);
        return;
      }
      if (_movie.mediaType == 'tv')
        stremioId = '$stremioId:$_selectedSeason:$_selectedEpisode';
      final type = _movie.mediaType == 'tv' ? 'series' : 'movie';

      int pendingCount = _streamAddons.length;

      for (final addon in _streamAddons) {
        // Fire each addon fetch independently â€” don't await here
        _stremio
            .getStreams(baseUrl: addon['baseUrl'], type: type, id: stremioId)
            .then((streams) {
              if (!mounted || gen != _fetchGeneration) return;
              final tagged = streams.map((s) {
                if (s is Map<String, dynamic>) {
                  return <String, dynamic>{
                    ...s,
                    '_addonName': addon['name'] ?? 'Unknown',
                    '_addonBaseUrl': addon['baseUrl'],
                  };
                }
                return <String, dynamic>{
                  '_addonName': addon['name'],
                  '_addonBaseUrl': addon['baseUrl'],
                };
              }).toList();

              setState(() {
                // Only show chip if addon returned results
                if (tagged.isNotEmpty) {
                  _loadedAddonBaseUrls.add(addon['baseUrl'] as String);
                }
                // Append below existing results
                _allCombinedStremioStreams.addAll(tagged);
                if (!_isTorrentSource) _applyStremioFilter();
              });
            })
            .catchError((_) {
              // No-op: don't show chip for errored addons
            })
            .whenComplete(() {
              if (!mounted || gen != _fetchGeneration) return;
              pendingCount--;
              if (pendingCount <= 0) {
                setState(() {
                  _isStremioFetching = false;
                  if (_allCombinedStremioStreams.isEmpty && !_isTorrentSource) {
                    _errorMessage = 'No streams found from any addon';
                  }
                });
              }
            });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = 'Error: $e';
          _isStremioFetching = false;
        });
    }
  }

  /// Fetches streams using the custom Stremio ID from the originating addon.
  Future<void> _fetchStremioStreamsForCustomId(
    Map<String, dynamic> item,
  ) async {
    final customId = item['id']?.toString() ?? '';
    final addonBaseUrl = item['_addonBaseUrl']?.toString() ?? '';
    final addonName = item['_addonName']?.toString() ?? 'Unknown';
    final type =
        item['type']?.toString() ??
        (_movie.mediaType == 'tv' ? 'series' : 'movie');
    debugPrint(
      '[CustomIdStreams] customId=$customId, addonBaseUrl=$addonBaseUrl, type=$type',
    );
    if (customId.isEmpty || addonBaseUrl.isEmpty) {
      debugPrint(
        '[CustomIdStreams] SKIPPED: customId empty=${customId.isEmpty}, addonBaseUrl empty=${addonBaseUrl.isEmpty}',
      );
      return;
    }

    setState(() {
      _isStremioFetching = true;
      _errorMessage = null;
      _stremioStreams = [];
      _allCombinedStremioStreams = [];
      _loadedAddonBaseUrls.clear();
    });

    try {
      // For collections, fetch meta to get videos array with collection items
      if (type == 'collections') {
        final meta = await _stremio.getMeta(
          baseUrl: addonBaseUrl,
          type: type,
          id: customId,
        );
        if (meta != null && meta['videos'] != null) {
          final videos = meta['videos'] as List;
          debugPrint(
            '[CustomIdStreams] Got ${videos.length} collection items from meta',
          );

          // Parse videos to build collection structure
          _parseCollectionVideos(videos);

          // Collections don't have streams - they're just containers for other content
          // The UI will display the collection items and allow navigation to them
          if (mounted) {
            setState(() {
              _isStremioFetching = false;
              _errorMessage = null;
            });
          }
          return;
        }
      }

      // For series, first fetch meta to get videos array with season/episode info
      if (type == 'series') {
        final meta = await _stremio.getMeta(
          baseUrl: addonBaseUrl,
          type: type,
          id: customId,
        );
        if (meta != null && meta['videos'] != null) {
          final videos = meta['videos'] as List;
          debugPrint('[CustomIdStreams] Got ${videos.length} videos from meta');

          // Parse videos to build season/episode structure
          _parseCustomIdVideos(videos);

          // Now fetch streams for the selected episode
          final selectedVideo = _getSelectedVideoFromCustomId(videos);
          if (selectedVideo != null) {
            final videoId = selectedVideo['id']?.toString() ?? '';
            debugPrint(
              '[CustomIdStreams] Fetching streams for video: $videoId',
            );
            final streams = await _stremio.getStreams(
              baseUrl: addonBaseUrl,
              type: type,
              id: videoId,
            );
            debugPrint('[CustomIdStreams] Got ${streams.length} streams');

            if (mounted) {
              final tagged = streams.map((s) {
                if (s is Map<String, dynamic>) {
                  return <String, dynamic>{
                    ...s,
                    '_addonName': addonName,
                    '_addonBaseUrl': addonBaseUrl,
                  };
                }
                return <String, dynamic>{
                  '_addonName': addonName,
                  '_addonBaseUrl': addonBaseUrl,
                };
              }).toList();
              setState(() {
                _stremioStreams = tagged;
                _allCombinedStremioStreams = tagged;
                _loadedAddonBaseUrls.add(addonBaseUrl);
                _isStremioFetching = false;
                if (streams.isEmpty) _errorMessage = 'No streams found';
              });
            }
            return;
          }
        }
      }

      // For movies or if meta fetch failed, use the original ID directly
      final streams = await _stremio.getStreams(
        baseUrl: addonBaseUrl,
        type: type,
        id: customId,
      );
      debugPrint('[CustomIdStreams] Got ${streams.length} streams');
      if (streams.isNotEmpty)
        debugPrint('[CustomIdStreams] First stream: ${streams.first}');
      if (mounted) {
        final tagged = streams.map((s) {
          if (s is Map<String, dynamic>) {
            return <String, dynamic>{
              ...s,
              '_addonName': addonName,
              '_addonBaseUrl': addonBaseUrl,
            };
          }
          return <String, dynamic>{
            '_addonName': addonName,
            '_addonBaseUrl': addonBaseUrl,
          };
        }).toList();
        setState(() {
          _stremioStreams = tagged;
          _allCombinedStremioStreams = tagged;
          _loadedAddonBaseUrls.add(addonBaseUrl);
          _isStremioFetching = false;
          if (streams.isEmpty) _errorMessage = 'No streams found';
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = 'Error: $e';
          _isStremioFetching = false;
          _loadedAddonBaseUrls.add(addonBaseUrl);
        });
    }
  }

  /// Parses the videos array from custom ID meta to build season/episode structure
  void _parseCustomIdVideos(List videos) {
    if (videos.isEmpty) return;

    // Build a map of seasons to episodes
    final Map<int, List<Map<String, dynamic>>> seasonMap = {};
    for (final video in videos) {
      if (video is! Map) continue;
      final season = video['season'] as int? ?? 1;
      final episode = video['episode'] as int? ?? 1;

      seasonMap.putIfAbsent(season, () => []);
      seasonMap[season]!.add({
        'id': video['id'],
        'title': video['title'] ?? 'Episode $episode',
        'episode': episode,
        'season': season,
        'thumbnail': video['thumbnail'],
        'released': video['released'],
      });
    }

    // Sort episodes within each season
    for (final episodes in seasonMap.values) {
      episodes.sort(
        (a, b) => (a['episode'] as int).compareTo(b['episode'] as int),
      );
    }

    // Store in _seasonData format compatible with existing UI
    if (mounted) {
      setState(() {
        _seasonData = {
          'seasons': seasonMap.keys.toList()..sort(),
          'episodesBySeason': seasonMap,
        };
        // Ensure selected season/episode are valid
        if (!seasonMap.containsKey(_selectedSeason)) {
          _selectedSeason = seasonMap.keys.first;
        }
        final episodes = seasonMap[_selectedSeason] ?? [];
        if (episodes.isEmpty || _selectedEpisode > episodes.length) {
          _selectedEpisode = episodes.isNotEmpty
              ? episodes.first['episode']
              : 1;
        }
      });
    }
  }

  /// Parses the videos array from collection meta to build collection items list
  void _parseCollectionVideos(List videos) {
    if (videos.isEmpty) return;

    final List<Map<String, dynamic>> items = [];
    for (final video in videos) {
      if (video is! Map) continue;

      items.add({
        'id': video['id'],
        'title': video['title'] ?? 'Unknown',
        'thumbnail': video['thumbnail'],
        'released': video['released'],
        'ratings': video['ratings'],
        'overview': video['overview'],
      });
    }

    if (mounted) {
      setState(() {
        _collectionItems = items;
        _isCollection = true;
      });
    }
  }

  /// Gets the selected video from the custom ID videos array
  Map<String, dynamic>? _getSelectedVideoFromCustomId(List videos) {
    for (final video in videos) {
      if (video is! Map) continue;
      final season = video['season'] as int? ?? 1;
      final episode = video['episode'] as int? ?? 1;
      if (season == _selectedSeason && episode == _selectedEpisode) {
        return video as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Fetches streams from a single selected addon only.
  Future<void> _fetchStremioStreams() async {
    if (_selectedSourceId == 'all_stremio') {
      // "All" chip â†’ just re-filter from cached results, or re-fetch if empty
      if (_allCombinedStremioStreams.isEmpty) {
        return _fetchAllStremioStreams();
      }
      setState(() {
        _stremioStreams = _allCombinedStremioStreams;
        _errorMessage = null;
      });
      return;
    }
    final addon = _streamAddons.firstWhere(
      (a) => a['baseUrl'] == _selectedSourceId,
      orElse: () =>
          _streamAddons.isNotEmpty ? _streamAddons.first : <String, dynamic>{},
    );
    if (addon.isEmpty) return;
    setState(() {
      _isStremioFetching = true;
      _errorMessage = null;
      _stremioStreams = [];
    });
    try {
      String stremioId = _movie.imdbId ?? '';
      if (_movie.mediaType == 'tv')
        stremioId = '$stremioId:$_selectedSeason:$_selectedEpisode';
      final type = _movie.mediaType == 'tv' ? 'series' : 'movie';
      final streams = await _stremio.getStreams(
        baseUrl: addon['baseUrl'],
        type: type,
        id: stremioId,
      );
      if (mounted) {
        setState(() {
          _stremioStreams = streams;
          if (streams.isEmpty)
            _errorMessage = 'No streams found in ${addon['name']}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isStremioFetching = false);
    }
  }

  /// Applies the current addon filter chip to _allCombinedStremioStreams.
  void _applyStremioFilter() {
    if (_selectedSourceId == 'all_stremio' || _isTorrentSource) {
      _stremioStreams = _allCombinedStremioStreams;
    } else {
      _stremioStreams = _allCombinedStremioStreams
          .where((s) => s['_addonBaseUrl'] == _selectedSourceId)
          .toList();
    }
  }

  Future<void> _searchTvTorrents(
    String seasonQuery,
    String episodeQuery,
  ) async {
    setState(() {
      _isSearching = true;
      _allTorrentResults = [];
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _torrentApi.searchTorrents(seasonQuery),
        _torrentApi.searchTorrents(episodeQuery),
      ]);
      if (mounted) {
        final filteredSeason = await TorrentFilter.filterTorrentsAsync(
          results[0],
          _movie.title,
          requiredSeason: _selectedSeason,
        );
        final filteredEpisode = await TorrentFilter.filterTorrentsAsync(
          results[1],
          _movie.title,
          requiredSeason: _selectedSeason,
          requiredEpisode: _selectedEpisode,
        );
        final combined = <String, TorrentResult>{};
        for (var r in filteredEpisode) {
          combined[r.magnet] = r;
        }
        for (var r in filteredSeason) {
          combined[r.magnet] = r;
        }
        if (mounted) {
          setState(() {
            _allTorrentResults = combined.values.toList();
            _isSearching = false;
          });
          _sortResults();
        }
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = e.toString();
          _isSearching = false;
        });
    }
  }

  Future<void> _searchTorrents(String query) async {
    setState(() {
      _isSearching = true;
      _allTorrentResults = [];
      _errorMessage = null;
    });
    try {
      final results = await _torrentApi.searchTorrents(query);
      if (mounted) {
        final filtered = await TorrentFilter.filterTorrentsAsync(
          results,
          _movie.title,
        );
        if (mounted) {
          setState(() {
            _allTorrentResults = filtered;
            _isSearching = false;
          });
          _sortResults();
        }
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = e.toString();
          _isSearching = false;
        });
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // Jackett Search
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<void> _searchJackett() async {
    if (!_isJackettConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Jackett is not configured. Go to Settings to add your Base URL and API Key.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _allTorrentResults = [];
      _errorMessage = null;
    });

    try {
      final baseUrl = await _settings.getJackettBaseUrl();
      final apiKey = await _settings.getJackettApiKey();

      if (baseUrl == null || apiKey == null)
        throw Exception('Jackett configuration missing');

      if (_movie.mediaType == 'tv') {
        final s = _selectedSeason.toString().padLeft(2, '0');
        final e = _selectedEpisode.toString().padLeft(2, '0');
        final results = await Future.wait([
          _jackett.search(baseUrl, apiKey, '${_movie.title} S$s'),
          _jackett.search(baseUrl, apiKey, '${_movie.title} S${s}E$e'),
        ]);
        if (mounted) {
          final filteredSeason = await TorrentFilter.filterTorrentsAsync(
            results[0],
            _movie.title,
            requiredSeason: _selectedSeason,
          );
          final filteredEpisode = await TorrentFilter.filterTorrentsAsync(
            results[1],
            _movie.title,
            requiredSeason: _selectedSeason,
            requiredEpisode: _selectedEpisode,
          );
          final combined = <String, TorrentResult>{};
          for (var r in filteredEpisode) {
            combined[r.magnet] = r;
          }
          for (var r in filteredSeason) {
            combined[r.magnet] = r;
          }
          if (mounted) {
            if (combined.isEmpty) {
              setState(() {
                _errorMessage =
                    'No results found for "S${s}E$e". Try checking your configured indexers in Jackett.';
                _isSearching = false;
              });
            } else {
              setState(() {
                _allTorrentResults = combined.values.toList();
                _isSearching = false;
              });
              _sortResults();
            }
          }
        }
      } else {
        final year = _movie.releaseDate.length >= 4
            ? _movie.releaseDate.substring(0, 4)
            : '';
        final query = year.isNotEmpty ? '${_movie.title} $year' : _movie.title;
        final results = await _jackett.search(baseUrl, apiKey, query);
        if (mounted) {
          final filtered = await TorrentFilter.filterTorrentsAsync(
            results,
            _movie.title,
          );
          if (mounted) {
            if (filtered.isEmpty) {
              setState(() {
                _errorMessage =
                    'No results found for "$query". Try checking your configured indexers in Jackett.';
                _isSearching = false;
              });
            } else {
              setState(() {
                _allTorrentResults = filtered;
                _isSearching = false;
              });
              _sortResults();
            }
          }
        }
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = e.toString();
          _isSearching = false;
        });
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // Prowlarr Search
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<void> _searchProwlarr() async {
    if (!_isProwlarrConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Prowlarr is not configured. Go to Settings to add your Base URL and API Key.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _allTorrentResults = [];
      _errorMessage = null;
    });

    try {
      final baseUrl = await _settings.getProwlarrBaseUrl();
      final apiKey = await _settings.getProwlarrApiKey();

      if (baseUrl == null || apiKey == null)
        throw Exception('Prowlarr configuration missing');

      if (_movie.mediaType == 'tv') {
        final s = _selectedSeason.toString().padLeft(2, '0');
        final e = _selectedEpisode.toString().padLeft(2, '0');
        final results = await Future.wait([
          _prowlarr.search(baseUrl, apiKey, '${_movie.title} S$s'),
          _prowlarr.search(baseUrl, apiKey, '${_movie.title} S${s}E$e'),
        ]);
        if (mounted) {
          final filteredSeason = await TorrentFilter.filterTorrentsAsync(
            results[0],
            _movie.title,
            requiredSeason: _selectedSeason,
          );
          final filteredEpisode = await TorrentFilter.filterTorrentsAsync(
            results[1],
            _movie.title,
            requiredSeason: _selectedSeason,
            requiredEpisode: _selectedEpisode,
          );
          final combined = <String, TorrentResult>{};
          for (var r in filteredEpisode) {
            combined[r.magnet] = r;
          }
          for (var r in filteredSeason) {
            combined[r.magnet] = r;
          }
          if (mounted) {
            if (combined.isEmpty) {
              setState(() {
                _errorMessage =
                    'No results found for "S${s}E$e". Try checking your configured indexers in Prowlarr.';
                _isSearching = false;
              });
            } else {
              setState(() {
                _allTorrentResults = combined.values.toList();
                _isSearching = false;
              });
              _sortResults();
            }
          }
        }
      } else {
        final year = _movie.releaseDate.length >= 4
            ? _movie.releaseDate.substring(0, 4)
            : '';
        final query = year.isNotEmpty ? '${_movie.title} $year' : _movie.title;
        final results = await _prowlarr.search(baseUrl, apiKey, query);
        if (mounted) {
          final filtered = await TorrentFilter.filterTorrentsAsync(
            results,
            _movie.title,
          );
          if (mounted) {
            if (filtered.isEmpty) {
              setState(() {
                _errorMessage =
                    'No results found for "$query". Try checking your configured indexers in Prowlarr.';
                _isSearching = false;
              });
            } else {
              setState(() {
                _allTorrentResults = filtered;
                _isSearching = false;
              });
              _sortResults();
            }
          }
        }
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = e.toString();
          _isSearching = false;
        });
    }
  }

  // â”€â”€â”€ safe field helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  List<String> _getCastNames() {
    try {
      final dynamic m = _movie;
      final dynamic raw = m.castNames ?? m.cast ?? m.credits;
      if (raw is List) return raw.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }

  String _getTrackerName(TorrentResult result) {
    try {
      final dynamic r = result;
      final dynamic raw = r.source ?? r.tracker ?? r.provider ?? r.site;
      if (raw is String) return raw;
    } catch (_) {}
    return '';
  }

  // â”€â”€â”€ play methods â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _playStremioStream(
    Map<String, dynamic> stream, {
    Duration? startPosition,
  }) async {
    // Handle externalUrl streams (e.g. "More Like This" addon)
    final externalUrl = stream['externalUrl']?.toString();
    if (externalUrl != null && externalUrl.isNotEmpty) {
      final streamAddonBaseUrl =
          stream['_addonBaseUrl']?.toString() ?? _selectedSourceId;
      await _handleExternalUrl(externalUrl, addonBaseUrl: streamAddonBaseUrl);
      return;
    }

    final useDebrid = await _settings.useDebridForStreams();
    final debridService = await _settings.getDebridService();

    // Determine stremio item ID for resume (custom ID or IMDB ID)
    final stremioId = widget.stremioItem?['id']?.toString() ?? _movie.imdbId;
    final stremioAddonBaseUrl =
        stream['_addonBaseUrl']?.toString() ?? _selectedSourceId;

    if (stream['url'] != null) {
      if (!mounted) return;
      final playTitle = _movie.mediaType == 'tv'
          ? '${_movie.title} - S$_selectedSeason E$_selectedEpisode'
          : _movie.title;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            streamUrl: stream['url'],
            title: playTitle,
            headers: Map<String, String>.from(
              stream['behaviorHints']?['proxyHeaders']?['request'] ?? {},
            ),
            movie: _movie,
            selectedSeason: _movie.mediaType == 'tv' ? _selectedSeason : null,
            selectedEpisode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
            startPosition: startPosition,
            activeProvider: 'stremio_direct',
            stremioId: stremioId,
            stremioAddonBaseUrl: stremioAddonBaseUrl,
          ),
        ),
      );
    } else if (stream['infoHash'] != null) {
      // Build a proper magnet link:
      // - include display name from stream title
      // - include tracker URLs from the 'sources' list
      //   (Stremio addons provide these as "tracker:udp://...", "tracker:http://...")
      final infoHash = stream['infoHash'] as String;
      final streamTitle = (stream['title'] ?? stream['name'] ?? '').toString();
      final dn = streamTitle.isNotEmpty
          ? '&dn=${Uri.encodeComponent(streamTitle)}'
          : '';

      // Extract trackers from sources
      final sources = stream['sources'];
      final trackerParams = StringBuffer();
      if (sources is List) {
        for (final src in sources) {
          if (src is String && src.startsWith('tracker:')) {
            final tracker = src.substring('tracker:'.length);
            trackerParams.write('&tr=${Uri.encodeComponent(tracker)}');
          }
        }
      }

      final magnet = 'magnet:?xt=urn:btih:$infoHash$dn$trackerParams';

      // fileIdx tells us exactly which file to play â€” no metadata poll needed

      if (!mounted) return;
      _streamCancelled = false;
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black,
        builder: (_) => LoadingOverlay(
          movie: _movie,
          message: useDebrid && debridService != 'None'
              ? 'Resolving with $debridService...'
              : 'Starting Torrent Engine...',
          onCancel: () {
            _streamCancelled = true;
            Navigator.of(context).pop();
          },
        ),
      );
      final navigator = Navigator.of(context);
      String? url;
      int? resolvedFileIndex;
      try {
        if (useDebrid && debridService != 'None') {
          final debrid = DebridApi();
          final files = debridService == 'Real-Debrid'
              ? await debrid.resolveRealDebrid(magnet)
              : await debrid.resolveTorBox(magnet);
          if (_streamCancelled) return;
          if (files.isNotEmpty) {
            if (_movie.mediaType == 'tv') {
              final s = 'S${_selectedSeason.toString().padLeft(2, '0')}';
              final e = 'E${_selectedEpisode.toString().padLeft(2, '0')}';
              final match = files
                  .where(
                    (f) =>
                        f.filename.toUpperCase().contains(s) &&
                        f.filename.toUpperCase().contains(e),
                  )
                  .toList();
              if (match.isNotEmpty) {
                resolvedFileIndex = files.indexOf(match.first);
                url = match.first.downloadUrl;
              } else {
                files.sort((a, b) => b.filesize.compareTo(a.filesize));
                url = files.first.downloadUrl;
              }
            } else {
              files.sort((a, b) => b.filesize.compareTo(a.filesize));
              url = files.first.downloadUrl;
            }
          }
        } else {
          url = await TorrentStreamService().streamTorrent(
            magnet,
            season: _movie.mediaType == 'tv' ? _selectedSeason : null,
            episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
          );
          if (_streamCancelled) return;
          if (url != null) {
            final idx = Uri.parse(url).queryParameters['index'];
            if (idx != null) resolvedFileIndex = int.tryParse(idx);
          }
        }
      } catch (e) {
        debugPrint('Stremio hash error: $e');
      }
      if (_streamCancelled) return;
      if (navigator.canPop()) navigator.pop();
      if (url != null && mounted) {
        final playTitle = _movie.mediaType == 'tv'
            ? '${_movie.title} - S$_selectedSeason E$_selectedEpisode'
            : _movie.title;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              streamUrl: url!,
              title: playTitle,
              magnetLink: magnet,
              movie: _movie,
              selectedSeason: _movie.mediaType == 'tv' ? _selectedSeason : null,
              selectedEpisode: _movie.mediaType == 'tv'
                  ? _selectedEpisode
                  : null,
              fileIndex: resolvedFileIndex,
              startPosition: startPosition,
              activeProvider: 'stremio_direct',
              stremioId: stremioId,
              stremioAddonBaseUrl: stremioAddonBaseUrl,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resolve stream.')),
        );
      }
    }
  }

  /// Handles a Stremio externalUrl: stremio:///detail, stremio:///search, or web URLs.
  Future<void> _handleExternalUrl(String url, {String? addonBaseUrl}) async {
    // Try parsing as a stremio:// link
    final parsed = StremioService.parseMetaLink(url);
    if (parsed != null) {
      switch (parsed['action']) {
        case 'detail':
          var id = parsed['id']?.toString() ?? '';
          final type = parsed['type']?.toString() ?? 'movie';
          // Extract IMDB ID from prefixed IDs like "mlt-rec-tt14905854"
          if (!id.startsWith('tt')) {
            final imdbMatch = RegExp(r'(tt\d+)').firstMatch(id);
            if (imdbMatch != null) {
              id = imdbMatch.group(1)!;
            }
          }
          await _openRecommendation({'id': id, 'type': type, 'name': ''});
          return;

        case 'search':
          final query = parsed['query']?.toString() ?? '';
          if (query.isNotEmpty && mounted) {
            // Pop back to MainScreen, then fire the search notifier
            Navigator.popUntil(context, (route) => route.isFirst);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MainScreen.stremioSearchNotifier.value = null;
              MainScreen.stremioSearchNotifier.value = {
                'query': query,
                'addonBaseUrl': addonBaseUrl ?? '',
              };
            });
          }
          return;

        case 'discover':
          // Open the catalog screen for this discover link
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StremioCatalogScreen()),
            );
          }
          return;
      }
    }

    // Regular https:// URL â†’ open in external browser
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to handle this link')),
      );
    }
  }

  void _playTorrent(TorrentResult result, {Duration? startPosition}) async {
    final useDebrid = await _settings.useDebridForStreams();
    final debridService = await _settings.getDebridService();
    if (!mounted) return;

    _streamCancelled = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder: (_) => LoadingOverlay(
        movie: _movie,
        message: useDebrid && debridService != 'None'
            ? 'Resolving with $debridService...'
            : 'Starting Torrent Engine...',
        onCancel: () {
          _streamCancelled = true;
          Navigator.of(context).pop();
        },
      ),
    );

    String? url;
    String? magnetLink = result.magnet;
    int? resolvedFileIndex;

    try {
      if (!magnetLink.startsWith('magnet:')) {
        if (!mounted || _streamCancelled) return;
        Navigator.pop(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black,
          builder: (_) => LoadingOverlay(
            movie: _movie,
            message: 'Resolving download link...',
            onCancel: () {
              _streamCancelled = true;
              Navigator.of(context).pop();
            },
          ),
        );
        try {
          final resolved = await _linkResolver.resolve(magnetLink);
          if (_streamCancelled) return;
          if (resolved.isMagnet) {
            magnetLink = resolved.link;
          } else if (resolved.torrentBytes != null) {
            if (!mounted) return;
            if (Navigator.canPop(context)) Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Torrent file downloads not yet supported. Please use magnet links.',
                ),
              ),
            );
            return;
          }
        } catch (e) {
          if (_streamCancelled) return;
          if (!mounted) return;
          if (Navigator.canPop(context)) Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
          return;
        }
        if (!mounted || _streamCancelled) return;
        if (Navigator.canPop(context)) Navigator.pop(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black,
          builder: (_) => LoadingOverlay(
            movie: _movie,
            message: useDebrid && debridService != 'None'
                ? 'Resolving with $debridService...'
                : 'Starting Torrent Engine...',
            onCancel: () {
              _streamCancelled = true;
              Navigator.of(context).pop();
            },
          ),
        );
      }

      if (useDebrid && debridService != 'None') {
        final debrid = DebridApi();
        final files = debridService == 'Real-Debrid'
            ? await debrid.resolveRealDebrid(magnetLink)
            : await debrid.resolveTorBox(magnetLink);
        if (_streamCancelled) return;
        if (files.isNotEmpty) {
          if (_movie.mediaType == 'tv') {
            final s = 'S${_selectedSeason.toString().padLeft(2, '0')}';
            final e = 'E${_selectedEpisode.toString().padLeft(2, '0')}';
            final match = files
                .where(
                  (f) =>
                      f.filename.toUpperCase().contains(s) &&
                      f.filename.toUpperCase().contains(e),
                )
                .toList();
            if (match.isNotEmpty) {
              resolvedFileIndex = files.indexOf(match.first);
              url = match.first.downloadUrl;
            } else {
              files.sort((a, b) => b.filesize.compareTo(a.filesize));
              url = files.first.downloadUrl;
            }
          } else {
            files.sort((a, b) => b.filesize.compareTo(a.filesize));
            url = files.first.downloadUrl;
          }
        }
      } else {
        url = await TorrentStreamService().streamTorrent(
          magnetLink,
          season: _movie.mediaType == 'tv' ? _selectedSeason : null,
          episode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
        );
        if (_streamCancelled) return;
        if (url != null) {
          final idx = Uri.parse(url).queryParameters['index'];
          if (idx != null) resolvedFileIndex = int.tryParse(idx);
        }
      }
    } catch (e) {
      debugPrint('Stream error: $e');
      if (mounted && !_streamCancelled)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    if (!mounted || _streamCancelled) return;
    if (Navigator.canPop(context)) Navigator.pop(context);

    if (url != null) {
      final playTitle = _movie.mediaType == 'tv'
          ? '${_movie.title} - S$_selectedSeason E$_selectedEpisode'
          : result.name;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            streamUrl: url!,
            title: playTitle,
            magnetLink: magnetLink,
            movie: _movie,
            selectedSeason: _movie.mediaType == 'tv' ? _selectedSeason : null,
            selectedEpisode: _movie.mediaType == 'tv' ? _selectedEpisode : null,
            fileIndex: resolvedFileIndex,
            startPosition: startPosition,
            activeProvider: 'torrent',
          ),
        ),
      );
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  BUILD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackdropWidget(),
            Center(
              child: CircularProgressIndicator(
                color: AppTheme.current.primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    final w = MediaQuery.of(context).size.width;
    final isMobile = (Platform.isAndroid || Platform.isIOS) || w < 800;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            _movie.mediaType == 'tv' &&
            _seasonData != null) {
          final episodes = _seasonData!['episodes'] as List?;
          if (episodes == null || episodes.isEmpty) return;
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              _selectedEpisode > 1) {
            setState(() => _selectedEpisode--);
            _autoSearch();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              _selectedEpisode < episodes.length) {
            setState(() => _selectedEpisode++);
            _autoSearch();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
              _selectedSeason > 1) {
            _fetchSeason(_selectedSeason - 1);
            setState(() => _selectedEpisode = 1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
              _selectedSeason < _movie.numberOfSeasons) {
            _fetchSeason(_selectedSeason + 1);
            setState(() => _selectedEpisode = 1);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: FocusableControl(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: 50,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            _buildBackdropWidget(),
            SafeArea(
              child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ shared backdrop â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Returns a full image URL. If the path is already a full URL (e.g. from
  /// Stremio), returns it as-is; otherwise wraps with TMDB base URL.
  String _imageUrl(String path) =>
      path.startsWith('http') ? path : TmdbApi.getBackdropUrl(path);

  Widget _buildBackdropWidget() {
    final url = _imageUrl(
      _movie.backdropPath.isNotEmpty ? _movie.backdropPath : _movie.posterPath,
    );
    return buildAtmosphereBackdrop(
      imageUrl: url,
      genres: _movie.genres,
      blurSigma: 12,
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  RATINGS ROW + ACTION BUTTONS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildRatingsRow() {
    final r = _mdblistRatings;
    final chips = <Widget>[];

    Widget ratingChip(
      String label,
      dynamic value, {
      Color color = const Color(0xFFB0B0C0),
      String? icon,
    }) {
      if (value == null || value == 0) return const SizedBox.shrink();
      final display = value is double
          ? value.toStringAsFixed(1)
          : value.toString();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Text(icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              display,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (r != null) {
      final scores =
          r['scores'] as List<dynamic>? ?? r['ratings'] as List<dynamic>? ?? [];
      for (final s in scores) {
        final source = (s['source'] ?? '').toString();
        final value = s['value'] ?? s['score'];
        if (value == null || value == 0) continue;
        String label;
        Color color;
        switch (source.toLowerCase()) {
          case 'imdb':
            label = 'IMDb';
            color = const Color(0xFFF5C518);
          case 'metacritic':
            label = 'MC';
            color = const Color(0xFF66CC33);
          case 'metacriticuser':
            label = 'MC User';
            color = const Color(0xFF66CC33);
          case 'trakt':
            label = 'Trakt';
            color = const Color(0xFFED1C24);
          case 'letterboxd':
            label = 'LB';
            color = const Color(0xFF00D735);
          case 'tomatoes':
            label = 'RT';
            color = const Color(0xFFFA320A);
          case 'tomatoesaudience':
            label = 'RT Aud';
            color = const Color(0xFFFA320A);
          case 'tmdb':
            label = 'TMDB';
            color = const Color(0xFF01B4E4);
          default:
            label = source.toUpperCase();
            color = AppTheme.textDisabled;
        }
        chips.add(ratingChip(label, value, color: color));
      }
    }

    if (_userTraktRating != null) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFED1C24),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Trakt: $_userTraktRating/10',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_userSimklRating != null) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: AppTheme.textPrimary, size: 14),
              const SizedBox(width: 4),
              Text(
                'Simkl: $_userSimklRating/10',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _actionButton(
          icon: _userTraktRating != null
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          label: _userTraktRating != null ? 'Rate: $_userTraktRating' : 'Rate',
          active: _userTraktRating != null,
          onTap: () async {
            if (await TraktService().isLoggedIn()) {
              _showRatingDialog();
            } else {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Login to Trakt in Settings')),
              );
            }
          },
        ),
        _actionButton(
          icon: _isInTraktCollection
              ? Icons.library_add_check_rounded
              : Icons.library_add_rounded,
          label: _isInTraktCollection ? 'Collected' : 'Collect',
          active: _isInTraktCollection,
          onTap: _toggleTraktCollection,
        ),
        _actionButton(
          icon: Icons.live_tv_rounded,
          label: 'Check In',
          active: false,
          onTap: _traktCheckin,
        ),
        _actionButton(
          icon: Icons.playlist_add_rounded,
          label: 'Add to List',
          active: false,
          onTap: _addToTraktList,
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return FocusableControl(
      onTap: onTap,
      borderRadius: 12,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primaryColor.withValues(alpha: 0.2)
              : AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : AppTheme.border,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  MOBILE LAYOUT
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileHero(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _movie.genres.take(3).map(_genreChip).toList(),
                ),
                const SizedBox(height: 20),
                if (_mdblistRatings != null ||
                    _userTraktRating != null ||
                    _userSimklRating != null) ...[
                  _buildRatingsRow(),
                  const SizedBox(height: 20),
                ],
                _buildActionButtons(),
                const SizedBox(height: 24),
                ExpandableSynopsis(text: _movie.overview),
                const SizedBox(height: 24),
                // Collection items display
                if (_isCollection && _collectionItems.isNotEmpty) ...[
                  CollectionItemsSection(
                    items: _collectionItems,
                    onItemTap: _openCollectionItem,
                  ),
                  const SizedBox(height: 24),
                ],
                Builder(
                  builder: (ctx) {
                    final cast = _getCastNames();
                    if (cast.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('Cast'),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: cast
                                .take(8)
                                .map(
                                  (n) => Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: _castChip(n),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
                RecommendationsSection(
                  recommendations: _stremioRecommendations,
                  isLoading: _isLoadingRecommendations,
                  scrollController: _recommendationsScrollController,
                  onItemTap: _openRecommendation,
                ),
                if (_movie.mediaType == 'tv' && !_isCollection) ...[
                  _buildSeasonSelector(),
                  const SizedBox(height: 20),
                  _buildEpisodeSelector(),
                  const SizedBox(height: 8),
                  Text(
                    'â† â†’ Episodes  |  â†‘ â†“ Season',
                    style: TextStyle(
                      color: AppTheme.textDisabled,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (!_isCollection) ...[
                  _buildSourceToggle(),
                  const SizedBox(height: 16),
                  _buildSourceChips(),
                  const SizedBox(height: 24),
                  _buildResultsHeader(),
                  const SizedBox(height: 16),
                  _buildStreamList(),
                ],
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHero() {
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: _imageUrl(
                _movie.backdropPath.isNotEmpty
                    ? _movie.backdropPath
                    : _movie.posterPath,
              ),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorWidget: (context, url, error) => Container(
                color: AppTheme.surfaceContainerHigh,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              ),
              placeholder: (context, url) =>
                  Container(color: AppTheme.surfaceContainerHigh),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.bgDark.withValues(alpha: 0.5),
                    AppTheme.bgDark,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Hero(
                  tag: 'movie-poster-${_movie.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: _imageUrl(_movie.posterPath),
                        width: 100,
                        height: 150,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          width: 100,
                          height: 150,
                          color: AppTheme.surfaceContainerHigh,
                          child: const Icon(
                            Icons.broken_image,
                            size: 32,
                            color: Colors.grey,
                          ),
                        ),
                        placeholder: (context, url) => Container(
                          width: 100,
                          height: 150,
                          color: AppTheme.surfaceContainerHigh,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _movie.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          height: 1.1,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _movie.releaseDate.take(4),
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _movie.voteAverage.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  DESKTOP LAYOUT
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 500,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(32, 24, 24, 48),
            child: _buildDesktopLeftPanel(),
          ),
        ),
        Container(width: 1, color: AppTheme.border),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
            child: _buildRightPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLeftPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'movie-poster-${_movie.id}',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: -10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: _imageUrl(_movie.posterPath),
                    width: 240,
                    height: 350,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 240,
                      height: 350,
                      color: AppTheme.surfaceContainerHigh,
                      child: const Icon(
                        Icons.broken_image,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                    placeholder: (context, url) => Container(
                      width: 240,
                      height: 350,
                      color: AppTheme.surfaceContainerHigh,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          _movie.title,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              _movie.releaseDate.take(4),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            const SizedBox(width: 12),
            Text('Â·', style: TextStyle(color: AppTheme.textDisabled)),
            const SizedBox(width: 12),
            const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 6),
            Text(
              _movie.voteAverage.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _movie.genres.take(3).map(_genreChip).toList(),
        ),
        const SizedBox(height: 20),
        if (_mdblistRatings != null ||
            _userTraktRating != null ||
            _userSimklRating != null) ...[
          _buildRatingsRow(),
          const SizedBox(height: 20),
        ],
        _buildActionButtons(),
        const SizedBox(height: 24),
        Text(
          _movie.overview,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        // Collection items display
        if (_isCollection && _collectionItems.isNotEmpty) ...[
          CollectionItemsSection(
            items: _collectionItems,
            onItemTap: _openCollectionItem,
          ),
          const SizedBox(height: 32),
        ],
        if (_castMembers.isNotEmpty) DesktopCastRow(
          castMembers: _castMembers,
          scrollController: _castScrollController,
        ),
        RecommendationsSection(
          recommendations: _stremioRecommendations,
          isLoading: _isLoadingRecommendations,
          scrollController: _recommendationsScrollController,
          onItemTap: _openRecommendation,
        ),
      ],
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  RIGHT PANEL
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildRightPanel() {
    // For collections, don't show stream/torrent sections
    if (_isCollection) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This is a collection. Select an item from the list to view details and streams.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_movie.mediaType == 'tv') ...[
          _buildSeasonSelector(),
          SizedBox(height: 20),
          _buildEpisodeSelector(),
          SizedBox(height: 8),
          Text(
            'â† â†’ Navigate Episodes  |  â†‘ â†“ Change Season',
            style: TextStyle(color: AppTheme.textDisabled, fontSize: 11),
          ),
          SizedBox(height: 24),
        ],
        _buildSourceToggle(),
        SizedBox(height: 14),
        _buildSourceChips(),
        SizedBox(height: 20),
        _buildResultsHeader(),
        SizedBox(height: 12),
        _buildStreamList(),
      ],
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  SEASON SELECTOR
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildSeasonSelector() {
    // Get season count from either TMDB or custom ID data
    int seasonCount = _movie.numberOfSeasons;
    if (_seasonData != null && _seasonData!['seasons'] != null) {
      // Custom ID format
      final seasons = _seasonData!['seasons'] as List<int>;
      seasonCount = seasons.length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.layers_outlined,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Seasons',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _scrollArrow(
                  Icons.arrow_back_ios_rounded,
                  () => _seasonScrollController.animateTo(
                    _seasonScrollController.offset - 160,
                    duration: Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                  ),
                ),
                _scrollArrow(
                  Icons.arrow_forward_ios_rounded,
                  () => _seasonScrollController.animateTo(
                    _seasonScrollController.offset + 160,
                    duration: Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            controller: _seasonScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: seasonCount,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final n = i + 1;
              final sel = _selectedSeason == n;
              return FocusableControl(
                onTap: () {
                  // For custom IDs, just update state and re-fetch
                  if (widget.stremioItem != null &&
                      _seasonData != null &&
                      _seasonData!['episodesBySeason'] != null) {
                    setState(() {
                      _selectedSeason = n;
                      _selectedEpisode = 1;
                    });
                    _fetchStremioStreamsForCustomId(widget.stremioItem!);
                  } else {
                    // For TMDB, fetch season data
                    _fetchSeason(n);
                  }
                },
                borderRadius: 20,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.textPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? AppTheme.textPrimary : AppTheme.border,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    'Season $n',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel ? AppTheme.bgDark : AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  EPISODE SELECTOR
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildEpisodeSelector() {
    if (_isLoadingSeason) {
      return SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.current.primaryColor,
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Handle both TMDB format (_seasonData['episodes']) and custom ID format (_seasonData['episodesBySeason'])
    List episodes = [];
    if (_seasonData != null) {
      if (_seasonData!['episodes'] != null) {
        // TMDB format
        episodes = _seasonData!['episodes'] as List;
      } else if (_seasonData!['episodesBySeason'] != null) {
        // Custom ID format
        final episodesBySeason =
            _seasonData!['episodesBySeason']
                as Map<int, List<Map<String, dynamic>>>;
        episodes = episodesBySeason[_selectedSeason] ?? [];
      }
    }

    if (episodes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionLabel('Episodes (${episodes.length})'),
            Row(
              children: [
                _scrollArrow(
                  Icons.arrow_back_ios_rounded,
                  () => _episodeScrollController.animateTo(
                    _episodeScrollController.offset - 260,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                ),
                _scrollArrow(
                  Icons.arrow_forward_ios_rounded,
                  () => _episodeScrollController.animateTo(
                    _episodeScrollController.offset + 260,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.separated(
            controller: _episodeScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: episodes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final ep = episodes[index];
              final epNum = (ep['episode_number'] ?? ep['episode']) as int;
              final isSelected = _selectedEpisode == epNum;
              final name = ep['name'] ?? ep['title'] ?? 'Episode $epNum';
              final stillPath = ep['still_path'] ?? ep['thumbnail'];
              final isWatched = _watchedEpisodes.contains(
                '${_movie.id}_S${_selectedSeason}_E$epNum',
              );

              return FocusableControl(
                onTap: () {
                  setState(() => _selectedEpisode = epNum);
                  if (_selectedSourceId == 'streame') {
                    _autoSearch();
                  } else if (_selectedSourceId == 'jackett') {
                    _searchJackett();
                  } else if (_selectedSourceId == 'prowlarr') {
                    _searchProwlarr();
                  } else if (_selectedSourceId == 'all_stremio') {
                    _fetchAllStremioStreams();
                  } else {
                    if (widget.stremioItem != null) {
                      _fetchStremioStreamsForCustomId(widget.stremioItem!);
                    } else {
                      _fetchStremioStreams();
                    }
                  }
                },
                borderRadius: 12,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 240,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.current.primaryColor.withValues(alpha: 0.1)
                        : AppTheme.surfaceContainerHigh.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.current.primaryColor
                          : AppTheme.border,
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      children: [
                        if (stillPath != null &&
                            stillPath.toString().isNotEmpty)
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: stillPath.toString().startsWith('http')
                                  ? stillPath.toString()
                                  : TmdbApi.getBackdropUrl(
                                      stillPath.toString(),
                                    ),
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: AppTheme.bgCard),
                              errorWidget: (_, __, ___) =>
                                  Container(color: AppTheme.bgCard),
                            ),
                          ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppTheme.bgDark.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (isWatched)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'WATCHED',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EP $epNum',
                                style: TextStyle(
                                  color: isSelected
                                      ? AppTheme.current.primaryColor
                                      : AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              Icons.play_circle_fill,
                              color: AppTheme.textPrimary,
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  SOURCE TOGGLE + CHIPS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  bool get _isTorrentSource =>
      _selectedSourceId == 'streame' ||
      _selectedSourceId == 'jackett' ||
      _selectedSourceId == 'prowlarr';

  Widget _buildSourceToggle() {
    final isTorrent = _isTorrentSource;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sourceTab(
            'Stremio Addons',
            Icons.extension_outlined,
            !isTorrent,
            () {
              if (_streamAddons.isNotEmpty) {
                setState(() {
                  _selectedSourceId = 'all_stremio';
                  _applyStremioFilter();
                  _errorMessage = null;
                });
                // Re-fetch if we don't have cached results
                if (_allCombinedStremioStreams.isEmpty)
                  _fetchAllStremioStreams();
              }
            },
          ),
          _sourceTab(
            'Torrent Sources',
            Icons.downloading_rounded,
            isTorrent,
            () {
              setState(() => _selectedSourceId = 'streame');
              _autoSearch();
            },
          ),
        ],
      ),
    );
  }

  Widget _sourceTab(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.current.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceChips() {
    final isTorrent = _isTorrentSource;
    final chips = <Map<String, dynamic>>[];
    if (isTorrent) {
      chips.add({'id': 'streame', 'label': 'Streame'});
      if (_isJackettConfigured)
        chips.add({'id': 'jackett', 'label': 'ðŸ” Jackett'});
      if (_isProwlarrConfigured)
        chips.add({'id': 'prowlarr', 'label': 'ðŸ” Prowlarr'});
      for (final a in _streamAddons) {
        if (a['type'] == 'torrent')
          chips.add({'id': a['baseUrl'], 'label': a['name']});
      }
    } else {
      // "All" chip shows combined streams from every addon
      if (_streamAddons.length > 1) {
        chips.add({'id': 'all_stremio', 'label': 'âš¡ All'});
      }
      // Only show addon chips that have finished loading
      for (final a in _streamAddons) {
        if (_loadedAddonBaseUrls.contains(a['baseUrl'])) {
          chips.add({'id': a['baseUrl'], 'label': a['name']});
        }
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          final sel = _selectedSourceId == chip['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                final id = chip['id'] as String;
                setState(() => _selectedSourceId = id);
                if (id == 'streame') {
                  _autoSearch();
                } else if (id == 'jackett') {
                  _searchJackett();
                } else if (id == 'prowlarr') {
                  _searchProwlarr();
                } else if (id == 'all_stremio') {
                  setState(() {
                    _applyStremioFilter();
                    _errorMessage =
                        _stremioStreams.isEmpty && !_isStremioFetching
                        ? 'No streams found from any addon'
                        : null;
                  });
                } else {
                  // Single addon filter from cached combined results
                  setState(() {
                    _applyStremioFilter();
                    _errorMessage =
                        _stremioStreams.isEmpty && !_isStremioFetching
                        ? 'No streams found in ${chip['label']}'
                        : null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: sel
                      ? AppTheme.current.primaryColor
                      : AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel
                        ? AppTheme.current.primaryColor
                        : AppTheme.border,
                  ),
                ),
                child: Text(
                  chip['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  RESULTS HEADER
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildResultsHeader() {
    // Show sort dropdown for ALL torrent sources, not just Streame
    final showSort = _isTorrentSource;
    String? epLabel;
    if (_movie.mediaType == 'tv') {
      final s = _selectedSeason.toString().padLeft(2, '0');
      final e = _selectedEpisode.toString().padLeft(2, '0');
      epLabel = 'S${s}E$e';
    }
    return Row(
      children: [
        Icon(Icons.download_rounded, color: AppTheme.textSecondary, size: 16),
        const SizedBox(width: 6),
        Text(
          'Available Sources',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        if (epLabel != null) ...[
          const SizedBox(width: 6),
          Text(
            'â€” $epLabel',
            style: TextStyle(color: AppTheme.textDisabled, fontSize: 12),
          ),
        ],
        if (_isSearching || _isStremioFetching) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.current.primaryColor,
            ),
          ),
        ],
        const Spacer(),
        if (showSort)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButton<String>(
              value: _sortPreference,
              isDense: true,
              underline: const SizedBox.shrink(),
              dropdownColor: AppTheme.surfaceContainer,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.textSecondary,
                size: 16,
              ),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              items: [
                'Seeders (High to Low)',
                'Seeders (Low to High)',
                'Quality (High to Low)',
                'Quality (Low to High)',
                'Size (High to Low)',
                'Size (Low to High)',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _sortPreference = val);
                  _settings.setSortPreference(val);
                  _sortResults();
                }
              },
            ),
          ),
        if (showSort) ...[const SizedBox(width: 8), _buildAudioFilterButton()],
      ],
    );
  }

  Widget _buildAudioFilterButton() {
    final active = _activeAudioFilters.isNotEmpty;
    return GestureDetector(
      onTapDown: (details) async {
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final position = RelativeRect.fromRect(
          Rect.fromLTWH(
            details.globalPosition.dx,
            details.globalPosition.dy,
            1,
            1,
          ),
          Offset.zero & overlay.size,
        );
        // Build a temporary stateful popup via showMenu
        await showMenu(
          context: context,
          position: position,
          color: AppTheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          items: [
            PopupMenuItem(
              enabled: false,
              padding: EdgeInsets.zero,
              child: AudioFilterMenu(
                allTags: _kAudioTags,
                activeTags: Set<String>.from(_activeAudioFilters),
                onChanged: (updated) =>
                    setState(() => _activeAudioFilters = updated),
              ),
            ),
          ],
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.current.primaryColor.withValues(alpha: 0.18)
              : AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: active
                ? AppTheme.current.primaryColor.withValues(alpha: 0.6)
                : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq,
              size: 14,
              color: active
                  ? AppTheme.current.primaryColor
                  : AppTheme.textSecondary,
            ),
            if (active) ...[
              const SizedBox(width: 4),
              Text(
                '${_activeAudioFilters.length}',
                style: TextStyle(
                  color: AppTheme.current.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  STREAM LIST
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildStreamList() {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }
    final isTorrent = _isTorrentSource;
    final count = isTorrent
        ? _filteredTorrentResults.length
        : _stremioStreams.length;
    if (!_isSearching && !_isStremioFetching && count == 0) {
      final msg =
          (isTorrent &&
              _activeAudioFilters.isNotEmpty &&
              _allTorrentResults.isNotEmpty)
          ? 'No results match the audio filter'
          : 'No streams found';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(msg, style: TextStyle(color: AppTheme.textDisabled)),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (isTorrent) {
          final r = _filteredTorrentResults[i];
          double prog = 0;
          bool resumable = false;
          if (_lastProgress != null && _lastProgress!['method'] == 'torrent') {
            if (_getHash(r.magnet) == _getHash(_lastProgress!['sourceId'])) {
              final pos = _lastProgress!['position'] as int;
              final dur = _lastProgress!['duration'] as int;
              if (dur > 0) {
                prog = (pos / dur).clamp(0.0, 1.0);
                resumable = true;
              }
            }
          }
          return TorrentTile(
            result: r,
            progress: prog,
            isResumable: resumable,
            startPosition: widget.startPosition,
            resumePosition: resumable
                ? Duration(milliseconds: _lastProgress!['position'] as int)
                : null,
            trackerName: _getTrackerName(r),
            onPlay: () => _playTorrent(
              r,
              startPosition: resumable
                  ? Duration(milliseconds: _lastProgress!['position'] as int)
                  : widget.startPosition,
            ),
            onCopyMagnet: () {
              Clipboard.setData(ClipboardData(text: r.magnet));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Magnet copied'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          );
        } else {
          final s = _stremioStreams[i];
          double prog = 0;
          bool resumable = false;
          if (_lastProgress != null) {
            final String? sid = s['infoHash'] != null
                ? 'magnet:?xt=urn:btih:${s['infoHash']}'
                : s['url'];
            if (sid != null) {
              final hs = _lastProgress!['sourceId'] as String;
              final match = s['infoHash'] != null
                  ? _getHash(hs) == _getHash(sid)
                  : hs == sid;
              if (match) {
                final pos = _lastProgress!['position'] as int;
                final dur = _lastProgress!['duration'] as int;
                if (dur > 0) {
                  prog = (pos / dur).clamp(0.0, 1.0);
                  resumable = true;
                }
              }
            }
          }
          return StremioTile(
            stream: s,
            title: s['title'] ?? s['name'] ?? 'Unknown Stream',
            description: s['description'] ?? '',
            progress: prog,
            isResumable: resumable,
            startPosition: widget.startPosition,
            resumePosition: resumable
                ? Duration(milliseconds: _lastProgress!['position'] as int)
                : null,
            selectedSourceId: _selectedSourceId,
            onPlay: () => _playStremioStream(
              s,
              startPosition: resumable
                  ? Duration(milliseconds: _lastProgress!['position'] as int)
                  : widget.startPosition,
            ),
          );
        }
      },
    );
  }


  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  SMALL REUSABLE WIDGETS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      color: AppTheme.textPrimary,
      fontWeight: FontWeight.w700,
      fontSize: 14,
    ),
  );

  Widget _genreChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.border),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _castChip(String name) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.border),
    ),
    child: Text(
      name,
      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
    ),
  );

  Widget _scrollArrow(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(icon, color: AppTheme.textDisabled, size: 16),
    ),
  );

  /// Opens a collection item by navigating to its detail page
  Future<void> _openCollectionItem(String id) async {
    // Try TMDB lookup first for IMDB IDs
    if (id.startsWith('tt')) {
      try {
        final movie = await _api.findByImdbId(id, mediaType: 'movie');
        if (movie != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailsScreen(movie: movie)),
          );
          return;
        }
      } catch (e) {
        debugPrint('[CollectionItem] TMDB lookup failed: $e');
      }
    }

    // Fallback: create minimal Movie object
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailsScreen(
            movie: Movie(
              id: id.hashCode,
              imdbId: id.startsWith('tt') ? id : null,
              title: id,
              posterPath: '',
              backdropPath: '',
              voteAverage: 0,
              releaseDate: '',
              overview: '',
              mediaType: 'movie',
            ),
          ),
        ),
      );
    }
  }
}

