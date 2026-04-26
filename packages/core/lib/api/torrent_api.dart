import '../models/torrent_result.dart';
import '../services/jackett_service.dart';
import '../services/prowlarr_service.dart';
import '../services/settings_service.dart';
import '../utils/app_logger.dart';

/// Torrent search API that delegates to configured backends (Jackett / Prowlarr).
class TorrentApi {
  static final TorrentApi _instance = TorrentApi._internal();
  factory TorrentApi() => _instance;
  TorrentApi._internal();

  final JackettService _jackett = JackettService();
  final ProwlarrService _prowlarr = ProwlarrService();
  final SettingsService _settings = SettingsService();

  /// Search torrents using the first available configured backend.
  /// Tries Prowlarr first, then Jackett, then returns empty list.
  Future<List<TorrentResult>> searchTorrents(String query) async {
    try {
      if (await _settings.isProwlarrConfigured()) {
        final baseUrl = await _settings.getProwlarrBaseUrl() ?? '';
        final apiKey = await _settings.getProwlarrApiKey() ?? '';
        return await _prowlarr.search(baseUrl, apiKey, query);
      }

      if (await _settings.isJackettConfigured()) {
        final baseUrl = await _settings.getJackettBaseUrl() ?? '';
        final apiKey = await _settings.getJackettApiKey() ?? '';
        return await _jackett.search(baseUrl, apiKey, query);
      }

      log.warning('[TorrentApi] No torrent search backend configured '
          '(Jackett or Prowlarr). Configure one in Settings.');
      return [];
    } catch (e) {
      log.warning('[TorrentApi] Search error: $e');
      rethrow;
    }
  }
}
