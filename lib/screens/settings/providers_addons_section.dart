import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../api/stremio_service.dart';
import '../../services/jackett_service.dart';
import '../../services/prowlarr_service.dart';
import '../../utils/app_theme.dart';

class ProvidersAddonsSection extends StatefulWidget {
  const ProvidersAddonsSection({super.key});

  @override
  State<ProvidersAddonsSection> createState() => _ProvidersAddonsSectionState();
}

class _ProvidersAddonsSectionState extends State<ProvidersAddonsSection> {
  final SettingsService _settings = SettingsService();
  final StremioService _stremio = StremioService();
  final JackettService _jackett = JackettService();
  final ProwlarrService _prowlarr = ProwlarrService();

  List<Map<String, dynamic>> _installedAddons = [];
  bool _isInstalling = false;
  final TextEditingController _addonController = TextEditingController();

  // Jackett
  final TextEditingController _jackettUrlController = TextEditingController();
  final TextEditingController _jackettApiKeyController = TextEditingController();
  bool _isTestingJackett = false;
  String? _jackettTestResult;

  // Prowlarr
  final TextEditingController _prowlarrUrlController = TextEditingController();
  final TextEditingController _prowlarrApiKeyController = TextEditingController();
  bool _isTestingProwlarr = false;
  String? _prowlarrTestResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final addons = await _settings.getStremioAddons();
    final jackettUrl = await _settings.getJackettBaseUrl();
    final jackettKey = await _settings.getJackettApiKey();
    final prowlarrUrl = await _settings.getProwlarrBaseUrl();
    final prowlarrKey = await _settings.getProwlarrApiKey();

    if (mounted) {
      setState(() {
        _installedAddons = addons;
        _jackettUrlController.text = jackettUrl ?? '';
        _jackettApiKeyController.text = jackettKey ?? '';
        _prowlarrUrlController.text = prowlarrUrl ?? '';
        _prowlarrApiKeyController.text = prowlarrKey ?? '';
      });
    }
  }

  @override
  void dispose() {
    _addonController.dispose();
    _jackettUrlController.dispose();
    _jackettApiKeyController.dispose();
    _prowlarrUrlController.dispose();
    _prowlarrApiKeyController.dispose();
    _jackett.dispose();
    _prowlarr.dispose();
    super.dispose();
  }

  Future<void> _installAddon() async {
    final url = _addonController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isInstalling = true);

    try {
      final addonData = await _stremio.fetchManifest(url);
      if (addonData != null) {
        await _settings.saveStremioAddon(addonData);
        _addonController.clear();
        await _loadSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Addon installed successfully!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to install addon. Check URL.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isInstalling = false);
    }
  }

  void _removeAddon(String baseUrl) async {
    await _settings.removeStremioAddon(baseUrl);
    await _loadSettings();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Addon removed')));
    }
  }

  Future<void> _testJackettConnection() async {
    final url = _jackettUrlController.text.trim();
    final apiKey = _jackettApiKeyController.text.trim();

    if (url.isEmpty || apiKey.isEmpty) {
      setState(
        () => _jackettTestResult = '❌ Please enter both Base URL and API Key',
      );
      return;
    }

    setState(() {
      _isTestingJackett = true;
      _jackettTestResult = null;
    });

    try {
      final result = await _jackett.testConnection(url, apiKey);
      if (mounted) {
        setState(() {
          _jackettTestResult = result.message;
          _isTestingJackett = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _jackettTestResult = '❌ Error: $e';
          _isTestingJackett = false;
        });
      }
    }
  }

  Future<void> _saveJackettSettings() async {
    final url = _jackettUrlController.text.trim();
    final apiKey = _jackettApiKeyController.text.trim();

    await _settings.setJackettBaseUrl(url);
    await _settings.setJackettApiKey(apiKey);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jackett settings saved!')));
    }
  }

  Future<void> _testProwlarrConnection() async {
    final url = _prowlarrUrlController.text.trim();
    final apiKey = _prowlarrApiKeyController.text.trim();

    if (url.isEmpty || apiKey.isEmpty) {
      setState(
        () => _prowlarrTestResult = '❌ Please enter both Base URL and API Key',
      );
      return;
    }

    setState(() {
      _isTestingProwlarr = true;
      _prowlarrTestResult = null;
    });

    try {
      final result = await _prowlarr.testConnection(url, apiKey);
      if (mounted) {
        setState(() {
          _prowlarrTestResult = result.message;
          _isTestingProwlarr = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _prowlarrTestResult = '❌ Error: $e';
          _isTestingProwlarr = false;
        });
      }
    }
  }

  Future<void> _saveProwlarrSettings() async {
    final url = _prowlarrUrlController.text.trim();
    final apiKey = _prowlarrApiKeyController.text.trim();

    await _settings.setProwlarrBaseUrl(url);
    await _settings.setProwlarrApiKey(apiKey);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prowlarr settings saved!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'STREMIO ADDONS',
            style: TextStyle(
              color: AppTheme.current.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildAddonInput(),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'JACKETT',
            style: TextStyle(
              color: AppTheme.current.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildJackettConfig(),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'PROWLARR',
            style: TextStyle(
              color: AppTheme.current.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildProwlarrConfig(),
      ],
    );
  }

  Widget _buildAddonInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Install Stremio Addon',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addonController,
                  decoration: InputDecoration(
                    hintText: 'stremio://... or https://...',
                    filled: true,
                    fillColor: AppTheme.surfaceContainerHigh.withValues(
                      alpha: 0.3,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isInstalling ? null : _installAddon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isInstalling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Install',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
          if (_installedAddons.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'INSTALLED ADDONS',
              style: TextStyle(
                color: AppTheme.textDisabled,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ..._installedAddons.map(
              (addon) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ListTile(
                  leading: addon['icon'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            addon['icon'],
                            width: 32,
                            height: 32,
                            errorBuilder: (c, e, s) =>
                                const Icon(Icons.extension),
                          ),
                        )
                      : const Icon(
                          Icons.extension,
                          color: AppTheme.primaryColor,
                        ),
                  title: Text(
                    addon['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    addon['baseUrl'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textDisabled,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _removeAddon(addon['baseUrl']),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJackettConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Base URL',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _jackettUrlController,
            decoration: InputDecoration(
              hintText: 'http://localhost:9117',
              filled: true,
              fillColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (_) => setState(() => _jackettTestResult = null),
          ),
          const SizedBox(height: 16),
          const Text(
            'API Key',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _jackettApiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter Jackett API Key',
              filled: true,
              fillColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (_) => setState(() => _jackettTestResult = null),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isTestingJackett ? null : _testJackettConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceContainerHigh.withValues(
                      alpha: 0.3,
                    ),
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isTestingJackett
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Test Connection',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveJackettSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          if (_jackettTestResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _jackettTestResult!.startsWith('✅')
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _jackettTestResult!.startsWith('✅')
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _jackettTestResult!,
                style: TextStyle(
                  color: _jackettTestResult!.startsWith('✅')
                      ? Colors.green
                      : Colors.red,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProwlarrConfig() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Base URL',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _prowlarrUrlController,
            decoration: InputDecoration(
              hintText: 'http://localhost:9696',
              filled: true,
              fillColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (_) => setState(() => _prowlarrTestResult = null),
          ),
          const SizedBox(height: 16),
          const Text(
            'API Key',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _prowlarrApiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter Prowlarr API Key',
              filled: true,
              fillColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (_) => setState(() => _prowlarrTestResult = null),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isTestingProwlarr
                      ? null
                      : _testProwlarrConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceContainerHigh.withValues(
                      alpha: 0.3,
                    ),
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isTestingProwlarr
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Test Connection',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveProwlarrSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          if (_prowlarrTestResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _prowlarrTestResult!.startsWith('✅')
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _prowlarrTestResult!.startsWith('✅')
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _prowlarrTestResult!,
                style: TextStyle(
                  color: _prowlarrTestResult!.startsWith('✅')
                      ? Colors.green
                      : Colors.red,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
