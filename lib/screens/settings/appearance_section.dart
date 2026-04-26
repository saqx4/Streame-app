import 'package:flutter/material.dart';
import 'package:streame_core/services/settings_service.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'settings_widgets.dart';

class AppearanceSection extends StatefulWidget {
  const AppearanceSection({super.key});

  @override
  State<AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends State<AppearanceSection> {
  final SettingsService _settings = SettingsService();
  final ScrollController _themeScrollController = ScrollController();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tap a theme to apply instantly',
              style: TextStyle(color: AppTheme.textDisabled, fontSize: 12),
            ),
            Row(
              children: [
                _scrollArrow(Icons.arrow_back_ios_rounded, () => _themeScrollController.animateTo(
                  _themeScrollController.offset - 200,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                )),
                _scrollArrow(Icons.arrow_forward_ios_rounded, () => _themeScrollController.animateTo(
                  _themeScrollController.offset + 200,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                )),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Theme pills — horizontal scroll
        SizedBox(
          height: 44,
          child: ListView.separated(
            controller: _themeScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: AppTheme.presets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final preset = AppTheme.presets[index];
              final isSelected = preset.id == _selectedThemeId;
              return GestureDetector(
                onTap: () async {
                  await AppTheme.setPreset(preset.id);
                  setState(() => _selectedThemeId = preset.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? preset.primaryColor.withValues(alpha: 0.15)
                        : GlassColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected ? preset.primaryColor : GlassColors.borderSubtle,
                      width: isSelected ? 1.5 : 0.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: preset.primaryColor.withValues(alpha: 0.25), blurRadius: 8)]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Color circle
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [preset.primaryColor, preset.accentColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(preset.icon, size: 12, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        preset.name,
                        style: TextStyle(
                          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_rounded, size: 16, color: preset.primaryColor),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _scrollArrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppTheme.textSecondary),
      ),
    );
  }
}
