import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../utils/app_theme.dart';
import 'movie_poster.dart';

class MovieSection extends StatefulWidget {
  final String title;
  final List<Movie> movies;

  const MovieSection({super.key, required this.title, required this.movies});

  @override
  State<MovieSection> createState() => _MovieSectionState();
}

class _MovieSectionState extends State<MovieSection> {
  final ScrollController _controller = ScrollController();
  final double _scrollAmount = 400.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollLeft() {
    if (_controller.hasClients) {
      final target = (_controller.offset - _scrollAmount).clamp(0.0, _controller.position.maxScrollExtent);
      _controller.animateTo(target, duration: AppDurations.slow, curve: Curves.easeInOutCubic);
    }
  }

  void _scrollRight() {
    if (_controller.hasClients) {
      final target = (_controller.offset + _scrollAmount).clamp(0.0, _controller.position.maxScrollExtent);
      _controller.animateTo(target, duration: AppDurations.slow, curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();
    final primary = AppTheme.current.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xl, top: AppSpacing.xl, bottom: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: AppTheme.isLightMode ? null : [
                    BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        // Horizontal list
        SizedBox(
          height: 400,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              ListView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                itemCount: widget.movies.length,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                clipBehavior: Clip.none,
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 180,
                    child: MoviePoster(movie: widget.movies[index]),
                  );
                },
              ),
              // Left arrow
              Positioned(
                left: 8,
                child: _ScrollArrow(icon: Icons.arrow_back_ios_new, onPressed: _scrollLeft),
              ),
              // Right arrow
              Positioned(
                right: 8,
                child: _ScrollArrow(icon: Icons.arrow_forward_ios, onPressed: _scrollRight),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScrollArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ScrollArrow({required this.icon, required this.onPressed});

  @override
  State<_ScrollArrow> createState() => _ScrollArrowState();
}

class _ScrollArrowState extends State<_ScrollArrow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        decoration: BoxDecoration(
          color: _isHovered ? AppTheme.surfaceContainerHigh : AppTheme.overlay.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: _isHovered ? AppTheme.borderStrong : AppTheme.border),
        ),
        child: IconButton(
          icon: Icon(widget.icon, color: AppTheme.textPrimary, size: 20),
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}
