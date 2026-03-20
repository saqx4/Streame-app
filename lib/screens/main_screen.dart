import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'discover_screen.dart';
import 'search_screen.dart';
import 'my_list_screen.dart';
import 'settings_screen.dart';
import 'music_screen.dart';
import 'audiobook_screen.dart';
import 'books_screen.dart';
import 'comics_screen.dart';
import 'manga_screen.dart';
import 'jellyfin_screen.dart';
import 'live_matches_screen.dart';
import 'magnet_player_screen.dart';
import '../features/iptv/screens/iptv_login_screen.dart';
import '../utils/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  /// Notifier that SearchScreen listens to for incoming Stremio search requests.
  /// Value is {'query': '...', 'addonBaseUrl': '...'} or null.
  static final ValueNotifier<Map<String, String>?> stremioSearchNotifier = ValueNotifier<Map<String, String>?>(null);

  static State<MainScreen>? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainScreenState>();
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  // Cache screens so they are NOT recreated on every build/orientation change
  late final List<Widget> _cachedScreens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MainScreen.stremioSearchNotifier.addListener(_onStremioSearch);
    _cachedScreens = [
      const HomeScreen(),
      const DiscoverScreen(),
      const SearchScreen(),
      const MyListScreen(),
      const MagnetPlayerScreen(),
      const LiveMatchesScreen(),
      const IptvLoginScreen(),
      const AudiobookScreen(),
      const BooksScreen(),
      const MusicScreen(),
      ComicsScreen(initialSearch: null),
      MangaScreen(initialSearch: null),
      const JellyfinScreen(),
      const SettingsScreen(),
    ];
  }

  /// Re-apply immersive mode after metrics changes settle (rotation, etc.).
  /// Some Android devices (especially Samsung) reset system-bar visibility on
  /// configuration changes. This callback debounces to let the rotation
  /// animation finish first, then re-hides the bars.  No `setState` needed —
  /// Flutter already rebuilds widgets that depend on `MediaQuery`.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (Platform.isAndroid) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
      });
    }
  }

  void _onStremioSearch() {
    final data = MainScreen.stremioSearchNotifier.value;
    if (data == null || (data['query'] ?? '').isEmpty) return;
    setState(() => _selectedIndex = 2);
  }

  void _onItemTapped(int index) {
    setState(() { 
      _selectedIndex = index;
      // Indices: 0=Home 1=Discover 2=Search 3=MyList 4=Magnet 5=LiveMatches 6=IPTV 7=Audiobooks 8=Books 9=Music 10=Comics 11=Manga 12=Jellyfin 13=Settings
    });
  }

  void searchComics(String query) {
    setState(() {
      _selectedIndex = 10;
    });
  }

  void searchManga(String query) {
    setState(() {
      _selectedIndex = 11;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MainScreen.stremioSearchNotifier.removeListener(_onStremioSearch);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    
    final bool useNavRail = isDesktop || isLandscape;


    return Scaffold(
      body: Stack(
        children: [
          // Base gradient
          Container(decoration: AppTheme.backgroundDecoration),
          // Ambient purple glow – top-right
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.18),
                    AppTheme.primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Ambient cyan glow – bottom-left
          Positioned(
            bottom: 40,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentColor.withValues(alpha: 0.08),
                    AppTheme.accentColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Soft violet glow – center-left
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6200EA).withValues(alpha: 0.10),
                    const Color(0xFF6200EA).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Content layer
          Row(
            children: [
              if (useNavRail)
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                          backgroundColor: Colors.transparent,
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: _onItemTapped,
                          labelType: NavigationRailLabelType.all,
                          indicatorColor: AppTheme.primaryColor,
                          selectedLabelTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          unselectedLabelTextStyle: const TextStyle(
                            color: Colors.white54,
                          ),
                          leading: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: Icon(
                              Icons.play_circle_fill,
                              color: AppTheme.primaryColor,
                              size: 48,
                            ),
                          ),
                          destinations: const [
                            NavigationRailDestination(
                              icon: Icon(Icons.home_outlined, color: Colors.white54),
                              selectedIcon: Icon(Icons.home, color: Colors.white),
                              label: Text('Home'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.explore_outlined, color: Colors.white54),
                              selectedIcon: Icon(Icons.explore, color: Colors.white),
                              label: Text('Discover'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.search, color: Colors.white54),
                              selectedIcon: Icon(Icons.search, color: Colors.white),
                              label: Text('Search'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.bookmark_outline, color: Colors.white54),
                              selectedIcon: Icon(Icons.bookmark, color: Colors.white),
                              label: Text('My List'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.link_rounded, color: Colors.white54),
                              selectedIcon: Icon(Icons.link_rounded, color: Colors.white),
                              label: Text('Magnet'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.sports_soccer_outlined, color: Colors.white54),
                              selectedIcon: Icon(Icons.sports_soccer_rounded, color: Colors.white),
                              label: Text('Live Matches'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.live_tv_outlined, color: Colors.white54),
                              selectedIcon: Icon(Icons.live_tv, color: Colors.white),
                              label: Text('IPTV'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.menu_book_outlined, color: Colors.white54),
                              selectedIcon: Icon(Icons.menu_book, color: Colors.white),
                              label: Text('Audiobooks'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.import_contacts_rounded, color: Colors.white54),
                              selectedIcon: Icon(Icons.import_contacts_rounded, color: Colors.white),
                              label: Text('Books'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.music_note_outlined, color: Colors.white54),
                              selectedIcon: Icon(Icons.music_note, color: Colors.white),
                              label: Text('Music'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.auto_stories_outlined, color: Colors.white54),
                              selectedIcon: Icon(Icons.auto_stories, color: Colors.white),
                              label: Text('Comics'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.book_outlined, color: Colors.white54),
                              selectedIcon: Icon(Icons.book, color: Colors.white),
                              label: Text('Manga'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.dns_outlined, color: Colors.white54),
                              selectedIcon: Icon(Icons.dns_rounded, color: Colors.white),
                              label: Text('Jellyfin'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.settings_outlined, color: Colors.white54),
                              selectedIcon: Icon(Icons.settings, color: Colors.white),
                              label: Text('Settings'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _cachedScreens,
              ),
            ),
          ],
        ),
        ],
      ),
      bottomNavigationBar: useNavRail
          ? null
          : _buildScrollableBottomNav(),
    );
  }

  Widget _buildScrollableBottomNav() {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.home_outlined, 'active': Icons.home, 'label': 'Home'},
      {'icon': Icons.explore_outlined, 'active': Icons.explore, 'label': 'Discover'},
      {'icon': Icons.search, 'active': Icons.search, 'label': 'Search'},
      {'icon': Icons.bookmark_outline, 'active': Icons.bookmark, 'label': 'My List'},
      {'icon': Icons.link_rounded, 'active': Icons.link_rounded, 'label': 'Magnet'},
      {'icon': Icons.sports_soccer_outlined, 'active': Icons.sports_soccer_rounded, 'label': 'Live Matches'},
      {'icon': Icons.live_tv_outlined, 'active': Icons.live_tv, 'label': 'IPTV'},
      {'icon': Icons.menu_book_outlined, 'active': Icons.menu_book, 'label': 'Audiobooks'},
      {'icon': Icons.import_contacts_rounded, 'active': Icons.import_contacts_rounded, 'label': 'Books'},
      {'icon': Icons.music_note_outlined, 'active': Icons.music_note, 'label': 'Music'},
      {'icon': Icons.auto_stories_outlined, 'active': Icons.auto_stories, 'label': 'Comics'},
      {'icon': Icons.book_outlined, 'active': Icons.book, 'label': 'Manga'},
      {'icon': Icons.dns_outlined, 'active': Icons.dns_rounded, 'label': 'Jellyfin'},
      {'icon': Icons.settings_outlined, 'active': Icons.settings, 'label': 'Settings'},
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0418).withValues(alpha: 0.75),
            border: const Border(top: BorderSide(color: Colors.white10, width: 0.5)),
          ),
          child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: items.asMap().entries.map((entry) {
                final int idx = entry.key;
                final Map<String, dynamic> item = entry.value;
                final bool isSelected = _selectedIndex == idx;

                return InkWell(
                  onTap: () => _onItemTapped(idx),
                  child: Container(
                    width: 100,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isSelected ? item['active'] : item['icon'],
                            color: isSelected ? Colors.white : Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['label'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Positioned(
            right: 0, top: 0, bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, const Color(0xFF0F0418).withValues(alpha: 0.7)],
                  ),
                ),
                child: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
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
