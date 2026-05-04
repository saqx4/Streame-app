import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/focus/focusable.dart';
import 'package:streame/core/repositories/profile_repository.dart';
import 'package:streame/core/models/profile_model.dart';

class ProfileSelectionScreen extends ConsumerStatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  ConsumerState<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends ConsumerState<ProfileSelectionScreen> {
  final _newProfileNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDefaultProfile());
  }

  /// Auto-create a default profile on first launch so user isn't stuck
  Future<void> _ensureDefaultProfile() async {
    if (!mounted) return;
    final repo = ref.read(profileRepositoryProvider);
    var profiles = await repo.loadProfiles();
    if (profiles.isEmpty) {
      final profile = await repo.createProfile(name: 'Main');
      await repo.setActiveProfile(profile.id);
      if (mounted) ref.invalidate(profilesProvider);
      ref.invalidate(activeProfileProvider);
    } else {
      // Ensure an active profile is set even if profiles exist
      final activeId = await repo.getActiveProfile();
      if (activeId == null && profiles.isNotEmpty) {
        await repo.setActiveProfile(profiles.first.id);
        ref.invalidate(activeProfileProvider);
      }
    }
  }

  @override
  void dispose() {
    _newProfileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(profilesProvider);
    final activeAsync = ref.watch(activeProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        title: const Text("Who's watching?"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: profilesAsync.when(
        data: (profiles) {
          final activeId = activeAsync.valueOrNull?.id;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  alignment: WrapAlignment.center,
                  children: [
                    ...profiles.map((profile) => _ProfileCard(
                      profile: profile,
                      isActive: profile.id == activeId,
                      onTap: () => _selectProfile(profile),
                      onLongPress: () => _editProfileDialog(profile),
                    )),
                    if (profiles.length < ProfileRepository.maxProfiles)
                      _AddProfileCard(
                        onTap: () => _addProfileDialog(),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.textTertiary)),
        error: (_, __) => const Center(child: Text('Error loading profiles', style: TextStyle(color: AppTheme.textTertiary))),
      ),
    );
  }

  Future<void> _selectProfile(Profile profile) async {
    // If locked, show PIN dialog
    if (profile.isLocked && profile.pin != null) {
      final verified = await _showPinDialog(profile);
      if (!verified) return;
    }

    final repo = ref.read(profileRepositoryProvider);
    await repo.setActiveProfile(profile.id);
    // Invalidate so activeProfileProvider refreshes, then navigate
    ref.invalidate(activeProfileProvider);
    ref.invalidate(activeProfileIdProvider);
    // Use Future.microtask to let the widget tree settle before navigating
    // This avoids GlobalKey conflicts when switching from non-ShellRoute to ShellRoute
    Future.microtask(() {
      if (mounted) context.go('/home');
    });
  }

  Future<bool> _showPinDialog(Profile profile) async {
    final pinController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: Text('Enter PIN for ${profile.name}', style: const TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 5,
          decoration: InputDecoration(
            hintText: 'PIN',
            filled: true,
            fillColor: AppTheme.backgroundElevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            counterText: '',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    pinController.dispose();
    if (result != true) return false;
    final repo = ref.read(profileRepositoryProvider);
    return repo.verifyPin(profile.id, pinController.text);
  }

  Future<void> _addProfileDialog() async {
    _newProfileNameController.clear();
    int selectedAvatarId = ProfileAvatars.random().id;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Profile', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newProfileNameController,
                decoration: InputDecoration(
                  hintText: 'Profile name',
                  filled: true,
                  fillColor: AppTheme.backgroundElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose Avatar', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ProfileAvatars.avatars.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final avatar = ProfileAvatars.avatars[i];
                    final isSelected = avatar.id == selectedAvatarId;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedAvatarId = avatar.id),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Color(avatar.color),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
                        ),
                        child: Icon(avatar.icon, color: Colors.white, size: 28),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Kids Profile', style: TextStyle(color: AppTheme.textPrimary)),
                value: false,
                activeColor: AppTheme.accentGreen,
                onChanged: null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_newProfileNameController.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, {
                    'name': _newProfileNameController.text.trim(),
                    'avatarId': selectedAvatarId,
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      final repo = ref.read(profileRepositoryProvider);
      final avatarId = result['avatarId'] as int;
      final avatar = ProfileAvatars.getById(avatarId);
      await repo.createProfile(
        name: result['name'] as String,
        avatarId: avatarId,
        avatarColor: avatar.color,
      );
      ref.invalidate(profilesProvider);
    }
  }

  Future<void> _editProfileDialog(Profile profile) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(profile.name, style: const TextStyle(color: AppTheme.textPrimary)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'rename'),
            child: const Row(children: [
              Icon(Icons.edit, color: AppTheme.accentYellow, size: 20),
              SizedBox(width: 12),
              Text('Edit Name', style: TextStyle(color: AppTheme.textPrimary)),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'avatar'),
            child: const Row(children: [
              Icon(Icons.face, color: AppTheme.accentYellow, size: 20),
              SizedBox(width: 12),
              Text('Change Avatar', style: TextStyle(color: AppTheme.textPrimary)),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'toggle_lock'),
            child: Row(children: [
              Icon(profile.isLocked ? Icons.lock_open : Icons.lock, color: AppTheme.textPrimary, size: 20),
              const SizedBox(width: 12),
              Text(
                profile.isLocked ? 'Remove PIN Lock' : 'Set PIN Lock',
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Row(children: [
              Icon(Icons.delete, color: AppTheme.accentRed, size: 20),
              SizedBox(width: 12),
              Text('Delete Profile', style: TextStyle(color: AppTheme.accentRed)),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
    if (result == null || result == 'cancel') return;
    final repo = ref.read(profileRepositoryProvider);

    if (result == 'rename') {
      await _showRenameDialog(profile);
    } else if (result == 'avatar') {
      await _showAvatarPicker(profile);
    } else if (result == 'delete') {
      await repo.deleteProfile(profile.id);
      ref.invalidate(profilesProvider);
    } else if (result == 'toggle_lock') {
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
                filled: true,
                fillColor: AppTheme.backgroundElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                counterText: '',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (pinController.text.length >= 4) {
                    Navigator.pop(ctx, pinController.text);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
                child: const Text('Set PIN'),
              ),
            ],
          ),
        );
        pinController.dispose();
        if (pinResult != null) {
          await repo.updateProfile(profile.copyWith(isLocked: true, pin: pinResult));
        }
      }
      ref.invalidate(profilesProvider);
    }
  }

  Future<void> _showRenameDialog(Profile profile) async {
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
            filled: true,
            fillColor: AppTheme.backgroundElevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.textPrimary, foregroundColor: AppTheme.backgroundDark),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(profile.copyWith(name: result));
      ref.invalidate(profilesProvider);
    }
  }

  Future<void> _showAvatarPicker(Profile profile) async {
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (_, i) {
              final avatar = ProfileAvatars.avatars[i];
              final isSelected = avatar.id == profile.avatarId;
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, avatar),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(avatar.color),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
                  ),
                  child: Icon(avatar.icon, color: Colors.white, size: 32),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
    if (result != null) {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(profile.copyWith(avatarId: result.id, avatarColor: result.color));
      ref.invalidate(profilesProvider);
    }
  }
}

class _ProfileCard extends StatelessWidget {
  final Profile profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return StreameFocusable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color(profile.avatarColor),
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(color: AppTheme.textPrimary, width: 3)
                  : Border.all(color: AppTheme.borderMedium, width: 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: profile.avatarId > 0
                      ? Icon(
                          ProfileAvatars.getById(profile.avatarId).icon,
                          color: Colors.white,
                          size: 48,
                        )
                      : Text(
                          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                        ),
                ),
                if (profile.isKidsProfile)
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.accentGreen, borderRadius: BorderRadius.circular(4)),
                      child: const Text('KIDS', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (profile.isLocked)
                  Positioned(
                    bottom: 4, right: 4,
                    child: Icon(Icons.lock, color: Colors.white.withValues(alpha: 0.7), size: 16),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(profile.name, style: TextStyle(color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddProfileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreameFocusable(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderMedium, width: 2),
            ),
            child: const Icon(Icons.add, color: AppTheme.textSecondary, size: 48),
          ),
          const SizedBox(height: 8),
          const Text('Add Profile', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}