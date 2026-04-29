import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:streame_core/api/tmdb_api.dart';
import 'package:streame_core/models/movie.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'package:streame_core/widgets/my_list_button.dart';

class MovieSection extends StatefulWidget {
  final String title;
  final IconData? icon;
  final Future<List<Movie>> future;
  final Function(Movie) onMovieTap;
  final bool isPortrait;
  final bool showRank;
  final bool isTv;

  const MovieSection({super.key,
    required this.title,
    this.icon,
    required this.future,
    required this.onMovieTap,
    this.isPortrait = false,
    this.showRank = false,
    this.isTv = false,
  });

  @override
  State<MovieSection> createState() => _MovieSectionState();
}

class _MovieSectionState extends State<MovieSection> {
  final ScrollController _scrollController = ScrollController();

  void _scrollLeft() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        (_scrollController.offset - 600).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollRight() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        (_scrollController.offset + 600).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildGlassArrow(IconData icon) {
    return _GlassArrowButton(icon: icon, onTap: icon == Icons.arrow_back_ios_new_rounded ? _scrollLeft : _scrollRight);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = widget.isTv ? 32.0 : 24.0;
    final sectionSpacing = widget.isTv ? 48.0 : 32.0;
    final itemSpacing = widget.isTv ? 20.0 : 14.0;

    return FutureBuilder<List<Movie>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            final shimmerChild = Padding(
                padding: EdgeInsets.only(top: sectionSpacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Container(height: 18, width: 140, decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(AppRadius.sm))),
                    ),
                    SizedBox(height: widget.isTv ? 24 : 16),
                    SizedBox(
                      height: widget.isPortrait ? 240 : 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        itemCount: 5,
                        separatorBuilder: (_, __) => SizedBox(width: itemSpacing),
                        itemBuilder: (_, __) => Container(
                          width: widget.isPortrait ? 150 : 280,
                          decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(AppRadius.card)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            if (AppTheme.isLightMode) return shimmerChild;
            return Shimmer.fromColors(
              baseColor: AppTheme.shimmerBase,
              highlightColor: AppTheme.shimmerHighlight,
              child: shimmerChild,
            );
          }
          return const SizedBox.shrink();
        }
        final movies = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, sectionSpacing, horizontalPadding, 18),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.current.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppTheme.current.primaryColor.withValues(alpha: 0.15), width: 0.5),
                      ),
                      child: Icon(widget.icon, color: AppTheme.current.primaryColor, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
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
                  _buildGlassArrow(Icons.arrow_back_ios_new_rounded),
                  const SizedBox(width: 6),
                  _buildGlassArrow(Icons.arrow_forward_ios_rounded),
                ],
              ),
            ),
            SizedBox(
              height: widget.isPortrait ? 260 : 190,
              child: ListView.separated(
                clipBehavior: Clip.none,
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                itemCount: movies.length,
                separatorBuilder: (_, __) => SizedBox(width: widget.showRank ? 6 : itemSpacing),
                itemBuilder: (context, index) => MovieCard(
                  movie: movies[index],
                  onTap: () => widget.onMovieTap(movies[index]),
                  isPortrait: widget.isPortrait,
                  rank: widget.showRank ? index + 1 : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class StaticMovieSection extends StatefulWidget {
  final String title;
  final IconData? icon;
  final List<Movie> movies;
  final Function(Movie) onMovieTap;

  const StaticMovieSection({super.key, 
    required this.title,
    this.icon,
    required this.movies,
    required this.onMovieTap,
  });

  @override
  State<StaticMovieSection> createState() => _StaticMovieSectionState();
}

class _StaticMovieSectionState extends State<StaticMovieSection> {
  final ScrollController _scrollController = ScrollController();

  void _scrollLeft() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.offset - 600,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollRight() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.offset + 600,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildGlassArrow(IconData icon) {
    return _GlassArrowButton(icon: icon, onTap: icon == Icons.arrow_back_ios_new_rounded ? _scrollLeft : _scrollRight);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 18),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.current.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppTheme.current.primaryColor.withValues(alpha: 0.15), width: 0.5),
                  ),
                  child: Icon(widget.icon, color: AppTheme.current.primaryColor, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: TextStyle(color: AppTheme.textPrimary, fontSize: scaledFontSize(context, 20), fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                    const SizedBox(height: 6),
                    Container(
                      height: 3,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [AppTheme.current.primaryColor, AppTheme.current.primaryColor.withValues(alpha: 0.0)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildGlassArrow(Icons.arrow_back_ios_new_rounded),
              const SizedBox(width: 6),
              _buildGlassArrow(Icons.arrow_forward_ios_rounded),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            clipBehavior: Clip.none,
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: widget.movies.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) => MovieCard(
              movie: widget.movies[index],
              onTap: () => widget.onMovieTap(widget.movies[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class MovieCard extends StatefulWidget {
  final Movie movie;
  final bool isPortrait;
  final int? rank;
  final VoidCallback onTap;

  const MovieCard({super.key, 
    required this.movie,
    required this.onTap,
    this.isPortrait = false,
    this.rank,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final primary = AppTheme.current.primaryColor;
    
    final cardWidth = widget.isPortrait 
        ? (isDesktop ? 165.0 : 140.0) 
        : (isDesktop ? 320.0 : 270.0);
        
    final image = widget.isPortrait ? widget.movie.posterPath : widget.movie.backdropPath;
    final imageUrl = image.isNotEmpty ? TmdbApi.getImageUrl(image) : '';
    final hasRank = widget.rank != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Big rank number
        if (hasRank)
          Text(
            '${widget.rank}',
            style: TextStyle(
              fontSize: widget.isPortrait ? 120 : 90,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = AppTheme.textDisabled.withValues(alpha: 0.15),
              height: 0.85,
              letterSpacing: -8,
            ),
          ),
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: FocusableControl(
            onTap: widget.onTap,
            borderRadius: AppRadius.card,
            scaleOnFocus: 1.05,
            child: AnimatedContainer(
              duration: AppDurations.fast,
              curve: AnimationPresets.smoothInOut,
              width: cardWidth,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: _isHovered ? primary.withValues(alpha: 0.5) : AppTheme.border,
                  width: _isHovered ? 1.0 : 0.5,
                ),
                boxShadow: AppTheme.isLightMode ? null : [
                  if (_isHovered) AppShadows.glow(0.15),
                  if (_isHovered) AppShadows.primary(0.1),
                  BoxShadow(color: AppTheme.overlay.withValues(alpha: _isHovered ? 0.4 : 0.2), blurRadius: _isHovered ? 16 : 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl.isNotEmpty)
                    RepaintBoundary(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 640,
                        placeholder: (_, _) => Container(color: AppTheme.surfaceContainer),
                        errorWidget: (_, _, _) => Container(
                          color: AppTheme.surfaceContainer,
                          child: Center(child: Text(widget.movie.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppTheme.textDisabled))),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: AppTheme.surfaceContainer,
                      child: Center(child: Text(widget.movie.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppTheme.textDisabled))),
                    ),
                  
                  // Gradient overlay — stronger on hover
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          AppTheme.bgDark.withValues(alpha: _isHovered ? 0.8 : 0.6),
                          AppTheme.bgDark.withValues(alpha: _isHovered ? 0.98 : 0.9),
                        ],
                        stops: const [0.0, 0.45, 0.8, 1.0],
                      ),
                    ),
                  ),

                  // Play icon on hover
                  if (_isHovered)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary.withValues(alpha: 0.25),
                          border: Border.all(color: primary.withValues(alpha: 0.5), width: 1),
                          boxShadow: [AppShadows.glow(0.2)],
                        ),
                        child: Icon(Icons.play_arrow_rounded, color: AppTheme.textPrimary, size: 24),
                      ),
                    ),
                  
                  // Rating badge (top right) — frosted glass
                  if (widget.movie.voteAverage > 0)
                    Positioned(
                      top: 8, right: 8,
                      child: buildRatingBadge(widget.movie.voteAverage),
                    ),

                  // Bottom content
                  Positioned(
                    bottom: 10, left: 10, right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.movie.title,
                          maxLines: widget.isPortrait ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimary, 
                            fontWeight: FontWeight.w600, 
                            fontSize: isDesktop ? 14 : 13,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (widget.movie.releaseDate.isNotEmpty)
                              Text(
                                widget.movie.releaseDate.split('-').first,
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              ),
                            if (widget.movie.mediaType == 'tv') ...[
                              if (widget.movie.releaseDate.isNotEmpty) ...[
                                Text('  •  ', style: TextStyle(color: AppTheme.textDisabled, fontSize: 11)),
                              ],
                              Text('TV', style: TextStyle(color: primary.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // My List button
                  Positioned(
                    top: 8, left: 8,
                    child: MyListButton.movie(movie: widget.movie),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rating badge for numeric ratings
Widget buildRatingBadge(double voteAverage) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.bgDark.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.2), width: 0.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          voteAverage.toStringAsFixed(1),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
      ],
    ),
  );
}

/// Rating badge for string ratings (Stremio)
Widget buildRatingBadgeText(String rating) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: AppTheme.bgDark.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.2), width: 0.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Colors.amber, size: 11),
        const SizedBox(width: 2),
        Text(rating, style: TextStyle(color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

//  STREMIO ADDON CATALOG SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class StremioCatalogSection extends StatefulWidget {
  final Map<String, dynamic> catalog;
  final List<Map<String, dynamic>> items;
  final Function(Map<String, dynamic>) onItemTap;
  final VoidCallback onShowAll;

  const StremioCatalogSection({super.key, 
    required this.catalog,
    required this.items,
    required this.onItemTap,
    required this.onShowAll,
  });

  @override
  State<StremioCatalogSection> createState() => _StremioCatalogSectionState();
}

class _StremioCatalogSectionState extends State<StremioCatalogSection> {
  final ScrollController _scrollController = ScrollController();

  void _scrollLeft() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.offset - 600,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollRight() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.offset + 600,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _wrapFrosted({required double borderRadius, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: child,
    );
  }

  Widget _buildStremioArrow(IconData icon) {
    return _GlassArrowButton(icon: icon, onTap: icon == Icons.arrow_back_ios_new_rounded ? _scrollLeft : _scrollRight);
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.catalog;
    final addonName = cat['addonName'] as String;
    final catalogName = cat['catalogName'] as String;
    final addonIcon = (cat['addonIcon'] ?? '').toString();
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 14),
          child: Row(
            children: [
              if (addonIcon.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: addonIcon,
                      width: 20, height: 20,
                      memCacheWidth: 40,
                      errorWidget: (_, _, _) => const Icon(Icons.extension, size: 20, color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.extension_rounded, color: AppTheme.primaryColor, size: 18),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalogName,
                      style: TextStyle(color: Colors.white, fontSize: scaledFontSize(context, 20), fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      addonName,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 2.5,
                      width: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.0)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              FocusableControl(
                onTap: widget.onShowAll,
                borderRadius: 20,
                child: _wrapFrosted(
                  borderRadius: 20,
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Show All', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 11, color: Colors.white.withValues(alpha: 0.6)),
                        ],
                      ),
                  ),
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 10),
              ],
              const SizedBox(width: 8),
              _buildStremioArrow(Icons.arrow_back_ios_new_rounded),
              const SizedBox(width: 6),
              _buildStremioArrow(Icons.arrow_forward_ios_rounded),
            ],
          ),
        ),
        SizedBox(
          height: isDesktop ? 240 : 200,
          child: ListView.separated(
            clipBehavior: Clip.none,
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: widget.items.length.clamp(0, 20),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return StremioCatalogCard(
                item: item,
                onTap: () => widget.onItemTap(item),
                height: isDesktop ? 240 : 200,
              );
            },
          ),
        ),
      ],
    );
  }
}

class StremioCatalogCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final double height;

  const StremioCatalogCard({super.key, required this.item, required this.onTap, this.height = 200});

  @override
  State<StremioCatalogCard> createState() => _StremioCatalogCardState();
}

class _StremioCatalogCardState extends State<StremioCatalogCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final poster = widget.item['poster']?.toString() ?? '';
    final name = widget.item['name']?.toString() ?? 'Unknown';
    final rating = widget.item['imdbRating']?.toString() ?? '';
    final shape = widget.item['posterShape']?.toString() ?? 'poster';
    final primary = AppTheme.current.primaryColor;

    final double width;
    if (shape == 'landscape') {
      width = widget.height * (16 / 9);
    } else if (shape == 'square') {
      width = widget.height;
    } else {
      width = widget.height * (2 / 3);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: FocusableControl(
        onTap: widget.onTap,
        borderRadius: AppRadius.card,
        scaleOnFocus: 1.05,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AnimationPresets.smoothInOut,
          width: width,
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: _isHovered ? primary.withValues(alpha: 0.5) : AppTheme.borderStrong.withValues(alpha: 0.1),
              width: _isHovered ? 1.0 : 0.5,
            ),
            boxShadow: AppTheme.isLightMode ? null : [
              if (_isHovered) AppShadows.glow(0.15),
              BoxShadow(color: AppTheme.overlay.withValues(alpha: _isHovered ? 0.4 : 0.2), blurRadius: _isHovered ? 16 : 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (poster.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: poster,
                  fit: BoxFit.cover,
                  memCacheWidth: 320,
                  placeholder: (_, _) => Container(color: AppTheme.bgCard),
                  errorWidget: (_, _, _) => Container(
                    color: AppTheme.bgCard,
                    child: Center(child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white38))),
                  ),
                )
              else
                Center(child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white38))),

              // Gradient — stronger on hover
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: _isHovered ? 0.8 : 0.7),
                      Colors.black.withValues(alpha: _isHovered ? 0.98 : 0.95),
                    ],
                    stops: const [0.0, 0.4, 0.75, 1.0],
                  ),
                ),
              ),

              // Play icon on hover
              if (_isHovered)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.25),
                      border: Border.all(color: primary.withValues(alpha: 0.5), width: 1),
                      boxShadow: [AppShadows.glow(0.2)],
                    ),
                    child: Icon(Icons.play_arrow_rounded, color: AppTheme.textPrimary, size: 24),
                  ),
                ),

              // Rating badge
              if (rating.isNotEmpty)
                Positioned(
                  top: 8, right: 8,
                  child: buildRatingBadgeText(rating),
                ),

              // Name
              Positioned(
                bottom: 10, left: 10, right: 10,
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, height: 1.2),
                ),
              ),

              // My List button
              Positioned(
                top: 8, left: 8,
                child: MyListButton.stremio(stremioItem: widget.item),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassArrowButton({required this.icon, required this.onTap});

  @override
  State<_GlassArrowButton> createState() => _GlassArrowButtonState();
}

class _GlassArrowButtonState extends State<_GlassArrowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AnimationPresets.smoothInOut,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppTheme.current.primaryColor.withValues(alpha: 0.15)
                : GlassColors.surfaceSubtle,
            shape: BoxShape.circle,
            border: Border.all(
              color: _isHovered
                  ? AppTheme.current.primaryColor.withValues(alpha: 0.4)
                  : GlassColors.borderSubtle,
              width: 0.5,
            ),
            boxShadow: _isHovered ? [AppShadows.glow(0.1)] : null,
          ),
          child: Icon(
            widget.icon,
            color: _isHovered ? AppTheme.current.primaryColor : AppTheme.textSecondary,
            size: 14,
          ),
        ),
      ),
    );
  }
}
