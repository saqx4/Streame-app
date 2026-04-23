import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../api/tmdb_api.dart';
import '../../widgets/my_list_button.dart';
import '../../models/movie.dart';
import '../../utils/app_theme.dart';

class FilterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const FilterButton({required this.label, required this.onTap, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: isActive ? AppTheme.current.primaryColor : AppTheme.surfaceContainerHigh,
        labelStyle: TextStyle(color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class CompactFilterDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final double? maxHeight;

  const CompactFilterDialog({required this.title, required this.child, this.maxHeight});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        constraints: BoxConstraints(maxWidth: 380, maxHeight: maxHeight ?? 500),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AppTheme.isLightMode
              ? _buildDialogBody(context)
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: _buildDialogBody(context),
                ),
        ),
      ),
    );
  }

  Widget _buildDialogBody(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.isLightMode ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: -5)],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppTheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class DiscoverCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback onTap;

  const DiscoverCard({required this.movie, required this.onTap});

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
          boxShadow: AppTheme.isLightMode ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppTheme.surfaceContainer),
                errorWidget: (_, __, ___) => Center(child: Icon(Icons.broken_image, color: AppTheme.textDisabled)),
              )
            else
              Center(child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(movie.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              )),
            
            // Rating Badge
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.overlay.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 10),
                    const SizedBox(width: 4),
                    Text(movie.voteAverage.toStringAsFixed(1), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ),

            // My List add/remove button
            Positioned(
              top: 8, left: 8,
              child: MyListButton.movie(movie: movie),
            ),
          ],
        ),
      ),
    );
  }
}


