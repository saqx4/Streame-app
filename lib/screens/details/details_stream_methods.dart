part of '../details_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  AUDIO FILTER + SORT HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

const List<String> _kAudioTags = [
  'Atmos',
  '5.1',
  '7.1',
  'AAC',
  'AC3',
  'DTS',
  'DTS-HD',
  'DTS-X',
  'Dolby',
  'TrueHD',
  'FLAC',
  'Opus',
  'Dual',
  'Dubbed',
];

mixin DetailsStreamMethods on _DetailsScreenBase {

@override
List<String> _detectAudioTags(String title) {
  final t = title.toUpperCase();
  return _kAudioTags.where((tag) => t.contains(tag)).toList();
}

@override
List<TorrentResult> get _filteredTorrentResults {
  if (_activeAudioFilters.isEmpty) return _allTorrentResults;
  return _allTorrentResults.where((r) {
    final tags = _detectAudioTags(r.name);
    return _activeAudioFilters.any((f) => tags.contains(f));
  }).toList();
}

@override
Future<void> _checkIndexerConfiguration() async {
  final jConfigured = await _settings.isJackettConfigured();
  final pConfigured = await _settings.isProwlarrConfigured();
  if (mounted) {
    setState(() {
      _isJackettConfigured = jConfigured;
      _isProwlarrConfigured = pConfigured;
    });
  }
}

@override
String _getHash(String magnetOrUrl) {
  final m = RegExp(r'btih:([a-fA-F0-9]{40})').firstMatch(magnetOrUrl);
  if (m != null) return m[1]!.toLowerCase();
  final m2 = RegExp(r'btih:([A-Za-z2-7]{32})').firstMatch(magnetOrUrl);
  if (m2 != null) return m2[1]!.toLowerCase();
  return magnetOrUrl.toLowerCase();
}

@override
Future<void> _sortResults() async {
  final sorted = await TorrentFilter.sortTorrentsAsync(
    _allTorrentResults,
    _sortPreference,
  );
  if (mounted) {
    setState(() => _allTorrentResults = sorted);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SEASON / EPISODE FETCH
// ═══════════════════════════════════════════════════════════════════════════════

@override
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

@override
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

// ═══════════════════════════════════════════════════════════════════════════════
//  STREMIO STREAM FETCH
// ═══════════════════════════════════════════════════════════════════════════════

/// Fetches streams from ALL installed stream addons in parallel,
/// updating the UI incrementally as each addon responds.
@override
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
    if (_movie.mediaType == 'tv') {
      stremioId = '$stremioId:$_selectedSeason:$_selectedEpisode';
    }
    final type = _movie.mediaType == 'tv' ? 'series' : 'movie';

    int pendingCount = _streamAddons.length;

    for (final addon in _streamAddons) {
      // Fire each addon fetch independently — don't await here
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
    if (mounted) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isStremioFetching = false;
      });
    }
  }
}

/// Fetches streams using the custom Stremio ID from the originating addon.
@override
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
    if (streams.isNotEmpty) {
      debugPrint('[CustomIdStreams] First stream: ${streams.first}');
    }
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
    if (mounted) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isStremioFetching = false;
        _loadedAddonBaseUrls.add(addonBaseUrl);
      });
    }
  }
}

/// Parses the videos array from custom ID meta to build season/episode structure
@override
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
@override
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
@override
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
@override
Future<void> _fetchStremioStreams() async {
  if (_selectedSourceId == 'all_stremio') {
    // "All" chip → just re-filter from cached results, or re-fetch if empty
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
    if (_movie.mediaType == 'tv') {
      stremioId = '$stremioId:$_selectedSeason:$_selectedEpisode';
    }
    final type = _movie.mediaType == 'tv' ? 'series' : 'movie';
    final streams = await _stremio.getStreams(
      baseUrl: addon['baseUrl'],
      type: type,
      id: stremioId,
    );
    if (mounted) {
      setState(() {
        _stremioStreams = streams;
        if (streams.isEmpty) {
          _errorMessage = 'No streams found in ${addon['name']}';
        }
      });
    }
  } catch (e) {
    if (mounted) setState(() => _errorMessage = 'Error: $e');
  } finally {
    if (mounted) setState(() => _isStremioFetching = false);
  }
}

/// Applies the current addon filter chip to _allCombinedStremioStreams.
@override
void _applyStremioFilter() {
  if (_selectedSourceId == 'all_stremio' || _isTorrentSource) {
    _stremioStreams = _allCombinedStremioStreams;
  } else {
    _stremioStreams = _allCombinedStremioStreams
        .where((s) => s['_addonBaseUrl'] == _selectedSourceId)
        .toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TORRENT SEARCH (Streame / Jackett / Prowlarr)
// ═══════════════════════════════════════════════════════════════════════════════

@override
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
    if (mounted) {
      setState(() {
        _errorMessage = e.toString();
        _isSearching = false;
      });
    }
  }
}

@override
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
    if (mounted) {
      setState(() {
        _errorMessage = e.toString();
        _isSearching = false;
      });
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Jackett Search
// ═══════════════════════════════════════════════════════════════════════════════

@override
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

    if (baseUrl == null || apiKey == null) {
      throw Exception('Jackett configuration missing');
    }

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
    if (mounted) {
      setState(() {
        _errorMessage = e.toString();
        _isSearching = false;
      });
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Prowlarr Search
// ═══════════════════════════════════════════════════════════════════════════════

@override
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

    if (baseUrl == null || apiKey == null) {
      throw Exception('Prowlarr configuration missing');
    }

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
    if (mounted) {
      setState(() {
        _errorMessage = e.toString();
        _isSearching = false;
      });
    }
  }
}

// ─── safe field helpers ────────────────────────────────────────────────────────

@override
List<String> _getCastNames() {
  try {
    final dynamic m = _movie;
    final dynamic raw = m.castNames ?? m.cast ?? m.credits;
    if (raw is List) return raw.map((e) => e.toString()).toList();
  } catch (_) {}
  return [];
}

@override
String _getTrackerName(TorrentResult result) {
  try {
    final dynamic r = result;
    final dynamic raw = r.source ?? r.tracker ?? r.provider ?? r.site;
    if (raw is String) return raw;
  } catch (_) {}
  return '';
}

}
