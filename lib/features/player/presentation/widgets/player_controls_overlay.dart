import 'package:flutter/material.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';

/// Player controls overlay data bundle
class PlayerControlsData {
  final String? logoUrl;
  final String? mediaTitle;
  final String mediaType;
  final int mediaId;
  final int? seasonNumber;
  final int? episodeNumber;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double playbackSpeed;
  final List<dynamic> streamResults;
  final int selectedSourceIndex;
  final String? sourceFilter;
  final bool showSourceSelector;

  const PlayerControlsData({
    required this.logoUrl,
    required this.mediaTitle,
    required this.mediaType,
    required this.mediaId,
    this.seasonNumber,
    this.episodeNumber,
    required this.isPlaying,
    required this.isBuffering,
    required this.position,
    required this.duration,
    required this.playbackSpeed,
    required this.streamResults,
    required this.selectedSourceIndex,
    required this.sourceFilter,
    required this.showSourceSelector,
  });
}

/// Player controls callbacks bundle
class PlayerControlsCallbacks {
  final VoidCallback onExit;
  final VoidCallback onSeekBackward;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekForward;
  final void Function(double) onSeek;
  final void Function(double) onSetSpeed;
  final VoidCallback onShowSubtitles;
  final VoidCallback onShowAudio;
  final VoidCallback onShowSources;
  final VoidCallback onShowEpisodes;
  final VoidCallback onFit;

  const PlayerControlsCallbacks({
    required this.onExit,
    required this.onSeekBackward,
    required this.onTogglePlay,
    required this.onSeekForward,
    required this.onSeek,
    required this.onSetSpeed,
    required this.onShowSubtitles,
    required this.onShowAudio,
    required this.onShowSources,
    required this.onShowEpisodes,
    required this.onFit,
  });
}

/// Full controls overlay (Nuvio: PlayerControlsShell)
class PlayerControlsOverlay extends StatelessWidget {
  final PlayerControlsData data;
  final PlayerControlsCallbacks callbacks;

  const PlayerControlsOverlay({
    super.key,
    required this.data,
    required this.callbacks,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top gradient
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: IgnorePointer(child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.backgroundDark.withValues(alpha: 0.7), Colors.transparent],
              ),
            ),
          )),
        ),
        // Bottom gradient
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 220,
          child: IgnorePointer(child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppTheme.backgroundDark.withValues(alpha: 0.7)],
              ),
            ),
          )),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildHeader(),
            _buildCenterControls(),
            _buildBottomControls(),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.logoUrl != null && data.logoUrl!.isNotEmpty)
                    IgnorePointer(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120, maxHeight: 30),
                        child: ResilientNetworkImage(
                          imageUrl: data.logoUrl!,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Text(
                            data.mediaTitle ?? '${data.mediaType} ${data.mediaId}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              height: 1.16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      data.mediaTitle ?? '${data.mediaType} ${data.mediaId}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (data.seasonNumber != null && data.episodeNumber != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'S${data.seasonNumber} E${data.episodeNumber}',
                      style: TextStyle(
                        color: AppTheme.textPrimary.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (data.streamResults.isNotEmpty) ...[
                        Text(
                          (data.streamResults[data.selectedSourceIndex] as dynamic).addonName as String,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _HeaderCircleButton(
              icon: Icons.lock_open,
              size: 20,
              onPressed: () {},
              semanticLabel: 'Unlock controls',
            ),
            const SizedBox(width: 10),
            _HeaderCircleButton(
              icon: Icons.arrow_back,
              size: 20,
              onPressed: callbacks.onExit,
              semanticLabel: 'Exit player',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: 'Seek back 10 seconds',
          child: GestureDetector(
            onTap: callbacks.onSeekBackward,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.replay_10, color: AppTheme.textPrimary, size: 34),
            ),
          ),
        ),
        const SizedBox(width: 56),
        Semantics(
          button: true,
          label: data.isPlaying ? 'Pause' : 'Play',
          child: GestureDetector(
            onTap: callbacks.onTogglePlay,
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: data.isBuffering
                  ? SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(color: AppTheme.textPrimary, strokeWidth: 3),
                    )
                  : Icon(
                      data.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AppTheme.textPrimary,
                      size: 44,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 56),
        Semantics(
          button: true,
          label: 'Seek forward 10 seconds',
          child: GestureDetector(
            onTap: callbacks.onSeekForward,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.forward_10, color: AppTheme.textPrimary, size: 34),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    final progress = data.duration.inMilliseconds > 0
        ? data.position.inMilliseconds / data.duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.textPrimary,
              inactiveTrackColor: AppTheme.arcticWhite30,
              thumbColor: AppTheme.textPrimary,
              trackHeight: 3,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: callbacks.onSeek,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TimePill(text: _formatDuration(data.position)),
                _TimePill(text: _formatDuration(data.duration)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.arcticWhite12, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionPillButton(icon: Icons.aspect_ratio, label: 'Fit', onPressed: callbacks.onFit),
                  _ActionPillButton(
                    icon: Icons.speed,
                    label: '${data.playbackSpeed.toString().replaceAll(RegExp(r'\.?0+$'), '')}x',
                    onPressed: () => callbacks.onSetSpeed(data.playbackSpeed >= 2.0 ? 0.5 : data.playbackSpeed + 0.25),
                  ),
                  _ActionPillButton(icon: Icons.subtitles, label: 'Subs', onPressed: callbacks.onShowSubtitles),
                  _ActionPillButton(icon: Icons.audiotrack, label: 'Audio', onPressed: callbacks.onShowAudio),
                  if (data.streamResults.isNotEmpty)
                    _ActionPillButton(
                      icon: Icons.swap_horiz,
                      label: 'Sources',
                      onPressed: callbacks.onShowSources,
                    ),
                  if (data.seasonNumber != null)
                    _ActionPillButton(
                      icon: Icons.video_library,
                      label: 'Episodes',
                      onPressed: callbacks.onShowEpisodes,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final String? semanticLabel;

  const _HeaderCircleButton({required this.icon, required this.size, required this.onPressed, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final buttonSize = size + 24;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppTheme.textPrimary, size: size),
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  final String text;
  const _TimePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionPillButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppTheme.textPrimary, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
