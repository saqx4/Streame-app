import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stream_source.dart';
import 'package:flutter/foundation.dart';

class WebStreamrService {
  static const String baseUrl = 'https://webstreamr.hayd.uk';

  Future<List<StreamSource>> getStreams({
    required String imdbId,
    bool isMovie = true,
    int? season,
    int? episode,
  }) async {
    try {
      final String url;
      if (isMovie) {
        url = '$baseUrl/stream/movie/$imdbId.json';
      } else {
        url = '$baseUrl/stream/series/$imdbId:$season:$episode.json';
      }

      debugPrint('[WebStreamrService] Fetching streams from: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> streams = data['streams'] ?? [];
        
        return streams.map((s) {
          // Combine name and title for a better display in the menu
          final name = s['name'] ?? '';
          final title = s['title'] ?? '';
          final displayTitle = name.isNotEmpty ? '$name\n$title' : title;
          
          return StreamSource(
            url: s['url'] ?? '',
            title: displayTitle,
            type: 'video',
          );
        }).toList();
      } else {
        debugPrint('[WebStreamrService] Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[WebStreamrService] Exception: $e');
      return [];
    }
  }
}
