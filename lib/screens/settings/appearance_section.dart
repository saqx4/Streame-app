import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../utils/app_theme.dart';
import 'settings_widgets.dart';

class AppearanceSection extends StatefulWidget {
  const AppearanceSection({super.key});

  @override
  State<AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends State<AppearanceSection> {
  final SettingsService _settings = SettingsService();
  bool _isLightMode = false;
  String _selectedThemeId = 'cinematic';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lightMode = await _settings.isLightModeEnabled();
    final themePreset = await _settings.getThemePreset();
    if (mounted) {
      setState(() {
        _isLightMode = lightMode;
        _selectedThemeId = themePreset;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FocusableToggle(
          title: 'Light Mode',
          subtitle: 'Disables blur, glows, shadows, and animations for better FPS.',
          value: _isLightMode,
          onChanged: (val) async {
            await _settings.setLightMode(val);
            setState(() => _isLightMode = val);
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'THEME',
            style: TextStyle(
              color: AppTheme.current.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildThemePicker(),
      ],
    );
  }

  Widget _buildThemePicker() {
    final width = MediaQuery.of(context).size.width;
    // Responsive: 2 cols on narrow, 3 on medium, 4 on wide
    final cols = width > 900 ? 4 : (width > 550 ? 3 : 2);
    final aspect = width > 550 ? 2.8 : 2.6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Choose a vibe for your app.',
            style: TextStyle(color: AppTheme.textDisabled, fontSize: 12),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: aspect,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: AppTheme.presets.length,
          itemBuilder: (context, index) {
            final preset = AppTheme.presets[index];
            final isSelected = preset.id == _selectedThemeId;
            return GestureDetector(
              onTap: () async {
                await AppTheme.setPreset(preset.id);
                setState(() => _selectedThemeId = preset.id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: preset.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? preset.primaryColor : AppTheme.border,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: preset.primaryColor.withValues(alpha: 0.25),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [preset.primaryColor, preset.accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        preset.icon,
                        size: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        preset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: preset.primaryColor,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
