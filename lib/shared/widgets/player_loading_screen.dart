import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/services/torrent_stream_service.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';

/// Opening overlay matching Nuvio's OpeningOverlay composable.
/// Full-screen dark backdrop, back button top-right, center logo/title with pulse, torrent stats.
class PlayerLoadingScreen extends StatefulWidget {
  final String? backdropUrl;
  final String? logoUrl;
  final String title;
  final String? subtitle;
  final String loadingMessage;
  final double? progress;
  final bool isError;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;
  final TorrentStats? torrentStats;

  const PlayerLoadingScreen({
    super.key,
    this.backdropUrl,
    this.logoUrl,
    this.title = '',
    this.subtitle,
    this.loadingMessage = 'Loading sources...',
    this.progress,
    this.isError = false,
    this.onRetry,
    this.onBack,
    this.torrentStats,
  });

  @override
  State<PlayerLoadingScreen> createState() => _PlayerLoadingScreenState();
}

class _PlayerLoadingScreenState extends State<PlayerLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final AnimationController _fadeInController;
  late final Animation<double> _fadeInAlpha;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.linear),
    );
    _pulseController.repeat(reverse: true);

    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeInAlpha = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.linear,
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fadeInController.forward();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop image
          if (widget.backdropUrl != null)
            Positioned.fill(
              child: ResilientNetworkImage(
                imageUrl: widget.backdropUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          // Gradient overlay: black 0.3 → 0.6 → 0.8 → 0.9
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x4D000000),
                    Color(0x99000000),
                    Color(0xCC000000),
                    Color(0xE6000000),
                  ],
                  stops: [0.0, 0.33, 0.66, 1.0],
                ),
              ),
            ),
          ),

          // Back button — top-right
          Positioned(
            top: 20,
            right: 20,
            child: _CircleButton(
              icon: Icons.arrow_back,
              iconSize: 24,
              buttonSize: 44,
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              onPressed: widget.onBack ?? () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/home');
                }
              },
            ),
          ),

          // Center: logo or title with pulse + fade-in
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseScale, _fadeInAlpha]),
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeInAlpha.value,
                  child: Transform.scale(
                    scale: _pulseScale.value,
                    child: child,
                  ),
                );
              },
              child: _buildCenterContent(),
            ),
          ),

          // Bottom: loading message + torrent stats + spinner
          if (!widget.isError)
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.loadingMessage.isNotEmpty)
                    Text(
                      widget.loadingMessage,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  if (widget.torrentStats != null) ...[
                    const SizedBox(height: 10),
                    _TorrentStatsBar(stats: widget.torrentStats!),
                  ],
                  if (widget.loadingMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Error state
          if (widget.isError)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 48),
                    const SizedBox(height: 16),
                    const Text('Playback Error', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(widget.loadingMessage, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 16), textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 20),
                    if (widget.onRetry != null)
                      SizedBox(
                        width: 220,
                        child: ElevatedButton(
                          onPressed: widget.onRetry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Go Back', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCenterContent() {
    if (widget.logoUrl != null && widget.logoUrl!.isNotEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 180),
        child: ResilientNetworkImage(
          imageUrl: widget.logoUrl!,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => _buildTitleFallback(),
        ),
      );
    }
    return _buildTitleFallback();
  }

  Widget _buildTitleFallback() {
    if (widget.title.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return const SizedBox(width: 54, height: 54, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3));
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final double buttonSize;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const _CircleButton({required this.icon, required this.iconSize, required this.buttonSize, required this.backgroundColor, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}

class _TorrentStatsBar extends StatelessWidget {
  final TorrentStats stats;
  const _TorrentStatsBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statPill(Icons.speed, stats.speedLabel),
          const SizedBox(width: 12),
          _statPill(Icons.people, stats.peersLabel),
          const SizedBox(width: 12),
          _statPill(Icons.downloading, stats.bufferLabel),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Icon(icon, color: Colors.white, size: 16)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }
}

/// Compact buffering indicator for overlay on video during playback
class BufferingIndicator extends StatefulWidget {
  const BufferingIndicator({super.key});

  @override
  State<BufferingIndicator> createState() => _BufferingIndicatorState();
}

class _BufferingIndicatorState extends State<BufferingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(angle: _controller.value * 2 * math.pi, child: child),
      child: Container(
        width: 54, height: 54,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
      ),
    );
  }
}
