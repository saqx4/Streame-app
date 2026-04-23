import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/my_list_service.dart';
import '../api/tmdb_api.dart';
import '../screens/details_screen.dart';
import '../screens/streaming_details_screen.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';
import 'smooth_page_transition.dart';

class MoviePoster extends StatefulWidget {
  final Movie movie;

  const MoviePoster({super.key, required this.movie});

  @override
  State<MoviePoster> createState() => _MoviePosterState();
}

class _MoviePosterState extends State<MoviePoster> {
  bool _isHovered = false;
  bool _isFocused = false;

  // Cached streaming mode — avoids async SharedPreferences read before Navigator.push
  static bool? _cachedStreamingMode;

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isHovered || _isFocused;
    final primary = AppTheme.current.primaryColor;

    return InkWell(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      onHover: (isHovering) => setState(() => _isHovered = isHovering),
      onTap: () {
        final navigator = Navigator.of(context);
        void push(bool isStreamingMode) {
          navigator.push(
            SmoothPageTransition(
              child: isStreamingMode
                  ? StreamingDetailsScreen(movie: widget.movie)
                  : DetailsScreen(movie: widget.movie),
            ),
          );
        }

        if (_cachedStreamingMode != null) {
          push(_cachedStreamingMode!);
        } else {
          SettingsService().isStreamingModeEnabled().then((v) {
            _cachedStreamingMode = v;
            if (mounted) push(v);
          });
        }
      },
      splashColor: primary.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedScale(
        scale: isActive ? 1.04 : 1.0,
        duration: AppDurations.slow,
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.all(3.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isActive ? primary : AppTheme.border,
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.2),
                      blurRadius: 16,
                      spreadRadius: -2,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg - 1),
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
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: primary.withValues(alpha: 0.3))),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.surfaceContainer,
                      child: Icon(Icons.movie_outlined, color: AppTheme.textDisabled, size: 32),
                    ),
                  ),
                ),

                // Info footer — slides up on hover/focus
                AnimatedPositioned(
                  duration: AppDurations.slow,
                  curve: Curves.easeOutQuart,
                  bottom: isActive ? 0 : -64,
                  left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.bgDark.withValues(alpha: 0.0),
                          AppTheme.bgDark.withValues(alpha: 0.88),
                          AppTheme.bgDark,
                        ],
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
                            Icon(Icons.star_rounded, color: Colors.amber.shade400, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              widget.movie.voteAverage.toStringAsFixed(1),
                              style: TextStyle(color: Colors.amber.shade400, fontSize: 11, fontWeight: FontWeight.w600),
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

                // My List button
                Positioned(
                  top: 6, right: 6,
                  child: ValueListenableBuilder<int>(
                    valueListenable: MyListService.changeNotifier,
                    builder: (context, _, _) {
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
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: inList ? primary : AppTheme.overlay.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            inList ? Icons.bookmark_rounded : Icons.add_rounded,
                            size: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
