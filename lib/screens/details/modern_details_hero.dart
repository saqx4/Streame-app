import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'package:streame_core/models/movie.dart';
import 'package:streame_core/api/tmdb_api.dart';
import 'package:streame_core/utils/extensions.dart';

class ModernDetailsHero extends StatefulWidget {
  final Movie movie;
  final Widget actionButtons;
  final List<Widget> genreChips;
  final Widget? ratingsRow;

  const ModernDetailsHero({
    super.key,
    required this.movie,
    required this.actionButtons,
    required this.genreChips,
    this.ratingsRow,
  });

  @override
  State<ModernDetailsHero> createState() => _ModernDetailsHeroState();
}

class _ModernDetailsHeroState extends State<ModernDetailsHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final primary = AppTheme.current.primaryColor;

    final horizontalPadding = isMobile ? 20.0 : 48.0;
    final titleSize = isMobile ? 34.0 : 64.0;
    final metaFontSize = isMobile ? 16.0 : 18.0;
    final ratingIconSize = isMobile ? 20.0 : 22.0;
    final ratingFontSize = isMobile ? 16.0 : 18.0;
    final posterWidth = isMobile ? 0.0 : 140.0;
    final posterHeight = isMobile ? 0.0 : 210.0;

    final hasLogo = widget.movie.logoPath.isNotEmpty;
    final logoUrl = hasLogo ? TmdbApi.getImageUrl(widget.movie.logoPath) : '';

    return SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isMobile)
                        Container(
                          width: posterWidth,
                          height: posterHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.55),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CachedNetworkImage(
                              imageUrl: TmdbApi.getImageUrl(widget.movie.posterPath),
                              fit: BoxFit.cover,
                              memCacheWidth: 360,
                            ),
                          ),
                        ),
                      if (!isMobile) const SizedBox(width: 22),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasLogo)
                              SizedBox(
                                height: isMobile ? 44 : 64,
                                child: CachedNetworkImage(
                                  imageUrl: logoUrl,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerLeft,
                                  errorWidget: (_, __, ___) => Text(
                                    widget.movie.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -1.2,
                                      height: 1.05,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 28,
                                          color: Colors.black.withValues(alpha: 0.85),
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              Text(
                                widget.movie.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1.2,
                                  height: 1.05,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 28,
                                      color: Colors.black.withValues(alpha: 0.85),
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 14,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (widget.movie.releaseDate.isNotEmpty)
                                  Text(
                                    widget.movie.releaseDate.take(4),
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: metaFontSize,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: widget.movie.mediaType == 'tv'
                                        ? primary.withValues(alpha: 0.25)
                                        : Colors.white.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: widget.movie.mediaType == 'tv'
                                          ? primary.withValues(alpha: 0.5)
                                          : Colors.white.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    widget.movie.mediaType == 'tv' ? 'TV SERIES' : 'MOVIE',
                                    style: TextStyle(
                                      color: widget.movie.mediaType == 'tv' ? primary : Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                if (widget.movie.voteAverage > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded, color: Colors.amber.shade400, size: ratingIconSize),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.movie.voteAverage.toStringAsFixed(1),
                                        style: TextStyle(
                                          color: Colors.amber.shade400,
                                          fontSize: ratingFontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            if (widget.genreChips.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: widget.genreChips,
                              ),
                            ],
                            if (widget.ratingsRow != null) ...[
                              const SizedBox(height: 16),
                              widget.ratingsRow!,
                            ],
                            const SizedBox(height: 22),
                            widget.actionButtons,
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
