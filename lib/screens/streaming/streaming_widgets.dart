import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../api/tmdb_api.dart';
import '../../models/movie.dart';
import '../streaming_details_screen.dart';

class HorizontalEpisodeCard extends StatefulWidget {
  final int epNum;
  final String title;
  final String? stillPath;
  final bool isSelected;
  final bool isWatched;
  final VoidCallback onTap;
  final VoidCallback onToggleWatched;

  const HorizontalEpisodeCard({
    required this.epNum,
    required this.title,
    required this.stillPath,
    required this.isSelected,
    required this.isWatched,
    required this.onTap,
    required this.onToggleWatched,
  });

  @override
  State<HorizontalEpisodeCard> createState() => _HorizontalEpisodeCardState();
}

class _HorizontalEpisodeCardState extends State<HorizontalEpisodeCard> {
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
          duration: const Duration(milliseconds: 150),
          width: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFF1565C0)
                  : _isHovered
                      ? Colors.white38
                      : Colors.white12,
              width: 2,
            ),
            boxShadow: (widget.isSelected || _isHovered)
                ? [
                    BoxShadow(
                      color: widget.isSelected
                          ? const Color(0xFF1565C0).withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.08),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              children: [
                // thumbnail
                SizedBox(
                  width: 220,
                  height: 190,
                  child: widget.stillPath != null
                      ? CachedNetworkImage(
                          imageUrl: TmdbApi.getStillUrl(widget.stillPath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Container(
                          color: Colors.white10,
                          child: const Center(
                            child: Icon(Icons.movie_rounded,
                                color: Colors.white24, size: 40),
                          ),
                        ),
                ),
                // dark gradient at bottom
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    height: 70,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ),
                // play icon in centre
                Center(
                  child: AnimatedOpacity(
                    opacity: _isHovered || widget.isSelected ? 1.0 : 0.55,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? const Color(0xFF1565C0).withValues(alpha: 0.85)
                            : Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ),
                // watched checkmark
                Positioned(
                  top: 6, right: 6,
                  child: GestureDetector(
                    onTap: widget.onToggleWatched,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: widget.isWatched ? Colors.green : Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: widget.isWatched ? Colors.white : Colors.white38,
                      ),
                    ),
                  ),
                ),
                // episode number + title
                Positioned(
                  left: 10, right: 10, bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'E${widget.epNum}',
                        style: TextStyle(
                          color: widget.isSelected
                              ? const Color(0xFF64B5F6)
                              : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class EpisodeCard extends StatefulWidget {
  final Map<String, dynamic> episode;
  final bool isSelected;
  final VoidCallback onTap;

  const EpisodeCard({
    required this.episode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<EpisodeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final epNum = widget.episode['episode_number'];
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isSelected 
                ? Colors.white.withValues(alpha: 0.12) 
                : _isHovered
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected 
                  ? const Color(0xFF1565C0) 
                  : _isHovered
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.transparent,
              width: widget.isSelected || _isHovered ? 2 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.isSelected
                          ? const Color(0xFF1565C0).withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 130,
                height: 73,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black26,
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.episode['still_path'] != null
                          ? CachedNetworkImage(
                              imageUrl: TmdbApi.getStillUrl(widget.episode['still_path']),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : const Center(
                              child: Icon(Icons.movie, color: Colors.white24, size: 32),
                            ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Episode $epNum',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.episode['name'] ?? 'Episode $epNum',
                      style: TextStyle(
                        color: _isHovered || widget.isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.episode['runtime'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${widget.episode['runtime']}m',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                    if (widget.episode['overview'] != null && widget.episode['overview'].isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.episode['overview'],
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: _isHovered ? 0.3 : 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Color(0xFF1565C0), size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SeasonChip extends StatefulWidget {
  final int seasonNumber;
  final bool isSelected;
  final VoidCallback onTap;

  const SeasonChip({
    required this.seasonNumber,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<SeasonChip> createState() => _SeasonChipState();
}

class _SeasonChipState extends State<SeasonChip> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          transform: _isPressed 
              ? Matrix4.diagonal3Values(0.95, 0.95, 1.0)
              : _isHovered 
                  ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
                  : Matrix4.identity(),
          decoration: BoxDecoration(
            color: widget.isSelected 
                ? const Color(0xFF1565C0) 
                : _isHovered 
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: widget.isSelected 
                  ? const Color(0xFF1565C0) 
                  : _isHovered
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.3),
              width: widget.isSelected || _isHovered ? 2 : 1,
            ),
            boxShadow: _isHovered && !widget.isSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              'Season ${widget.seasonNumber}',
              style: TextStyle(
                color: widget.isSelected || _isHovered ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SimilarMovieCard extends StatefulWidget {
  final Movie movie;

  const SimilarMovieCard({required this.movie});

  @override
  State<SimilarMovieCard> createState() => _SimilarMovieCardState();
}

class _SimilarMovieCardState extends State<SimilarMovieCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => StreamingDetailsScreen(movie: widget.movie),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 130,
          margin: const EdgeInsets.only(right: 16),
          transform: _isHovered ? Matrix4.diagonal3Values(1.05, 1.05, 1.0) : Matrix4.identity(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 195,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered 
                          ? const Color(0xFF1565C0).withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.3),
                      blurRadius: _isHovered ? 12 : 8,
                      spreadRadius: _isHovered ? 3 : 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: widget.movie.posterPath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: TmdbApi.getImageUrl(widget.movie.posterPath),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.white.withValues(alpha: 0.1),
                          child: const Icon(Icons.movie, color: Colors.white38),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _isHovered ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: _isHovered ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    widget.movie.voteAverage.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
