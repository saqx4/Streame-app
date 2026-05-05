import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/focus/focusable.dart';
import 'package:streame/shared/widgets/resilient_network_image.dart';
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

class SettingsScreen extends ConsumerStatefulWidget {
  final bool autoCloudAuth;

  const SettingsScreen({super.key, this.autoCloudAuth = false});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState is AuthAuthenticated;
    final isGuest = authState is AuthAuthenticated && authState.isGuest;
    final traktRepo = ref.watch(traktRepositoryProvider);
    final isTraktLinked = traktRepo.isLinked();

    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // ─── Nuvio-style sticky header ───
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.backgroundDark,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    // Round back button (Nuvio: NuvioBackButton)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary, size: 22),
                        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Profile ───
                if (activeProfile != null) ...[
                  _ProfileCard(profile: activeProfile),
                  const SizedBox(height: 24),
                ],
                _Section('Appearance', [
                  _SwitchTile(
                    Icons.blur_on,
                    'Cinematic Background',
                    _getSettingBool('cinematic_background', false),
                    description: 'Blur a full-screen backdrop on detail pages',
                    onChanged: (v) => _setSettingBool('cinematic_background', v),
                  ),
                ]),
                _Section('Playback', [
                  _SettingTile(Icons.language, 'Content Language', _getSetting('content_language', 'en'), onTap: () => _showLanguagePicker()),
                  _SettingTile(Icons.slow_motion_video, 'Default Quality', _getSetting('default_quality', 'Auto'), onTap: () => _showQualityPicker()),
                  _SettingTile(Icons.volume_up, 'Volume Boost', _getSetting('volume_boost', 'Off'), onTap: () => _showVolumeBoostPicker()),
                  _SettingTile(Icons.subtitles, 'Subtitle Language', _getSetting('subtitle_lang', 'en'), onTap: () => _showSubtitleLangPicker()),
                  _SettingTile(Icons.audiotrack, 'Audio Language', _getSetting('audio_lang', 'en'), onTap: () => _showAudioLangPicker()),
                  _SwitchTile(Icons.timer, 'Auto-detect Skip Intro', _getSettingBool('skip_intro_auto', true), description: 'Automatically skip intros when detected', onChanged: (v) => _setSettingBool('skip_intro_auto', v)),
                  _SwitchTile(Icons.skip_next, 'Autoplay Next Episode', _getSettingBool('autoplay_next', true), description: 'Play the next episode automatically', onChanged: (v) => _setSettingBool('autoplay_next', v)),
                  _SwitchTile(Icons.high_quality, 'Trailer Autoplay', _getSettingBool('trailer_autoplay', true), description: 'Autoplay trailers on detail pages', onChanged: (v) => _setSettingBool('trailer_autoplay', v)),
                ]),
                _Section('Content Sources', [
                  _SettingTile(Icons.extension, 'Manage Addons', 'Install, remove, or configure addons', onTap: () => _showAddonManager()),
                  _SettingTile(Icons.add, 'Load Addon URL', 'Add a community addon from URL', onTap: () => _showAddAddonDialog()),
                  _SettingTile(Icons.collections, 'Manage Catalogs', 'Organize your content catalogs', onTap: () => _showCatalogManager()),
                  _SettingTile(Icons.add_circle_outline, 'Add Custom Catalog', 'Add a Trakt or MDBList catalog', onTap: () => _showAddCatalogDialog()),
                  _SettingTile(Icons.dns, 'TorrServer', 'Manage torrent server connections', onTap: () => _showTorrServers()),
                ]),
                _Section('Accounts & Sync', [
                  _SettingTile(
                    Icons.cloud,
                    'Cloud Account',
                    isGuest ? 'Local Mode' : (isLoggedIn ? authState.email : 'Not connected'),
                    onTap: isGuest ? () => _connectCloudAccount() : (isLoggedIn ? null : () => context.go('/login')),
                  ),
                  _SettingTile(
                    Icons.sync,
                    'Trakt.tv',
                    isTraktLinked ? 'Connected' : 'Connect to sync watch history',
                    onTap: isTraktLinked ? () => _showTraktDisconnect() : () => _connectTrakt(),
                  ),
                  if (isLoggedIn && !isGuest) ...[
                    _SettingTile(Icons.tv, 'TV Sign-In (QR Code)', 'Sign in on a TV device', onTap: _showTvAuth),
                  ],
                  if (isLoggedIn)
                    _SettingTile(Icons.logout, isGuest ? 'Switch to Cloud Account' : 'Sign Out', '', onTap: _signOut),
                ]),
                _Section('Advanced', [
                  _SwitchTile(Icons.format_list_bulleted, 'Include Specials', _getSettingBool('include_specials', true), description: 'Show special episodes in season lists', onChanged: (v) => _setSettingBool('include_specials', v)),
                  _SwitchTile(Icons.analytics, 'Show Loading Stats', _getSettingBool('show_loading_stats', false), description: 'Display loading performance data', onChanged: (v) => _setSettingBool('show_loading_stats', v)),
                  _SettingTile(Icons.access_time, 'Clock Format', _getSetting('clock_format', '12h'), onTap: () => _showClockFormatPicker()),
                  _SettingTile(Icons.filter_alt, 'Quality Filters', 'Filter streams by resolution', onTap: () => _showQualityFilters()),
                  _SwitchTile(Icons.screen_lock_portrait, 'Screensaver', _getSettingBool('screensaver_enabled', true), description: 'Show screensaver when idle', onChanged: (v) => _setSettingBool('screensaver_enabled', v)),
                ]),
                _Section('About', [
                  _SettingTile(Icons.info, 'Version', '1.0.0+1'),
                  _SettingTile(Icons.code, 'Build', 'Flutter Debug'),
                  _SettingTile(Icons.open_in_new, 'Open Source Licenses', 'View open source licenses', onTap: () => showLicensePage(context: context, applicationName: 'Streame')),
                ]),
                const SizedBox(height: 32),
                // Version footer (Nuvio-style centered)
                Text(
                  'Made with ❤️',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'v1.0.0+1',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _getSetting(String key, String defaultValue) {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString('settings_$key') ?? defaultValue;
  }

  bool _getSettingBool(String key, bool defaultValue) {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool('settings_$key') ?? defaultValue;
  }

  Future<void> _setSetting(String key, String value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('settings_$key', value);
    setState(() {});
  }

  Future<void> _setSettingBool(String key, bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('settings_$key', value);
    setState(() {});
  }

  void _showLanguagePicker() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: const Text('Content Language', style: TextStyle(color: AppTheme.textPrimary)),
        children: ['en', 'es', 'fr', 'de', 'ja', 'ko', 'pt', 'it', 'hi', 'zh'].map((code) {
          final name = LanguageMap.getLanguageName(code);
          return SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx, code); _setSetting('content_language', code); },
            child: Text(name, style: const TextStyle(color: AppTheme.textPrimary)),
          );
        }).toList(),
      ),
    );
  }

  void _showQualityPicker() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: const Text('Default Quality', style: TextStyle(color: AppTheme.textPrimary)),
        children: ['Auto', '4K', '1080p', '720p', '480p'].map((q) {
          return SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx, q); _setSetting('default_quality', q); },
            child: Text(q, style: const TextStyle(color: AppTheme.textPrimary)),
          );
        }).toList(),
      ),
    );
  }

  void _showSubtitleLangPicker() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: const Text('Subtitle Language', style: TextStyle(color: AppTheme.textPrimary)),
        children: ['en', 'es', 'fr', 'de', 'ja', 'ko', 'pt', 'it', 'hi', 'zh', 'Off'].map((code) {
          final name = code == 'Off' ? 'Off' : LanguageMap.getLanguageName(code);
          return SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx, code); _setSetting('subtitle_lang', code); },
            child: Text(name, style: const TextStyle(color: AppTheme.textPrimary)),
          );
        }).toList(),
      ),
    );
  }

  void _showAudioLangPicker() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: const Text('Audio Language', style: TextStyle(color: AppTheme.textPrimary)),
        children: ['en', 'es', 'fr', 'de', 'ja', 'ko', 'pt', 'it', 'hi', 'zh'].map((code) {
          final name = LanguageMap.getLanguageName(code);
          return SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx, code); _setSetting('audio_lang', code); },
            child: Text(name, style: const TextStyle(color: AppTheme.textPrimary)),
          );
        }).toList(),
      ),
    );
  }

  void _showClockFormatPicker() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: const Text('Clock Format', style: TextStyle(color: AppTheme.textPrimary)),
        children: ['12h', '24h'].map((f) {
          return SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx, f); _setSetting('clock_format', f); },
            child: Text(f, style: const TextStyle(color: AppTheme.textPrimary)),
          );
        }).toList(),
      ),
    );
  }

  void _showAddonManager() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AddonManagerScreen()));
  }

  /// Resolve active profile ID, auto-selecting first profile if none is active
  Future<String?> _resolveProfileId() async {
    var id = ref.read(activeProfileIdProvider);
    if (id != null) return id;
    // No active profile — try to auto-select the first one
    final repo = ref.read(profileRepositoryProvider);
    final profiles = await repo.loadProfiles();
    if (profiles.isEmpty) return null;
    await repo.setActiveProfile(profiles.first.id);
    ref.invalidate(activeProfileProvider);
    // Allow provider to rebuild
    await Future.delayed(const Duration(milliseconds: 50));
    id = ref.read(activeProfileIdProvider);
    return id;
  }

  void _showAddAddonDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Load Addon URL', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'https://example.com/manifest.json',
            filled: true, fillColor: AppTheme.backgroundElevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = controller.text.trim();
              Navigator.pop(ctx);
              if (url.isEmpty) return;
              final profileId = await _resolveProfileId();
              if (profileId == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No active profile. Please select a profile first.'), backgroundColor: AppTheme.accentRed),
                  );
                }
                return;
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loading addon...'), backgroundColor: AppTheme.backgroundCard),
                );
              }
              try {
                final repo = ref.read(addonRepositoryProvider(profileId));
                final manifest = await repo.loadManifest(url);
                if (manifest == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to load addon manifest. Check the URL.'), backgroundColor: AppTheme.accentRed),
                    );
                  }
                  return;
                }
                await repo.addCustomAddon(url);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${manifest.name} installed'), backgroundColor: AppTheme.backgroundCard),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.accentRed),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectTrakt() async {
    final repo = ref.read(traktRepositoryProvider);

    // Step 1: Request device code
    final deviceData = await repo.requestDeviceCode();
    if (deviceData == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to Trakt. Try again.'), backgroundColor: AppTheme.accentRed),
      );
      return;
    }

    final userCode = deviceData['user_code'] as String? ?? '';
    final verificationUrl = deviceData['verification_url'] as String? ?? 'https://trakt.tv/activate';
    final deviceCode = deviceData['device_code'] as String? ?? '';
    final expiresIn = deviceData['expires_in'] as int? ?? 600;
    final interval = deviceData['interval'] as int? ?? 5;

    // Step 2: Show dialog with user code + verification URL
    if (!mounted) return;
    bool cancelled = false;
    bool success = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sync, color: AppTheme.accentRed, size: 22),
            const SizedBox(width: 8),
            const Text('Connect Trakt', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Go to the link below and enter this code:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            SelectableText(
              verificationUrl,
              style: const TextStyle(color: AppTheme.accentGreen, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.backgroundElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: SelectableText(
                userCode,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Expires in ${Duration(seconds: expiresIn).inMinutes} minutes',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentRed)),
                SizedBox(width: 8),
                Text('Waiting for authorization...', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.pop(ctx);
            },
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => launchUrl(Uri.parse(verificationUrl), mode: LaunchMode.externalApplication),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: AppTheme.textPrimary),
            child: const Text('Open Link'),
          ),
        ],
      ),
    );

    // Step 3: Poll for token
    final deadline = DateTime.now().add(Duration(seconds: expiresIn));
    while (!cancelled && DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: interval));
      if (cancelled || !mounted) break;

      final tokens = await repo.pollDeviceToken(deviceCode);
      if (tokens != null) {
        success = true;
        break;
      }
    }

    // Step 4: Close dialog and show result
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close the waiting dialog

    if (success) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trakt connected!'), backgroundColor: AppTheme.accentGreen),
      );
    } else if (!cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trakt authorization timed out. Try again.'), backgroundColor: AppTheme.accentRed),
      );
    }
  }

  void _showTraktDisconnect() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: const Text('Disconnect Trakt?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Your Trakt data will no longer sync.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(traktRepositoryProvider).logout();
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: AppTheme.textPrimary),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: const Text('Sign Out?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('You will need to sign in again to access your account.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: AppTheme.textPrimary),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).signOut();
      if (mounted) context.go('/login');
    }
  }

  void _showVolumeBoostPicker() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: const Text('Volume Boost', style: TextStyle(color: AppTheme.textPrimary)),
        children: ['Off', 'Low (+6dB)', 'Medium (+12dB)', 'High (+18dB)', 'Max (+24dB)'].map((v) {
          return SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx, v); _setSetting('volume_boost', v); },
            child: Text(v, style: const TextStyle(color: AppTheme.textPrimary)),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _showCatalogManager() async {
    final profileId = await _resolveProfileId();
    if (profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active profile. Please select a profile first.'), backgroundColor: AppTheme.accentRed),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CatalogManagerScreen(profileId: profileId)));
  }

  void _showAddCatalogDialog() {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedType = 'trakt';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Custom Catalog', style: TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    filled: true, fillColor: AppTheme.backgroundElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  dropdownColor: AppTheme.backgroundCard,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'trakt', child: Text('Trakt List')),
                    DropdownMenuItem(value: 'mdblist', child: Text('MDBList')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v ?? 'trakt'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Catalog name',
                    filled: true, fillColor: AppTheme.backgroundElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    hintText: selectedType == 'trakt' ? 'Trakt list URL or slug' : 'MDBList URL or slug',
                    filled: true, fillColor: AppTheme.backgroundElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
            ElevatedButton(
              onPressed: () async {
                final url = urlCtrl.text.trim();
                final name = nameCtrl.text.trim();
                Navigator.pop(ctx);
                if (url.isEmpty) return;
                final profileId = await _resolveProfileId();
                if (profileId == null) return;
                try {
                  final repo = ref.read(catalogRepositoryProvider(profileId));
                  await repo.addCatalog(CatalogConfig(
                    id: '${selectedType}_${DateTime.now().millisecondsSinceEpoch}',
                    title: name.isNotEmpty ? name : url,
                    sourceType: selectedType == 'trakt' ? CatalogSourceType.trakt : CatalogSourceType.mdblist,
                    sourceUrl: url,
                  ));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Catalog added'), backgroundColor: AppTheme.backgroundCard),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.accentRed),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTorrServers() async {
    final profileId = await _resolveProfileId();
    if (profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active profile. Please select a profile first.'), backgroundColor: AppTheme.accentRed),
      );
      return;
    }
    final manager = ref.read(addonManagerProvider(profileId));
    manager.getTorrServers().then((servers) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('TorrServer Servers', style: TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            width: 400,
            child: servers.isEmpty
                ? const Text('No servers added', style: TextStyle(color: AppTheme.textSecondary))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: servers.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(servers[i].name, style: const TextStyle(color: AppTheme.textPrimary)),
                      subtitle: Text(servers[i].url, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: AppTheme.accentRed, size: 18),
                        onPressed: () async {
                          try {
                            await manager.removeTorrServer(servers[i].url);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showTorrServers();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.accentRed),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(ctx); _showAddTorrServerDialog(); },
              child: const Text('Add Server', style: TextStyle(color: AppTheme.accentGreen)),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary))),
          ],
        ),
      );
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading servers: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    });
  }

  void _showAddTorrServerDialog() {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add TorrServer', style: TextStyle(color: AppTheme.textPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Server name',
                  filled: true, fillColor: AppTheme.backgroundElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.x:8090',
                  filled: true, fillColor: AppTheme.backgroundElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              final url = urlCtrl.text.trim();
              final name = nameCtrl.text.trim();
              Navigator.pop(ctx);
              if (url.isEmpty) return;
              final profileId = await _resolveProfileId();
              if (profileId == null) return;
              try {
                await ref.read(addonManagerProvider(profileId)).addTorrServer(url, name.isNotEmpty ? name : url);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Server added'), backgroundColor: AppTheme.backgroundCard),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.accentRed),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Cloud sync removed — Trakt handles sync now

  void _showTvAuth() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('TV QR sign-in coming soon'), backgroundColor: AppTheme.backgroundCard),
    );
  }

  void _connectCloudAccount() {
    // Sign out of guest mode, then redirect to login
    ref.read(authStateProvider.notifier).signOut().then((_) {
      if (mounted) context.go('/login');
    });
  }

  Future<void> _showQualityFilters() async {
    final profileId = await _resolveProfileId();
    if (profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active profile. Please select a profile first.'), backgroundColor: AppTheme.accentRed),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _QualityFiltersScreen(profileId: profileId)));
  }

}

class _AddonManagerScreen extends ConsumerStatefulWidget {
  const _AddonManagerScreen();

  @override
  ConsumerState<_AddonManagerScreen> createState() => _AddonManagerScreenState();
}

class _AddonManagerScreenState extends ConsumerState<_AddonManagerScreen> {
  List<Addon> _addons = [];
  bool _loading = true;
  String _searchQuery = '';
  _AddonFilter _filter = _AddonFilter.all;

  /// Resolve active profile ID, auto-selecting first profile if none is active
  Future<String?> _resolveProfileId() async {
    var id = ref.read(activeProfileIdProvider);
    if (id != null) return id;
    final repo = ref.read(profileRepositoryProvider);
    final profiles = await repo.loadProfiles();
    if (profiles.isEmpty) return null;
    await repo.setActiveProfile(profiles.first.id);
    ref.invalidate(activeProfileProvider);
    await Future.delayed(const Duration(milliseconds: 50));
    id = ref.read(activeProfileIdProvider);
    return id;
  }

  @override
  void initState() {
    super.initState();
    _loadAddons();
  }

  Future<void> _loadAddons() async {
    final profileId = await _resolveProfileId();
    if (profileId == null) { setState(() => _loading = false); return; }
    final repo = ref.read(addonRepositoryProvider(profileId));
    final addons = await repo.getInstalledAddons();
    if (mounted) setState(() { _addons = addons; _loading = false; });
  }

  List<Addon> get _filteredAddons {
    var list = _addons;
    if (_filter == _AddonFilter.official) {
      list = list.where((a) => a.type == AddonType.official).toList();
    } else if (_filter == _AddonFilter.custom) {
      list = list.where((a) => a.type != AddonType.official).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) => a.name.toLowerCase().contains(q) || a.description.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Future<void> _toggleAddon(Addon addon, bool enabled) async {
    final profileId = await _resolveProfileId();
    if (profileId == null) return;
    final repo = ref.read(addonRepositoryProvider(profileId));
    await repo.toggleAddon(addon.id, enabled);
    _loadAddons();
  }

  Future<void> _removeAddon(Addon addon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove ${addon.name}?', style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text('This addon will be uninstalled.', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: AppTheme.textPrimary),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final profileId = await _resolveProfileId();
    if (profileId == null) return;
    final repo = ref.read(addonRepositoryProvider(profileId));
    await repo.removeAddon(addon.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${addon.name} removed'), backgroundColor: AppTheme.backgroundCard),
      );
    }
    _loadAddons();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAddons;
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        title: const Text('Manage Addons', style: TextStyle(color: AppTheme.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.textPrimary))
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search addons...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textTertiary),
                      filled: true, fillColor: AppTheme.backgroundCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  ),
                ),
                // Filter tabs
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: _AddonFilter.values.map((f) {
                      final selected = _filter == f;
                      final label = f == _AddonFilter.all ? 'All'
                          : f == _AddonFilter.official ? 'Official' : 'Custom';
                      final count = f == _AddonFilter.all ? _addons.length
                          : f == _AddonFilter.official ? _addons.where((a) => a.type == AddonType.official).length
                          : _addons.where((a) => a.type != AddonType.official).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$label ($count)'),
                          selected: selected,
                          onSelected: (_) => setState(() => _filter = f),
                          selectedColor: AppTheme.accentGreen.withValues(alpha: 0.2),
                          backgroundColor: AppTheme.backgroundCard,
                          side: BorderSide(color: selected ? AppTheme.accentGreen : AppTheme.borderLight),
                          labelStyle: TextStyle(
                            color: selected ? AppTheme.accentGreen : AppTheme.textSecondary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Addon list
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.extension, size: 64, color: AppTheme.textTertiary),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ? 'No addons match "$_searchQuery"' : 'No addons installed',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final addon = filtered[index];
                            return _AddonTile(
                              addon: addon,
                              onToggle: (enabled) => _toggleAddon(addon, enabled),
                              onRemove: () => _removeAddon(addon),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

enum _AddonFilter { all, official, custom }

class _AddonTile extends StatelessWidget {
  final Addon addon;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;

  const _AddonTile({required this.addon, required this.onToggle, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final rawLogo = addon.logo;
    final logoUrl = (rawLogo != null && rawLogo.isNotEmpty)
        ? (rawLogo.startsWith('http')
            ? rawLogo
            : (addon.url != null
                ? Uri.parse(addon.url!).resolve(rawLogo).toString()
                : rawLogo))
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.backgroundElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: logoUrl != null && logoUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ResilientNetworkImage(imageUrl: logoUrl, errorWidget: (_, __, ___) => const Icon(Icons.extension, color: AppTheme.textTertiary)),
                  )
                : const Icon(Icons.extension, color: AppTheme.textTertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(addon.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (addon.type == AddonType.official)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.accentYellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Official', style: TextStyle(color: AppTheme.accentYellow, fontSize: 9, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  addon.description.isNotEmpty ? addon.description : addon.version,
                  style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: addon.isEnabled,
            activeColor: AppTheme.accentGreen,
            onChanged: onToggle,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.textTertiary, size: 22),
            onPressed: onRemove,
            visualDensity: VisualDensity.standard,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// NUVIO-STYLE SETTINGS COMPONENTS
// ═══════════════════════════════════════════════

/// Section label above a settings group (Nuvio: NuvioSectionLabel)
class _SettingsSection extends StatelessWidget {
  final String title;
  const _SettingsSection(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Rounded card container with thin border (Nuvio: SettingsGroup / SettingsCard)
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup(this.children);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderLight.withValues(alpha: 0.24),
          width: 0.5,
        ),
      ),
      child: Column(children: children),
    );
  }
}

/// Thin divider inside a group, offset from left to align after icon area
class _SettingsGroupDivider extends StatelessWidget {
  const _SettingsGroupDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 66),
      child: Divider(height: 0.5, thickness: 0.5, color: AppTheme.borderLight.withValues(alpha: 0.12)),
    );
  }
}

/// Navigation row with icon chip, title, description, and chevron (Nuvio: SettingsNavigationRow)
class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingTile(this.icon, this.title, this.subtitle, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreameFocusable(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon chip (Nuvio: Surface with primary 12% bg, rounded 10dp)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.textPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.textPrimary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.92), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Switch row with icon chip, title, description, and toggle (Nuvio: SettingsSwitchRow)
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile(this.icon, this.title, this.value, {this.description, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: () => onChanged?.call(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icon chip
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.textPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.textPrimary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                    if (description != null && description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(description!, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.92), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppTheme.textPrimary,
                activeTrackColor: AppTheme.textPrimary.withValues(alpha: 0.5),
                inactiveThumbColor: AppTheme.textSecondary,
                inactiveTrackColor: AppTheme.borderMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Combined section + group builder that auto-inserts dividers between items
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsSection(title),
          _SettingsGroup([
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const _SettingsGroupDivider(),
            ],
          ]),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// PROFILE CARD — Shows current profile at top of settings
// ═══════════════════════════════════════════════
class _ProfileCard extends ConsumerWidget {
  final Profile profile;
  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Change profile',
            child: GestureDetector(
              onTap: () => Future.microtask(() => context.go('/profile-select')),
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Color(profile.avatarColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: profile.avatarId > 0
                      ? Icon(ProfileAvatars.getById(profile.avatarId).icon, color: AppTheme.textPrimary, size: 24)
                      : Text(
                          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  profile.isKidsProfile ? 'Kids Profile' : 'Standard Profile',
                  style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 22),
            onPressed: () => _showProfileEditSheet(context, ref),
            tooltip: 'Edit Profile',
            visualDensity: VisualDensity.standard,
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: AppTheme.textSecondary, size: 22),
            onPressed: () => Future.microtask(() => context.go('/profile-select')),
            tooltip: 'Switch Profile',
          ),
        ],
      ),
    );
  }

  void _showProfileEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Color(profile.avatarColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: profile.avatarId > 0
                          ? Icon(ProfileAvatars.getById(profile.avatarId).icon, color: AppTheme.textPrimary, size: 20)
                          : Text(profile.name[0].toUpperCase(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(profile.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderLight),
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.accentYellow),
              title: const Text('Edit Name', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () { Navigator.pop(ctx); _showRenameDialog(context, ref); },
            ),
            ListTile(
              leading: const Icon(Icons.face, color: AppTheme.accentYellow),
              title: const Text('Change Avatar', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () { Navigator.pop(ctx); _showAvatarPicker(context, ref); },
            ),
            ListTile(
              leading: Icon(profile.isLocked ? Icons.lock_open : Icons.lock, color: AppTheme.textPrimary),
              title: Text(profile.isLocked ? 'Remove PIN Lock' : 'Set PIN Lock', style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () { Navigator.pop(ctx); _togglePinLock(context, ref); },
            ),
            if (profile.isKidsProfile)
              ListTile(
                leading: const Icon(Icons.child_care, color: AppTheme.textPrimary),
                title: const Text('Remove Kids Mode', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(profileRepositoryProvider).updateProfile(profile.copyWith(isKidsProfile: false));
                  ref.invalidate(profilesProvider);
                  ref.invalidate(activeProfileProvider);
                },
              ),
            const SizedBox(height: 8),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Name', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Profile name',
            filled: true, fillColor: AppTheme.backgroundElevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () { if (controller.text.trim().isNotEmpty) Navigator.pop(ctx, controller.text.trim()); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
            child: const Text('Save'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Choose Avatar', style: TextStyle(color: AppTheme.textPrimary)),
        content: SizedBox(
          width: 320,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: ProfileAvatars.avatars.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12),
            itemBuilder: (_, i) {
              final avatar = ProfileAvatars.avatars[i];
              final isSelected = avatar.id == profile.avatarId;
              return Semantics(
                button: true,
                label: 'Avatar ${avatar.id}',
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, avatar),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(avatar.color),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: AppTheme.textPrimary, width: 3) : Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.12), width: 1),
                    ),
                    child: Icon(avatar.icon, color: AppTheme.textPrimary, size: 32),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)))],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Set PIN for ${profile.name}', style: const TextStyle(color: AppTheme.textPrimary)),
          content: TextField(
            controller: pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 5,
            decoration: InputDecoration(
              hintText: '4-5 digit PIN',
              filled: true, fillColor: AppTheme.backgroundElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              counterText: '',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
            ElevatedButton(
              onPressed: () { if (pinController.text.length >= 4) Navigator.pop(ctx, pinController.text); },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
              child: const Text('Set PIN'),
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
// CATALOG MANAGER — Full screen to manage catalogs
// ═══════════════════════════════════════════════
class _CatalogManagerScreen extends ConsumerStatefulWidget {
  final String profileId;
  const _CatalogManagerScreen({required this.profileId});

  @override
  ConsumerState<_CatalogManagerScreen> createState() => _CatalogManagerScreenState();
}

class _CatalogManagerScreenState extends ConsumerState<_CatalogManagerScreen> {
  List<CatalogConfig> _catalogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    final repo = ref.read(catalogRepositoryProvider(widget.profileId));
    final catalogs = await repo.getCatalogs();
    if (mounted) setState(() { _catalogs = catalogs; _loading = false; });
  }

  Future<void> _togglePreinstalled(CatalogConfig catalog, bool visible) async {
    final repo = ref.read(catalogRepositoryProvider(widget.profileId));
    if (visible) {
      await repo.showPreinstalled(catalog.id);
    } else {
      await repo.hidePreinstalled(catalog.id);
    }
    _loadCatalogs();
  }

  Future<void> _removeCatalog(CatalogConfig catalog) async {
    final repo = ref.read(catalogRepositoryProvider(widget.profileId));
    await repo.removeCatalog(catalog.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${catalog.title} removed'), backgroundColor: AppTheme.backgroundCard),
      );
    }
    _loadCatalogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        title: const Text('Manage Catalogs', style: TextStyle(color: AppTheme.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.textPrimary))
          : _catalogs.isEmpty
              ? const Center(child: Text('No catalogs', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _catalogs.length,
                  itemBuilder: (context, index) {
                    final catalog = _catalogs[index];
                    final isPreinstalled = catalog.isPreinstalled;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            catalog.sourceType == CatalogSourceType.preinstalled ? Icons.folder_special
                                : catalog.sourceType == CatalogSourceType.trakt ? Icons.sync
                                : catalog.sourceType == CatalogSourceType.mdblist ? Icons.list
                                : Icons.extension,
                            color: AppTheme.textSecondary, size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(catalog.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  catalog.sourceType.name.toUpperCase(),
                                  style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (isPreinstalled)
                            Switch(
                              value: true,
                              activeColor: AppTheme.accentGreen,
                              onChanged: (v) => _togglePreinstalled(catalog, v),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed, size: 20),
                              onPressed: () => _removeCatalog(catalog),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ═══════════════════════════════════════════════
// QUALITY FILTERS — Manage regex-based quality filters
// ═══════════════════════════════════════════════
class _QualityFiltersScreen extends ConsumerStatefulWidget {
  final String profileId;
  const _QualityFiltersScreen({required this.profileId});

  @override
  ConsumerState<_QualityFiltersScreen> createState() => _QualityFiltersScreenState();
}

class _QualityFiltersScreenState extends ConsumerState<_QualityFiltersScreen> {
  List<QualityFilterConfig> _filters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    final manager = ref.read(addonManagerProvider(widget.profileId));
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Quality Filter', style: TextStyle(color: AppTheme.textPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Filter name (e.g. "Block CAM")',
                  filled: true, fillColor: AppTheme.backgroundElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: regexCtrl,
                decoration: InputDecoration(
                  hintText: 'Regex pattern (e.g. "(?i)cam|hdts")',
                  filled: true, fillColor: AppTheme.backgroundElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {'name': nameCtrl.text.trim(), 'regex': regexCtrl.text.trim()}),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
            child: const Text('Add'),
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
    final manager = ref.read(addonManagerProvider(widget.profileId));
    await manager.saveQualityFilters(_filters);
    _loadFilters();
  }

  Future<void> _removeFilter(int index) async {
    _filters.removeAt(index);
    final manager = ref.read(addonManagerProvider(widget.profileId));
    await manager.saveQualityFilters(_filters);
    _loadFilters();
  }

  Future<void> _toggleFilter(int index, bool enabled) async {
    _filters[index] = QualityFilterConfig(
      id: _filters[index].id,
      deviceName: _filters[index].deviceName,
      regexPattern: _filters[index].regexPattern,
      enabled: enabled,
      createdAt: _filters[index].createdAt,
    );
    final manager = ref.read(addonManagerProvider(widget.profileId));
    await manager.saveQualityFilters(_filters);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        title: const Text('Quality Filters', style: TextStyle(color: AppTheme.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.textPrimary),
            onPressed: _addFilter,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.textPrimary))
          : _filters.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.filter_alt_off, size: 64, color: AppTheme.textTertiary),
                      const SizedBox(height: 16),
                      const Text('No quality filters', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _addFilter,
                        child: const Text('Add a filter', style: TextStyle(color: AppTheme.accentYellow)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(filter.deviceName.isNotEmpty ? filter.deviceName : 'Unnamed Filter',
                                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(filter.regexPattern,
                                    style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                          Switch(
                            value: filter.enabled,
                            activeColor: AppTheme.accentGreen,
                            onChanged: (v) => _toggleFilter(index, v),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed, size: 20),
                            onPressed: () => _removeFilter(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}