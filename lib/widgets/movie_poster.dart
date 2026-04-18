import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/my_list_service.dart';
import '../api/tmdb_api.dart';
import '../screens/details_screen.dart';
import '../screens/streaming_details_screen.dart';
import '../api/settings_service.dart';
import '../utils/app_theme.dart';

class MoviePoster extends StatefulWidget {
  final Movie movie;

  const MoviePoster({super.key, required this.movie});

  @override
  State<MoviePoster> createState() => _MoviePosterState();
}

class _MoviePosterState extends State<MoviePoster> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isHovered || _isFocused;

    return InkWell(
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      onHover: (isHovering) {
        setState(() {
          _isHovered = isHovering;
        });
      },
      onTap: () async {
        final navigator = Navigator.of(context);
        final isStreamingMode = await SettingsService().isStreamingModeEnabled();
        if (mounted) {
          navigator.push(
            MaterialPageRoute(
              builder: (context) => isStreamingMode
                  ? StreamingDetailsScreen(movie: widget.movie)
                  : DetailsScreen(movie: widget.movie),
            ),
          );
        }
      },
      splashColor: AppTheme.primaryColor.withValues(alpha: 0.15),
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(16.0),
      child: AnimatedScale(
        scale: isActive ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: Container(
          margin: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: isActive ? AppTheme.primaryColor : Colors.white10,
              width: isActive ? 2.5 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    )
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image
                CachedNetworkImage(
                  imageUrl: TmdbApi.getImageUrl(widget.movie.posterPath),
                  fit: BoxFit.cover,
                  memCacheWidth: 320,
                  placeholder: (context, url) => Container(
                    color: AppTheme.bgCard,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor.withValues(alpha: 0.4))),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppTheme.bgCard,
                    child: const Icon(Icons.movie_outlined, color: Colors.white12),
                  ),
                ),
                
                // Fancy Info Footer - Sliding up on Focus
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutQuart,
                  bottom: isActive ? 0 : -60,
                  left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF05050A).withValues(alpha: 0.0),
                          const Color(0xFF05050A).withValues(alpha: 0.85),
                          const Color(0xFF05050A),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              widget.movie.voteAverage.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (widget.movie.releaseDate.isNotEmpty)
                              Text(
                                widget.movie.releaseDate.take(4),
                                style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // My List add/remove button
                Positioned(
                  top: 8, right: 8,
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
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: inList ? AppTheme.primaryColor : Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            inList ? Icons.bookmark_rounded : Icons.add_rounded,
                            size: 16,
                            color: Colors.white,
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
