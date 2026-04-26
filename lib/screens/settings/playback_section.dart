import 'package:flutter/material.dart';
import 'package:streame_core/services/settings_service.dart';
import 'package:streame_core/services/external_player_service.dart';
import 'settings_widgets.dart';

class PlaybackSection extends StatefulWidget {
  const PlaybackSection({super.key});

  @override
  State<PlaybackSection> createState() => _PlaybackSectionState();
}

class _PlaybackSectionState extends State<PlaybackSection> {
  final SettingsService _settings = SettingsService();
  bool _isStreamingMode = false;
  String _externalPlayer = 'Built-in Player';
  bool _autoOptimize = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final streaming = await _settings.isStreamingModeEnabled();
    final externalPlayer = await _settings.getExternalPlayer();
    final autoOptimize = await _settings.isAutoOptimizeEnabled();

    if (mounted) {
      setState(() {
        _isStreamingMode = streaming;
        final validNames = ExternalPlayerService.playerNames;
        _externalPlayer = validNames.contains(externalPlayer)
            ? externalPlayer
            : 'Built-in Player';
        _autoOptimize = autoOptimize;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FocusableToggle(
          title: 'Auto-Optimize Player',
          subtitle: 'Automatically choose best HW decoding and video sync settings based on your device.',
          value: _autoOptimize,
          onChanged: (val) async {
            await _settings.setAutoOptimize(val);
            setState(() => _autoOptimize = val);
          },
        ),
        FocusableToggle(
          title: 'Direct Streaming Mode',
          subtitle: 'Use direct stream links instead of torrents by default.',
          value: _isStreamingMode,
          onChanged: (val) async {
            await _settings.setStreamingMode(val);
            setState(() => _isStreamingMode = val);
          },
        ),
        FocusableDropdown(
          title: 'Video Player',
          subtitle: 'Choose which player opens videos.',
          value: _externalPlayer,
          options: ExternalPlayerService.playerNames,
          onChanged: (val) async {
            if (val != null) {
              await _settings.setExternalPlayer(val);
              setState(() => _externalPlayer = val);
            }
          },
        ),
      ],
    );
  }
}
