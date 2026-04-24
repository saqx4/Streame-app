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
                  '← → Episodes  |  ↑ ↓ Season',
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

@override
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
            memCacheWidth: 800,
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
                      memCacheWidth: 200,
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
                        fontSize: scaledFontSize(context, 24),
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

// ═══════════════════════════════════════════════════════════════════════════════
//  DESKTOP LAYOUT
// ═══════════════════════════════════════════════════════════════════════════════

@override
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

@override
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
      Row(
        children: [
          Text(
            _movie.releaseDate.take(4),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(width: 12),
          Text('·', style: TextStyle(color: AppTheme.textDisabled)),
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

// ═══════════════════════════════════════════════════════════════════════════════
//  RIGHT PANEL
// ═══════════════════════════════════════════════════════════════════════════════

@override
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
        const SizedBox(height: 20),
        _buildEpisodeSelector(),
        const SizedBox(height: 8),
        Text(
          '← → Navigate Episodes  |  ↑ ↓ Change Season',
          style: TextStyle(color: AppTheme.textDisabled, fontSize: 11),
        ),
        const SizedBox(height: 24),
      ],
      _buildSourceToggle(),
      const SizedBox(height: 14),
      _buildSourceChips(),
      const SizedBox(height: 20),
      _buildResultsHeader(),
      const SizedBox(height: 12),
      _buildStreamList(),
    ],
  );
}

}
