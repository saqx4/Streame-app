import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../api/tmdb_api.dart';
import '../services/my_list_service.dart';
import '../utils/app_theme.dart';
import '../utils/extensions.dart';

class HeroBanner extends StatefulWidget {
  final List<Movie> movies;
  final Map<int, String>? logoUrls;
  final void Function(Movie)? onMovieTap;

  const HeroBanner({super.key, required this.movies, this.logoUrls, this.onMovieTap});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();

  late final AnimationController _textAnimController;
  late final Animation<double> _textFadeAnim;
  late final Animation<Offset> _textSlideAnim;

  @override
  void initState() {
    super.initState();
    _textAnimController = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
    );
    _textFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textAnimController, curve: AnimationPresets.smoothEnter),
    );
    _textSlideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _textAnimController, curve: AnimationPresets.smoothEnter),
    );
    _textAnimController.forward();
  }

  @override
  void dispose() {
    _textAnimController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, _) {
    setState(() => _currentIndex = index);
    _textAnimController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final heroHeight = isMobile ? screenHeight * 0.55 : screenHeight * 0.72;
    final featuredMovies = widget.movies.take(5).toList();
    final primary = AppTheme.current.primaryColor;
    final movie = featuredMovies[_currentIndex];

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
              onPageChanged: _onPageChanged,
            ),
            items: featuredMovies.map((m) {
              final imageUrl = TmdbApi.getBackdropUrl(m.backdropPath);
              return InkWell(
                onTap: () => _navigateToDetails(m),
                focusColor: primary.withValues(alpha: 0.1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      memCacheWidth: 800,
                      placeholder: (_, __) => Container(color: AppTheme.bgDark),
                      errorWidget: (_, __, ___) => Container(color: AppTheme.bgDark),
                    ),
                    // Netflix-style overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppShadows.netflixOverlay,
                        ),
                      ),
                    ),
                    // Side fade (desktop)
                    if (!isMobile)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppTheme.bgDark.withValues(alpha: 0.9),
                              AppTheme.bgDark.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35, 0.55],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),

          // Content overlay with animated entrance
          Positioned(
            bottom: AppSpacing.xl + 8,
            left: isMobile ? AppSpacing.xl : 60,
            right: isMobile ? AppSpacing.xl : null,
            child: SlideTransition(
              position: _textSlideAnim,
              child: FadeTransition(
                opacity: _textFadeAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Trending rank badge
                    if (_currentIndex < featuredMovies.length)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primary.withValues(alpha: 0.9), primary.withValues(alpha: 0.6)],
                                ),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                boxShadow: [AppShadows.primary(0.3)],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '#${_currentIndex + 1} in Trending',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Logo or Title
                    if (widget.logoUrls != null && widget.logoUrls![movie.id] != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isMobile ? screenWidth * 0.7 : screenWidth * 0.35,
                          maxHeight: isMobile ? 60 : 80,
                        ),
                        child: CachedNetworkImage(
                          imageUrl: widget.logoUrls![movie.id]!,
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.centerLeft,
                        ),
                      )
                    else
                      SizedBox(
                        width: isMobile ? null : screenWidth * 0.45,
                        child: Text(
                          movie.title,
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

                    // Glassmorphic metadata badges
                    Row(
                      children: [
                        _buildGlassBadge(
                          movie.voteAverage.toStringAsFixed(1),
                          Colors.amber,
                          Icons.star_rounded,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (movie.releaseDate.isNotEmpty)
                          _buildGlassBadge(
                            movie.releaseDate.take(4),
                            AppTheme.textSecondary,
                            Icons.calendar_today_rounded,
                          ),
                        const SizedBox(width: AppSpacing.sm),
                        if (movie.mediaType == 'tv')
                          _buildGlassBadge(
                            'SERIES',
                            primary,
                            Icons.tv_rounded,
                          ),
                      ],
                    ),
                    if (movie.overview.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isMobile ? screenWidth * 0.85 : screenWidth * 0.4),
                        child: Text(
                          movie.overview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                            shadows: [
                              Shadow(
                                blurRadius: 12.0,
                                color: Colors.black.withValues(alpha: 0.5),
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),

                    // Glassmorphic action buttons
                    Row(
                      children: [
                        _buildGlassPlayButton(movie, primary),
                        const SizedBox(width: AppSpacing.md),
                        _buildGlassListButton(movie, primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Page indicators with progress bar
          Positioned(
            bottom: AppSpacing.sm,
            left: isMobile ? AppSpacing.xl : 60,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: featuredMovies.asMap().entries.map((entry) {
                final isActive = _currentIndex == entry.key;
                return GestureDetector(
                  onTap: () => _carouselController.animateToPage(entry.key),
                  child: AnimatedContainer(
                    duration: AppDurations.normal,
                    curve: AnimationPresets.smoothInOut,
                    width: isActive ? 32.0 : 8.0,
                    height: 4.0,
                    margin: const EdgeInsets.symmetric(horizontal: 3.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isActive
                          ? primary
                          : AppTheme.textDisabled.withValues(alpha: 0.3),
                      boxShadow: isActive ? [AppShadows.primary(0.3)] : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Navigation arrows (desktop only)
          if (!isMobile) ...[
            Positioned(
              left: 12,
              top: heroHeight / 2 - 20,
              child: _buildNavArrow(Icons.chevron_left_rounded, () {
                if (_currentIndex > 0) {
                  _carouselController.animateToPage(_currentIndex - 1);
                }
              }),
            ),
            Positioned(
              right: 12,
              top: heroHeight / 2 - 20,
              child: _buildNavArrow(Icons.chevron_right_rounded, () {
                if (_currentIndex < featuredMovies.length - 1) {
                  _carouselController.animateToPage(_currentIndex + 1);
                }
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassBadge(String text, Color color, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.bgDark.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.2), width: 0.5),
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
        ),
      ),
    );
  }

  Widget _buildGlassPlayButton(Movie movie, Color primary) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: primary.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: () => _navigateToDetails(movie),
            borderRadius: BorderRadius.circular(AppRadius.md),
            splashColor: Colors.white.withValues(alpha: 0.15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: primary.withValues(alpha: 0.4), width: 0.5),
                boxShadow: [AppShadows.primary(0.25)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 22, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Play Now', style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassListButton(Movie movie, Color primary) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: ValueListenableBuilder<int>(
          valueListenable: MyListService.changeNotifier,
          builder: (context, _, __) {
            final uid = MyListService.movieId(movie.id, movie.mediaType);
            final inList = MyListService().contains(uid);
            return Material(
              color: AppTheme.bgDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                onTap: () async {
                  await MyListService().toggleMovie(
                    tmdbId: movie.id,
                    imdbId: movie.imdbId,
                    title: movie.title,
                    posterPath: movie.posterPath,
                    mediaType: movie.mediaType,
                    voteAverage: movie.voteAverage,
                    releaseDate: movie.releaseDate,
                  );
                },
                borderRadius: BorderRadius.circular(AppRadius.md),
                splashColor: primary.withValues(alpha: 0.15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: inList ? primary.withValues(alpha: 0.5) : AppTheme.borderStrong.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        inList ? Icons.bookmark_rounded : Icons.add_rounded,
                        size: 20,
                        color: inList ? primary : AppTheme.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        inList ? 'In My List' : 'My List',
                        style: TextStyle(
                          color: inList ? primary : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
    );
  }

  Widget _buildNavArrow(IconData icon, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: AppTheme.bgDark.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            splashColor: AppTheme.current.primaryColor.withValues(alpha: 0.15),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.2), width: 0.5),
              ),
              child: Icon(icon, color: AppTheme.textSecondary, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToDetails(Movie movie) async {
    if (widget.onMovieTap != null) {
      widget.onMovieTap!(movie);
    }
  }
}
