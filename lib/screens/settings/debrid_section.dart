import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:streame_core/services/settings_service.dart';
import 'package:streame_core/api/debrid_api.dart';
import 'package:streame_core/utils/app_theme.dart';
import 'settings_widgets.dart';

class DebridSection extends StatefulWidget {
  const DebridSection({super.key});

  @override
  State<DebridSection> createState() => _DebridSectionState();
}

class _DebridSectionState extends State<DebridSection> {
  final SettingsService _settings = SettingsService();
  final DebridApi _debrid = DebridApi();

  bool _useDebrid = false;
  String _debridService = 'None';

  // Real-Debrid
  bool _isRDLoggedIn = false;
  String? _rdUserCode;
  Timer? _rdPollTimer;

  // TorBox
  final TextEditingController _torboxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final useDebrid = await _settings.useDebridForStreams();
    final service = await _settings.getDebridService();
    final torboxKey = await _debrid.getTorBoxKey();
    final rdToken = await _debrid.getRDAccessToken();

    if (mounted) {
      setState(() {
        _useDebrid = useDebrid;
        _debridService = service;
        _torboxController.text = torboxKey ?? '';
        _isRDLoggedIn = rdToken != null;
      });
    }
  }

  @override
  void dispose() {
    _torboxController.dispose();
    _rdPollTimer?.cancel();
    super.dispose();
  }

  void _startRDLogin() async {
    final data = await _debrid.startRDLogin();
    if (data != null) {
      final userCode = data['user_code'];
      setState(() {
        _rdUserCode = userCode;
      });

      await Clipboard.setData(ClipboardData(text: userCode));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Code $userCode copied to clipboard!')),
        );
      }

      _rdPollTimer?.cancel();
      _rdPollTimer = Timer.periodic(Duration(seconds: data['interval']), (
        timer,
      ) async {
        final success = await _debrid.pollRDCredentials(data['device_code']);
        if (success) {
          timer.cancel();
          setState(() {
            _rdUserCode = null;
            _isRDLoggedIn = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Real-Debrid Login Successful!')),
            );
          }
        }
      });

      Future.delayed(Duration(seconds: data['expires_in']), () {
        if (_rdPollTimer?.isActive ?? false) {
          _rdPollTimer?.cancel();
          setState(() => _rdUserCode = null);
        }
      });
    }
  }

  void _logoutRD() async {
    await _debrid.logoutRD();
    setState(() {
      _isRDLoggedIn = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out of Real-Debrid')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FocusableToggle(
          title: 'Use Debrid for Streams',
          subtitle: 'Resolve torrents using your debrid account.',
          value: _useDebrid,
          onChanged: (val) async {
            await _settings.setUseDebridForStreams(val);
            setState(() => _useDebrid = val);
          },
        ),
        FocusableDropdown(
          title: 'Debrid Service',
          subtitle: 'Select your preferred provider.',
          value: _debridService,
          options: ['None', 'Real-Debrid', 'TorBox'],
          onChanged: (val) async {
            if (val != null) {
              await _settings.setDebridService(val);
              setState(() => _debridService = val);
            }
          },
        ),
        if (_debridService == 'Real-Debrid') _buildRDLogin(),
        if (_debridService == 'TorBox') _buildTorBoxConfig(),
      ],
    );
  }

  Widget _buildRDLogin() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isRDLoggedIn)
            ElevatedButton.icon(
              onPressed: _logoutRD,
              icon: const Icon(Icons.logout),
              label: const Text('Logout from Real-Debrid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          else if (_rdUserCode != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Enter this code at real-debrid.com/device:'),
                  const SizedBox(height: 8),
                  Text(
                    _rdUserCode!,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    color: AppTheme.primaryColor,
                    backgroundColor: AppTheme.surfaceContainerHigh.withValues(
                      alpha: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: _startRDLogin,
              icon: const Icon(Icons.login),
              label: const Text('Login with Real-Debrid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surfaceContainerHigh.withValues(
                  alpha: 0.2,
                ),
                foregroundColor: AppTheme.textPrimary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTorBoxConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'API Key',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _torboxController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter TorBox API Key',
                    filled: true,
                    fillColor: AppTheme.surfaceContainerHigh.withValues(
                      alpha: 0.3,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await _debrid.saveTorBoxKey(_torboxController.text);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('TorBox API Key Saved!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
