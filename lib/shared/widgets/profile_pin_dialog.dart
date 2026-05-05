// Profile PIN dialog — for locking/unlocking kids profiles and profile management
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/models/profile_model.dart';

class ProfilePinDialog extends StatefulWidget {
  final Profile profile;
  final bool isVerification;

  const ProfilePinDialog({
    super.key,
    required this.profile,
    this.isVerification = false,
  });

  /// Show PIN entry dialog for verification
  static Future<bool> verify(BuildContext context, Profile profile) async {
    if (profile.pin == null || profile.pin!.isEmpty) return true;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfilePinDialog(profile: profile, isVerification: true),
    );
    return result == profile.pin;
  }

  /// Show PIN setup/change dialog
  static Future<String?> setup(BuildContext context, Profile profile) async {
    return showDialog<String>(
      context: context,
      builder: (_) => ProfilePinDialog(profile: profile, isVerification: false),
    );
  }

  @override
  State<ProfilePinDialog> createState() => _ProfilePinDialogState();
}

class _ProfilePinDialogState extends State<ProfilePinDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() => _error = 'PIN must be 4 digits');
      return;
    }

    if (!widget.isVerification) {
      final confirm = _confirmController.text.trim();
      if (confirm != pin) {
        setState(() => _error = 'PINs do not match');
        return;
      }
    }

    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.backgroundCard,
      title: Text(
        widget.isVerification ? 'Enter PIN' : 'Set PIN',
        style: const TextStyle(color: AppTheme.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.isVerification
                ? 'Enter the PIN for ${widget.profile.name}'
                : 'Set a 4-digit PIN for ${widget.profile.name}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: InputDecoration(
              hintText: '4-digit PIN',
              counterText: '',
              filled: true,
              fillColor: AppTheme.backgroundElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, letterSpacing: 8),
            textAlign: TextAlign.center,
            onSubmitted: (_) => _submit(),
          ),
          if (!widget.isVerification) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'Confirm PIN',
                counterText: '',
                filled: true,
                fillColor: AppTheme.backgroundElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, letterSpacing: 8),
              textAlign: TextAlign.center,
              onSubmitted: (_) => _submit(),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: AppTheme.accentRed, fontSize: 12)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.focusRing,
            foregroundColor: AppTheme.backgroundDark,
          ),
          child: Text(widget.isVerification ? 'Unlock' : 'Save'),
        ),
      ],
    );
  }
}

/// Profile management dialog — create, edit, delete profiles
class ProfileManageDialog extends StatelessWidget {
  final List<Profile> profiles;
  final ValueChanged<Profile> onCreate;
  final ValueChanged<Profile> onUpdate;
  final ValueChanged<String> onDelete;

  const ProfileManageDialog({
    super.key,
    required this.profiles,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
  });

  static void show(BuildContext context, {
    required List<Profile> profiles,
    required ValueChanged<Profile> onCreate,
    required ValueChanged<Profile> onUpdate,
    required ValueChanged<String> onDelete,
  }) {
    showDialog(
      context: context,
      builder: (_) => ProfileManageDialog(
        profiles: profiles,
        onCreate: onCreate,
        onUpdate: onUpdate,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.backgroundCard,
      title: const Text('Manage Profiles', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 400,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: profiles.length + 1,
          itemBuilder: (context, index) {
            if (index == profiles.length) {
              return ListTile(
                leading: Icon(Icons.add_circle_outline, color: AppTheme.accentGreen, size: 36),
                title: const Text('Add Profile', style: TextStyle(color: AppTheme.accentGreen)),
                onTap: () => _showCreateDialog(context),
              );
            }
            final profile = profiles[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(ProfileColors.getByIndex(profile.avatarColor)).withOpacity(0.3),
                child: Text(
                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                  style: TextStyle(color: Color(ProfileColors.getByIndex(profile.avatarColor))),
                ),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(profile.name, style: const TextStyle(color: AppTheme.textPrimary))),
                  if (profile.isKidsProfile)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentYellow.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Kids', style: TextStyle(color: AppTheme.accentYellow, fontSize: 10)),
                    ),
                  if (profile.isLocked)
                    const Icon(Icons.lock, color: AppTheme.textTertiary, size: 14),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed, size: 18),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.backgroundCard,
                      title: Text('Delete ${profile.name}?', style: const TextStyle(color: AppTheme.textPrimary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: AppTheme.textPrimary),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) onDelete(profile.id);
                },
              ),
              onTap: () => _showEditDialog(context, profile),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    bool isKids = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          title: const Text('New Profile', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Profile name',
                  filled: true, fillColor: AppTheme.backgroundElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Kids Profile', style: TextStyle(color: AppTheme.textPrimary)),
                value: isKids,
                activeColor: AppTheme.accentGreen,
                onChanged: (v) => setState(() => isKids = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                onCreate(Profile.create(name: name).copyWith(isKidsProfile: isKids));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.focusRing, foregroundColor: AppTheme.backgroundDark),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Profile profile) {
    final nameCtrl = TextEditingController(text: profile.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: Text('Edit ${profile.name}', style: const TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                hintText: 'Profile name',
                filled: true, fillColor: AppTheme.backgroundElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                final pin = await ProfilePinDialog.setup(context, profile);
                if (pin != null) {
                  onUpdate(profile.copyWith(pin: pin.isEmpty ? null : pin, isLocked: pin.isNotEmpty));
                }
              },
              icon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
              label: Text(
                profile.pin != null ? 'Change PIN' : 'Set PIN',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              onUpdate(profile.copyWith(name: name));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.focusRing, foregroundColor: AppTheme.backgroundDark),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
