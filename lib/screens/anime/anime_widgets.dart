import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../api/anime_service.dart';
import '../../utils/app_theme.dart';

class AnimeCardWidget extends StatefulWidget {
  final AnimeCard anime;
  final VoidCallback onTap;

  const AnimeCardWidget({super.key, required this.anime, required this.onTap});

  @override
  State<AnimeCardWidget> createState() => _AnimeCardWidgetState();
}

class _AnimeCardWidgetState extends State<AnimeCardWidget> {
  bool _isHovered = false;
  bool _isLiked = false;
  final _service = AnimeService();

  @override
  void initState() {
    super.initState();
    _checkLiked();
  }

  @override
  void didUpdateWidget(covariant AnimeCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anime.id != widget.anime.id) _checkLiked();
  }

  void _checkLiked() {
    _service.isLiked(widget.anime.id).then((v) {
      if (mounted) setState(() => _isLiked = v);
    });
  }

  void _toggleLike() {
    _service.toggleLike(widget.anime).then((_) => _checkLiked());
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          transform: _isHovered ? Matrix4.diagonal3Values(1.04, 1.04, 1.0) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isHovered
                ? [BoxShadow(color: const Color(0xFFFF6B9D).withValues(alpha: 0.3), blurRadius: 20, spreadRadius: -2)]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cover
                widget.anime.coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.anime.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: AppTheme.bgCard, child: const Center(child: Icon(Icons.movie_outlined, color: Colors.white12, size: 28))),
                        errorWidget: (_, _, _) => Container(color: AppTheme.bgCard, child: const Center(child: Icon(Icons.broken_image, color: Colors.white12, size: 28))),
                      )
                    : Container(color: AppTheme.bgCard, child: const Center(child: Icon(Icons.movie_outlined, color: Colors.white12, size: 28))),

                // Gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.7), Colors.black.withValues(alpha: 0.95)],
                        stops: const [0.0, 0.45, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),

                // Like button (top-left)
                Positioned(
                  top: 6, left: 6,
                  child: GestureDetector(
                    onTap: _toggleLike,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? const Color(0xFFFF6B9D) : Colors.white54,
                        size: 14,
                      ),
                    ),
                  ),
                ),

                // Score badge (top-right)
                if (widget.anime.averageScore != null)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: _scoreColors(widget.anime.averageScore!)),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: _scoreColors(widget.anime.averageScore!).first.withValues(alpha: 0.5), blurRadius: 6)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 2),
                          Text((widget.anime.averageScore! / 10).toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),

                // Title + info
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.anime.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.2)),
                        const SizedBox(height: 4),
                        Row(children: [
                          if (widget.anime.format != null)
                            Text(widget.anime.format!, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, fontWeight: FontWeight.w500)),
                          if (widget.anime.episodes != null) ...[
                            if (widget.anime.format != null)
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('•', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10))),
                            Text('${widget.anime.episodes} ep', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10)),
                          ],
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _scoreColors(int score) {
    if (score >= 80) return [const Color(0xFF00E676), const Color(0xFF00C853)];
    if (score >= 60) return [const Color(0xFFFFD740), const Color(0xFFFFC400)];
    return [const Color(0xFFFF5252), const Color(0xFFD32F2F)];
  }
}