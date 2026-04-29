part of '../details_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  MOBILE LAYOUT
// ═══════════════════════════════════════════════════════════════════════════════

mixin DetailsUiLayouts on _DetailsScreenBase {

@override
Widget _buildMobileLayout() {
  return SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernDetailsHero(
          movie: _movie,
          genreChips: _movie.genres.take(3).map(_genreChip).toList(),
          ratingsRow: (_mdblistRatings != null || _userTraktRating != null || _userSimklRating != null) 
              ? _buildRatingsRow() 
              : null,
          actionButtons: _buildActionButtons(),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Synopsis
              ExpandableSynopsis(text: _movie.overview),
              const SizedBox(height: 32),
              // Collection items
              if (_isCollection && _collectionItems.isNotEmpty) ...[
                CollectionItemsSection(
                  items: _collectionItems,
                  onItemTap: _openCollectionItem,
                ),
                const SizedBox(height: 24),
              ],
              // Cast section
              Builder(
                builder: (ctx) {
                  final cast = _getCastNames();
                  if (cast.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Cast'),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: cast.length > 8 ? 8 : cast.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (ctx, i) => _castChip(cast[i]),
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
              // TV show sections
              if (_movie.mediaType == 'tv' && !_isCollection) ...[
                const SizedBox(height: 24),
                _buildSeasonSelector(),
                const SizedBox(height: 16),
                _buildEpisodeSelector(),
                const SizedBox(height: 24),
              ],
              // Stream sources
              if (!_isCollection) ...[
                _buildSourceToggle(),
                const SizedBox(height: 12),
                _buildSourceChips(),
                const SizedBox(height: 20),
                _buildResultsHeader(),
                const SizedBox(height: 12),
                _buildStreamList(),
              ],
              const SizedBox(height: 60),
            ],
          ),
        ),
      ],
    ),
  );
}

// Remove _buildSectionCard - no longer needed

@override
Widget _buildMobileHero() {
  return Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      MediaQuery.of(context).padding.top + 16,
      16,
      16,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact poster
        Hero(
          tag: 'movie-poster-${_movie.id}',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: [
                AppShadows.strong,
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: CachedNetworkImage(
                imageUrl: _imageUrl(_movie.posterPath),
                width: 100,
                height: 150,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                errorWidget: (context, url, error) => Container(
                  width: 100,
                  height: 150,
                  color: AppTheme.surfaceContainerHigh,
                  child: const Icon(
                    Icons.broken_image,
                    size: 28,
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
        const SizedBox(width: 16),
        // Title + meta info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _movie.title,
                style: TextStyle(
                  fontSize: scaledFontSize(context, 20),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  height: 1.2,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.current.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _movie.releaseDate.take(4),
                      style: TextStyle(
                        color: AppTheme.current.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          _movie.voteAverage.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  DESKTOP LAYOUT
// ═══════════════════════════════════════════════════════════════════════════════

@override
 Widget _buildDesktopLayout() {
  return SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernDetailsHero(
          movie: _movie,
          genreChips: _movie.genres.take(5).map(_genreChip).toList(),
          ratingsRow: (_mdblistRatings != null || _userTraktRating != null || _userSimklRating != null) 
              ? _buildRatingsRow() 
              : null,
          actionButtons: _buildActionButtons(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Overview'),
                    const SizedBox(height: 16),
                    ExpandableSynopsis(text: _movie.overview),
                    const SizedBox(height: 40),
                    if (_castMembers.isNotEmpty) ...[
                      _sectionLabel('Cast'),
                      const SizedBox(height: 16),
                      DesktopCastRow(
                        castMembers: _castMembers,
                        scrollController: _castScrollController,
                      ),
                      const SizedBox(height: 40),
                    ],
                    RecommendationsSection(
                      recommendations: _stremioRecommendations,
                      isLoading: _isLoadingRecommendations,
                      scrollController: _recommendationsScrollController,
                      onItemTap: _openRecommendation,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                flex: 3,
                child: _buildRightPanel(),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

@override
Widget _buildDesktopLeftPanel() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Poster with glow shadow
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'movie-poster-${_movie.id}',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: [
                  AppShadows.strong,
                  AppShadows.glow(0.08),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: CachedNetworkImage(
                  imageUrl: _imageUrl(_movie.posterPath),
                  width: 240,
                  height: 350,
                  fit: BoxFit.cover,
                  memCacheWidth: 480,
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
      // Title
      Text(
        _movie.title,
        style: TextStyle(
          fontSize: scaledFontSize(context, 32),
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
          height: 1.1,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 12),
      // Year + rating badges
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.current.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _movie.releaseDate.take(4),
              style: TextStyle(
                color: AppTheme.current.primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
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
          ),
        ],
      ),
      const SizedBox(height: 16),
      // Genre chips
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _movie.genres.take(3).map(_genreChip).toList(),
      ),
      const SizedBox(height: 20),
      // Ratings
      if (_mdblistRatings != null ||
          _userTraktRating != null ||
          _userSimklRating != null) ...[
        _buildRatingsRow(),
        const SizedBox(height: 20),
      ],
      // Action buttons
      _buildActionButtons(),
      const SizedBox(height: 24),
      // Synopsis
      ExpandableSynopsis(text: _movie.overview),
      const SizedBox(height: 24),
      // Collection items
      if (_isCollection && _collectionItems.isNotEmpty) ...[
        CollectionItemsSection(
          items: _collectionItems,
          onItemTap: _openCollectionItem,
        ),
        const SizedBox(height: 24),
      ],
      // Cast section
      if (_castMembers.isNotEmpty) ...[
        _sectionLabel('Cast'),
        const SizedBox(height: 12),
        DesktopCastRow(
          castMembers: _castMembers,
          scrollController: _castScrollController,
        ),
        const SizedBox(height: 16),
      ],
      RecommendationsSection(
        recommendations: _stremioRecommendations,
        isLoading: _isLoadingRecommendations,
        scrollController: _recommendationsScrollController,
        onItemTap: _openRecommendation,
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  RIGHT PANEL
// ═══════════════════════════════════════════════════════════════════════════════

@override
Widget _buildRightPanel() {
  // For collections, don't show stream/torrent sections
  if (_isCollection) {
    return Row(
      children: [
        Icon(Icons.info_outline_rounded, color: AppTheme.textDisabled, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'This is a collection. Select an item from the list to view details and streams.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // TV episodes section
      if (_movie.mediaType == 'tv') ...[
        _buildSeasonSelector(),
        const SizedBox(height: 16),
        _buildEpisodeSelector(),
        const SizedBox(height: 24),
      ],
      // Streams section
      _buildSourceToggle(),
      const SizedBox(height: 12),
      _buildSourceChips(),
      const SizedBox(height: 20),
      _buildResultsHeader(),
      const SizedBox(height: 12),
      _buildStreamList(),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TV LAYOUT — leanback-style, larger poster, bigger fonts, D-pad friendly
// ═══════════════════════════════════════════════════════════════════════════════

@override
Widget _buildTvLayout() {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Left panel — poster + info
      SizedBox(
        width: 550,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(48, 24, 32, 48),
          child: _buildTvLeftPanel(),
        ),
      ),
      Container(width: 0.5, color: AppTheme.borderStrong.withValues(alpha: 0.15)),
      // Right panel — episodes + streams
      Expanded(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(48, 24, 48, 48),
          child: _buildTvRightPanel(),
        ),
      ),
    ],
  );
}

Widget _buildTvLeftPanel() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Poster with glow — larger for TV (300x440)
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'movie-poster-${_movie.id}',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: [
                  AppShadows.strong,
                  AppShadows.glow(0.08),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: CachedNetworkImage(
                  imageUrl: _imageUrl(_movie.posterPath),
                  width: 300,
                  height: 440,
                  fit: BoxFit.cover,
                  memCacheWidth: 600,
                  errorWidget: (context, url, error) => Container(
                    width: 300,
                    height: 440,
                    color: AppTheme.surfaceContainerHigh,
                    child: const Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 32),
          // Title + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  _movie.title,
                  style: TextStyle(
                    fontSize: scaledFontSize(context, 28),
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                // Year + runtime + rating
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (_movie.releaseDate.isNotEmpty)
                      Text(
                        _movie.releaseDate.substring(0, 4),
                        style: TextStyle(
                          fontSize: scaledFontSize(context, 16),
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    if (_movie.runtime > 0)
                      Text(
                        '${_movie.runtime} min',
                        style: TextStyle(
                          fontSize: scaledFontSize(context, 16),
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: Colors.amber.shade400, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          _movie.voteAverage.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: scaledFontSize(context, 16),
                            color: Colors.amber.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Genre chips
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: _movie.genres.take(5).map(_genreChip).toList(),
                ),
                const SizedBox(height: 16),
                // Ratings row
                if (_mdblistRatings != null ||
                    _userTraktRating != null ||
                    _userSimklRating != null) ...[
                  _buildRatingsRow(),
                  const SizedBox(height: 16),
                ],
                // Action buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      // Synopsis
      ExpandableSynopsis(text: _movie.overview),
      const SizedBox(height: 24),
      // Cast section
      Builder(
        builder: (ctx) {
          final cast = _getCastNames();
          if (cast.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Cast'),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cast.length > 10 ? 10 : cast.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) => _castChip(cast[i]),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
      // Collection items
      if (_isCollection && _collectionItems.isNotEmpty) ...[
        CollectionItemsSection(
          items: _collectionItems,
          onItemTap: _openCollectionItem,
        ),
        const SizedBox(height: 24),
      ],
      // Recommendations
      RecommendationsSection(
        recommendations: _stremioRecommendations,
        isLoading: _isLoadingRecommendations,
        scrollController: _recommendationsScrollController,
        onItemTap: _openRecommendation,
      ),
    ],
  );
}

Widget _buildTvRightPanel() {
  if (_isCollection) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection',
          style: TextStyle(
            fontSize: scaledFontSize(context, 22),
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'This is a collection. Select an item from the list to view details and streams.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ),
      ],
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // TV episodes section
      if (_movie.mediaType == 'tv') ...[
        _buildSeasonSelector(),
        const SizedBox(height: 16),
        _buildEpisodeSelector(),
        const SizedBox(height: 24),
      ],
      // Streams section
      _buildSourceToggle(),
      const SizedBox(height: 12),
      _buildSourceChips(),
      const SizedBox(height: 20),
      _buildResultsHeader(),
      const SizedBox(height: 12),
      _buildStreamList(),
    ],
  );
}

}
