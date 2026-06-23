import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/shared/widgets/streame_toast.dart';
import 'package:streame/core/focus/focusable.dart';

import 'package:streame/core/repositories/auth_repository_simple.dart';
import 'package:streame/core/repositories/trakt_repository.dart';
import 'package:streame/core/repositories/addon_repository.dart';
import 'package:streame/core/repositories/profile_repository.dart';
import 'package:streame/core/repositories/catalog_repository.dart';
import 'package:streame/core/constants/api_constants.dart';
import 'package:streame/core/models/stream_models.dart';
import 'package:streame/core/models/catalog_models.dart';
import 'package:streame/core/models/profile_model.dart';
import 'package:streame/core/providers/shared_providers.dart';

// ═══════════════════════════════════════════════
// MAIN SETTINGS SCREEN — Clean list of sections
// ═══════════════════════════════════════════════
class SettingsScreen extends ConsumerWidget {
  final bool autoCloudAuth;
  const SettingsScreen({super.key, this.autoCloudAuth = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traktRepo = ref.watch(traktRepositoryProvider);
    final isTraktLinked = traktRepo.isLinked();
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.backgroundDark,
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 18),
                        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Settings',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (activeProfile != null) ...[
                  _ProfileCard(profile: activeProfile),
                  SizedBox(height: 24),
                ],
                _SectionTile(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Theme, cinematic background',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AppearanceSettingsScreen())),
                ),
                _SectionTile(
                  icon: Icons.dashboard_outlined,
                  title: 'Cards',
                  subtitle: 'Size, orientation, edges',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _CardSettingsScreen())),
                ),
                _SectionTile(
                  icon: Icons.play_circle_outline,
                  title: 'Playback',
                  subtitle: 'Language, quality, subtitles',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _PlaybackSettingsScreen())),
                ),
                _SectionTile(
                  icon: Icons.dns_outlined,
                  title: 'Content Sources',
                  subtitle: 'Addons, catalogs, TorrServer',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ContentSourcesScreen())),
                ),
                _SectionTile(
                  icon: Icons.sync_alt,
                  title: 'Accounts & Sync',
                  subtitle: isTraktLinked ? 'Trakt connected' : 'Cloud, Trakt',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AccountsSettingsScreen())),
                ),
                _SectionTile(
                  icon: Icons.tune,
                  title: 'Advanced',
                  subtitle: 'Specials, stats, screensaver',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AdvancedSettingsScreen())),
                ),
                _SectionTile(
                  icon: Icons.info_outline,
                  title: 'About',
                  subtitle: 'v1.0.0+1, licenses',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AboutScreen())),
                ),
                SizedBox(height: 32),
                Center(
                  child: Text(
                    'Streame',
                    style: TextStyle(
                      color: AppTheme.textTertiary.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// SHARED — Reusable section page shell
// ═══════════════════════════════════════════════
class _SettingsPage extends StatelessWidget {
  final String title;
  final Widget child;
  const _SettingsPage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.backgroundDark,
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 18),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([child]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// SECTION TILE — Navigation row for main list
// ═══════════════════════════════════════════════
class _SectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: StreameFocusable(
        onTap: onTap ?? () {},
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundCard,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppTheme.textSecondary, size: 22),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.textTertiary.withValues(alpha: 0.4),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// GROUP — Card container for settings items
// ═══════════════════════════════════════════════
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: EdgeInsets.only(left: 54),
      color: AppTheme.borderLight.withValues(alpha: 0.12),
    );
  }
}

// ═══════════════════════════════════════════════
// SETTING ROW — Single setting with value/chevron
// ═══════════════════════════════════════════════
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(subtitle!, style: TextStyle(color: AppTheme.textTertiary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(color: valueColor ?? AppTheme.textTertiary, fontSize: 14),
                ),
              if (onTap != null) ...[
                SizedBox(width: 6),
                Icon(Icons.chevron_right, color: AppTheme.textTertiary.withValues(alpha: 0.4), size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// SWITCH ROW — Toggle setting
// ═══════════════════════════════════════════════
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged?.call(!value),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(subtitle!, style: TextStyle(color: AppTheme.textTertiary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 24,
                decoration: BoxDecoration(
                  color: value ? AppTheme.accentGreen.withValues(alpha: 0.9) : AppTheme.backgroundElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 180),
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 18,
                    height: 18,
                    margin: EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: value ? AppTheme.textPrimary : AppTheme.textTertiary,
                      shape: BoxShape.circle,
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

// ═══════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4, top: 20, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// PROFILE CARD
// ═══════════════════════════════════════════════
class _ProfileCard extends ConsumerWidget {
  final Profile profile;
  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(profile.avatarColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: profile.avatarId > 0
                  ? Icon(ProfileAvatars.getById(profile.avatarId).icon, color: AppTheme.textPrimary, size: 24)
                  : Text(
                      profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text(
                  profile.isKidsProfile ? 'Kids Profile' : 'Standard Profile',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 18),
                  onPressed: () => _showProfileEditSheet(context, ref),
                ),
                Container(width: 1, height: 18, color: AppTheme.borderLight.withValues(alpha: 0.15)),
                IconButton(
                  icon: Icon(Icons.swap_horiz, color: AppTheme.textSecondary, size: 18),
                  onPressed: () => context.go('/profile-select'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: AppTheme.accentYellow),
              title: Text('Edit Name', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () { Navigator.pop(ctx); _showRenameDialog(context, ref); },
            ),
            ListTile(
              leading: Icon(Icons.face, color: AppTheme.accentYellow),
              title: Text('Change Avatar', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () { Navigator.pop(ctx); _showAvatarPicker(context, ref); },
            ),
            ListTile(
              leading: Icon(profile.isLocked ? Icons.lock_open : Icons.lock, color: AppTheme.textPrimary),
              title: Text(profile.isLocked ? 'Remove PIN Lock' : 'Set PIN Lock', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () { Navigator.pop(ctx); _togglePinLock(context, ref); },
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: profile.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Edit Name', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Profile name',
            filled: true,
            fillColor: AppTheme.backgroundElevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () { if (controller.text.trim().isNotEmpty) Navigator.pop(ctx, controller.text.trim()); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
            child: Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref.read(profileRepositoryProvider).updateProfile(profile.copyWith(name: result));
      ref.invalidate(profilesProvider);
      ref.invalidate(activeProfileProvider);
    }
  }

  Future<void> _showAvatarPicker(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<ProfileAvatar>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Choose Avatar', style: TextStyle(color: AppTheme.textPrimary)),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: ProfileAvatars.avatars.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10),
            itemBuilder: (_, i) {
              final avatar = ProfileAvatars.avatars[i];
              final isSelected = avatar.id == profile.avatarId;
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, avatar),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(avatar.color),
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected ? Border.all(color: AppTheme.textPrimary, width: 2) : null,
                  ),
                  child: Icon(avatar.icon, color: AppTheme.textPrimary, size: 28),
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)))],
      ),
    );
    if (result != null) {
      await ref.read(profileRepositoryProvider).updateProfile(profile.copyWith(avatarId: result.id, avatarColor: result.color));
      ref.invalidate(profilesProvider);
      ref.invalidate(activeProfileProvider);
    }
  }

  Future<void> _togglePinLock(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(profileRepositoryProvider);
    if (profile.isLocked) {
      await repo.updateProfile(profile.copyWith(isLocked: false, pin: null));
    } else {
      final pinController = TextEditingController();
      final pinResult = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Set PIN for ${profile.name}', style: TextStyle(color: AppTheme.textPrimary)),
          content: TextField(
            controller: pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 5,
            decoration: InputDecoration(
              hintText: '4-5 digit PIN',
              filled: true,
              fillColor: AppTheme.backgroundElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              counterText: '',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
            ElevatedButton(
              onPressed: () { if (pinController.text.length >= 4) Navigator.pop(ctx, pinController.text); },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
              child: Text('Set PIN'),
            ),
          ],
        ),
      );
      if (pinResult != null) {
        await repo.updateProfile(profile.copyWith(isLocked: true, pin: pinResult));
      }
    }
    ref.invalidate(profilesProvider);
    ref.invalidate(activeProfileProvider);
  }
}

// ═══════════════════════════════════════════════
// APPEARANCE SETTINGS
// ═══════════════════════════════════════════════
class _AppearanceSettingsScreen extends ConsumerWidget {
  const _AppearanceSettingsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final cinematic = prefs.getBool('settings_cinematic_background') ?? false;
    final currentThemeType = ref.watch(themeTypeProvider);

    return _SettingsPage(
      title: 'Appearance',
      child: Column(
        children: [
          // Theme Picker
          _Label('Theme'),
          _Group(
            children: AppThemeType.values.map((type) {
              final theme = StreameThemes.getTheme(type);
              final isSelected = currentThemeType == type;
              return _ThemeOption(
                type: type,
                theme: theme,
                isSelected: isSelected,
                onTap: () async {
                  await prefs.setString('settings_theme_type', type.name);
                  ref.read(themeTypeProvider.notifier).state = type;
                },
              );
            }).toList(),
          ),
          SizedBox(height: 16),
          _Label('Effects'),
          _Group(
            children: [
              _SwitchRow(
                icon: Icons.blur_on,
                title: 'Cinematic Background',
                subtitle: 'Blur a full-screen backdrop on detail pages',
                value: cinematic,
                onChanged: (v) async {
                  await prefs.setBool('settings_cinematic_background', v);
                  ref.invalidate(sharedPreferencesProvider);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// THEME OPTION — Visual theme picker item
// ═══════════════════════════════════════════════
class _ThemeOption extends StatelessWidget {
  final AppThemeType type;
  final StreameThemeData theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.type,
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Color preview
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.backgroundDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? theme.accentPrimary : theme.borderLight,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    // Accent color indicator
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.accentPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.displayName,
                      style: TextStyle(
                        color: isSelected ? theme.accentPrimary : AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      type.description,
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: theme.accentPrimary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// CARD SETTINGS
// ═══════════════════════════════════════════════
class _CardSettingsScreen extends ConsumerWidget {
  const _CardSettingsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final cardSize = prefs.getDouble('settings_card_size') ?? 0.5;
    final landscape = prefs.getBool('settings_card_landscape') ?? false;
    final edgeStyle = prefs.getString('settings_card_edge_style') ?? 'rounded';

    return _SettingsPage(
      title: 'Cards',
      child: Column(
        children: [
          _Group(
            children: [
              // Card Size
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(Icons.aspect_ratio, color: AppTheme.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Card Size', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                          SizedBox(height: 6),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: AppTheme.accentGreen,
                              inactiveTrackColor: AppTheme.backgroundElevated,
                              thumbColor: AppTheme.textPrimary,
                              trackHeight: 3,
                              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
                            ),
                            child: Slider(
                              value: cardSize,
                              onChanged: (v) async {
                                await prefs.setDouble('settings_card_size', v);
                                ref.invalidate(sharedPreferencesProvider);
                              },
                              min: 0.0,
                              max: 1.0,
                              divisions: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      cardSize <= 0.25 ? 'S' : cardSize <= 0.5 ? 'M' : cardSize <= 0.75 ? 'L' : 'XL',
                      style: TextStyle(color: AppTheme.textTertiary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const _Divider(),
              _SwitchRow(
                icon: Icons.screen_rotation,
                title: 'Landscape Cards',
                subtitle: 'Show cards in landscape orientation',
                value: landscape,
                onChanged: (v) async {
                  await prefs.setBool('settings_card_landscape', v);
                  ref.invalidate(sharedPreferencesProvider);
                },
              ),
            ],
          ),
          const _Label('Edge Style'),
          _Group(
            children: [
              for (final style in ['sharp', 'soft', 'rounded', 'pill'])
                _SettingRow(
                  icon: style == 'sharp'
                      ? Icons.crop_square
                      : style == 'soft'
                          ? Icons.rounded_corner
                          : style == 'rounded'
                              ? Icons.square
                              : Icons.circle,
                  title: style[0].toUpperCase() + style.substring(1),
                  value: edgeStyle == style ? '✓' : null,
                  valueColor: AppTheme.accentGreen,
                  onTap: () async {
                    await prefs.setString('settings_card_edge_style', style);
                    ref.invalidate(sharedPreferencesProvider);
                  },
                ),
            ],
          ),
          SizedBox(height: 32),
          _Group(
            children: [
              _SettingRow(
                icon: Icons.restart_alt,
                title: 'Reset to Defaults',
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.backgroundCard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      title: Text('Reset Card Settings?', style: TextStyle(color: AppTheme.textPrimary)),
                      content: Text('This will restore all card settings to their default values.', style: TextStyle(color: AppTheme.textSecondary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
                          child: Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await prefs.remove('settings_card_size');
                    await prefs.remove('settings_card_landscape');
                    await prefs.remove('settings_card_edge_style');
                    ref.invalidate(sharedPreferencesProvider);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// PLAYBACK SETTINGS
// ═══════════════════════════════════════════════
class _PlaybackSettingsScreen extends ConsumerWidget {
  const _PlaybackSettingsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);

    String getStr(String key, String def) => prefs.getString('settings_$key') ?? def;
    bool getBool(String key, bool def) => prefs.getBool('settings_$key') ?? def;

    return _SettingsPage(
      title: 'Playback',
      child: Column(
        children: [
          _Group(
            children: [
              _SettingRow(icon: Icons.language, title: 'Content Language', value: LanguageMap.getLanguageName(getStr('content_language', 'en')),
                onTap: () => _showPicker(context, ref, 'Content Language', ['en', 'es', 'fr', 'de', 'ja', 'ko', 'pt', 'it', 'hi', 'zh'], getStr('content_language', 'en'), (v) => prefs.setString('settings_content_language', v))),
              const _Divider(),
              _SettingRow(icon: Icons.slow_motion_video, title: 'Default Quality', value: getStr('default_quality', 'Auto'),
                onTap: () => _showPicker(context, ref, 'Default Quality', ['Auto', '4K', '1080p', '720p', '480p'], getStr('default_quality', 'Auto'), (v) => prefs.setString('settings_default_quality', v))),
              const _Divider(),
              _SettingRow(icon: Icons.volume_up, title: 'Volume Boost', value: getStr('volume_boost', 'Off'),
                onTap: () => _showPicker(context, ref, 'Volume Boost', ['Off', 'Low (+6dB)', 'Medium (+12dB)', 'High (+18dB)'], getStr('volume_boost', 'Off'), (v) => prefs.setString('settings_volume_boost', v))),
              const _Divider(),
              _SettingRow(icon: Icons.subtitles, title: 'Subtitle Language', value: LanguageMap.getLanguageName(getStr('subtitle_lang', 'en')),
                onTap: () => _showPicker(context, ref, 'Subtitle Language', ['en', 'es', 'fr', 'de', 'ja', 'ko', 'pt', 'it', 'hi', 'zh', 'Off'], getStr('subtitle_lang', 'en'), (v) => prefs.setString('settings_subtitle_lang', v))),
              const _Divider(),
              _SettingRow(icon: Icons.audiotrack, title: 'Audio Language', value: LanguageMap.getLanguageName(getStr('audio_lang', 'en')),
                onTap: () => _showPicker(context, ref, 'Audio Language', ['en', 'es', 'fr', 'de', 'ja', 'ko', 'pt', 'it', 'hi', 'zh'], getStr('audio_lang', 'en'), (v) => prefs.setString('settings_audio_lang', v))),
            ],
          ),
          const _Label('Automation'),
          _Group(
            children: [
              _SwitchRow(icon: Icons.timer, title: 'Auto-detect Skip Intro', subtitle: 'Automatically skip intros when detected',
                value: getBool('skip_intro_auto', true),
                onChanged: (v) async { await prefs.setBool('settings_skip_intro_auto', v); ref.invalidate(sharedPreferencesProvider); }),
              const _Divider(),
              _SwitchRow(icon: Icons.skip_next, title: 'Autoplay Next Episode', subtitle: 'Play the next episode automatically',
                value: getBool('autoplay_next', true),
                onChanged: (v) async { await prefs.setBool('settings_autoplay_next', v); ref.invalidate(sharedPreferencesProvider); }),
              const _Divider(),
              _SwitchRow(icon: Icons.high_quality, title: 'Trailer Autoplay', subtitle: 'Autoplay trailers on detail pages',
                value: getBool('trailer_autoplay', true),
                onChanged: (v) async { await prefs.setBool('settings_trailer_autoplay', v); ref.invalidate(sharedPreferencesProvider); }),
            ],
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref, String title, List<String> options, String current, ValueChanged<String> onSelected) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: Text(title, style: TextStyle(color: AppTheme.textPrimary)),
        children: options.map((code) {
          final label = code == 'Off' ? 'Off' : LanguageMap.getLanguageName(code);
          final isSelected = code == current;
          return SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx); onSelected(code); },
            child: Row(
              children: [
                Expanded(child: Text(label, style: TextStyle(color: isSelected ? AppTheme.accentGreen : AppTheme.textPrimary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
                if (isSelected) Icon(Icons.check, color: AppTheme.accentGreen, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// CONTENT SOURCES SCREEN
// ═══════════════════════════════════════════════
class _ContentSourcesScreen extends ConsumerWidget {
  const _ContentSourcesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsPage(
      title: 'Content Sources',
      child: _Group(
        children: [
          _SettingRow(icon: Icons.extension, title: 'Manage Addons', subtitle: 'Install, remove, or configure addons',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AddonManagerScreen()))),
          const _Divider(),
          _SettingRow(icon: Icons.add_link, title: 'Load Addon URL', subtitle: 'Add a community addon from URL',
            onTap: () => _showAddAddonDialog(context, ref)),
          const _Divider(),
          _SettingRow(icon: Icons.collections_bookmark_outlined, title: 'Manage Catalogs', subtitle: 'Organize your content catalogs',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _CatalogManagerScreen())),
          ),
          const _Divider(),
          _SettingRow(icon: Icons.playlist_add, title: 'Add Custom Catalog', subtitle: 'Add a Trakt or MDBList catalog',
            onTap: () => _showAddCatalogDialog(context, ref)),
          const _Divider(),
          _SettingRow(icon: Icons.storage, title: 'TorrServer', subtitle: 'Manage torrent server connections',
            onTap: () => _showTorrServers(context, ref)),
        ],
      ),
    );
  }

  Future<void> _showAddAddonDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Load Addon URL', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'https://example.com/manifest.json',
            filled: true,
            fillColor: AppTheme.backgroundElevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              final url = controller.text.trim();
              Navigator.pop(ctx);
              if (url.isEmpty) return;
              try {
                final profileId = ref.read(activeProfileIdProvider);
                if (profileId == null) return;
                final repo = ref.read(addonRepositoryProvider(profileId));
                final manifest = await repo.loadManifest(url);
                if (manifest == null) {
                  if (context.mounted) StreameToast.show(context, message: 'Failed to load addon', type: StreameToastType.error);
                  return;
                }
                await repo.addCustomAddon(url);
                if (context.mounted) StreameToast.show(context, message: '${manifest.name} installed', type: StreameToastType.success);
              } catch (e) {
                if (context.mounted) StreameToast.show(context, message: 'Error: $e', type: StreameToastType.error);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCatalogDialog(BuildContext context, WidgetRef ref) async {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedType = 'trakt';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Add Custom Catalog', style: TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.backgroundElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  dropdownColor: AppTheme.backgroundCard,
                  style: TextStyle(color: AppTheme.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'trakt', child: Text('Trakt List')),
                    DropdownMenuItem(value: 'mdblist', child: Text('MDBList')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v ?? 'trakt'),
                ),
                SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: InputDecoration(hintText: 'Catalog name', filled: true, fillColor: AppTheme.backgroundElevated, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)), style: TextStyle(color: AppTheme.textPrimary)),
                SizedBox(height: 12),
                TextField(controller: urlCtrl, decoration: InputDecoration(hintText: 'URL or slug', filled: true, fillColor: AppTheme.backgroundElevated, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)), style: TextStyle(color: AppTheme.textPrimary)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
            ElevatedButton(
              onPressed: () async {
                final url = urlCtrl.text.trim();
                final name = nameCtrl.text.trim();
                Navigator.pop(ctx);
                if (url.isEmpty) return;
                final profileId = ref.read(activeProfileIdProvider);
                if (profileId == null) return;
                try {
                  final repo = ref.read(catalogRepositoryProvider(profileId));
                  await repo.addCatalog(CatalogConfig(
                    id: '${selectedType}_${DateTime.now().millisecondsSinceEpoch}',
                    title: name.isNotEmpty ? name : url,
                    sourceType: selectedType == 'trakt' ? CatalogSourceType.trakt : CatalogSourceType.mdblist,
                    sourceUrl: url,
                  ));
                  if (context.mounted) StreameToast.show(context, message: 'Catalog added', type: StreameToastType.success);
                } catch (e) {
                  if (context.mounted) StreameToast.show(context, message: 'Error: $e', type: StreameToastType.error);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
              child: Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTorrServers(BuildContext context, WidgetRef ref) async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    final manager = ref.read(addonManagerProvider(profileId));
    final servers = await manager.getTorrServers();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('TorrServer', style: TextStyle(color: AppTheme.textPrimary)),
        content: SizedBox(
          width: 360,
          child: servers.isEmpty
              ? Text('No servers added', style: TextStyle(color: AppTheme.textSecondary))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: servers.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(servers[i].name, style: TextStyle(color: AppTheme.textPrimary)),
                    subtitle: Text(servers[i].url, style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: AppTheme.accentRed, size: 18),
                      onPressed: () async {
                        await manager.removeTorrServer(servers[i].url);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close', style: TextStyle(color: AppTheme.textSecondary))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// ACCOUNTS SETTINGS
// ═══════════════════════════════════════════════
class _AccountsSettingsScreen extends ConsumerWidget {
  const _AccountsSettingsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState is AuthAuthenticated;
    final isGuest = authState is AuthAuthenticated && authState.isGuest;
    final traktRepo = ref.watch(traktRepositoryProvider);
    final isTraktLinked = traktRepo.isLinked();

    return _SettingsPage(
      title: 'Accounts & Sync',
      child: _Group(
        children: [
          _SettingRow(
            icon: Icons.cloud_outlined,
            title: 'Cloud Account',
            value: isGuest ? 'Local Mode' : (isLoggedIn ? authState.email : 'Not connected'),
            onTap: isGuest ? () {
              final router = GoRouter.of(context);
              ref.read(authStateProvider.notifier).signOut().then((_) => router.go('/login'));
            } : (isLoggedIn ? null : () => context.go('/login')),
          ),
          const _Divider(),
          _SettingRow(
            icon: Icons.sync,
            title: 'Trakt.tv',
            value: isTraktLinked ? 'Connected' : 'Connect',
            valueColor: isTraktLinked ? AppTheme.accentGreen : null,
            onTap: isTraktLinked ? () => _showTraktDisconnect(context, ref) : () => _connectTrakt(context, ref),
          ),
          if (isLoggedIn && !isGuest) ...[
            const _Divider(),
            _SettingRow(icon: Icons.tv, title: 'TV Sign-In (QR Code)', subtitle: 'Sign in on a TV device',
              onTap: () => StreameToast.show(context, message: 'Coming soon', type: StreameToastType.info)),
          ],
          if (isLoggedIn) ...[
            const _Divider(),
            _SettingRow(
              icon: Icons.logout,
              title: isGuest ? 'Switch to Cloud Account' : 'Sign Out',
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.backgroundCard,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    title: Text('Sign Out?', style: TextStyle(color: AppTheme.textPrimary)),
                    content: Text('You will need to sign in again.', style: TextStyle(color: AppTheme.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: AppTheme.textPrimary),
                        child: Text('Sign Out'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authStateProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _connectTrakt(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(traktRepositoryProvider);
    final deviceData = await repo.requestDeviceCode();
    if (deviceData == null || !context.mounted) {
      StreameToast.show(context, message: 'Failed to connect to Trakt', type: StreameToastType.error);
      return;
    }
    final userCode = deviceData['user_code'] as String? ?? '';
    final verificationUrl = deviceData['verification_url'] as String? ?? 'https://trakt.tv/activate';
    final deviceCode = deviceData['device_code'] as String? ?? '';
    final expiresIn = deviceData['expires_in'] as int? ?? 600;
    final interval = deviceData['interval'] as int? ?? 5;

    bool cancelled = false;
    bool success = false;
    final navigator = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [Icon(Icons.sync, color: AppTheme.accentRed, size: 20), SizedBox(width: 8), Text('Connect Trakt', style: TextStyle(color: AppTheme.textPrimary))]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Go to the link and enter this code:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            SizedBox(height: 12),
            SelectableText(verificationUrl, style: TextStyle(color: AppTheme.accentGreen, fontSize: 15, fontWeight: FontWeight.w700)),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: AppTheme.backgroundElevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.borderLight)),
              child: SelectableText(userCode, style: TextStyle(color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3), textAlign: TextAlign.center),
            ),
            SizedBox(height: 10),
            Text('Expires in ${Duration(seconds: expiresIn).inMinutes}m', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(onPressed: () { cancelled = true; navigator.pop(); }, child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () => launchUrl(Uri.parse(verificationUrl), mode: LaunchMode.externalApplication),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: AppTheme.textPrimary),
            child: Text('Open Link'),
          ),
        ],
      ),
    );

    final deadline = DateTime.now().add(Duration(seconds: expiresIn));
    while (!cancelled && DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: interval));
      if (cancelled || !context.mounted) break;
      final tokens = await repo.pollDeviceToken(deviceCode);
      if (tokens != null) { success = true; break; }
    }

    if (!context.mounted) return;
    navigator.pop();
    if (success) {
      StreameToast.show(context, message: 'Trakt connected!', type: StreameToastType.success);
    } else if (!cancelled) {
      StreameToast.show(context, message: 'Authorization timed out', type: StreameToastType.error);
    }
  }

  void _showTraktDisconnect(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Disconnect Trakt?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Your Trakt data will no longer sync.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () async { Navigator.pop(ctx); await ref.read(traktRepositoryProvider).logout(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: AppTheme.textPrimary),
            child: Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// ADVANCED SETTINGS
// ═══════════════════════════════════════════════
class _AdvancedSettingsScreen extends ConsumerWidget {
  const _AdvancedSettingsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    bool getBool(String key, bool def) => prefs.getBool('settings_$key') ?? def;

    return _SettingsPage(
      title: 'Advanced',
      child: Column(
        children: [
          _Group(
            children: [
              _SwitchRow(icon: Icons.format_list_bulleted, title: 'Include Specials', subtitle: 'Show special episodes in season lists',
                value: getBool('include_specials', true),
                onChanged: (v) async { await prefs.setBool('settings_include_specials', v); ref.invalidate(sharedPreferencesProvider); }),
              const _Divider(),
              _SwitchRow(icon: Icons.analytics_outlined, title: 'Show Loading Stats', subtitle: 'Display loading performance data',
                value: getBool('show_loading_stats', false),
                onChanged: (v) async { await prefs.setBool('settings_show_loading_stats', v); ref.invalidate(sharedPreferencesProvider); }),
            ],
          ),
          const _Label('More'),
          _Group(
            children: [
              _SettingRow(icon: Icons.access_time, title: 'Clock Format', value: prefs.getString('settings_clock_format') ?? '12h',
                onTap: () {
                  final current = prefs.getString('settings_clock_format') ?? '12h';
                  showDialog(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      backgroundColor: AppTheme.backgroundCard,
                      title: Text('Clock Format', style: TextStyle(color: AppTheme.textPrimary)),
                      children: ['12h', '24h'].map((f) => SimpleDialogOption(
                        onPressed: () { Navigator.pop(ctx); prefs.setString('settings_clock_format', f); },
                        child: Text(f, style: TextStyle(color: f == current ? AppTheme.accentGreen : AppTheme.textPrimary)),
                      )).toList(),
                    ),
                  );
                },
              ),
              const _Divider(),
              _SettingRow(icon: Icons.filter_alt_outlined, title: 'Quality Filters', subtitle: 'Filter streams by resolution',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _QualityFiltersScreen()))),
              const _Divider(),
              _SwitchRow(icon: Icons.screen_lock_portrait, title: 'Screensaver', subtitle: 'Show screensaver when idle',
                value: getBool('screensaver_enabled', true),
                onChanged: (v) async { await prefs.setBool('settings_screensaver_enabled', v); ref.invalidate(sharedPreferencesProvider); }),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// ABOUT SCREEN
// ═══════════════════════════════════════════════
class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      title: 'About',
      child: _Group(
        children: [
          const _SettingRow(icon: Icons.apps, title: 'Version', value: '1.0.0+1'),
          const _Divider(),
          const _SettingRow(icon: Icons.build_outlined, title: 'Build', value: 'Flutter Debug'),
          const _Divider(),
          _SettingRow(icon: Icons.description_outlined, title: 'Open Source Licenses',
            onTap: () => showLicensePage(context: context, applicationName: 'Streame')),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// ADDON MANAGER SCREEN
// ═══════════════════════════════════════════════
class _AddonManagerScreen extends ConsumerStatefulWidget {
  const _AddonManagerScreen();
  @override
  ConsumerState<_AddonManagerScreen> createState() => _AddonManagerScreenState();
}

class _AddonManagerScreenState extends ConsumerState<_AddonManagerScreen> {
  List<Addon> _addons = [];
  bool _loading = true;
  String _searchQuery = '';
  String _filter = 'all';

  @override
  void initState() { super.initState(); _loadAddons(); }

  Future<void> _loadAddons() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) { setState(() => _loading = false); return; }
    final repo = ref.read(addonRepositoryProvider(profileId));
    final addons = await repo.getInstalledAddons();
    if (mounted) setState(() { _addons = addons; _loading = false; });
  }

  List<Addon> get _filtered {
    var list = _addons;
    if (_filter == 'official') list = list.where((a) => a.type == AddonType.official).toList();
    else if (_filter == 'custom') list = list.where((a) => a.type != AddonType.official).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) => a.name.toLowerCase().contains(q) || a.description.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      title: 'Manage Addons',
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search addons...',
                prefixIcon: Icon(Icons.search, color: AppTheme.textTertiary, size: 20),
                filled: true,
                fillColor: AppTheme.backgroundCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            ),
          ),
          if (_loading)
            Center(child: CircularProgressIndicator(color: AppTheme.textPrimary, strokeWidth: 2))
          else if (_filtered.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 48),
              child: Column(children: [
                Icon(Icons.extension, size: 48, color: AppTheme.textTertiary),
                SizedBox(height: 12),
                Text(_searchQuery.isNotEmpty ? 'No matches' : 'No addons', style: TextStyle(color: AppTheme.textSecondary)),
              ]),
            )
          else
            _Group(
              children: _filtered.map((addon) => _AddonTile(
                addon: addon,
                onToggle: (v) async {
                  final profileId = ref.read(activeProfileIdProvider);
                  if (profileId != null) {
                    await ref.read(addonRepositoryProvider(profileId)).toggleAddon(addon.id, v);
                    _loadAddons();
                  }
                },
                onRemove: () async {
                  final profileId = ref.read(activeProfileIdProvider);
                  if (profileId != null) {
                    await ref.read(addonRepositoryProvider(profileId)).removeAddon(addon.id);
                    _loadAddons();
                  }
                },
              )).toList(),
            ),
        ],
      ),
    );
  }
}

class _AddonTile extends StatelessWidget {
  final Addon addon;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;
  const _AddonTile({required this.addon, required this.onToggle, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 14),
        Icon(Icons.extension, color: AppTheme.textSecondary, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(addon.name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(addon.description.isNotEmpty ? addon.description : addon.version, style: TextStyle(color: AppTheme.textTertiary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42, height: 24,
          decoration: BoxDecoration(
            color: addon.isEnabled ? AppTheme.accentGreen.withValues(alpha: 0.9) : AppTheme.backgroundElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: GestureDetector(
            onTap: () => onToggle(!addon.isEnabled),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              alignment: addon.isEnabled ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18, height: 18,
                margin: EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: addon.isEnabled ? AppTheme.textPrimary : AppTheme.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: AppTheme.textTertiary, size: 18),
          onPressed: onRemove,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
// CATALOG MANAGER SCREEN
// ═══════════════════════════════════════════════
class _CatalogManagerScreen extends ConsumerStatefulWidget {
  const _CatalogManagerScreen();
  @override
  ConsumerState<_CatalogManagerScreen> createState() => _CatalogManagerScreenState();
}

class _CatalogManagerScreenState extends ConsumerState<_CatalogManagerScreen> {
  List<CatalogConfig> _catalogs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadCatalogs(); }

  Future<void> _loadCatalogs() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    final repo = ref.read(catalogRepositoryProvider(profileId));
    final catalogs = await repo.getCatalogs();
    if (mounted) setState(() { _catalogs = catalogs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      title: 'Manage Catalogs',
      child: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.textPrimary, strokeWidth: 2))
          : _catalogs.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Column(children: [
                    Icon(Icons.collections_bookmark_outlined, size: 48, color: AppTheme.textTertiary),
                    SizedBox(height: 12),
                    Text('No catalogs', style: TextStyle(color: AppTheme.textSecondary)),
                  ]),
                )
              : _Group(
                  children: _catalogs.map((catalog) => Row(
                    children: [
                      SizedBox(width: 14),
                      Icon(
                        catalog.sourceType == CatalogSourceType.trakt ? Icons.sync
                            : catalog.sourceType == CatalogSourceType.mdblist ? Icons.list
                            : Icons.folder_special,
                        color: AppTheme.textSecondary, size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(catalog.title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                            Text(catalog.sourceType.name.toUpperCase(), style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (catalog.isPreinstalled)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 42, height: 24,
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(width: 18, height: 18, margin: EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: AppTheme.textPrimary, shape: BoxShape.circle)),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: AppTheme.accentRed, size: 18),
                          onPressed: () async {
                            final profileId = ref.read(activeProfileIdProvider);
                            if (profileId != null) {
                              await ref.read(catalogRepositoryProvider(profileId)).removeCatalog(catalog.id);
                              _loadCatalogs();
                            }
                          },
                        ),
                    ],
                  )).toList(),
                ),
    );
  }
}

// ═══════════════════════════════════════════════
// QUALITY FILTERS SCREEN
// ═══════════════════════════════════════════════
class _QualityFiltersScreen extends ConsumerStatefulWidget {
  const _QualityFiltersScreen();
  @override
  ConsumerState<_QualityFiltersScreen> createState() => _QualityFiltersScreenState();
}

class _QualityFiltersScreenState extends ConsumerState<_QualityFiltersScreen> {
  List<QualityFilterConfig> _filters = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadFilters(); }

  Future<void> _loadFilters() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    final manager = ref.read(addonManagerProvider(profileId));
    final filters = await manager.getQualityFilters();
    if (mounted) setState(() { _filters = filters; _loading = false; });
  }

  Future<void> _addFilter() async {
    final regexCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Add Filter', style: TextStyle(color: AppTheme.textPrimary)),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(hintText: 'Filter name', filled: true, fillColor: AppTheme.backgroundElevated, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)), style: TextStyle(color: AppTheme.textPrimary)),
              SizedBox(height: 12),
              TextField(controller: regexCtrl, decoration: InputDecoration(hintText: 'Regex pattern', filled: true, fillColor: AppTheme.backgroundElevated, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)), style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {'name': nameCtrl.text.trim(), 'regex': regexCtrl.text.trim()}),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
            child: Text('Add'),
          ),
        ],
      ),
    );
    if (result == null || result['regex']!.isEmpty) return;
    final newFilter = QualityFilterConfig(
      id: 'qf_${DateTime.now().millisecondsSinceEpoch}',
      deviceName: result['name']!.isNotEmpty ? result['name']! : 'Filter',
      regexPattern: result['regex']!,
      enabled: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _filters.add(newFilter);
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId != null) await ref.read(addonManagerProvider(profileId)).saveQualityFilters(_filters);
    _loadFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.backgroundDark,
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppTheme.backgroundCard, borderRadius: BorderRadius.circular(10)),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 18),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text('Quality Filters', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: AppTheme.accentGreen, size: 24),
                      onPressed: _addFilter,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 120),
            sliver: _loading
                ? SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: AppTheme.textPrimary, strokeWidth: 2)))
                : _filters.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Column(children: [
                            Icon(Icons.filter_alt_off, size: 48, color: AppTheme.textTertiary),
                            SizedBox(height: 12),
                            Text('No filters', style: TextStyle(color: AppTheme.textSecondary)),
                            TextButton(onPressed: _addFilter, child: Text('Add one', style: TextStyle(color: AppTheme.accentGreen))),
                          ]),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final filter = _filters[i];
                            return Padding(
                              padding: EdgeInsets.only(bottom: 2),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                decoration: BoxDecoration(color: AppTheme.backgroundCard, borderRadius: BorderRadius.circular(14)),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(filter.deviceName.isNotEmpty ? filter.deviceName : 'Unnamed', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                                          Text(filter.regexPattern, style: TextStyle(color: AppTheme.textTertiary, fontSize: 12, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      width: 42, height: 24,
                                      decoration: BoxDecoration(
                                        color: filter.enabled ? AppTheme.accentGreen.withValues(alpha: 0.9) : AppTheme.backgroundElevated,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: GestureDetector(
                                        onTap: () async {
                                          _filters[i] = QualityFilterConfig(
                                            id: filter.id, deviceName: filter.deviceName,
                                            regexPattern: filter.regexPattern, enabled: !filter.enabled,
                                            createdAt: filter.createdAt,
                                          );
                                          final profileId = ref.read(activeProfileIdProvider);
                                          if (profileId != null) await ref.read(addonManagerProvider(profileId)).saveQualityFilters(_filters);
                                          setState(() {});
                                        },
                                        child: AnimatedAlign(
                                          duration: const Duration(milliseconds: 180),
                                          alignment: filter.enabled ? Alignment.centerRight : Alignment.centerLeft,
                                          child: Container(
                                            width: 18, height: 18,
                                            margin: EdgeInsets.symmetric(horizontal: 3),
                                            decoration: BoxDecoration(
                                              color: filter.enabled ? AppTheme.textPrimary : AppTheme.textTertiary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: AppTheme.textTertiary, size: 18),
                                      onPressed: () async {
                                        _filters.removeAt(i);
                                        final profileId = ref.read(activeProfileIdProvider);
                                        if (profileId != null) await ref.read(addonManagerProvider(profileId)).saveQualityFilters(_filters);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: _filters.length,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
