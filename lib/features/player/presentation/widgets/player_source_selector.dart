import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/models/stream_models.dart';
import 'package:streame/core/models/source_presentation.dart';
import 'package:streame/core/services/stream_resolver.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';

/// Full-screen source selector overlay (Nuvio: SourceSelectorScreen)
class PlayerSourceSelector extends StatelessWidget {
  final String? backdropUrl;
  final String? logoUrl;
  final String? mediaTitle;
  final String mediaType;
  final int mediaId;
  final List<AddonStreamResult> streamResults;
  final int selectedSourceIndex;
  final String? sourceFilter;
  final void Function(int) onSourceChange;
  final void Function(String?) onFilterChange;
  final VoidCallback onClose;

  const PlayerSourceSelector({
    super.key,
    required this.backdropUrl,
    required this.logoUrl,
    required this.mediaTitle,
    required this.mediaType,
    required this.mediaId,
    required this.streamResults,
    required this.selectedSourceIndex,
    required this.sourceFilter,
    required this.onSourceChange,
    required this.onFilterChange,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<int>>{};
    for (var i = 0; i < streamResults.length; i++) {
      final name = streamResults[i].addonName;
      groups.putIfAbsent(name, () => []).add(i);
    }

    final filteredGroups = sourceFilter == null
        ? groups
        : Map.fromEntries(groups.entries.where((e) => e.key == sourceFilter));

    return Container(
      color: AppTheme.backgroundDark,
      child: Stack(
        children: [
          if (backdropUrl != null)
            Positioned.fill(
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: ResilientNetworkImage(
                    imageUrl: backdropUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          Positioned.fill(child: ColoredBox(color: AppTheme.backgroundDark)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 8, right: 12),
                  child: Row(
                    children: [
                      _HeaderCircleButton(
                        icon: Icons.arrow_back,
                        size: 20,
                        onPressed: onClose,
                        semanticLabel: 'Back',
                      ),
                      const Spacer(),
                      _HeaderCircleButton(
                        icon: Icons.close,
                        size: 20,
                        onPressed: onClose,
                        semanticLabel: 'Close',
                      ),
                    ],
                  ),
                ),
                if (logoUrl != null || mediaTitle != null)
                  Container(
                    height: 100,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: logoUrl != null
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 80, maxWidth: 300),
                            child: ResilientNetworkImage(
                              imageUrl: logoUrl!,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => _titleFallback(),
                            ),
                          )
                        : _titleFallback(),
                  ),
                if (groups.length > 1)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _SourceFilterChip(
                          label: 'All',
                          isSelected: sourceFilter == null,
                          onTap: () => onFilterChange(null),
                        ),
                        const SizedBox(width: 8),
                        ...groups.keys.map((name) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _SourceFilterChip(
                            label: name,
                            isSelected: sourceFilter == name,
                            onTap: () => onFilterChange(name),
                          ),
                        )),
                      ],
                    ),
                  ),
                Expanded(
                  child: filteredGroups.isEmpty
                      ? const _SourceEmptyState()
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          children: [
                            for (final entry in filteredGroups.entries) ...[
                              if (sourceFilter == null && filteredGroups.length > 1)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              for (final index in entry.value)
                                _StreamCard(
                                  addonName: streamResults[index].addonName,
                                  stream: StreamResolver.sortForPlayback(streamResults[index].streams).firstOrNull,
                                  isSelected: index == selectedSourceIndex,
                                  onTap: () => onSourceChange(index),
                                ),
                            ],
                            if (streamResults.isEmpty)
                              const _SourceEmptyState(),
                            const SizedBox(height: 32),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleFallback() {
    return Text(
      mediaTitle ?? 'Select Source',
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets (private to this file)
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

class _SourceFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SourceFilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.textPrimary : AppTheme.textPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.textPrimary : AppTheme.textPrimary.withValues(alpha: 0.12),
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.backgroundDark : AppTheme.textPrimary.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

class _StreamCard extends StatelessWidget {
  final String addonName;
  final StreamSource? stream;
  final bool isSelected;
  final VoidCallback onTap;

  const _StreamCard({
    required this.addonName,
    this.stream,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = stream;
    if (s == null) return const SizedBox.shrink();

    final p = presentSource(s, addonName);
    final sizeLabel = formatSizeBytes(p.sizeBytes);

    return Semantics(
      button: true,
      label: p.title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: const BoxConstraints(minHeight: 68),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.textPrimary.withValues(alpha: 0.12)
                : AppTheme.textPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.textPrimary : AppTheme.textPrimary.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(color: AppTheme.backgroundDark.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.title,
                            style: TextStyle(
                              color: isSelected ? AppTheme.textPrimary : AppTheme.textPrimary.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: p.qualityColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            p.resolutionLabel,
                            style: TextStyle(color: p.qualityColor, fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...p.chips.take(10).map((chip) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundCard,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                chip.label,
                                style: TextStyle(
                                  color: chip.color == AppTheme.textSecondary
                                      ? AppTheme.textPrimary.withValues(alpha: 0.78)
                                      : chip.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          )),
                          if (sizeLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundCard,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  sizeLabel,
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppTheme.textPrimary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceEmptyState extends StatelessWidget {
  const _SourceEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.search_off, color: AppTheme.textPrimary.withValues(alpha: 0.4), size: 48),
          const SizedBox(height: 12),
          Text('No sources available', style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: 0.7), fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Try adding more addons in Settings', style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: 0.45), fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
