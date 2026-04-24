import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_theme.dart';
import 'details_widgets.dart';

class CollectionItemsSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<String> onItemTap;

  const CollectionItemsSection({
    super.key,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionLabel('Collection Items'),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final id = item['id']?.toString() ?? '';
            final title = item['title']?.toString() ?? 'Unknown';
            final thumbnail = item['thumbnail']?.toString() ?? '';
            final ratings = item['ratings']?.toString() ?? '';
            final overview = item['overview']?.toString() ?? '';

            return FocusableControl(
              onTap: () => onItemTap(id),
              borderRadius: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (thumbnail.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: thumbnail,
                          width: 120,
                          height: 68,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            width: 120,
                            height: 68,
                            color: AppTheme.surfaceContainerHigh.withValues(
                              alpha: 0.3,
                            ),
                            child: Icon(
                              Icons.movie,
                              color: AppTheme.textDisabled,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (ratings.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              ratings,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (overview.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              overview,
                              style: TextStyle(
                                color: AppTheme.textDisabled,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppTheme.textDisabled,
                      size: 16,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class RecommendationsSection extends StatelessWidget {
  final List<Map<String, dynamic>> recommendations;
  final bool isLoading;
  final ScrollController scrollController;
  final ValueChanged<Map<String, dynamic>> onItemTap;

  const RecommendationsSection({
    super.key,
    required this.recommendations,
    required this.isLoading,
    required this.scrollController,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionLabel('Similar'),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.current.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              sectionLabel('Similar'),
              const Spacer(),
              Row(
                children: [
                  scrollArrow(
                    Icons.arrow_back_ios_rounded,
                    () => scrollController.animateTo(
                      scrollController.offset - 260,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                    ),
                  ),
                  scrollArrow(
                    Icons.arrow_forward_ios_rounded,
                    () => scrollController.animateTo(
                      scrollController.offset + 260,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: recommendations.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final rec = recommendations[index];
                final poster = rec['poster']?.toString() ?? '';
                final name = rec['name']?.toString() ?? 'Unknown';

                return FocusableControl(
                  onTap: () => onItemTap(rec),
                  borderRadius: 10,
                  child: SizedBox(
                    width: 115,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 115,
                            height: 150,
                            color: AppTheme.bgCard,
                            child: poster.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: poster,
                                    fit: BoxFit.cover,
                                    width: 115,
                                    height: 150,
                                    placeholder: (_, _) =>
                                        Container(color: AppTheme.bgCard),
                                    errorWidget: (_, _, _) => Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Text(
                                          name,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textDisabled,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Text(
                                        name,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textDisabled,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
