import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../utils/app_theme.dart';

class NavbarSection extends StatefulWidget {
  const NavbarSection({super.key});

  @override
  State<NavbarSection> createState() => _NavbarSectionState();
}

class _NavbarSectionState extends State<NavbarSection> {
  final SettingsService _settings = SettingsService();

  static const Map<String, Map<String, dynamic>> _navMeta = {
    'home': {'icon': Icons.home, 'label': 'Home'},
    'discover': {'icon': Icons.explore, 'label': 'Discover'},
    'search': {'icon': Icons.search, 'label': 'Search'},
    'mylist': {'icon': Icons.bookmark, 'label': 'My List'},
    'magnet': {'icon': Icons.link_rounded, 'label': 'Magnet'},
  };

  List<String> _navbarVisible = [];
  List<String> _navbarOrder = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final navVisible = await _settings.getNavbarConfig();
    // Full order: visible items first, then hidden items
    const allIds = SettingsService.allNavIds;
    final hidden = allIds.where((id) => !navVisible.contains(id)).toList();
    final navOrder = [...navVisible, ...hidden];

    if (mounted) {
      setState(() {
        _navbarVisible = navVisible;
        _navbarOrder = navOrder;
      });
    }
  }

  void _saveNavbarConfig() {
    final visible = _navbarOrder
        .where((id) => _navbarVisible.contains(id))
        .toList();
    _settings.setNavbarConfig(visible);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Show, hide, and reorder navigation tabs. Drag to reorder. Settings is always visible.',
            style: TextStyle(color: AppTheme.textDisabled, fontSize: 13),
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _navbarOrder.length,
          proxyDecorator: (child, index, animation) {
            return Material(color: Colors.transparent, child: child);
          },
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _navbarOrder.removeAt(oldIndex);
              _navbarOrder.insert(newIndex, item);
            });
            _saveNavbarConfig();
          },
          itemBuilder: (context, index) {
            final id = _navbarOrder[index];
            final meta = _navMeta[id]!;
            final isVisible = _navbarVisible.contains(id);

            return Container(
              key: ValueKey(id),
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: isVisible
                    ? AppTheme.surfaceContainerHigh.withValues(alpha: 0.2)
                    : AppTheme.surfaceContainerHigh.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  meta['icon'] as IconData,
                  color: isVisible
                      ? AppTheme.textPrimary
                      : AppTheme.textDisabled,
                  size: 22,
                ),
                title: Text(
                  meta['label'] as String,
                  style: TextStyle(
                    color: isVisible
                        ? AppTheme.textPrimary
                        : AppTheme.textDisabled,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: isVisible,
                      activeTrackColor: AppTheme.primaryColor,
                      onChanged: (val) {
                        setState(() {
                          if (val) {
                            _navbarVisible.add(id);
                          } else {
                            _navbarVisible.remove(id);
                          }
                        });
                        _saveNavbarConfig();
                      },
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.drag_handle,
                          color: AppTheme.textDisabled,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Settings row — always visible, not reorderable
        Container(
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.settings,
              color: AppTheme.primaryColor,
              size: 22,
            ),
            title: const Text(
              'Settings',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  color: AppTheme.textDisabled,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Always visible',
                  style: TextStyle(color: AppTheme.textDisabled, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
