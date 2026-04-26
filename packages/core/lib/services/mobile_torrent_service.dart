import '../utils/app_logger.dart';

/// Mobile torrent service placeholder
/// TODO: Implement using native Android torrent library (frostwire-jlibtorrent)
/// For now, returns null to indicate feature not available on mobile
class MobileTorrentService {
  static final MobileTorrentService _instance = MobileTorrentService._internal();
  factory MobileTorrentService() => _instance;
  MobileTorrentService._internal();

  /// Initialize the torrent engine
  Future<void> initialize() async {
    log.info('[MobileTorrent] Mobile torrent streaming requires native implementation');
    log.info('[MobileTorrent] Please use Stream Extraction feature for now');
  }

  /// Add a magnet link and start downloading
  Future<String?> streamTorrent(String magnetLink, {int? season, int? episode}) async {
    log.info('[MobileTorrent] Torrent streaming not yet implemented on mobile');
    log.info('[MobileTorrent] Use Stream Extraction (vidlink/111movies) instead');
    return null;
  }

  /// Remove a torrent
  Future<void> removeTorrent(String magnetLink) async {
    // No-op
  }

  /// Cleanup
  Future<void> cleanup() async {
    // No-op
  }
}
