part of '../details_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  BACKDROP + IMAGE URL HELPER
// ═══════════════════════════════════════════════════════════════════════════════

mixin DetailsUiInfo on _DetailsScreenBase {

/// Returns a full image URL. If the path is already a full URL (e.g. from
/// Stremio), returns it as-is; otherwise wraps with TMDB base URL.
@override
String _imageUrl(String path) =>
    path.startsWith('http') ? path : TmdbApi.getBackdropUrl(path);

@override
Widget _buildBackdropWidget() {
  final url = _imageUrl(
    _movie.backdropPath.isNotEmpty ? _movie.backdropPath : _movie.posterPath,
  );
  return Stack(
    fit: StackFit.expand,
    children: [
      CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 800,
        errorWidget: (c, u, e) => Container(color: const Color(0xFF05050A)),
      ),
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (atmosphereColors?.dominant ?? const Color(0xFF05050A)).withValues(alpha: 0.5),
              const Color(0xFF05050A).withValues(alpha: 0.8),
              const Color(0xFF05050A),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  RATINGS ROW
// ═══════════════════════════════════════════════════════════════════════════════

@override
Widget _buildRatingsRow() {
  final r = _mdblistRatings;
  final chips = <Widget>[];

  Widget ratingChip(
    String label,
    dynamic value, {
    Color color = const Color(0xFFB0B0C0),
    String? icon,
  }) {
    if (value == null || value == 0) return const SizedBox.shrink();
    final display = value is double
        ? value.toStringAsFixed(1)
        : value.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            display,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  if (r != null) {
    final scores =
        r['scores'] as List<dynamic>? ?? r['ratings'] as List<dynamic>? ?? [];
    for (final s in scores) {
      final source = (s['source'] ?? '').toString();
      final value = s['value'] ?? s['score'];
      if (value == null || value == 0) continue;
      String label;
      Color color;
      switch (source.toLowerCase()) {
        case 'imdb':
          label = 'IMDb';
          color = const Color(0xFFF5C518);
        case 'metacritic':
          label = 'MC';
          color = const Color(0xFF66CC33);
        case 'metacriticuser':
          label = 'MC User';
          color = const Color(0xFF66CC33);
        case 'trakt':
          label = 'Trakt';
          color = const Color(0xFFED1C24);
        case 'letterboxd':
          label = 'LB';
          color = const Color(0xFF00D735);
        case 'tomatoes':
          label = 'RT';
          color = const Color(0xFFFA320A);
        case 'tomatoesaudience':
          label = 'RT Aud';
          color = const Color(0xFFFA320A);
        case 'tmdb':
          label = 'TMDB';
          color = const Color(0xFF01B4E4);
        default:
          label = source.toUpperCase();
          color = AppTheme.textDisabled;
      }
      chips.add(ratingChip(label, value, color: color));
    }
  }

  if (_userTraktRating != null) {
    chips.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFED1C24).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFED1C24).withValues(alpha: 0.25), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              color: Color(0xFFED1C24),
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              'Trakt',
              style: const TextStyle(
                color: Color(0xFFED1C24),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$_userTraktRating/10',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  if (_userSimklRating != null) {
    chips.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.current.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.current.primaryColor.withValues(alpha: 0.25), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: AppTheme.current.primaryColor, size: 14),
            const SizedBox(width: 4),
            Text(
              'Simkl',
              style: TextStyle(
                color: AppTheme.current.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$_userSimklRating/10',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  if (chips.isEmpty) return const SizedBox.shrink();
  return Wrap(spacing: 8, runSpacing: 8, children: chips);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ACTION BUTTONS
// ═══════════════════════════════════════════════════════════════════════════════

@override
Widget _buildActionButtons() {
  return Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _actionButton(
        icon: _userTraktRating != null
            ? Icons.star_rounded
            : Icons.star_outline_rounded,
        label: _userTraktRating != null ? 'Rate: $_userTraktRating' : 'Rate',
        active: _userTraktRating != null,
        onTap: () async {
          if (await TraktService().isLoggedIn()) {
            _showRatingDialog();
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Login to Trakt in Settings')),
            );
          }
        },
      ),
      _actionButton(
        icon: _isInTraktCollection
            ? Icons.library_add_check_rounded
            : Icons.library_add_rounded,
        label: _isInTraktCollection ? 'Collected' : 'Collect',
        active: _isInTraktCollection,
        onTap: _toggleTraktCollection,
      ),
      _actionButton(
        icon: Icons.live_tv_rounded,
        label: 'Check In',
        active: false,
        onTap: _traktCheckin,
      ),
      _actionButton(
        icon: Icons.playlist_add_rounded,
        label: 'Add to List',
        active: false,
        onTap: _addToTraktList,
      ),
    ],
  );
}

@override
Widget _actionButton({
  required IconData icon,
  required String label,
  required bool active,
  required VoidCallback onTap,
}) {
  return _HoverActionButton(icon: icon, label: label, active: active, onTap: onTap);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SMALL REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

@override
Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppTheme.current.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );

@override
Widget _genreChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.current.primaryColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.current.primaryColor.withValues(alpha: 0.12), width: 0.5),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

@override
Widget _castChip(String name) {
  final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
  return Container(
    padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
    decoration: BoxDecoration(
      color: GlassColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: GlassColors.borderSubtle, width: 0.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.current.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: AppTheme.current.primaryColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(name, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    ),
  );
}

@override
Widget _scrollArrow(IconData icon, VoidCallback onTap) => _HoverScrollArrow(icon: icon, onTap: onTap);

}

class _HoverScrollArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HoverScrollArrow({required this.icon, required this.onTap});

  @override
  State<_HoverScrollArrow> createState() => _HoverScrollArrowState();
}

class _HoverScrollArrowState extends State<_HoverScrollArrow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.current.primaryColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AnimationPresets.smoothInOut,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _isHovered ? primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(widget.icon,
            color: _isHovered ? primary : AppTheme.textDisabled, size: 16),
        ),
      ),
    );
  }
}

class _HoverActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _HoverActionButton({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.current.primaryColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: FocusableControl(
        onTap: widget.onTap,
        borderRadius: 24,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AnimationPresets.smoothInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.active
                ? primary.withValues(alpha: _isHovered ? 0.25 : 0.18)
                : (_isHovered ? GlassColors.surfaceSubtle.withValues(alpha: 0.9) : GlassColors.surfaceSubtle),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.active
                  ? primary.withValues(alpha: _isHovered ? 0.65 : 0.5)
                  : (_isHovered ? primary.withValues(alpha: 0.25) : GlassColors.borderSubtle),
              width: widget.active ? 1.5 : 0.5,
            ),
            boxShadow: widget.active
                ? [AppShadows.glow(_isHovered ? 0.18 : 0.12)]
                : (_isHovered ? [AppShadows.glow(0.06)] : null),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppDurations.fast,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: widget.active
                      ? primary.withValues(alpha: 0.25)
                      : (_isHovered ? primary.withValues(alpha: 0.1) : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.active ? primary : (_isHovered ? AppTheme.textPrimary : AppTheme.textSecondary),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.active ? AppTheme.textPrimary : (_isHovered ? AppTheme.textPrimary : AppTheme.textSecondary),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
