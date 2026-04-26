import 'package:flutter/material.dart';
import 'package:streame_core/models/torrent_result.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'package:streame_core/api/stremio_service.dart';
import 'details_widgets.dart';

class TorrentTile extends StatelessWidget {
  final TorrentResult result;
  final double progress;
  final bool isResumable;
  final Duration? startPosition;
  final Duration? resumePosition;
  final String trackerName;
  final VoidCallback onPlay;
  final VoidCallback onCopyMagnet;

  const TorrentTile({
    super.key,
    required this.result,
    this.progress = 0,
    this.isResumable = false,
    this.startPosition,
    this.resumePosition,
    required this.trackerName,
    required this.onPlay,
    required this.onCopyMagnet,
  });

  @override
  Widget build(BuildContext context) {
    final n = result.name.toUpperCase();
    String quality = '?';
    Color qColor = Colors.grey;
    if (n.contains('2160') || n.contains('4K') || n.contains('UHD')) {
      quality = '4K';
      qColor = const Color(0xFF7C3AED);
    } else if (n.contains('1080')) {
      quality = '1080p';
      qColor = const Color(0xFF1D4ED8);
    } else if (n.contains('720')) {
      quality = '720p';
      qColor = const Color(0xFF0369A1);
    } else if (n.contains('480')) {
      quality = '480p';
      qColor = Colors.grey.shade700;
    }

    String? codec;
    if (n.contains('HEVC') || n.contains('X265') || n.contains('H.265')) {
      codec = 'HEVC';
    } else if (n.contains('X264') ||
        n.contains('H.264') ||
        n.contains('H264') ||
        n.contains('AVC')) {
      codec = 'h264';
    } else if (n.contains('AV1')) {
      codec = 'AV1';
    }

    return FocusableControl(
      onTap: onPlay,
      borderRadius: 10,
      child: Container(
        decoration: BoxDecoration(
          color: (isResumable || startPosition != null)
              ? AppTheme.current.primaryColor.withValues(alpha: 0.08)
              : AppTheme.surfaceContainerHigh.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isResumable
                ? AppTheme.current.primaryColor.withValues(alpha: 0.35)
                : AppTheme.border,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 52,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        qualityBadge(quality, qColor),
                        if (codec != null) ...[
                          const SizedBox(height: 4),
                          codecBadge(codec),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isResumable)
                          const Text(
                            'RESUME',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        Text(
                          result.name,
                          maxLines: 3,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 11,
                                  color: Color(0xFF22C55E),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  result.seeders,
                                  style: const TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              result.size,
                              style: TextStyle(
                                color: AppTheme.textDisabled,
                                fontSize: 11,
                              ),
                            ),
                            if (trackerName.isNotEmpty)
                              Text(
                                trackerName,
                                style: const TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      iconBtn(Icons.content_copy_rounded, false, onCopyMagnet),
                      const SizedBox(height: 6),
                      iconBtn(
                        Icons.play_arrow_rounded,
                        true,
                        onPlay,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isResumable && progress > 0)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.transparent,
                    color: AppTheme.primaryColor,
                    minHeight: 2.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class StremioTile extends StatelessWidget {
  final Map<String, dynamic> stream;
  final String title;
  final String description;
  final double progress;
  final bool isResumable;
  final Duration? startPosition;
  final Duration? resumePosition;
  final String selectedSourceId;
  final VoidCallback onPlay;

  const StremioTile({
    super.key,
    required this.stream,
    required this.title,
    required this.description,
    this.progress = 0,
    this.isResumable = false,
    this.startPosition,
    this.resumePosition,
    required this.selectedSourceId,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final externalUrl = stream['externalUrl']?.toString();
    final isExternal = externalUrl != null && externalUrl.isNotEmpty;
    final bool isStremioLink =
        isExternal && externalUrl.startsWith('stremio://');
    final bool isWebLink = isExternal &&
        (externalUrl.startsWith('http://') ||
            externalUrl.startsWith('https://'));
    final String? addonName = stream['_addonName']?.toString();

    IconData leadingIcon;
    Color leadingColor;
    IconData actionIcon;
    if (isStremioLink) {
      final parsed = StremioService.parseMetaLink(externalUrl);
      final action = parsed?['action'];
      if (action == 'detail') {
        leadingIcon = Icons.movie_outlined;
        leadingColor = Colors.amberAccent;
        actionIcon = Icons.open_in_new_rounded;
      } else if (action == 'search') {
        leadingIcon = Icons.search_rounded;
        leadingColor = Colors.cyanAccent;
        actionIcon = Icons.search_rounded;
      } else {
        leadingIcon = Icons.explore_outlined;
        leadingColor = Colors.tealAccent;
        actionIcon = Icons.open_in_new_rounded;
      }
    } else if (isWebLink) {
      leadingIcon = Icons.language_rounded;
      leadingColor = Colors.lightBlueAccent;
      actionIcon = Icons.open_in_browser_rounded;
    } else if (isResumable) {
      leadingIcon = Icons.play_circle_filled_rounded;
      leadingColor = AppTheme.primaryColor;
      actionIcon = Icons.play_arrow_rounded;
    } else {
      leadingIcon = Icons.extension_rounded;
      leadingColor = Colors.blueAccent;
      actionIcon = Icons.play_arrow_rounded;
    }

    return FocusableControl(
      onTap: onPlay,
      borderRadius: 10,
      child: Container(
        decoration: BoxDecoration(
          color: isExternal
              ? leadingColor.withValues(alpha: 0.06)
              : ((isResumable || startPosition != null)
                  ? AppTheme.current.primaryColor.withValues(alpha: 0.08)
                  : AppTheme.surfaceContainerHigh.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isExternal
                ? leadingColor.withValues(alpha: 0.25)
                : (isResumable
                    ? AppTheme.current.primaryColor.withValues(alpha: 0.35)
                    : AppTheme.border),
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(leadingIcon, color: leadingColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isResumable && !isExternal)
                          const Text(
                            'RESUME',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        if (addonName != null &&
                            selectedSourceId == 'all_stremio')
                          Text(
                            addonName,
                            style: TextStyle(
                              color: leadingColor.withValues(alpha: 0.7),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        Text(
                          title,
                          maxLines: 4,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textDisabled,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  iconBtn(
                    actionIcon,
                    true,
                    onPlay,
                  ),
                ],
              ),
            ),
            if (isResumable && progress > 0 && !isExternal)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.transparent,
                    color: AppTheme.primaryColor,
                    minHeight: 2.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

