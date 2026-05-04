import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;

/// A drop-in replacement for [CachedNetworkImage] that falls back to pure-Dart
/// image decoding when the platform's native decoder is broken (e.g. some
/// Android emulator system images).
///
/// Strategy:
///  1. Try the normal platform decode via [CachedNetworkImage].
///  2. If that fails, download the bytes again and decode them with the
///     pure-Dart `image` package, then render via [ui.decodeImageFromPixels].
class ResilientNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  const ResilientNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = Duration.zero,
    this.fadeOutDuration = Duration.zero,
  });

  @override
  State<ResilientNetworkImage> createState() => _ResilientNetworkImageState();
}

class _ResilientNetworkImageState extends State<ResilientNetworkImage> {
  _ImageState _state = _ImageState.loading;
  ui.Image? _dartImage; // image decoded by pure-Dart fallback

  @override
  void dispose() {
    _dartImage?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ResilientNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _dartImage?.dispose();
      _dartImage = null;
      _state = _ImageState.loading;
    }
  }

  /// Called when CachedNetworkImage's platform decoder fails.
  /// Falls back to pure-Dart decoding.
  Future<void> _onPlatformDecodeFailed() async {
    if (_state != _ImageState.loading) return; // already handled
    setState(() => _state = _ImageState.fallbackLoading);

    try {
      final uri = Uri.parse(widget.imageUrl);
      final bytes = await _fetchBytes(uri);
      final dartImg = img.decodeImage(bytes);
      if (dartImg == null) throw FormatException('image package could not decode');

      // Convert to RGBA pixel bytes
      final rgba = dartImg.convert(numChannels: 4, alpha: 255);
      final pixelBytes = Uint8List.fromList(rgba.buffer.asUint8List().toList());

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixelBytes,
        rgba.width,
        rgba.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );

      final image = await completer.future;
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _dartImage?.dispose();
        _dartImage = image;
        _state = _ImageState.fallbackOk;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('ResilientNetworkImage dart-fallback failed: $e');
      if (mounted) setState(() => _state = _ImageState.error);
    }
  }

  Future<Uint8List> _fetchBytes(Uri uri) async {
    // Use the same HTTP client that CachedNetworkImage would use
    final request = await HttpClient().getUrl(uri);
    final response = await request.close();
    final builder = BytesBuilder();
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  @override
  Widget build(BuildContext context) {
    // If the Dart fallback succeeded, render it directly
    if (_state == _ImageState.fallbackOk && _dartImage != null) {
      return RawImage(
        image: _dartImage,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
      );
    }

    // If everything failed, show error widget
    if (_state == _ImageState.error) {
      return widget.errorWidget?.call(context, widget.imageUrl, 'Decode failed') ??
          Container(
            width: widget.width,
            height: widget.height,
            color: const Color(0xFF1A1A1A),
          );
    }

    // Try platform decode first via CachedNetworkImage
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      fadeInDuration: widget.fadeInDuration,
      fadeOutDuration: widget.fadeOutDuration,
      placeholder: widget.placeholder != null
          ? (ctx, url) => widget.placeholder!(ctx, url)
          : null,
      errorWidget: (ctx, url, error) {
        // Schedule the fallback — don't block the build method
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onPlatformDecodeFailed();
        });
        // While the fallback is loading, show placeholder or a subtle indicator
        return widget.placeholder?.call(context, url) ??
            Container(
              width: widget.width,
              height: widget.height,
              color: const Color(0xFF1A1A1A),
              child: _state == _ImageState.fallbackLoading
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFF666666),
                        ),
                      ),
                    )
                  : null,
            );
      },
    );
  }
}

enum _ImageState { loading, fallbackLoading, fallbackOk, error }
