import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/focus/tv_widgets.dart';

/// Navigation items shared across all sidebar/bottom-nav screens
const _navItems = [
  SidebarItem(icon: Icons.home, label: 'Home'),
  SidebarItem(icon: Icons.search, label: 'Search'),
  SidebarItem(icon: Icons.bookmark_border, label: 'Vault'),
  SidebarItem(icon: Icons.person_outline, label: 'Profile'),
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
        decoration: const BoxDecoration(
          color: AppTheme.backgroundCard,
          border: Border(top: BorderSide(color: AppTheme.borderLight)),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.textPrimary,
          unselectedItemColor: AppTheme.textTertiary,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          currentIndex: _selectedIndex,
          onTap: _onNavSelected,
          items: _navItems.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            if (i == 3) {
              return BottomNavigationBarItem(
                icon: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderMedium),
                  ),
                  child: const Icon(Icons.person, size: 18),
                ),
                activeIcon: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.textPrimary, width: 1.5),
                  ),
                  child: const Icon(Icons.person, size: 18, color: AppTheme.textPrimary),
                ),
                label: item.label,
              );
            }
            return BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}
