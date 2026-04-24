import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../utils/app_theme.dart';
import 'settings_widgets.dart';

class SearchTorrentsSection extends StatefulWidget {
  const SearchTorrentsSection({super.key});

  @override
  State<SearchTorrentsSection> createState() => _SearchTorrentsSectionState();
}

class _SearchTorrentsSectionState extends State<SearchTorrentsSection> {
  final SettingsService _settings = SettingsService();
  String _sortPreference = 'Seeders (High to Low)';
  String _torrentCacheType = 'ram';
  int _torrentRamCacheMb = 200;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sort = await _settings.getSortPreference();
    final cacheType = await _settings.getTorrentCacheType();
    final ramCacheMb = await _settings.getTorrentRamCacheMb();
    if (mounted) {
      setState(() {
        _sortPreference = sort;
        _torrentCacheType = cacheType;
        _torrentRamCacheMb = ramCacheMb;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FocusableDropdown(
          title: 'Default Sort Order',
          subtitle: 'How torrent results are sorted automatically.',
          value: _sortPreference,
          options: [
            'Seeders (High to Low)',
            'Seeders (Low to High)',
            'Quality (High to Low)',
            'Quality (Low to High)',
            'Size (High to Low)',
            'Size (Low to High)',
          ],
          onChanged: (val) {
            if (val != null) {
              _settings.setSortPreference(val);
              setState(() => _sortPreference = val);
            }
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'TORRENT ENGINE',
            style: TextStyle(
              color: AppTheme.current.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        FocusableDropdown(
          title: 'Cache Type',
          subtitle: 'Where torrent data is cached during streaming.',
          value: _torrentCacheType == 'ram' ? 'RAM' : 'Disk',
          options: ['RAM', 'Disk'],
          onChanged: (val) async {
            if (val != null) {
              final type = val == 'RAM' ? 'ram' : 'disk';
              await _settings.setTorrentCacheType(type);
              setState(() => _torrentCacheType = type);
            }
          },
        ),
        if (_torrentCacheType == 'ram')
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 4,
                  top: 8,
                  bottom: 4,
                ),
                child: Text(
                  'RAM Cache Size: $_torrentRamCacheMb MB',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              Slider(
                value: _torrentRamCacheMb.toDouble(),
                min: 50,
                max: 2048,
                divisions: 39,
                activeColor: Colors.deepPurpleAccent,
                inactiveColor: AppTheme.textDisabled.withValues(
                  alpha: 0.15,
                ),
                label: '$_torrentRamCacheMb MB',
                onChanged: (val) => setState(
                  () => _torrentRamCacheMb = val.round(),
                ),
                onChangeEnd: (val) async => await _settings
                    .setTorrentRamCacheMb(val.round()),
              ),
            ],
          ),
      ],
    );
  }
}
