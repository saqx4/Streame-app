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
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16, color: AppTheme.textSecondary),
        onPressed: () {
          if (!scrollController.hasClients) return;
          final target = (scrollController.offset + delta).clamp(
            0.0,
            scrollController.position.maxScrollExtent,
          );
          scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }
}
