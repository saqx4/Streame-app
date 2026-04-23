import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../api/tmdb_api.dart';
import '../screens/details_screen.dart';
import '../screens/streaming_details_screen.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';
import '../utils/extensions.dart';

class HeroBanner extends StatefulWidget {
  final List<Movie> movies;

  const HeroBanner({super.key, required this.movies});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  int _currentIndex = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final heroHeight = isMobile ? screenHeight * 0.55 : screenHeight * 0.72;
    final featuredMovies = widget.movies.take(5).toList();
    final primary = AppTheme.current.primaryColor;

    return Focus(
      child: Stack(
        children: [
          // Carousel
          CarouselSlider(
            carouselController: _carouselController,
            options: CarouselOptions(
              height: heroHeight,
              viewportFraction: 1.0,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 8),
              autoPlayAnimationDuration: const Duration(milliseconds: 1000),
              autoPlayCurve: Curves.fastOutSlowIn,
              onPageChanged: (index, reason) {
                setState(() => _currentIndex = index);
              },
            ),
            items: featuredMovies.map((movie) {
              final imageUrl = TmdbApi.getBackdropUrl(movie.backdropPath);
              return InkWell(
                onTap: () => _navigateToDetails(movie),
                focusColor: primary.withValues(alpha: 0.1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      placeholder: (_, __) => Container(color: AppTheme.bgDark),
                      errorWidget: (_, __, ___) => Container(color: AppTheme.bgDark),
                    ),
                    // Bottom fade
                    Container(decoration: BoxDecoration(gradient: AppTheme.bottomFade(0.35))),
                    // Side fade (desktop)
                    if (!isMobile)
                      Container(decoration: BoxDecoration(gradient: AppTheme.leftFade())),
                  ],
                ),
              );
            }).toList(),
          ),

          // Content overlay
          Positioned(
            bottom: AppSpacing.xl,
            left: isMobile ? AppSpacing.xl : 60,
            right: isMobile ? AppSpacing.xl : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                SizedBox(
                  width: isMobile ? null : screenWidth * 0.45,
                  child: Text(
                    featuredMovies[_currentIndex].title,
                    style: TextStyle(
                      fontSize: isMobile ? 28 : 48,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      height: 1.1,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          blurRadius: 24.0,
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Metadata badges
                Row(
                  children: [
                    _buildBadge(
                      '${featuredMovies[_currentIndex].voteAverage.toStringAsFixed(1)}',
                      Colors.amber,
                      Icons.star_rounded,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _buildBadge(
                      featuredMovies[_currentIndex].releaseDate.take(4),
                      AppTheme.textSecondary,
                      Icons.calendar_today_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Action buttons
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _navigateToDetails(featuredMovies[_currentIndex]),
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: const Text('Play Now'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('My List'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Page indicators
          Positioned(
            bottom: AppSpacing.sm,
            right: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: featuredMovies.asMap().entries.map((entry) {
                final isActive = _currentIndex == entry.key;
                return GestureDetector(
                  onTap: () => _carouselController.animateToPage(entry.key),
                  child: AnimatedContainer(
                    duration: AppDurations.normal,
                    width: isActive ? 24.0 : 8.0,
                    height: 4.0,
                    margin: const EdgeInsets.symmetric(horizontal: 3.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isActive ? primary : AppTheme.textDisabled.withValues(alpha: 0.3),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.overlay.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToDetails(Movie movie) async {
    final navigator = Navigator.of(context);
    final isStreamingMode = await SettingsService().isStreamingModeEnabled();
    if (mounted) {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => isStreamingMode
              ? StreamingDetailsScreen(movie: movie)
              : DetailsScreen(movie: movie),
        ),
      );
    }
  }
}


