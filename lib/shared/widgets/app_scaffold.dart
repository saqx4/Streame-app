import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/focus/tv_widgets.dart';

/// Navigation items shared across all sidebar/bottom-nav screens
const _navItems = [
  SidebarItem(icon: Icons.home_rounded, label: 'Home'),
  SidebarItem(icon: Icons.search_rounded, label: 'Search'),
  SidebarItem(icon: Icons.bookmark_rounded, label: 'Vault'),
  SidebarItem(icon: Icons.person_rounded, label: 'Profile'),
];

const _navRoutes = ['/home', '/search', '/watchlist', '/settings'];

/// Breakpoint: use sidebar on wide screens, bottom nav on narrow
const _kWideBreakpoint = 600.0;

/// A shared scaffold that includes the TV sidebar on wide screens
/// and a bottom navigation bar on narrow/mobile screens.
class AppScaffold extends StatefulWidget {
  final Widget child;
  final bool showSidebar;

  const AppScaffold({
    super.key,
    required this.child,
    this.showSidebar = true,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSelectedIndex();
  }

  void _updateSelectedIndex() {
    final GoRouterState? state;
    try {
      state = GoRouterState.of(context);
    } catch (_) {
      return; // Not yet in router tree during transition
    }
    final location = state.matchedLocation;
    final idx = _navRoutes.indexWhere((route) => location.startsWith(route));
    if (idx >= 0 && idx != _selectedIndex) {
      setState(() => _selectedIndex = idx);
    }
  }

  void _onNavSelected(int index) {
    setState(() => _selectedIndex = index);
    context.go(_navRoutes[index]);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showSidebar) {
      return widget.child;
    }

    final width = MediaQuery.of(context).size.width;
    final isWide = width >= _kWideBreakpoint;

    if (isWide) {
      // TV / tablet / desktop: sidebar layout
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Row(
          children: [
            TvSidebar(
              items: _navItems,
              selectedIndex: _selectedIndex,
              onSelected: _onNavSelected,
            ),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    // Mobile: bottom navigation bar
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundCard.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(
              color: AppTheme.borderLight.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = _selectedIndex == index;
                return _NavBarItem(
                  icon: item.icon,
                  label: item.label,
                  isSelected: isSelected,
                  onTap: () => _onNavSelected(index),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual navigation bar item with modern design
class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.textPrimary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textTertiary,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
