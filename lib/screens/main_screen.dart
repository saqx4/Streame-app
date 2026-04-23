import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'discover_screen.dart';
import 'search_screen.dart';
import 'my_list_screen.dart';
import 'settings_screen.dart';
import 'magnet_player_screen.dart';
import '../utils/app_theme.dart';
import '../services/settings_service.dart';
import '../services/app_updater_service.dart';
import '../widgets/update_dialog.dart';
import '../providers/service_providers.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  /// Notifier that SearchScreen listens to for incoming Stremio search requests.
  /// Value is {'query': '...', 'addonBaseUrl': '...'} or null.
  static final ValueNotifier<Map<String, String>?> stremioSearchNotifier = ValueNotifier<Map<String, String>?>(null);

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Timer? _metricsDebounce;
  Timer? _metricsSafety;

  /// All screens keyed by nav ID — created once, never recreated.
  late final Map<String, Widget> _allScreens;

  /// Nav item metadata keyed by nav ID.
  static const Map<String, Map<String, dynamic>> _navMeta = {
    'home':         {'icon': Icons.home_outlined,              'active': Icons.home,                    'label': 'Home'},
    'discover':     {'icon': Icons.explore_outlined,            'active': Icons.explore,                 'label': 'Discover'},
    'search':       {'icon': Icons.search,                      'active': Icons.search,                  'label': 'Search'},
    'mylist':       {'icon': Icons.bookmark_outline,            'active': Icons.bookmark,                'label': 'My List'},
    'magnet':       {'icon': Icons.link_rounded,                'active': Icons.link_rounded,            'label': 'Magnet'},
    'settings':     {'icon': Icons.settings_outlined,           'active': Icons.settings,                'label': 'Settings'},
  };

  /// Currently visible nav IDs (always ends with 'settings').
  List<String> _visibleIds = [...SettingsService.allNavIds, 'settings'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MainScreen.stremioSearchNotifier.addListener(_onStremioSearch);
    SettingsService.navbarChangeNotifier.addListener(_onNavbarConfigChanged);

    _allScreens = {
      'home':         const HomeScreen(),
      'discover':     const DiscoverScreen(),
      'search':       const SearchScreen(),
      'mylist':       const MyListScreen(),
      'magnet':       const MagnetPlayerScreen(),
      'settings':     const SettingsScreen(),
    };

    _loadNavbarConfig();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      final updater = AppUpdaterService();
      final updateInfo = await updater.checkForUpdates();
      if (updateInfo != null && mounted) {
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => UpdateDialog(updateInfo: updateInfo),
        );
      }
    } catch (e) {
      debugPrint('[MainScreen] Update check failed: $e');
    }
  }

  Future<void> _loadNavbarConfig() async {
    final settings = ref.read(settingsServiceProvider);
    final visible = await settings.getNavbarConfig();
    if (!mounted) return;
    setState(() {
      // Remember which screen we're currently on
      final currentId = _selectedIndex < _visibleIds.length
          ? _visibleIds[_selectedIndex]
          : null;
      _visibleIds = [...visible, 'settings'];
      // Try to stay on the same screen after reorder/hide
      if (currentId != null) {
        final newIndex = _visibleIds.indexOf(currentId);
        if (newIndex >= 0) {
          _selectedIndex = newIndex;
        } else if (_selectedIndex >= _visibleIds.length) {
          _selectedIndex = _visibleIds.length - 1;
        }
      } else if (_selectedIndex >= _visibleIds.length) {
        _selectedIndex = 0;
      }
    });
  }

  void _onNavbarConfigChanged() {
    _loadNavbarConfig();
  }

  /// Rotation on MediaTek/Transsion can cause a multi-second frame storm.
  /// Two-timer strategy:
  ///   1. Debounced timer (1.5s): resets on every metrics change, fires
  ///      after the storm quiets down.
  ///   2. Safety timer (4s): fires once after the FIRST metrics change—
  ///      never cancelled—so even if the storm outlasts the debounce,
  ///      a clean rebuild is guaranteed.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Debounced: fires 1.5s after the LAST metrics change.
    _metricsDebounce?.cancel();
    _metricsDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() {});
    });
    // Safety: fires 4s after the FIRST metrics change. Never cancelled.
    _metricsSafety ??= Timer(const Duration(seconds: 4), () {
      _metricsSafety = null;
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      // Only re-apply immersive mode; do NOT reset preferred orientations
      // here — it interferes with the player's orientation lock when the
      // player is pushed on top of this screen.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _onStremioSearch() {
    final data = MainScreen.stremioSearchNotifier.value;
    if (data == null || (data['query'] ?? '').isEmpty) return;
    final idx = _visibleIds.indexOf('search');
    if (idx != -1) setState(() => _selectedIndex = idx);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }


  @override
  void dispose() {
    _metricsDebounce?.cancel();
    _metricsSafety?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    MainScreen.stremioSearchNotifier.removeListener(_onStremioSearch);
    SettingsService.navbarChangeNotifier.removeListener(_onNavbarConfigChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Row(
        children: [
          if (!isMobile) _ModernSideRail(
            visibleIds: _visibleIds,
            selectedIndex: _selectedIndex,
            navMeta: _navMeta,
            onItemTapped: _onItemTapped,
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _visibleIds.map((id) => _allScreens[id]!).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _ModernBottomNav(
        visibleIds: _visibleIds,
        selectedIndex: _selectedIndex,
        navMeta: _navMeta,
        onItemTapped: _onItemTapped,
      ) : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MODERN SIDE RAIL — collapsible, hover-to-expand (Netflix/OSN+ style)
// ═══════════════════════════════════════════════════════════════════════════

class _ModernSideRail extends StatefulWidget {
  final List<String> visibleIds;
  final int selectedIndex;
  final Map<String, Map<String, dynamic>> navMeta;
  final ValueChanged<int> onItemTapped;

  const _ModernSideRail({
    required this.visibleIds,
    required this.selectedIndex,
    required this.navMeta,
    required this.onItemTapped,
  });

  @override
  State<_ModernSideRail> createState() => _ModernSideRailState();
}

class _ModernSideRailState extends State<_ModernSideRail> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final collapsedWidth = 72.0;
    final expandedWidth = 200.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isExpanded = true),
      onExit: (_) => setState(() => _isExpanded = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        clipBehavior: Clip.hardEdge,
        width: _isExpanded ? expandedWidth : collapsedWidth,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDim,
          border: Border(right: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // App branding
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _buildBranding(),
            ),
            const SizedBox(height: 8),
            // Nav items
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 12 : 10),
                itemCount: widget.visibleIds.length,
                itemBuilder: (context, index) {
                  final id = widget.visibleIds[index];
                  final meta = widget.navMeta[id]!;
                  final isSelected = widget.selectedIndex == index;
                  return _buildNavItem(
                    id: id,
                    meta: meta,
                    isSelected: isSelected,
                    index: index,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: EdgeInsets.all(_isExpanded ? 10 : 10),
      decoration: BoxDecoration(
        color: AppTheme.current.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, color: AppTheme.current.primaryColor, size: 28),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                opacity: _isExpanded ? 1.0 : 0.0,
                child: Text(
                  'STREAME',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppTheme.current.primaryColor,
                  ),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required String id,
    required Map<String, dynamic> meta,
    required bool isSelected,
    required int index,
  }) {
    final activeColor = AppTheme.current.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: FocusableControl(
        onTap: () => widget.onItemTapped(index),
        borderRadius: AppRadius.md,
        glowColor: activeColor,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              const SizedBox(width: 4),
              // Active indicator bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                width: 3,
                height: isSelected ? 24 : 0,
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isSelected ? meta['active'] as IconData : meta['icon'] as IconData,
                color: isSelected ? activeColor : AppTheme.textDisabled,
                size: 22,
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    opacity: _isExpanded ? 1.0 : 0.0,
                    child: Text(
                      meta['label'] as String,
                      overflow: TextOverflow.clip,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MODERN BOTTOM NAV — pill indicator, clean icons (mobile)
// ═══════════════════════════════════════════════════════════════════════════

class _ModernBottomNav extends StatelessWidget {
  final List<String> visibleIds;
  final int selectedIndex;
  final Map<String, Map<String, dynamic>> navMeta;
  final ValueChanged<int> onItemTapped;

  const _ModernBottomNav({
    required this.visibleIds,
    required this.selectedIndex,
    required this.navMeta,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.current.primaryColor;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDim,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(visibleIds.length, (index) {
          final id = visibleIds[index];
          final meta = navMeta[id]!;
          final isSelected = selectedIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => onItemTapped(index),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Active pill indicator
                  AnimatedContainer(
                    duration: AppDurations.fast,
                    width: isSelected ? 24 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: isSelected ? activeColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    isSelected ? meta['active'] as IconData : meta['icon'] as IconData,
                    color: isSelected ? activeColor : AppTheme.textDisabled,
                    size: 22,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta['label'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textDisabled,
                      letterSpacing: isSelected ? 0.3 : 0,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

