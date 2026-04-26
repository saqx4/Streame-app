import 'package:flutter/material.dart';
import 'package:streame_core/api/mdblist_service.dart';
import 'package:streame_core/utils/app_theme.dart';

class MdblistSection extends StatefulWidget {
  const MdblistSection({super.key});

  @override
  State<MdblistSection> createState() => _MdblistSectionState();
}

class _MdblistSectionState extends State<MdblistSection> {
  final MdblistService _mdblist = MdblistService();

  bool _isMdblistConfigured = false;
  final TextEditingController _mdblistApiKeyController =
      TextEditingController();
  String? _mdblistUsername;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final configured = await _mdblist.isConfigured();
    String? user;
    final key = await _mdblist.getApiKey();
    if (configured) {
      final info = await _mdblist.getUserInfo();
      user = info?['name']?.toString();
    }
    if (mounted) {
      setState(() {
        _isMdblistConfigured = configured;
        _mdblistUsername = user;
        _mdblistApiKeyController.text = key ?? '';
      });
    }
  }

  @override
  void dispose() {
    _mdblistApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveMdblistApiKey() async {
    final key = _mdblistApiKeyController.text.trim();
    if (key.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter an API key')),
        );
      }
      return;
    }

    await _mdblist.setApiKey(key);

    // Validate by fetching user info
    final info = await _mdblist.getUserInfo();
    if (info != null) {
      if (mounted) {
        setState(() {
          _isMdblistConfigured = true;
          _mdblistUsername = info['name']?.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'MDBlist connected${_mdblistUsername != null ? " as $_mdblistUsername" : ""}!',
            ),
          ),
        );
      }
    } else {
      await _mdblist.logout();
      if (mounted) {
        setState(() {
          _isMdblistConfigured = false;
          _mdblistUsername = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid MDBlist API key')),
        );
      }
    }
  }

  void _logoutMdblist() async {
    await _mdblist.logout();
    if (mounted) {
      setState(() {
        _isMdblistConfigured = false;
        _mdblistUsername = null;
        _mdblistApiKeyController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('MDBlist API key removed')));
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
            'Aggregated ratings from IMDb, TMDB, Trakt, Letterboxd, RT, and more',
            style: TextStyle(fontSize: 13, color: AppTheme.textDisabled),
          ),
          const SizedBox(height: 16),

          if (_isMdblistConfigured) ...[
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
                          'Connected${_mdblistUsername != null ? " as $_mdblistUsername" : ""}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'MDBlist',
                          style: TextStyle(
                            color: AppTheme.textDisabled,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _logoutMdblist,
              icon: const Icon(Icons.logout),
              label: const Text('Remove API Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else ...[
            TextField(
              controller: _mdblistApiKeyController,
              decoration: InputDecoration(
                labelText: 'MDBlist API Key',
                hintText: 'Paste your API key from mdblist.com',
                labelStyle: TextStyle(color: AppTheme.textDisabled),
                hintStyle: TextStyle(color: AppTheme.textDisabled),
                filled: true,
                fillColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: AppTheme.textPrimary),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saveMdblistApiKey,
              icon: const Icon(Icons.save),
              label: const Text('Save API Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
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
