import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:streame_core/widgets/my_list_button.dart';
import 'package:streame_core/utils/app_theme.dart';

class StremioCatalogCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const StremioCatalogCard({super.key, required this.item, required this.onTap});

  @override
  State<StremioCatalogCard> createState() => _StremioCatalogCardState();
}

class _StremioCatalogCardState extends State<StremioCatalogCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final poster = widget.item['poster']?.toString() ?? '';
    final name = widget.item['name']?.toString() ?? 'Unknown';
    final type = widget.item['type']?.toString() ?? '';
    final rating = widget.item['imdbRating']?.toString() ?? '';
    final releaseInfo = widget.item['releaseInfo']?.toString() ?? '';
    final primary = AppTheme.current.primaryColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: FocusableControl(
        onTap: widget.onTap,
        borderRadius: 14,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AnimationPresets.smoothInOut,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered ? primary.withValues(alpha: 0.5) : Colors.transparent,
              width: _isHovered ? 1.0 : 0,
            ),
            boxShadow: [
              if (_isHovered) AppShadows.glow(0.15),
              BoxShadow(color: AppTheme.overlay.withValues(alpha: _isHovered ? 0.4 : 0.2), blurRadius: _isHovered ? 16 : 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster
              if (poster.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: poster,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: AppTheme.bgCard),
                  errorWidget: (_, _, _) => Container(
                    color: AppTheme.bgCard,
                    child: Center(child: Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppTheme.textDisabled))),
                  ),
                )
              else
                Container(
                  color: AppTheme.bgCard,
                  child: Center(child: Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppTheme.textDisabled))),
                ),

              // Play icon on hover
              if (_isHovered)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.25),
                      border: Border.all(color: primary.withValues(alpha: 0.5), width: 1),
                      boxShadow: [AppShadows.glow(0.2)],
                    ),
                    child: Icon(Icons.play_arrow_rounded, color: AppTheme.textPrimary, size: 24),
                  ),
                ),

              // Rating badge
              if (rating.isNotEmpty)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 10, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(rating, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                      ],
                    ),
                  ),
                ),

              // Type badge
              if (type.isNotEmpty)
                Positioned(
                  top: 6, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: type == 'series'
                          ? Colors.blue.withValues(alpha: 0.7)
                          : AppTheme.primaryColor.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type.toUpperCase(),
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ),
                ),

              // Bottom info — stronger gradient on hover
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: _isHovered ? 0.95 : 0.9), Colors.transparent],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      if (releaseInfo.isNotEmpty)
                        Text(
                          releaseInfo,
                          style: TextStyle(color: AppTheme.textDisabled, fontSize: 10),
                        ),
                    ],
                  ),
                ),
              ),

              // My List add/remove button
              Positioned(
                bottom: 44, right: 6,
                child: MyListButton.stremio(stremioItem: widget.item),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


