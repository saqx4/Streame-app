import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:streame_core/api/tmdb_api.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'details_widgets.dart';

class DesktopCastRow extends StatelessWidget {
  final List<Map<String, String>> castMembers;
  final ScrollController scrollController;

  const DesktopCastRow({
    super.key,
    required this.castMembers,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            sectionLabel('Cast'),
            Row(
              children: [
                _castNavButton(Icons.arrow_back_ios_rounded, -300),
                const SizedBox(width: 4),
                _castNavButton(Icons.arrow_forward_ios_rounded, 300),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 155,
          child: ListView.separated(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: castMembers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final m = castMembers[i];
              final profilePath = m['profilePath'] ?? '';
              final name = m['name'] ?? '';
              final character = m['character'] ?? '';
              return SizedBox(
                width: 92,
                child: Column(
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: Stack(
                        children: [
                          if (profilePath.isNotEmpty)
                            ClipOval(
                              child: CachedNetworkImage(
                                imageUrl:
                                    TmdbApi.getProfileUrl(profilePath),
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    CircleAvatar(
                                  radius: 42,
                                  backgroundColor: AppTheme
                                      .surfaceContainerHigh
                                      .withValues(alpha: 0.3),
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: AppTheme.textDisabled,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                placeholder: (context, url) =>
                                    CircleAvatar(
                                  radius: 42,
                                  backgroundColor:
                                      AppTheme.surfaceContainerHigh
                                          .withValues(alpha: 0.3),
                                ),
                              ),
                            )
                          else
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: AppTheme
                                  .surfaceContainerHigh
                                  .withValues(alpha: 0.3),
                              child: Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: AppTheme.textDisabled,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      character,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textDisabled,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _castNavButton(IconData icon, double delta) {
    return _CastNavButton(
      icon: icon,
      delta: delta,
      scrollController: scrollController,
    );
  }
}

class _CastNavButton extends StatefulWidget {
  final IconData icon;
  final double delta;
  final ScrollController scrollController;

  const _CastNavButton({required this.icon, required this.delta, required this.scrollController});

  @override
  State<_CastNavButton> createState() => _CastNavButtonState();
}

class _CastNavButtonState extends State<_CastNavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.current.primaryColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          if (!widget.scrollController.hasClients) return;
          final target = (widget.scrollController.offset + widget.delta).clamp(
            0.0,
            widget.scrollController.position.maxScrollExtent,
          );
          widget.scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AnimationPresets.smoothInOut,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _isHovered ? primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: _isHovered ? primary.withValues(alpha: 0.3) : Colors.transparent,
              width: 0.5,
            ),
          ),
          child: Icon(widget.icon, size: 16,
            color: _isHovered ? primary : AppTheme.textSecondary),
        ),
      ),
    );
  }
}
