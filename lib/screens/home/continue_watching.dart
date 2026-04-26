import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:streame_core/api/tmdb_api.dart';
import 'package:streame_core/services/watch_history_service.dart';
import 'package:streame_core/services/settings_service.dart';
import 'package:streame_core/models/movie.dart';
import 'package:streame_core/utils/app_theme.dart';
import '../details_screen.dart';
import 'package:streame_core/api/stremio_service.dart';
import 'package:streame_core/api/webstreamr_service.dart';
import 'package:streame_core/providers/stream_services.dart';
import 'package:streame_core/services/stream_extractor.dart';
import 'package:streame_core/api/debrid_api.dart';
import 'package:streame_core/services/torrent_stream_service.dart';
import 'package:streame_core/api/trakt_service.dart';
import '../streaming_details_screen.dart';
import '../player_screen.dart';

class ContinueWatchingSection extends StatefulWidget {
  const ContinueWatchingSection({super.key});

  @override
  State<ContinueWatchingSection> createState() => _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState extends State<ContinueWatchingSection> {
  final ScrollController _scrollController = ScrollController();
  String? _loadingItemId;

  void _scrollLeft() {
    _scrollController.animateTo(
      _scrollController.offset - 600,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + 600,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildCWSectionArrow(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: GlassColors.surfaceSubtle,
        shape: BoxShape.circle,
        border: Border.all(color: GlassColors.borderSubtle, width: 0.5),
      ),
      child: Icon(icon, color: AppTheme.textSecondary, size: 14),
    );
  }

  Future<void> _resumePlayback(Map<String, dynamic> item) async {
    final uniqueId = item['uniqueId'] as String;
    if (_loadingItemId != null) return;
    
    setState(() => _loadingItemId = uniqueId);

    try {
      final method = item['method'] as String;
      final tmdbId = item['tmdbId'] as int;
      final season = item['season'] as int?;
      final episode = item['episode'] as int?;
      final title = item['title'] as String;
      final posterPath = item['posterPath'] as String; 
      final startPos = Duration(milliseconds: item['position'] as int);
      
      // Get saved magnet link and file index for torrents
      final savedMagnetLink = item['magnetLink'] as String?;
      final savedFileIndex = item['fileIndex'] as int?;

      String? streamUrl;
      String? activeProvider;
      String? magnetLink;
      int? fileIndex;
      String? stremioItemId;
      String? stremioAddonBase;

      if (method == 'stremio_direct') {
        // Direct stremio stream — try the saved URL first
        final savedUrl = item['streamUrl'] as String?;
        stremioItemId = item['stremioId'] as String?;
        stremioAddonBase = item['stremioAddonBaseUrl'] as String?;
        activeProvider = 'stremio_direct';

        if (savedUrl != null && savedUrl.isNotEmpty) {
          // Try playing the saved URL directly
          streamUrl = savedUrl;
          debugPrint('[Resume] Trying saved stremio direct URL: $savedUrl');
        }

        // If no saved URL, or if player fails, we'll fall through to the
        // "open details page" fallback below
        if (streamUrl == null && stremioItemId != null && stremioAddonBase != null) {
          // Re-fetch streams from the addon
          debugPrint('[Resume] Re-fetching stremio streams for $stremioItemId from $stremioAddonBase');
          final stremioType = item['stremioType'] as String? ?? (season != null ? 'series' : 'movie');
          final stremio = StremioService();
          try {
            final streams = await stremio.getStreams(
              baseUrl: stremioAddonBase,
              type: stremioType,
              id: stremioItemId,
            );
            if (streams.isNotEmpty) {
              final first = streams.first;
              if (first is Map<String, dynamic> && first['url'] != null) {
                streamUrl = first['url'] as String;
              }
            }
          } catch (e) {
            debugPrint('[Resume] Re-fetch stremio streams failed: $e');
          }
        }

        // If we still have nothing, open the details page
        if (streamUrl == null) {
          if (mounted) {
            final mediaType = item['mediaType'] as String? ?? (season != null ? 'tv' : 'movie');
            final movie = Movie(
              id: tmdbId,
              title: title,
              posterPath: posterPath,
              backdropPath: '',
              overview: '',
              releaseDate: '',
              voteAverage: 0,
              mediaType: mediaType,
              genres: [],
              imdbId: item['imdbId'],
            );
            Map<String, dynamic>? stremioItem;
            if (stremioItemId != null) {
              stremioItem = {
                'id': stremioItemId,
                '_addonBaseUrl': stremioAddonBase ?? '',
                'type': item['stremioType'] ?? (season != null ? 'series' : 'movie'),
                'name': title,
              };
            }
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => DetailsScreen(
                movie: movie,
                stremioItem: stremioItem,
                initialSeason: season,
                initialEpisode: episode,
                startPosition: startPos,
              ),
            ));
          }
          return; // Skip the player launch below
        }
      } else if (method == 'stream') {
        // Re-extract stream using saved sourceId (tmdbId + season + episode)
        final sourceId = item['sourceId'] as String;
        activeProvider = sourceId;
        
        if (sourceId == 'webstreamr') {
          debugPrint('[Resume] Using WebStreamrService for $title');
          final webStreamr = WebStreamrService();
          final imdbId = item['imdbId']?.toString() ?? '';
          if (imdbId.isNotEmpty) {
            final webStreamrSources = await webStreamr.getStreams(
              imdbId: imdbId,
              isMovie: season == null,
              season: season,
              episode: episode,
            );
            if (webStreamrSources.isNotEmpty) {
              streamUrl = webStreamrSources.first.url;
              if (mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                      streamUrl: streamUrl!,
                      title: title,
                      movie: Movie(
                        id: tmdbId,
                        title: title,
                        posterPath: posterPath,
                        backdropPath: '', 
                        overview: '', 
                        releaseDate: '', 
                        voteAverage: 0, 
                        mediaType: season != null ? 'tv' : 'movie', 
                        genres: [], 
                        imdbId: imdbId,
                      ),
                      selectedSeason: season,
                      selectedEpisode: episode,
                      activeProvider: 'webstreamr',
                      startPosition: startPos,
                      sources: webStreamrSources,
                    ),
                  ),
                );
                return;
              }
            }
          }
        }

        final provider = StreamProviders.providers[sourceId];
        if (provider == null) {
           throw Exception('Provider $sourceId not available');
        }

        debugPrint('[Resume] Re-extracting stream for $title (TMDB: $tmdbId, S:$season, E:$episode)');
        final url = season != null && episode != null
            ? provider['tv'](tmdbId, season, episode)
            : provider['movie'](tmdbId);
        
        final extractor = StreamExtractor();
        final result = await extractor.extract(url, timeout: const Duration(seconds: 20));
        streamUrl = result?.url;
      } else if (method == 'torrent') {
        // Use saved magnet link - NEVER re-search
        magnetLink = savedMagnetLink;
        fileIndex = savedFileIndex;
        
        if (magnetLink == null || magnetLink.isEmpty) {
          throw Exception('No magnet link saved for this torrent');
        }
        
        debugPrint('[Resume] Using saved magnet link: ${magnetLink.substring(0, 60)}...');
        debugPrint('[Resume] Using saved file index: $fileIndex');

        // Check Debrid Preference
        final useDebridSetting = await SettingsService().useDebridForStreams();
        final debridService = await SettingsService().getDebridService();
        final useDebrid = useDebridSetting && debridService != 'None';

        if (useDebrid) {
          debugPrint('[Resume] Using debrid service: $debridService');
          if (debridService == 'Real-Debrid') {
             final files = await DebridApi().resolveRealDebrid(magnetLink);
             if (fileIndex != null && fileIndex < files.length) {
               // Use saved file index
               streamUrl = files[fileIndex].downloadUrl;
               debugPrint('[Resume] Using file at index $fileIndex: ${files[fileIndex].filename}');
             } else {
               // Fallback to largest file
               files.sort((a, b) => b.filesize.compareTo(a.filesize));
               if (files.isNotEmpty) streamUrl = files.first.downloadUrl;
             }
          } else if (debridService == 'TorBox') {
             final files = await DebridApi().resolveTorBox(magnetLink);
             if (fileIndex != null && fileIndex < files.length) {
               streamUrl = files[fileIndex].downloadUrl;
               debugPrint('[Resume] Using file at index $fileIndex: ${files[fileIndex].filename}');
             } else {
               files.sort((a, b) => b.filesize.compareTo(a.filesize));
               if (files.isNotEmpty) streamUrl = files.first.downloadUrl;
             }
          } else {
             throw Exception('No Debrid service configured');
          }
        } else {
          // Local Torrent Engine
          debugPrint('[Resume] Using local torrent engine');
          streamUrl = await TorrentStreamService().streamTorrent(magnetLink, season: season, episode: episode, fileIdx: fileIndex);
        }
      } else if (method == 'trakt_import') {
        // Trakt-imported items have no stream source — find one automatically
        if (context.mounted) {
          final mediaType = item['mediaType'] as String? ?? (season != null ? 'tv' : 'movie');
          final movie = Movie(
            id: tmdbId,
            title: title,
            posterPath: posterPath,
            backdropPath: '',
            overview: '',
            releaseDate: '',
            voteAverage: 0,
            mediaType: mediaType,
            genres: [],
            imdbId: item['imdbId'],
          );
          final navigator = Navigator.of(context);
          final isStreaming = await SettingsService().isStreamingModeEnabled();
          navigator.push(MaterialPageRoute(
            builder: (_) => isStreaming
                ? StreamingDetailsScreen(
                    movie: movie,
                    initialSeason: season,
                    initialEpisode: episode,
                    startPosition: startPos,
                  )
                : DetailsScreen(
                    movie: movie,
                    initialSeason: season,
                    initialEpisode: episode,
                    startPosition: startPos,
                  ),
          ));
        }
        return;
      }

      if (streamUrl != null && mounted) {
        // Launch Player
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              streamUrl: streamUrl!,
              title: title,
              movie: Movie(
                id: tmdbId,
                title: title,
                posterPath: posterPath,
                backdropPath: '', 
                overview: '', 
                releaseDate: '', 
                voteAverage: 0, 
                mediaType: season != null ? 'tv' : 'movie', 
                genres: [], 
                imdbId: item['imdbId'],
              ),
              selectedSeason: season,
              selectedEpisode: episode,
              magnetLink: magnetLink,
              fileIndex: fileIndex, // Pass file index to player
              activeProvider: activeProvider,
              startPosition: startPos,
              stremioId: stremioItemId,
              stremioAddonBaseUrl: stremioAddonBase,
            ),
          ),
        );
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load video')));
      }
    } catch (e) {
      debugPrint('[Resume] Error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingItemId = null);
    }
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    await WatchHistoryService().removeItem(item['uniqueId']);

    // Also remove from Trakt playback progress if logged in
    final tmdbId = item['tmdbId'] as int?;
    if (tmdbId != null) {
      final mediaType = item['mediaType']?.toString() ?? 'movie';
      final season = item['season'] as int?;
      final episode = item['episode'] as int?;
      await TraktService().removePlaybackProgress(
        tmdbId: tmdbId,
        mediaType: mediaType,
        season: season,
        episode: episode,
      );
    }
  }

  /// Opens the details page for a history item based on streaming mode and item type
  Future<void> _openHistoryItemDetails(Map<String, dynamic> item) async {
    final tmdbId = item['tmdbId'] as int;
    final title = item['title'] as String;
    final posterPath = item['posterPath'] as String;
    final season = item['season'] as int?;
    final episode = item['episode'] as int?;
    final mediaType = item['mediaType'] as String? ?? (season != null ? 'tv' : 'movie');
    
    final movie = Movie(
      id: tmdbId,
      title: title,
      posterPath: posterPath,
      backdropPath: '',
      overview: '',
      releaseDate: '',
      voteAverage: 0,
      mediaType: mediaType,
      genres: [],
      imdbId: item['imdbId'],
    );

    final isStreamingMode = await SettingsService().isStreamingModeEnabled();
    
    // Determine which screen to open based on streaming mode and item type
    if (isStreamingMode) {
      // Streaming mode ON -> always open StreamingDetailsScreen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StreamingDetailsScreen(
              movie: movie,
              initialSeason: season,
              initialEpisode: episode,
            ),
          ),
        );
      }
    } else {
      // Streaming mode OFF
      // Check if it's a Stremio addon with custom ID
      final stremioItemId = item['stremioId'] as String?;
      final stremioAddonBase = item['stremioAddonBaseUrl'] as String?;
      final isCustomId = stremioItemId != null && 
                         stremioAddonBase != null && 
                         !stremioItemId.startsWith('tt');
      
      if (isCustomId) {
        // Stremio addon with custom ID -> open DetailsScreen (torrent mode)
        Map<String, dynamic>? stremioItem = {
          'id': stremioItemId,
          '_addonBaseUrl': stremioAddonBase,
          'type': item['stremioType'] ?? (season != null ? 'series' : 'movie'),
          'name': title,
        };
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailsScreen(
                movie: movie,
                stremioItem: stremioItem,
                initialSeason: season,
                initialEpisode: episode,
              ),
            ),
          );
        }
      } else {
        // Regular content -> open DetailsScreen (torrent mode)
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailsScreen(
                movie: movie,
                initialSeason: season,
                initialEpisode: episode,
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: WatchHistoryService().historyStream,
      initialData: WatchHistoryService().current,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        // Deduplicate by tmdbId for shows — keep only the latest episode per show
        final raw = snapshot.data!;
        final seen = <dynamic>{};
        final history = <Map<String, dynamic>>[];
        for (final item in raw) {
          final key = (item['mediaType'] == 'tv' || item['season'] != null)
              ? item['tmdbId']
              : item['uniqueId'];
          if (seen.add(key)) history.add(item);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.current.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.play_circle_outline_rounded, color: AppTheme.current.primaryColor, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Continue Watching',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: scaledFontSize(context, 20),
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 3,
                          width: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.current.primaryColor,
                                AppTheme.current.primaryColor.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (history.isNotEmpty) ...[
                    GestureDetector(
                      onTap: _scrollLeft,
                      child: _buildCWSectionArrow(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _scrollRight,
                      child: _buildCWSectionArrow(Icons.arrow_forward_ios_rounded),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).orientation == Orientation.landscape ? 140 : 175,
              child: ListView.separated(
                clipBehavior: Clip.none,
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: history.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final historyItem = history[index];
                  final itemId = historyItem['uniqueId'] as String;
                  return HistoryCard(
                    item: historyItem,
                    onTap: () => _resumePlayback(historyItem),
                    onRemove: () => _removeItem(historyItem),
                    onInfo: () => _openHistoryItemDetails(historyItem),
                    isLoading: _loadingItemId == itemId,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

Widget _buildCWPlayButton() {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.current.primaryColor.withValues(alpha: 0.8),
      shape: BoxShape.circle,
      border: Border.all(color: AppTheme.border),
    ),
    child: Icon(Icons.play_arrow_rounded, color: AppTheme.textPrimary, size: 28),
  );
}

class HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onInfo;
  final bool isLoading;

  const HistoryCard({super.key, 
    required this.item,
    required this.onTap,
    required this.onRemove,
    required this.onInfo,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final posterPath = item['posterPath'] as String;
    final title = item['title'] as String;
    final season = item['season'] as int?;
    final episode = item['episode'] as int?;
    final episodeTitle = item['episodeTitle'] as String?;
    final position = item['position'] as int;
    final duration = item['duration'] as int;
    
    final progress = duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
    final remaining = duration > 0 ? Duration(milliseconds: duration - position) : Duration.zero;
    final remainingText = remaining.inMinutes > 0 ? '${remaining.inMinutes}m left' : '';
    final imageUrl = posterPath.isNotEmpty
        ? (posterPath.startsWith('http') ? posterPath : TmdbApi.getImageUrl(posterPath))
        : '';
    
    final subtitle = season != null 
        ? 'S$season E$episode${episodeTitle != null && episodeTitle.isNotEmpty ? ' • $episodeTitle' : ''}'
        : '';

    return FocusableControl(
      onTap: isLoading ? () {} : onTap,
      borderRadius: AppRadius.lg,
      scaleOnFocus: 1.05,
      child: Container(
        width: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppTheme.border, width: 0.5),
          boxShadow: AppTheme.isLightMode ? null : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6)),
            BoxShadow(color: AppTheme.current.primaryColor.withValues(alpha: 0.06), blurRadius: 24, spreadRadius: -4),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full bleed poster image
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppTheme.surfaceContainer),
              )
            else
              Container(color: AppTheme.surfaceContainer, child: Icon(Icons.movie, color: AppTheme.textDisabled, size: 40)),
            
            // Dark overlay gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.bgDark.withValues(alpha: 0.1),
                    AppTheme.bgDark.withValues(alpha: 0.3),
                    AppTheme.bgDark.withValues(alpha: 0.85),
                    AppTheme.bgDark.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),

            // Play button (center)
            Center(
              child: _buildCWPlayButton(),
            ),

            // Top-left: progress percentage badge
            if (progress > 0)
              Positioned(
                top: 6, left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      color: progress > 0.9
                          ? Colors.greenAccent
                          : AppTheme.current.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            // Top-right actions
            Positioned(
              top: 6, right: 6,
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: AppTheme.overlay.withValues(alpha: 0.5), shape: BoxShape.circle),
                        child: Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onInfo,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: AppTheme.overlay.withValues(alpha: 0.5), shape: BoxShape.circle),
                        child: Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom content: title + episode + progress
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ),
                        if (remainingText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              remainingText,
                              style: TextStyle(color: AppTheme.current.primaryColor.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Progress bar
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg)),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      color: progress > 0.9
                          ? Colors.greenAccent
                          : AppTheme.current.primaryColor,
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            
            if (isLoading)
               Container(
                 decoration: BoxDecoration(
                   color: AppTheme.bgDark.withValues(alpha: 0.6),
                   borderRadius: BorderRadius.circular(AppRadius.lg),
                 ),
                 child: Center(child: CircularProgressIndicator(color: AppTheme.current.primaryColor)),
               ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
