import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:streame_core/utils/app_theme.dart';
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
            return _CollectionCard(
              item: item,
              onTap: () => onItemTap(item['id']?.toString() ?? ''),
            );
          },
        ),
      ],
    );
  }
}

class _CollectionCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _CollectionCard({required this.item, required this.onTap});

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.item['title']?.toString() ?? 'Unknown';
    final thumbnail = widget.item['thumbnail']?.toString() ?? '';
    final ratings = widget.item['ratings']?.toString() ?? '';
    final overview = widget.item['overview']?.toString() ?? '';
    final primary = AppTheme.current.primaryColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: FocusableControl(
        onTap: widget.onTap,
        borderRadius: AppRadius.card,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AnimationPresets.smoothInOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isHovered ? GlassColors.surfaceSubtle.withValues(alpha: 0.9) : GlassColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: _isHovered ? primary.withValues(alpha: 0.3) : GlassColors.borderSubtle,
              width: _isHovered ? 1.0 : 0.5,
            ),
            boxShadow: _isHovered ? [AppShadows.glow(0.08)] : null,
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
                      color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
                      child: Icon(Icons.movie, color: AppTheme.textDisabled),
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
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ratings.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(ratings, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                    if (overview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(overview, style: TextStyle(color: AppTheme.textDisabled, fontSize: 11),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              AnimatedScale(
                duration: AppDurations.fast,
                scale: _isHovered ? 1.15 : 1.0,
                child: Icon(Icons.arrow_forward_ios,
                  color: _isHovered ? primary : AppTheme.textDisabled, size: 16),
              ),
            ],
          ),
        ),
      ),
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
                return _RecommendationCard(
                  rec: rec,
                  onTap: () => onItemTap(rec),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatefulWidget {
  final Map<String, dynamic> rec;
  final VoidCallback onTap;

  const _RecommendationCard({required this.rec, required this.onTap});

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final poster = widget.rec['poster']?.toString() ?? '';
    final name = widget.rec['name']?.toString() ?? 'Unknown';
    final primary = AppTheme.current.primaryColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: FocusableControl(
        onTap: widget.onTap,
        borderRadius: 10,
        child: SizedBox(
          width: 115,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: AppDurations.fast,
                curve: AnimationPresets.smoothInOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isHovered ? primary.withValues(alpha: 0.5) : Colors.transparent,
                    width: _isHovered ? 1.0 : 0,
                  ),
                  boxShadow: _isHovered ? [AppShadows.glow(0.12)] : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 115,
                    height: 150,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (poster.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: poster,
                            fit: BoxFit.cover,
                            width: 115,
                            height: 150,
                            placeholder: (_, _) => Container(color: AppTheme.bgCard),
                            errorWidget: (_, _, _) => Center(
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(name, textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 10, color: AppTheme.textDisabled)),
                              ),
                            ),
                          )
                        else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(name, textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 10, color: AppTheme.textDisabled)),
                            ),
                          ),
                        if (_isHovered)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primary.withValues(alpha: 0.25),
                                border: Border.all(color: primary.withValues(alpha: 0.5), width: 1),
                                boxShadow: [AppShadows.glow(0.2)],
                              ),
                              child: Icon(Icons.play_arrow_rounded, color: AppTheme.textPrimary, size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
