// Shared providers that are initialized in main.dart with overrides
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streame/core/theme/app_theme.dart';

/// SharedPreferences instance — override in main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize in main');
});

/// Current theme type — persisted in SharedPreferences
final themeTypeProvider = StateProvider<AppThemeType>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final name = prefs.getString('settings_theme_type') ?? 'midnight';
  return AppThemeType.values.firstWhere(
    (e) => e.name == name,
    orElse: () => AppThemeType.midnight,
  );
});

/// Current StreameThemeData derived from themeTypeProvider
final currentThemeProvider = Provider<StreameThemeData>((ref) {
  final type = ref.watch(themeTypeProvider);
  return StreameThemes.getTheme(type);
});
