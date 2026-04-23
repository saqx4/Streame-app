import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../api/tmdb_api.dart';
import '../../widgets/my_list_button.dart';
import '../../models/movie.dart';
import '../../utils/app_theme.dart';


class ScrollableSlider extends StatefulWidget {
  final double height;
  final int itemCount;
  final double cardWidth;
  final IndexedWidgetBuilder itemBuilder;

  const ScrollableSlider({
    required this.height,
    required this.itemCount,
    required this.cardWidth,
    required this.itemBuilder,
  });

  @override
  State<ScrollableSlider> createState() => _ScrollableSliderState();
}

class _ScrollableSliderState extends State<ScrollableSlider> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeft = false;
  bool _showRight = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
  }

  void _updateArrows() {
    if (!mounted) return;
    final pos = _scrollController.position;
    final newLeft = pos.pixels > 10;
    final newRight = pos.pixels < pos.maxScrollExtent - 10;
    if (newLeft != _showLeft || newRight != _showRight) {
      setState(() {
        _showLeft = newLeft;
        _showRight = newRight;
      });
    }
  }

  void _scroll(double direction) {
    final target = _scrollController.offset + direction * (widget.cardWidth + 12) * 3;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: widget.itemBuilder,
          ),
          // Left arrow
          if (_showLeft)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ArrowButton(
                icon: Icons.chevron_left,
                onTap: () => _scroll(-1),
                alignment: Alignment.centerLeft,
              ),
            ),
          // Right arrow
          if (_showRight && widget.itemCount > 2)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: ArrowButton(
                icon: Icons.chevron_right,
                onTap: () => _scroll(1),
                alignment: Alignment.centerRight,
              ),
            ),
        ],
      ),
    );
  }
}

class ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Alignment alignment;

  const ArrowButton({required this.icon, required this.onTap, required this.alignment});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        alignment: alignment,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: alignment == Alignment.centerLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: alignment == Alignment.centerLeft ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              AppTheme.bgDark.withValues(alpha: 0.9),
              AppTheme.bgDark.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.textSecondary, size: 18),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Result Cards
// ═════════════════════════════════════════════════════════════════════════════

class SearchCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback onTap;

  const SearchCard({required this.movie, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = movie.posterPath.isNotEmpty ? TmdbApi.getImageUrl(movie.posterPath) : '';

    return FocusableControl(
      onTap: onTap,
      borderRadius: AppRadius.md,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Hero(
                tag: 'movie-poster-${movie.id}',
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppTheme.surfaceContainer),
                  errorWidget: (_, __, ___) => Center(child: Icon(Icons.broken_image, color: AppTheme.textDisabled)),
                ),
              )
            else
              Center(child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(movie.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              )),

            if (movie.voteAverage > 0)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.overlay.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(movie.voteAverage.toStringAsFixed(1), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                ),
              ),

            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppTheme.bgDark.withValues(alpha: 0.85), Colors.transparent],
                  ),
                ),
                child: Text(
                  movie.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                ),
              ),
            ),

            Positioned(
              top: 6, left: 6,
              child: MyListButton.movie(movie: movie),
            ),
          ],
        ),
      ),
    );
  }
}

class StremioSearchCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const StremioSearchCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final poster = item['poster']?.toString() ?? '';
    final name = item['name']?.toString() ?? 'Unknown';
    final rating = item['imdbRating']?.toString() ?? '';
    final type = item['type']?.toString() ?? '';

    return FocusableControl(
      onTap: onTap,
      borderRadius: AppRadius.md,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (poster.isNotEmpty)
              CachedNetworkImage(
                imageUrl: poster,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppTheme.surfaceContainer),
                errorWidget: (_, __, ___) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppTheme.textDisabled)),
                  ),
                ),
              )
            else
              Center(child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppTheme.textDisabled)),
              )),

            if (type.isNotEmpty)
              Positioned(
                top: 5, left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: type == 'series' ? Colors.blue.withValues(alpha: 0.7) : AppTheme.current.primaryColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(type.toUpperCase(), style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                ),
              ),

            if (rating.isNotEmpty)
              Positioned(
                top: 5, right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.overlay.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 9, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(rating, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                    ],
                  ),
                ),
              ),

            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppTheme.bgDark.withValues(alpha: 0.85), Colors.transparent],
                  ),
                ),
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                ),
              ),
            ),

            Positioned(
              bottom: 30, right: 5,
              child: MyListButton.stremio(stremioItem: item),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My List button helpers for search cards
// ─────────────────────────────────────────────────────────────────────────────




