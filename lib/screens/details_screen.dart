// ignore_for_file: unused_element, unused_element_parameter
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:streame_core/models/movie.dart';
import 'package:streame_core/api/tmdb_api.dart';
import 'package:streame_core/models/torrent_result.dart';
import 'package:streame_core/api/torrent_api.dart';
import 'package:streame_core/services/torrent_stream_service.dart';
import 'package:streame_core/api/stremio_service.dart';
import 'package:streame_core/services/torrent_filter.dart';
import 'package:streame_core/services/settings_service.dart';
import 'package:streame_core/api/debrid_api.dart';
import 'package:streame_core/services/jackett_service.dart';
import 'package:streame_core/services/prowlarr_service.dart';
import 'package:streame_core/services/link_resolver.dart';
import 'package:streame_core/services/watch_history_service.dart';
import 'package:streame_core/services/episode_watched_service.dart';
import 'package:streame_core/api/trakt_service.dart';
import 'package:streame_core/api/simkl_service.dart';
import 'package:streame_core/api/mdblist_service.dart';
import 'package:streame_core/utils/extensions.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'package:streame_core/utils/device_detector.dart';
import 'package:streame_core/utils/app_logger.dart';
import 'package:streame_core/widgets/loading_overlay.dart';
import 'player_screen.dart';
import 'stremio_catalog_screen.dart';
import 'main_screen.dart';
import 'package:streame_core/widgets/movie_atmosphere.dart';
import 'details/expandable_synopsis.dart';
import 'details/audio_filter_menu.dart';
import 'details/stream_tiles.dart';
import 'details/cast_row.dart';
import 'details/sections.dart';

part 'details/details_fetch_methods.dart';
part 'details/details_stream_methods.dart';
part 'details/details_playback_methods.dart';
part 'details/details_ui_info.dart';
part 'details/details_ui_layouts.dart';
part 'details/details_ui_streams.dart';

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

// ═══════════════════════════════════════════════════════════════════════════════
//  ABSTRACT BASE CLASS — fields + abstract method contracts
// ═══════════════════════════════════════════════════════════════════════════════

abstract class _DetailsScreenBase extends State<DetailsScreen> with AtmosphereMixin {
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

  // ─── concrete data methods (no cross-mixin deps) ─────────────────────────────

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

  // ─── abstract method contracts (implemented by mixins) ───────────────────────

  // Fetch methods
  Future<void> _fetchDetails();
  Future<void> _fetchCastMembers();
  Future<void> _fetchExternalRatings();
  Future<void> _fetchUserTraktRating();
  Future<void> _rateTraktItem(int rating);
  Future<void> _removeTraktRating();
  Future<void> _fetchUserSimklRating();
  Future<void> _fetchTraktCollectionStatus();
  Future<void> _toggleTraktCollection();
  Future<void> _traktCheckin();
  Future<void> _addToTraktList();
  void _showRatingDialog();
  Future<void> _fetchStremioRecommendations();
  Future<void> _openRecommendation(Map<String, dynamic> rec);
  Future<void> _openCollectionItem(String id);

  // Stream methods
  List<String> _detectAudioTags(String title);
  List<TorrentResult> get _filteredTorrentResults;
  Future<void> _checkIndexerConfiguration();
  String _getHash(String magnetOrUrl);
  Future<void> _sortResults();
  Future<void> _fetchSeason(int seasonNumber);
  void _autoSearch();
  Future<void> _fetchAllStremioStreams();
  Future<void> _fetchStremioStreamsForCustomId(Map<String, dynamic> item);
  void _parseCustomIdVideos(List videos);
  void _parseCollectionVideos(List videos);
  Map<String, dynamic>? _getSelectedVideoFromCustomId(List videos);
  Future<void> _fetchStremioStreams();
  void _applyStremioFilter();
  Future<void> _searchTvTorrents(String seasonQuery, String episodeQuery);
  Future<void> _searchTorrents(String query);
  Future<void> _searchJackett();
  Future<void> _searchProwlarr();
  List<String> _getCastNames();
  String _getTrackerName(TorrentResult result);

  // Playback methods
  void _playStremioStream(Map<String, dynamic> stream, {Duration? startPosition});
  Future<void> _handleExternalUrl(String url, {String? addonBaseUrl});
  void _playTorrent(TorrentResult result, {Duration? startPosition});

  // UI info methods
  String _imageUrl(String path);
  Widget _buildBackdropWidget();
  Widget _buildRatingsRow();
  Widget _buildActionButtons();
  Widget _actionButton({required IconData icon, required String label, required bool active, required VoidCallback onTap});
  Widget _sectionLabel(String text);
  Widget _genreChip(String label);
  Widget _castChip(String name);
  Widget _scrollArrow(IconData icon, VoidCallback onTap);

  // UI layout methods
  Widget _buildMobileLayout();
  Widget _buildMobileHero();
  Widget _buildDesktopLayout();
  Widget _buildDesktopLeftPanel();
  Widget _buildRightPanel();

  // UI streams methods
  bool get _isTorrentSource;
  Widget _buildSeasonSelector();
  Widget _buildEpisodeSelector();
  Widget _buildSourceToggle();
  Widget _sourceTab(String label, IconData icon, bool selected, VoidCallback onTap);
  Widget _buildSourceChips();
  Widget _buildResultsHeader();
  Widget _buildAudioFilterButton();
  Widget _buildStreamList();
  Widget _buildTvLayout();
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CONCRETE STATE CLASS — lifecycle + build only
// ═══════════════════════════════════════════════════════════════════════════════

class _DetailsScreenState extends _DetailsScreenBase
    with
        DetailsFetchMethods,
        DetailsStreamMethods,
        DetailsPlaybackMethods,
        DetailsUiInfo,
        DetailsUiLayouts,
        DetailsUiStreams {
  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
    if (widget.initialSeason != null) _selectedSeason = widget.initialSeason!;
    if (widget.initialEpisode != null) {
      _selectedEpisode = widget.initialEpisode!;
    }
    // Start atmosphere color extraction
    final url = (_movie.posterPath.isNotEmpty
        ? _movie.posterPath
        : _movie.backdropPath);
    loadAtmosphere(url.startsWith('http') ? url : TmdbApi.getImageUrl(url));
    _checkHistory();
    _loadSortPreference();
    _loadWatchedEpisodes();
    _fetchDetails();
    // Defer non-essential fetches to after the first frame for faster initial paint
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIndexerConfiguration();
      _fetchExternalRatings();
      _fetchUserTraktRating();
      _fetchUserSimklRating();
      _fetchTraktCollectionStatus();
    });
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

    final isTv = PlatformInfo.isTv(context);
    final isMobile = PlatformInfo.isMobile(context);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            _movie.mediaType == 'tv' &&
            _seasonData != null) {
          // Handle both TMDB format and custom ID format
          List episodes;
          if (_seasonData!['episodes'] != null) {
            episodes = _seasonData!['episodes'] as List;
          } else if (_seasonData!['episodesBySeason'] != null) {
            final bySeason = _seasonData!['episodesBySeason']
                as Map<int, List<Map<String, dynamic>>>;
            episodes = bySeason[_selectedSeason] ?? [];
          } else {
            return;
          }
          if (episodes.isEmpty) return;
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
        backgroundColor: AppTheme.bgDark,
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
                backgroundColor: AppTheme.overlay,
                child: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            _buildBackdropWidget(),
            SafeArea(
              child: isTv ? _buildTvLayout() : (isMobile ? _buildMobileLayout() : _buildDesktopLayout()),
            ),
          ],
        ),
      ),
    );
  }
}
