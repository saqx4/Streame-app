import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/my_list_service.dart';
import '../api/tmdb_api.dart';
// Screen navigation handled via onMovieTap callback
import '../utils/app_theme.dart';

class MoviePoster extends StatefulWidget {
  final Movie movie;
  final int? rank;
  final void Function(Movie)? onMovieTap;

  const MoviePoster({super.key, required this.movie, this.rank, this.onMovieTap});

  @override
  State<MoviePoster> createState() => _MoviePosterState();
}

class _MoviePosterState extends State<MoviePoster>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: AnimationPresets.cardHoverScale)
        .animate(CurvedAnimation(parent: _scaleController, curve: AnimationPresets.smoothEnter));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _updateScale() {
    if (_isHovered || _isFocused) {
      _scaleController.forward();
    } else {
      _scaleController.reverse();
    }
  }

  void _navigate() {
    if (widget.onMovieTap != null) {
      widget.onMovieTap!(widget.movie);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isHovered || _isFocused;
    final primary = AppTheme.current.primaryColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _navigate,
      child: Focus(
        onFocusChange: (f) {
          setState(() => _isFocused = f);
          _updateScale();
        },
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _isHovered = true);
            _updateScale();
          },
          onExit: (_) {
            setState(() => _isHovered = false);
            _updateScale();
          },
          child: AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) {
              final scale = _isPressed
                  ? AnimationPresets.pressScale
                  : _scaleAnim.value;
              return Transform.scale(scale: scale, child: child);
            },
            child: AnimatedContainer(
              duration: AppDurations.fast,
              curve: AnimationPresets.smoothInOut,
              margin: EdgeInsets.all(isActive ? 2.0 : 4.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: isActive ? primary.withValues(alpha: 0.7) : Colors.transparent,
                  width: isActive ? 1.5 : 0,
                ),
                boxShadow: [
                  if (isActive) AppShadows.glow(0.2),
                  if (isActive) AppShadows.primary(0.15),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card - 1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Poster image
                    Hero(
                      tag: 'movie-poster-${widget.movie.id}',
                      child: CachedNetworkImage(
                        imageUrl: TmdbApi.getImageUrl(widget.movie.posterPath),
                        fit: BoxFit.cover,
                        memCacheWidth: 320,
                        placeholder: (_, __) => Container(
                          color: AppTheme.surfaceContainer,
                          child: Center(child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primary.withValues(alpha: 0.3),
                          )),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.surfaceContainer,
                          child: Icon(Icons.movie_outlined, color: AppTheme.textDisabled, size: 32),
                        ),
                      ),
                    ),

                    // Netflix-style gradient overlay — only on hover/focus
                    Positioned.fill(
                      child: AnimatedOpacity(
                        duration: AppDurations.normal,
                        curve: AnimationPresets.smoothInOut,
                        opacity: isActive ? 1.0 : 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppShadows.netflixCardGradient,
                          ),
                        ),
                      ),
                    ),

                    // Glassmorphic hover overlay with play icon
                    AnimatedOpacity(
                      duration: AppDurations.normal,
                      curve: AnimationPresets.smoothInOut,
                      opacity: isActive ? 1.0 : 0.0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppTheme.bgDark.withValues(alpha: 0.3),
                              AppTheme.bgDark.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primary.withValues(alpha: 0.25),
                              border: Border.all(
                                color: primary.withValues(alpha: 0.5),
                                width: 1,
                              ),
                              boxShadow: [AppShadows.glow(0.3)],
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: AppTheme.textPrimary,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Rating badge — top left
                    if (widget.movie.voteAverage > 0 && widget.rank == null)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.bgDark.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: Colors.amber.shade400.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: Colors.amber.shade400, size: 11),
                              const SizedBox(width: 2),
                              Text(
                                widget.movie.voteAverage.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Colors.amber.shade400,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Rank badge — top left (overrides rating)
                    if (widget.rank != null)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primary, primary.withValues(alpha: 0.7)],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            boxShadow: [AppShadows.primary(0.3)],
                          ),
                          child: Text(
                            '#${widget.rank}',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                    // My List button — top right (glassmorphic)
                    Positioned(
                      top: 6, right: 6,
                      child: ValueListenableBuilder<int>(
                        valueListenable: MyListService.changeNotifier,
                        builder: (context, _, __) {
                          final uid = MyListService.movieId(widget.movie.id, widget.movie.mediaType);
                          final inList = MyListService().contains(uid);
                          return GestureDetector(
                            onTap: () async {
                              final added = await MyListService().toggleMovie(
                                tmdbId: widget.movie.id,
                                imdbId: widget.movie.imdbId,
                                title: widget.movie.title,
                                posterPath: widget.movie.posterPath,
                                mediaType: widget.movie.mediaType,
                                voteAverage: widget.movie.voteAverage,
                                releaseDate: widget.movie.releaseDate,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(added ? 'Added to My List' : 'Removed from My List'),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ));
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: AnimatedContainer(
                                  duration: AppDurations.fast,
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: inList
                                        ? primary.withValues(alpha: 0.8)
                                        : AppTheme.bgDark.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: inList
                                          ? primary.withValues(alpha: 0.5)
                                          : AppTheme.borderStrong.withValues(alpha: 0.3),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Icon(
                                    inList ? Icons.bookmark_rounded : Icons.add_rounded,
                                    size: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Info footer — glassmorphic slide-up on hover/focus
                    AnimatedPositioned(
                      duration: AppDurations.normal,
                      curve: AnimationPresets.smoothEnter,
                      bottom: isActive ? 0 : -72,
                      left: 0, right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(AppRadius.card - 1),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.bgDark.withValues(alpha: 0.5),
                                  AppTheme.bgDark.withValues(alpha: 0.9),
                                ],
                              ),
                              border: Border(
                                top: BorderSide(
                                  color: AppTheme.borderStrong.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.movie.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (widget.movie.mediaType == 'tv')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: primary.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text('TV',
                                          style: TextStyle(color: primary, fontSize: 9, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    Icon(Icons.star_rounded, color: Colors.amber.shade400, size: 12),
                                    const SizedBox(width: 2),
                                    Text(
                                      widget.movie.voteAverage.toStringAsFixed(1),
                                      style: TextStyle(color: Colors.amber.shade400, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                    const Spacer(),
                                    if (widget.movie.releaseDate.isNotEmpty)
                                      Text(
                                        widget.movie.releaseDate.substring(0, 4),
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
