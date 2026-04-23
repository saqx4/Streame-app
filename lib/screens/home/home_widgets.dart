import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../api/tmdb_api.dart';
import '../../models/movie.dart';
import '../../utils/app_theme.dart';
import '../../widgets/my_list_button.dart';

class MovieSection extends StatefulWidget {
  final String title;
  final IconData? icon;
  final Future<List<Movie>> future;
  final Function(Movie) onMovieTap;
  final bool isPortrait;
  final bool showRank;

  const MovieSection({
    required this.title,
    this.icon,
    required this.future,
    required this.onMovieTap,
    this.isPortrait = false,
    this.showRank = false,
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

  Widget _buildSmallFrostedArrow(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.border),
      ),
      child: Icon(icon, color: AppTheme.textSecondary, size: 14),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Shimmer placeholder while loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            final shimmerChild = Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(height: 18, width: 140, decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(AppRadius.sm))),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: widget.isPortrait ? 240 : 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: 5,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (_, _) => Container(
                          width: widget.isPortrait ? 150 : 280,
                          decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
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
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 18),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.current.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
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
                            fontSize: 20,
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
                  GestureDetector(
                    onTap: _scrollLeft,
                    child: _buildSmallFrostedArrow(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _scrollRight,
                    child: _buildSmallFrostedArrow(Icons.arrow_forward_ios_rounded),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: widget.isPortrait ? 260 : 190,
              child: ListView.separated(
                clipBehavior: Clip.none,
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: movies.length,
                separatorBuilder: (_, _) => SizedBox(width: widget.showRank ? 6 : 14),
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

  const StaticMovieSection({
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

  Widget _buildSmallFrostedArrow(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.border),
      ),
      child: Icon(icon, color: AppTheme.textSecondary, size: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.current.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(widget.icon, color: AppTheme.current.primaryColor, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Container(
                      height: 2.5,
                      width: 36,
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
              GestureDetector(
                onTap: _scrollLeft,
                child: _buildSmallFrostedArrow(Icons.arrow_back_ios_new_rounded),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _scrollRight,
                child: _buildSmallFrostedArrow(Icons.arrow_forward_ios_rounded),
              ),
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

class MovieCard extends StatelessWidget {
  final Movie movie;
  final bool isPortrait;
  final int? rank;
  final VoidCallback onTap;

  const MovieCard({
    required this.movie,
    required this.onTap,
    this.isPortrait = false,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    
    final cardWidth = isPortrait 
        ? (isDesktop ? 165.0 : 140.0) 
        : (isDesktop ? 320.0 : 270.0);
        
    final image = isPortrait ? movie.posterPath : movie.backdropPath;
    final imageUrl = image.isNotEmpty ? TmdbApi.getImageUrl(image) : '';
    final hasRank = rank != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Big rank number
        if (hasRank)
          Text(
            '$rank',
            style: TextStyle(
              fontSize: isPortrait ? 120 : 90,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = AppTheme.textDisabled.withValues(alpha: 0.15),
              height: 0.85,
              letterSpacing: -8,
            ),
          ),
        FocusableControl(
          onTap: onTap,
          borderRadius: AppRadius.lg,
          scaleOnFocus: 1.05,
          child: Container(
            width: cardWidth,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppTheme.border, width: 0.5),
              boxShadow: AppTheme.isLightMode ? null : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 8)),
                BoxShadow(color: AppTheme.current.primaryColor.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: -4),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.surfaceContainer),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.surfaceContainer,
                      child: Center(child: Text(movie.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppTheme.textDisabled))),
                    ),
                  )
                else
                  Container(
                    color: AppTheme.surfaceContainer,
                    child: Center(child: Text(movie.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppTheme.textDisabled))),
                  ),
                
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        AppTheme.bgDark.withValues(alpha: 0.7),
                        AppTheme.bgDark.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.45, 0.8, 1.0],
                    ),
                  ),
                ),
                
                // Rating badge (top right) — frosted glass
                if (movie.voteAverage > 0)
                  Positioned(
                    top: 8, right: 8,
                    child: buildRatingBadge(movie.voteAverage),
                  ),

                // Bottom content
                Positioned(
                  bottom: 10, left: 10, right: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        movie.title,
                        maxLines: isPortrait ? 2 : 1,
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
                          if (movie.releaseDate.isNotEmpty)
                            Text(
                              movie.releaseDate.split('-').first,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                          if (movie.mediaType == 'tv') ...[
                            if (movie.releaseDate.isNotEmpty) ...[
                              Text('  •  ', style: TextStyle(color: AppTheme.textDisabled, fontSize: 11)),
                            ],
                            Text('TV', style: TextStyle(color: AppTheme.current.primaryColor.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // My List button
                Positioned(
                  top: 8, left: 8,
                  child: MyListButton.movie(movie: movie),
                ),
              ],
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
      color: AppTheme.overlay.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppTheme.border),
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
      color: AppTheme.overlay.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppTheme.border),
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

  const StremioCatalogSection({
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
    final inner = Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 14),
    );
    return inner;
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
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
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
              GestureDetector(
                onTap: _scrollLeft,
                child: _buildStremioArrow(Icons.arrow_back_ios_new_rounded),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _scrollRight,
                child: _buildStremioArrow(Icons.arrow_forward_ios_rounded),
              ),
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

class StremioCatalogCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final double height;

  const StremioCatalogCard({required this.item, required this.onTap, this.height = 200});

  @override
  Widget build(BuildContext context) {
    final poster = item['poster']?.toString() ?? '';
    final name = item['name']?.toString() ?? 'Unknown';
    final rating = item['imdbRating']?.toString() ?? '';
    final shape = item['posterShape']?.toString() ?? 'poster';

    final double width;
    if (shape == 'landscape') {
      width = height * (16 / 9);
    } else if (shape == 'square') {
      width = height;
    } else {
      width = height * (2 / 3);
    }

    return FocusableControl(
      onTap: onTap,
      borderRadius: 14,
      scaleOnFocus: 1.05,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
          boxShadow: AppTheme.isLightMode ? null : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6)),
            BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: -4),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (poster.isNotEmpty)
              CachedNetworkImage(
                imageUrl: poster,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppTheme.bgCard),
                errorWidget: (_, _, _) => Container(
                  color: AppTheme.bgCard,
                  child: Center(child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white38))),
                ),
              )
            else
              Center(child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white38))),

            // Improved gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.4, 0.75, 1.0],
                ),
              ),
            ),

            // Rating badge — frosted glass
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
              child: MyListButton.stremio(stremioItem: item),
            ),
          ],
        ),
      ),
    );
  }
}
