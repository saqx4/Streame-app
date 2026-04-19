import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/app_theme.dart';

/// Optimized image widget with advanced caching, placeholders, and error handling
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final bool useShimmer;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.useShimmer = true,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorWidget();
    }

    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fadeInDuration,
      memCacheWidth: _calculateMemCacheWidth(),
      memCacheHeight: _calculateMemCacheHeight(),
      maxHeightDiskCache: _calculateMaxDiskCache(),
      placeholder: placeholder != null
          ? (context, url) => placeholder!
          : useShimmer
              ? (context, url) => _buildShimmerPlaceholder()
              : (context, url) => _buildDefaultPlaceholder(),
      errorWidget: errorWidget != null
          ? (context, url, error) => errorWidget!
          : (context, url, error) => _buildErrorWidget(),
      imageBuilder: (context, imageProvider) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            image: DecorationImage(
              image: imageProvider,
              fit: fit,
            ),
          ),
        );
      },
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: imageWidget,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: imageWidget,
    );
  }

  /// Calculate optimal memory cache width based on device pixel ratio
  int? _calculateMemCacheWidth() {
    if (width == null) return null;
    return (width! * MediaQueryData.fromWindow(WidgetsBinding.instance.platformDispatcher).devicePixelRatio).toInt();
  }

  /// Calculate optimal memory cache height based on device pixel ratio
  int? _calculateMemCacheHeight() {
    if (height == null) return null;
    return (height! * MediaQueryData.fromWindow(WidgetsBinding.instance.platformDispatcher).devicePixelRatio).toInt();
  }

  /// Calculate max disk cache size (limit to 1080p for performance)
  int _calculateMaxDiskCache() {
    return 1920; // 1080p height
  }

  /// Shimmer placeholder for loading state
  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.withValues(alpha: 0.3),
      highlightColor: Colors.grey.withValues(alpha: 0.1),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3),
          borderRadius: borderRadius,
        ),
      ),
    );
  }

  /// Default placeholder (simple grey box)
  Widget _buildDefaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
        ),
      ),
    );
  }

  /// Error widget with icon
  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          Icons.broken_image,
          size: (width ?? height ?? 48) * 0.4,
          color: Colors.white24,
        ),
      ),
    );
  }
}

/// Specialized poster image widget for movie posters
class PosterImage extends StatelessWidget {
  final String posterPath;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const PosterImage({
    super.key,
    required this.posterPath,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseUrl = 'https://image.tmdb.org/t/p/w500';
    final fullUrl = posterPath.startsWith('http') 
        ? posterPath 
        : '$baseUrl$posterPath';

    return OptimizedImage(
      imageUrl: fullUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
    );
  }
}

/// Specialized backdrop image widget for movie backdrops
class BackdropImage extends StatelessWidget {
  final String backdropPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  const BackdropImage({
    super.key,
    required this.backdropPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final baseUrl = 'https://image.tmdb.org/t/p/original';
    final fullUrl = backdropPath.startsWith('http') 
        ? backdropPath 
        : '$baseUrl$backdropPath';

    return OptimizedImage(
      imageUrl: fullUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 500),
    );
  }
}

/// Preload images for smooth scrolling
class ImagePreloader {
  static final Map<String, CachedNetworkImageProvider> _cache = {};

  /// Preload a list of images
  static Future<void> preloadImages(List<String> urls) async {
    final futures = urls.where((url) => url.isNotEmpty).map((url) {
      final provider = CachedNetworkImageProvider(url);
      _cache[url] = provider;
      return precacheImage(provider, WidgetsBinding.instance.platformDispatcher.views.first);
    });

    await Future.wait(futures, eagerError: true);
  }

  /// Preload a single image
  static Future<void> preloadImage(String url) async {
    if (url.isEmpty) return;
    final provider = CachedNetworkImageProvider(url);
    _cache[url] = provider;
    await precacheImage(provider, WidgetsBinding.instance.platformDispatcher.views.first);
  }

  /// Clear the preload cache
  static void clearCache() {
    _cache.clear();
  }
}
