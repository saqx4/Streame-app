import 'dart:io';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../utils/app_logger.dart';

/// Pre-warms media_kit players during app startup for instant playback
class PlayerPoolService {
  static final PlayerPoolService _instance = PlayerPoolService._internal();
  factory PlayerPoolService() => _instance;
  PlayerPoolService._internal();

  Player? _warmPlayer;
  VideoController? _warmController;
  bool _isReady = false;

  /// Pre-warm a player during app initialization.
  /// Eliminates ~500ms cold-start delay when opening a stream.
  Future<void> warmUp() async {
    if (_isReady) return;
    try {
      log.info('[PlayerPool] Pre-warming player...');
      _warmPlayer = Player(
        configuration: PlayerConfiguration(
          libass: !Platform.isAndroid,
        ),
      );
      _warmController = VideoController(
        _warmPlayer!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );
      _isReady = true;
      log.info('[PlayerPool] Player pre-warmed and ready');
    } catch (e) {
      log.warning('[PlayerPool] Pre-warm failed: $e');
      _isReady = false;
    }
  }

  /// Get a player — returns the pre-warmed one if available, otherwise creates fresh.
  ({Player player, VideoController controller}) getPlayer() {
    if (_isReady && _warmPlayer != null && _warmController != null) {
      log.info('[PlayerPool] Returning pre-warmed player');
      final result = (player: _warmPlayer!, controller: _warmController!);
      _warmPlayer = null;
      _warmController = null;
      _isReady = false;
      // Pre-warm a replacement in the background for next time
      _replenish();
      return result;
    }
    log.info('[PlayerPool] Creating fresh player');
    final player = Player(
      configuration: PlayerConfiguration(
        libass: !Platform.isAndroid,
      ),
    );
    final controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    return (player: player, controller: controller);
  }

  /// Replenish the pool after a player is taken.
  void _replenish() {
    Future.microtask(() => warmUp());
  }

  /// Check if a warm player is ready
  bool get isReady => _isReady;

  /// Dispose the warm player (call on app shutdown)
  Future<void> dispose() async {
    if (_warmPlayer != null) {
      log.info('[PlayerPool] Disposing warm player');
      await _warmPlayer!.dispose();
      _warmPlayer = null;
      _warmController = null;
      _isReady = false;
    }
  }
}
