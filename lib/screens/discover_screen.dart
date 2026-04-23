import 'dart:ui';
import 'package:flutter/material.dart';
import '../api/tmdb_api.dart';
import '../services/settings_service.dart';
import '../models/movie.dart';
import '../utils/app_theme.dart';
import 'details_screen.dart';
import 'streaming_details_screen.dart';
import 'discover/discover_widgets.dart';
import '../widgets/smooth_page_transition.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with AutomaticKeepAliveClientMixin {
  final TmdbApi _api = TmdbApi();
  final ScrollController _scrollController = ScrollController();
  
  // State
  List<Movie> _movies = [];
  bool _isLoading = false;
  int _currentPage = 1;

  // Cached streaming mode — avoids async SharedPreferences read before Navigator.push
  bool _isStreamingMode = false;
  
  // Filters
  String _selectedType = "Movies"; // Movies, TV Shows, All
  final List<String> _selectedGenreNames = [];
  final List<int> _selectedYears = [];
  double _minRating = 0;
  String? _selectedLanguage; // ISO 639-1 code

  // Genre Maps
  final Map<String, int> _movieGenreMap = {};
  final Map<String, int> _tvGenreMap = {};
  List<String> _allGenreNames = [];

  // Language map (display name -> ISO 639-1 code)
  static const Map<String, String> _languageMap = {
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Italian': 'it',
    'Portuguese': 'pt',
    'Russian': 'ru',
    'Japanese': 'ja',
    'Korean': 'ko',
    'Chinese': 'zh',
    'Hindi': 'hi',
    'Arabic': 'ar',
    'Turkish': 'tr',
    'Thai': 'th',
    'Swedish': 'sv',
    'Danish': 'da',
    'Norwegian': 'no',
    'Finnish': 'fi',
    'Dutch': 'nl',
    'Polish': 'pl',
    'Czech': 'cs',
    'Romanian': 'ro',
    'Hungarian': 'hu',
    'Greek': 'el',
    'Hebrew': 'he',
    'Indonesian': 'id',
    'Malay': 'ms',
    'Vietnamese': 'vi',
    'Tagalog': 'tl',
    'Ukrainian': 'uk',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Cache streaming mode once so _openDetails() is synchronous
    SettingsService().isStreamingModeEnabled().then((v) {
      if (mounted) _isStreamingMode = v;
    });

    _loadGenres();
    _loadData();
  }

  Future<void> _loadGenres() async {
    try {
      final mGenres = await _api.getMovieGenres();
      final tGenres = await _api.getTvGenres();
      
      final Set<String> names = {};
      
      for (var g in mGenres) {
        _movieGenreMap[g['name']] = g['id'];
        names.add(g['name']);
      }
      for (var g in tGenres) {
        _tvGenreMap[g['name']] = g['id'];
        names.add(g['name']);
      }
      
      if (mounted) {
        setState(() {
          _allGenreNames = names.toList()..sort();
        });
      }
    } catch (e) {
      debugPrint("Error loading genres: $e");
    }
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    try {
      List<Movie> results = [];
      
      // Determine years to fetch (default to null if empty, otherwise iterate)
      final yearsToFetch = _selectedYears.isEmpty ? [null] : _selectedYears;
      
      List<Future<List<Movie>>> tasks = [];

      for (var year in yearsToFetch) {
        // Movies
        if (_selectedType == "Movies" || _selectedType == "All") {
          final genreIds = _selectedGenreNames.map((n) => _movieGenreMap[n]).whereType<int>().toList();
          tasks.add(_api.discoverMovies(
            page: _currentPage,
            genres: genreIds,
            year: year,
            minRating: _minRating > 0 ? _minRating : null,
            language: _selectedLanguage,
          ));
        }
        
        // TV Shows
        if (_selectedType == "TV Shows" || _selectedType == "All") {
          final genreIds = _selectedGenreNames.map((n) => _tvGenreMap[n]).whereType<int>().toList();
          tasks.add(_api.discoverTvShows(
            page: _currentPage,
            genres: genreIds,
            year: year,
            minRating: _minRating > 0 ? _minRating : null,
            language: _selectedLanguage,
          ));
        }
      }

      final responses = await Future.wait(tasks);
      for (var list in responses) {
        results.addAll(list);
      }

      // Shuffle if "All" or multiple years to mix results
      if (_selectedType == "All" || yearsToFetch.length > 1) {
        results.shuffle();
      }

      if (mounted) {
        setState(() {
          _movies = results;
          _isLoading = false;
        });
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      }
    } catch (e) {
      debugPrint("Error loading discover: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextPage() {
    setState(() => _currentPage++);
    _loadData();
  }

  void _prevPage() {
    if (_currentPage > 1) {
      setState(() => _currentPage--);
      _loadData();
    }
  }

  void _showTypeMenu() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => CompactFilterDialog(
        title: 'Content Type',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['All', 'Movies', 'TV Shows'].map((type) {
            final isSelected = _selectedType == type;
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Text(type, style: TextStyle(color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
              trailing: isSelected ? Icon(Icons.check_circle, color: AppTheme.current.primaryColor, size: 20) : null,
              onTap: () {
                setState(() { _selectedType = type; _currentPage = 1; });
                Navigator.pop(context);
                _loadData();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showGenreMenu() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CompactFilterDialog(
              title: 'Select Genres',
              maxHeight: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _allGenreNames.map((name) {
                          final isSelected = _selectedGenreNames.contains(name);
                          return FilterChip(
                            label: Text(name, style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) { _selectedGenreNames.add(name); } else { _selectedGenreNames.remove(name); }
                              });
                            },
                            backgroundColor: AppTheme.surfaceContainerHigh,
                            selectedColor: AppTheme.current.primaryColor,
                            checkmarkColor: AppTheme.textPrimary,
                            labelStyle: TextStyle(color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide.none),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _currentPage = 1);
                        _loadData();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.current.primaryColor, padding: const EdgeInsets.symmetric(vertical: 10)),
                      child: Text("Apply", style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showYearMenu() {
    final currentYear = DateTime.now().year;
    final years = List.generate(100, (index) => currentYear - index);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CompactFilterDialog(
              title: 'Select Years',
              maxHeight: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: years.map((y) {
                          final isSelected = _selectedYears.contains(y);
                          return FilterChip(
                            label: Text(y.toString(), style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) { _selectedYears.add(y); } else { _selectedYears.remove(y); }
                              });
                            },
                            backgroundColor: AppTheme.surfaceContainerHigh,
                            selectedColor: AppTheme.current.primaryColor,
                            labelStyle: TextStyle(color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide.none),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _currentPage = 1);
                        _loadData();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.current.primaryColor, padding: const EdgeInsets.symmetric(vertical: 10)),
                      child: Text("Apply", style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguageMenu() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final languages = _languageMap.keys.toList();
            return CompactFilterDialog(
              title: 'Select Language',
              maxHeight: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          FilterChip(
                            label: const Text('Any', style: TextStyle(fontSize: 12)),
                            selected: _selectedLanguage == null,
                            onSelected: (_) => setDialogState(() => _selectedLanguage = null),
                            backgroundColor: AppTheme.surfaceContainerHigh,
                            selectedColor: AppTheme.current.primaryColor,
                            checkmarkColor: AppTheme.textPrimary,
                            labelStyle: TextStyle(color: _selectedLanguage == null ? AppTheme.textPrimary : AppTheme.textSecondary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide.none),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          ...languages.map((name) {
                            final code = _languageMap[name]!;
                            final isSelected = _selectedLanguage == code;
                            return FilterChip(
                              label: Text(name, style: const TextStyle(fontSize: 12)),
                              selected: isSelected,
                              onSelected: (_) => setDialogState(() => _selectedLanguage = isSelected ? null : code),
                              backgroundColor: AppTheme.surfaceContainerHigh,
                              selectedColor: AppTheme.current.primaryColor,
                              checkmarkColor: AppTheme.textPrimary,
                              labelStyle: TextStyle(color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide.none),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _currentPage = 1);
                        _loadData();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.current.primaryColor, padding: const EdgeInsets.symmetric(vertical: 10)),
                      child: Text("Apply", style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRatingMenu() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        double localRating = _minRating;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CompactFilterDialog(
              title: 'Minimum Rating',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${localRating.toStringAsFixed(1)}+", style: const TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppTheme.current.primaryColor,
                      inactiveTrackColor: AppTheme.border,
                      thumbColor: AppTheme.current.primaryColor,
                      overlayColor: AppTheme.current.primaryColor.withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: localRating,
                      min: 0,
                      max: 9,
                      divisions: 9,
                      onChanged: (v) => setDialogState(() => localRating = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel", style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() { _minRating = localRating; _currentPage = 1; });
                            Navigator.pop(context);
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.current.primaryColor, padding: const EdgeInsets.symmetric(vertical: 10)),
                          child: Text("Apply", style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openDetails(Movie movie) {
    if (_isStreamingMode) {
      Navigator.push(context, SmoothPageTransition(child: StreamingDetailsScreen(movie: movie)));
    } else {
      Navigator.push(context, SmoothPageTransition(child: DetailsScreen(movie: movie)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200 ? 6 : (width > 900 ? 5 : (width > 600 ? 4 : 3));

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            color: AppTheme.surfaceContainer,
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterButton(label: "Type: $_selectedType", onTap: _showTypeMenu, isActive: true),
                        FilterButton(label: "Genres", onTap: _showGenreMenu, isActive: _selectedGenreNames.isNotEmpty),
                        FilterButton(label: "Year", onTap: _showYearMenu, isActive: _selectedYears.isNotEmpty),
                        FilterButton(label: "Rating", onTap: _showRatingMenu, isActive: _minRating > 0),
                        FilterButton(label: _selectedLanguage != null ? "Lang: ${_languageMap.entries.firstWhere((e) => e.value == _selectedLanguage, orElse: () => MapEntry(_selectedLanguage!, _selectedLanguage!)).key}" : "Language", onTap: _showLanguageMenu, isActive: _selectedLanguage != null),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: AppTheme.current.primaryColor))
              : _movies.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore_outlined, size: 80, color: AppTheme.textDisabled.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: TextStyle(color: AppTheme.textDisabled, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters or changing the page',
                          style: TextStyle(color: AppTheme.textDisabled, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    cacheExtent: 800,
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 2 / 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _movies.length,
                    itemBuilder: (context, index) {
                      final movie = _movies[index];
                      return DiscoverCard(movie: movie, onTap: () => _openDetails(movie));
                    },
                  ),
          ),

          // Pagination
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentPage > 1 ? _prevPage : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surfaceContainerHigh),
                  child: Text("Previous", style: TextStyle(color: AppTheme.textPrimary)),
                ),
                Text("Page $_currentPage", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: _movies.isNotEmpty ? _nextPage : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.current.primaryColor),
                  child: Text("Next", style: TextStyle(color: AppTheme.textPrimary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
