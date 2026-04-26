import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:streame_core/api/simkl_service.dart';
import 'package:streame_core/utils/app_theme.dart';

class SimklSection extends StatefulWidget {
  const SimklSection({super.key});

  @override
  State<SimklSection> createState() => _SimklSectionState();
}

class _SimklSectionState extends State<SimklSection> {
  final SimklService _simkl = SimklService();

  bool _isSimklLoggedIn = false;
  String? _simklUserCode;
  String? _simklVerifyUrl;
  Timer? _simklPollTimer;
  bool _isSimklSyncing = false;
  String? _simklUsername;
  final TextEditingController _simklClientIdController =
      TextEditingController();
  final TextEditingController _simklClientSecretController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loggedIn = await _simkl.isLoggedIn();
    String? user;
    if (loggedIn) {
      final profile = await _simkl.getUserProfile();
      user = profile?['name']?.toString();
    }
    if (mounted) {
      setState(() {
        _isSimklLoggedIn = loggedIn;
        _simklUsername = user;
      });
    }
  }

  @override
  void dispose() {
    _simklClientIdController.dispose();
    _simklClientSecretController.dispose();
    _simklPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveSimklCredentials() async {
    final id = _simklClientIdController.text.trim();
    final secret = _simklClientSecretController.text.trim();
    if (id.isEmpty || secret.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter both Client ID and Client Secret'),
          ),
        );
      }
      return;
    }
    await _simkl.saveCredentials(id, secret);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Simkl credentials saved!')));
    }
  }

  void _startSimklLogin() async {
    final configured = await _simkl.isConfiguredAsync();
    if (!configured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Simkl credentials not configured. Enter your Client ID and Client Secret below.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    final data = await _simkl.requestPin();
    if (data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start Simkl login')),
        );
      }
      return;
    }

    final userCode = data['user_code'] as String;
    final verifyUrl =
        data['verification_url']?.toString() ??
        'https://simkl.com/pin/$userCode';
    final interval = (data['interval'] as int?) ?? 5;
    final expiresIn = (data['expires_in'] as int?) ?? 900;

    setState(() {
      _simklUserCode = userCode;
      _simklVerifyUrl = verifyUrl;
    });

    await Clipboard.setData(ClipboardData(text: userCode));

    final uri = Uri.parse(verifyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code $userCode copied! Opening $verifyUrl...')),
      );
    }

    _simklPollTimer?.cancel();
    _simklPollTimer = Timer.periodic(Duration(seconds: interval), (
      timer,
    ) async {
      final token = await _simkl.pollForToken(userCode);
      if (token != null) {
        timer.cancel();
        final profile = await _simkl.getUserProfile();
        final username = profile?['name']?.toString();
        if (mounted) {
          setState(() {
            _simklUserCode = null;
            _simklVerifyUrl = null;
            _isSimklLoggedIn = true;
            _simklUsername = username;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Logged in to Simkl${username != null ? " as $username" : ""}!',
              ),
            ),
          );
        }
        _syncSimkl();
      }
    });

    Future.delayed(Duration(seconds: expiresIn), () {
      if (_simklPollTimer?.isActive ?? false) {
        _simklPollTimer?.cancel();
        if (mounted) {
          setState(() {
            _simklUserCode = null;
            _simklVerifyUrl = null;
          });
        }
      }
    });
  }

  void _logoutSimkl() async {
    await _simkl.logout();
    if (mounted) {
      setState(() {
        _isSimklLoggedIn = false;
        _simklUsername = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logged out of Simkl')));
    }
  }

  Future<void> _syncSimkl() async {
    if (_isSimklSyncing) return;
    setState(() => _isSimklSyncing = true);

    try {
      final watchlistCount = await _simkl.importWatchlistToMyList();
      final episodesImported = await _simkl.importWatchedEpisodes();
      final exportedCount = await _simkl.exportMyListToWatchlist();
      final episodesExported = await _simkl.exportWatchedEpisodes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Simkl sync done! Imported $watchlistCount watchlist, '
              '$episodesImported episodes. '
              'Exported $exportedCount watchlist, $episodesExported episodes.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Simkl sync error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSimklSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sync your watchlist and watch history with Simkl',
            style: TextStyle(fontSize: 13, color: AppTheme.textDisabled),
          ),
          const SizedBox(height: 16),

          if (_isSimklLoggedIn) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected${_simklUsername != null ? " as $_simklUsername" : ""}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Simkl',
                          style: TextStyle(
                            color: AppTheme.textDisabled,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.sync,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSimklSyncing ? null : _syncSimkl,
                icon: _isSimklSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isSimklSyncing ? 'Syncing...' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.textPrimary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _logoutSimkl,
              icon: const Icon(Icons.logout),
              label: const Text('Logout from Simkl'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else if (_simklUserCode != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Go to the URL below and enter this code:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _simklUserCode!,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _simklVerifyUrl ?? 'https://simkl.com/pin',
                    style: TextStyle(
                      color: AppTheme.textDisabled,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    color: AppTheme.primaryColor,
                    backgroundColor: AppTheme.surfaceContainerHigh.withValues(
                      alpha: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Waiting for authorization...',
                    style: TextStyle(
                      color: AppTheme.textDisabled,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Credential input fields
            TextField(
              controller: _simklClientIdController,
              decoration: InputDecoration(
                labelText: 'Simkl Client ID',
                hintText: 'Enter your Simkl Client ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _simklClientSecretController,
              decoration: InputDecoration(
                labelText: 'Simkl Client Secret',
                hintText: 'Enter your Simkl Client Secret',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saveSimklCredentials,
              icon: const Icon(Icons.save),
              label: const Text('Save Credentials'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.8),
                foregroundColor: AppTheme.textPrimary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _startSimklLogin,
              icon: const Icon(Icons.login),
              label: const Text('Login with Simkl'),
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
        ],
      ),
    );
  }
}
