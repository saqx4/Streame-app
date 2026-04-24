part of '../details_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  SEASON SELECTOR
// ═══════════════════════════════════════════════════════════════════════════════

mixin DetailsUiStreams on _DetailsScreenBase {

@override
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
              const SizedBox(width: 6),
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
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                ),
              ),
              _scrollArrow(
                Icons.arrow_forward_ios_rounded,
                () => _seasonScrollController.animateTo(
                  _seasonScrollController.offset + 160,
                  duration: const Duration(milliseconds: 280),
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

// ═══════════════════════════════════════════════════════════════════════════════
//  EPISODE SELECTOR
// ═══════════════════════════════════════════════════════════════════════════════

@override
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
          separatorBuilder: (_, _) => const SizedBox(width: 16),
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
                            memCacheWidth: 600,
                            placeholder: (_, _) =>
                                Container(color: AppTheme.bgCard),
                            errorWidget: (_, _, _) =>
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

// ═══════════════════════════════════════════════════════════════════════════════
//  SOURCE TOGGLE + CHIPS
// ═══════════════════════════════════════════════════════════════════════════════

@override
bool get _isTorrentSource =>
    _selectedSourceId == 'streame' ||
    _selectedSourceId == 'jackett' ||
    _selectedSourceId == 'prowlarr';

@override
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
              if (_allCombinedStremioStreams.isEmpty) {
                _fetchAllStremioStreams();
              }
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

@override
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

@override
Widget _buildSourceChips() {
  final isTorrent = _isTorrentSource;
  final chips = <Map<String, dynamic>>[];
  if (isTorrent) {
    chips.add({'id': 'streame', 'label': 'Streame'});
    if (_isJackettConfigured) {
      chips.add({'id': 'jackett', 'label': '🔍 Jackett'});
    }
    if (_isProwlarrConfigured) {
      chips.add({'id': 'prowlarr', 'label': '🔍 Prowlarr'});
    }
    for (final a in _streamAddons) {
      if (a['type'] == 'torrent') {
        chips.add({'id': a['baseUrl'], 'label': a['name']});
      }
    }
  } else {
    // "All" chip shows combined streams from every addon
    if (_streamAddons.length > 1) {
      chips.add({'id': 'all_stremio', 'label': '⚡ All'});
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

// ═══════════════════════════════════════════════════════════════════════════════
//  RESULTS HEADER
// ═══════════════════════════════════════════════════════════════════════════════

@override
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
          '— $epLabel',
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

@override
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

// ═══════════════════════════════════════════════════════════════════════════════
//  STREAM LIST
// ═══════════════════════════════════════════════════════════════════════════════

@override
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

}
