import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../api/tmdb_api.dart';
import '../utils/app_theme.dart';

class LoadingOverlay extends StatefulWidget {
  final Movie movie;
  final String? message;
  final VoidCallback? onCancel;
  const LoadingOverlay({super.key, required this.movie, this.message, this.onCancel});

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.current.primaryColor;

    return Material(
      color: AppTheme.bgDark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred backdrop
          CachedNetworkImage(
            imageUrl: TmdbApi.getBackdropUrl(widget.movie.backdropPath),
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: AppTheme.bgDark),
            errorWidget: (_, _, _) => Container(color: AppTheme.bgDark),
          ),
          if (AppTheme.isLightMode)
            Container(color: AppTheme.bgDark.withValues(alpha: 0.85))
          else
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: AppTheme.bgDark.withValues(alpha: 0.65)),
            ),

          // Logo / Title
          Center(
            child: FadeTransition(
              opacity: _animation,
              child: widget.movie.logoPath.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: TmdbApi.getImageUrl(widget.movie.logoPath),
                      width: MediaQuery.of(context).size.width * 0.55,
                      fit: BoxFit.contain,
                    )
                  : Text(
                      widget.movie.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
            ),
          ),

          // Status
          Positioned(
            bottom: 80,
            left: 0, right: 0,
            child: Column(
              children: [
                SizedBox(
                  width: 36, height: 36,
                  child: CircularProgressIndicator(color: primary, strokeWidth: 3),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  widget.message?.toUpperCase() ?? 'STARTING STREAM',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                  ),
                ),
                if (widget.onCancel != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  OutlinedButton(
                    onPressed: widget.onCancel,
                    child: Text('CANCEL', style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: AppTheme.textSecondary,
                    )),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
