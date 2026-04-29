import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:streame_core/api/trakt_service.dart';
import 'package:streame_core/utils/app_theme.dart';

class TraktSection extends StatefulWidget {
  const TraktSection({super.key});

  @override
  State<TraktSection> createState() => _TraktSectionState();
}

class _TraktSectionState extends State<TraktSection> {
  final TraktService _trakt = TraktService();

  bool _isTraktLoggedIn = false;
  String? _traktUserCode;
  String? _traktVerifyUrl;
  Timer? _traktPollTimer;
  bool _isTraktSyncing = false;
  String? _traktUsername;
  Map<String, dynamic>? _traktStats;
  final TextEditingController _traktClientIdController =
      TextEditingController();
  final TextEditingController _traktClientSecretController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loggedIn = await _trakt.isLoggedIn();
    String? user;
    Map<String, dynamic>? stats;
    if (loggedIn) {
      final profile = await _trakt.getUserProfile();
      user =
          profile?['user']?['username']?.toString() ??
          profile?['username']?.toString();
      stats = await _trakt.getUserStats();
    }
    // Pre-fill credential fields from saved storage
    final savedId = await _trakt.clientId;
    final savedSecret = await _trakt.clientSecret;
    if (mounted) {
      setState(() {
        _isTraktLoggedIn = loggedIn;
        _traktUsername = user;
        _traktStats = stats;
        if (savedId.isNotEmpty) _traktClientIdController.text = savedId;
        if (savedSecret.isNotEmpty) _traktClientSecretController.text = savedSecret;
      });
    }
  }

  @override
  void dispose() {
    _traktClientIdController.dispose();
    _traktClientSecretController.dispose();
    _traktPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveTraktCredentials() async {
    final id = _traktClientIdController.text.trim();
    final secret = _traktClientSecretController.text.trim();
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
    await _trakt.saveCredentials(id, secret);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trakt credentials saved!')));
    }
  }

  void _startTraktLogin() async {
    final configured = await _trakt.isConfiguredAsync();
    if (!configured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Trakt credentials not configured. Enter your Client ID and Client Secret below.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    final data = await _trakt.startDeviceAuth();
    if (data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start Trakt login')),
        );
      }
      return;
    }

    final userCode = data['user_code'] as String;
    final verifyUrl = data['verification_url'] as String;
    final interval = (data['interval'] as int?) ?? 5;
    final expiresIn = (data['expires_in'] as int?) ?? 600;
    final deviceCode = data['device_code'] as String;

    setState(() {
      _traktUserCode = userCode;
      _traktVerifyUrl = verifyUrl;
    });

    await Clipboard.setData(ClipboardData(text: userCode));

    // Auto-open the verification URL in the default browser
    final uri = Uri.parse(verifyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code $userCode copied! Opening $verifyUrl...')),
      );
    }

    _traktPollTimer?.cancel();
    _traktPollTimer = Timer.periodic(Duration(seconds: interval), (
      timer,
    ) async {
      final result = await _trakt.pollForToken(deviceCode);
      if (result == 'success') {
        timer.cancel();
        // Fetch username
        final profile = await _trakt.getUserProfile();
        final username =
            profile?['user']?['username']?.toString() ??
            profile?['username']?.toString();
        if (mounted) {
          setState(() {
            _traktUserCode = null;
            _traktVerifyUrl = null;
            _isTraktLoggedIn = true;
            _traktUsername = username;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Logged in to Trakt${username != null ? " as $username" : ""}!',
              ),
            ),
          );
        }
        // Auto-sync after login
        _syncTrakt();
      } else if (result == 'expired' || result == 'denied') {
        timer.cancel();
        if (mounted) {
          setState(() {
            _traktUserCode = null;
            _traktVerifyUrl = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result == 'denied'
                    ? 'Trakt login denied'
                    : 'Code expired, try again',
              ),
            ),
          );
        }
      }
      // 'pending' → keep polling
    });

    // Expire timer
    Future.delayed(Duration(seconds: expiresIn), () {
      if (_traktPollTimer?.isActive ?? false) {
        _traktPollTimer?.cancel();
        if (mounted) {
          setState(() {
            _traktUserCode = null;
            _traktVerifyUrl = null;
          });
        }
      }
    });
  }

  void _logoutTrakt() async {
    await _trakt.logout();
    if (mounted) {
      setState(() {
        _isTraktLoggedIn = false;
        _traktUsername = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logged out of Trakt')));
    }
  }

  Future<void> _syncTrakt() async {
    if (_isTraktSyncing) return;
    setState(() => _isTraktSyncing = true);

    try {
      final watchlistCount = await _trakt.importWatchlistToMyList();
      final playbackCount = await _trakt.importPlaybackToWatchHistory();
      final episodesImported = await _trakt.importWatchedEpisodes();
      final exportedCount = await _trakt.exportMyListToWatchlist();
      final episodesExported = await _trakt.exportWatchedEpisodes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trakt sync done! Imported $watchlistCount watchlist, '
              '$playbackCount playback, $episodesImported episodes. '
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
        ).showSnackBar(SnackBar(content: Text('Trakt sync error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isTraktSyncing = false);
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
            'Sync your watchlist and watch history with Trakt.tv',
            style: TextStyle(fontSize: 13, color: AppTheme.textDisabled),
          ),
          const SizedBox(height: 16),

          if (_isTraktLoggedIn) ...[
            // ── Logged in ──
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
                          'Connected${_traktUsername != null ? " as $_traktUsername" : ""}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Trakt.tv',
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

            // Stats
            if (_traktStats != null) ...[
              _buildTraktStatsWidget(),
              const SizedBox(height: 12),
            ],

            // Sync button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTraktSyncing ? null : _syncTrakt,
                icon: _isTraktSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isTraktSyncing ? 'Syncing...' : 'Sync Now'),
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

            // Logout button
            ElevatedButton.icon(
              onPressed: _logoutTrakt,
              icon: const Icon(Icons.logout),
              label: const Text('Logout from Trakt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else if (_traktUserCode != null) ...[
            // ── Polling — show code ──
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
                    _traktUserCode!,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _traktVerifyUrl ?? 'https://trakt.tv/activate',
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
            // ── Not logged in ──
            // Credential input fields
            TextField(
              controller: _traktClientIdController,
              decoration: InputDecoration(
                labelText: 'Trakt Client ID',
                hintText: 'Enter your Trakt Client ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _traktClientSecretController,
              decoration: InputDecoration(
                labelText: 'Trakt Client Secret',
                hintText: 'Enter your Trakt Client Secret',
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
              onPressed: _saveTraktCredentials,
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
              onPressed: _startTraktLogin,
              icon: const Icon(Icons.login),
              label: const Text('Login with Trakt'),
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

  Widget _buildTraktStatsWidget() {
    final stats = _traktStats!;
    final movies = stats['movies'] as Map<String, dynamic>? ?? {};
    final episodes = stats['episodes'] as Map<String, dynamic>? ?? {};
    final moviesWatched = movies['watched'] as int? ?? 0;
    final moviesMinutes = movies['minutes'] as int? ?? 0;
    final epsWatched = episodes['watched'] as int? ?? 0;
    final epsMinutes = episodes['minutes'] as int? ?? 0;
    final totalHours = ((moviesMinutes + epsMinutes) / 60).round();

    Widget stat(IconData icon, String label, String value) {
      return Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: AppTheme.textDisabled, fontSize: 11),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          stat(Icons.movie_rounded, 'Movies', '$moviesWatched'),
          stat(Icons.tv_rounded, 'Episodes', '$epsWatched'),
          stat(Icons.schedule_rounded, 'Hours', '$totalHours'),
        ],
      ),
    );
  }
}
