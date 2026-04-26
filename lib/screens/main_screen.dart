import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:streame_core/utils/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'discover_screen.dart';
import 'search_screen.dart';
import 'my_list_screen.dart';
import 'settings_screen.dart';
import 'magnet_player_screen.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'package:streame_core/services/settings_service.dart';
import 'package:streame_core/services/app_updater_service.dart';
import 'package:streame_core/widgets/update_dialog.dart';
import 'package:streame_core/providers/service_providers.dart';
import 'package:streame_core/utils/device_detector.dart';

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
      log.info('[MainScreen] Update check failed: $e');
    }
  }

  Future<void> _loadNavbarConfig() async {
    final settings = ref.read(settingsServiceProvider);
    final visible = await settings.getNavbarConfig();
    if (!mounted) return;
    setState(() {
      final currentId = _selectedIndex < _visibleIds.length
          ? _visibleIds[_selectedIndex]
          : null;
      _visibleIds = [...visible, 'settings'];
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

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _metricsDebounce?.cancel();
    _metricsDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() {});
    });
    _metricsSafety ??= Timer(const Duration(seconds: 4), () {
      _metricsSafety = null;
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      // TV: keep system bars visible for leanback; mobile: immersive
      final isTv = PlatformInfo.isTv(context);
      SystemChrome.setEnabledSystemUIMode(
        isTv ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
      );
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
    final isMobile = PlatformInfo.isMobile(context);
    final isTv = PlatformInfo.isTv(context);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      extendBody: true,
      body: Row(
        children: [
          if (!isMobile) _GlassSideRail(
            visibleIds: _visibleIds,
            selectedIndex: _selectedIndex,
            navMeta: _navMeta,
            onItemTapped: _onItemTapped,
            isTv: isTv,
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _visibleIds.map((id) => _allScreens[id]!).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _FloatingBottomNav(
        visibleIds: _visibleIds,
        selectedIndex: _selectedIndex,
        navMeta: _navMeta,
        onItemTapped: _onItemTapped,
      ) : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  GLASS SIDE RAIL — adaptive, glassmorphic, animated pill indicator
// ═══════════════════════════════════════════════════════════════════════════

class _GlassSideRail extends StatefulWidget {
  final List<String> visibleIds;
  final int selectedIndex;
  final Map<String, Map<String, dynamic>> navMeta;
  final ValueChanged<int> onItemTapped;
  final bool isTv;

  const _GlassSideRail({
    required this.visibleIds,
    required this.selectedIndex,
    required this.navMeta,
    required this.onItemTapped,
    this.isTv = false,
  });

  @override
  State<_GlassSideRail> createState() => _GlassSideRailState();
}

class _GlassSideRailState extends State<_GlassSideRail> {
  bool _isExpanded = false;

  bool get _isTv => widget.isTv;
  bool get _showExpanded => _isTv || _isExpanded;

  @override
  Widget build(BuildContext context) {
    const collapsedWidth = 72.0;
    const expandedWidth = 220.0;

    Widget rail = ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: GlassColors.blur, sigmaY: GlassColors.blur),
        child: AnimatedContainer(
          duration: AppDurations.slow,
          curve: AnimationPresets.smoothInOut,
          clipBehavior: Clip.hardEdge,
          width: _showExpanded ? expandedWidth : collapsedWidth,
          decoration: BoxDecoration(
            color: AppTheme.surfaceDim.withValues(alpha: 0.85),
            border: Border(right: BorderSide(color: AppTheme.borderStrong.withValues(alpha: 0.15), width: 0.5)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _buildBranding(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: _showExpanded ? 12 : 10),
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
      ),
    );

    // TV: no MouseRegion (D-pad doesn't trigger hover), always expanded
    if (_isTv) return rail;

    return MouseRegion(
      onEnter: (_) => setState(() => _isExpanded = true),
      onExit: (_) => setState(() => _isExpanded = false),
      child: rail,
    );
  }

  Widget _buildBranding() {
    final primary = AppTheme.current.primaryColor;
    return AnimatedContainer(
      duration: AppDurations.slow,
      curve: AnimationPresets.smoothInOut,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: primary.withValues(alpha: 0.12), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, color: primary, size: 28),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: AnimatedOpacity(
                duration: AppDurations.normal,
                curve: AnimationPresets.smoothInOut,
                opacity: _showExpanded ? 1.0 : 0.0,
                child: Text(
                  'STREAME',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: primary,
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
    final primary = AppTheme.current.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: FocusableControl(
        onTap: () => widget.onItemTapped(index),
        borderRadius: AppRadius.md,
        glowColor: primary,
        child: AnimatedContainer(
          duration: AppDurations.normal,
          curve: AnimationPresets.smoothInOut,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              const SizedBox(width: 4),
              // Animated pill indicator
              AnimatedContainer(
                duration: AppDurations.normal,
                curve: AnimationPresets.smoothInOut,
                width: 3,
                height: isSelected ? 28 : 0,
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isSelected ? [AppShadows.primary(0.3)] : null,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isSelected ? meta['active'] as IconData : meta['icon'] as IconData,
                color: isSelected ? primary : AppTheme.textDisabled,
                size: 22,
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: AnimatedOpacity(
                    duration: AppDurations.normal,
                    curve: AnimationPresets.smoothInOut,
                    opacity: _showExpanded ? 1.0 : 0.0,
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
//  FLOATING BOTTOM NAV — glassmorphic pill bar with backdrop blur (mobile)
// ═══════════════════════════════════════════════════════════════════════════

class _FloatingBottomNav extends StatelessWidget {
  final List<String> visibleIds;
  final int selectedIndex;
  final Map<String, Map<String, dynamic>> navMeta;
  final ValueChanged<int> onItemTapped;

  const _FloatingBottomNav({
    required this.visibleIds,
    required this.selectedIndex,
    required this.navMeta,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.current.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: GlassColors.blur, sigmaY: GlassColors.blur),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDim.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.15), width: 0.5),
              boxShadow: [AppShadows.medium],
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
                          duration: AppDurations.normal,
                          curve: AnimationPresets.smoothInOut,
                          width: isSelected ? 24 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isSelected ? primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: isSelected ? [AppShadows.primary(0.3)] : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Icon(
                          isSelected ? meta['active'] as IconData : meta['icon'] as IconData,
                          color: isSelected ? primary : AppTheme.textDisabled,
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
          ),
        ),
      ),
    );
  }
}
