part of '../details_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  DATA FETCH METHODS
// ═══════════════════════════════════════════════════════════════════════════════

mixin DetailsFetchMethods on _DetailsScreenBase {

@override
Future<void> _fetchDetails() async {
  final stremioItem = widget.stremioItem;
  final bool isCustomId =
      stremioItem != null &&
      !(stremioItem['id']?.toString().startsWith('tt') ?? true);

  try {
    final streamAddons = await _stremio.getAddonsForResource('stream');

    // If this is a custom-ID Stremio item, skip TMDB fetch — we already
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

@override
Future<void> _fetchCastMembers() async {
  try {
    final members = await _api.getCredits(_movie.id, _movie.mediaType);
    if (mounted) setState(() => _castMembers = members);
  } catch (_) {}
}

@override
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

// ─── Trakt rating ─────────────────────────────────────────────────────────────

@override
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

@override
Future<void> _rateTraktItem(int rating) async {
  final success = await TraktService().rateItem(
    tmdbId: _movie.id,
    mediaType: _movie.mediaType,
    rating: rating,
  );
  if (success && mounted) setState(() => _userTraktRating = rating);
}

@override
Future<void> _removeTraktRating() async {
  final success = await TraktService().removeRating(
    tmdbId: _movie.id,
    mediaType: _movie.mediaType,
  );
  if (success && mounted) setState(() => _userTraktRating = null);
}

// ─── Simkl rating ──────────────────────────────────────────────────────────────

@override
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

// ─── Trakt collection ──────────────────────────────────────────────────────────

@override
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

@override
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

// ─── Trakt check-in ────────────────────────────────────────────────────────────

@override
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

// ─── Trakt add to list ─────────────────────────────────────────────────────────

@override
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

@override
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

// ═══════════════════════════════════════════════════════════════════════════════
//  RECOMMENDATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Fetches recommendations by getting meta from Stremio addons and
/// collecting meta.links (stremio:///detail/...) items.
@override
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

@override
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

@override
Future<void> _openCollectionItem(String id) async {
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

