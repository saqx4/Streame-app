import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StremioAddon {
  final String id;
  final String name;
  final String manifestUrl;
  final bool isInstalled;
  final DateTime? installedAt;

  StremioAddon({required this.id, required this.name, required this.manifestUrl, this.isInstalled = false, this.installedAt});
}

class StremioManifest {
  final String id;
  final String name;
  final String? description;
  final Map<String, String> behaviorUrls;

  StremioManifest({required this.id, required this.name, this.description, this.behaviorUrls = const {}});

  factory StremioManifest.fromJson(Map<String, dynamic> json) {
    return StremioManifest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      behaviorUrls: {
        'catalogs': json['behaviorUrls']?['catalogs'] ?? '',
        'stream': json['behaviorUrls']?['stream'] ?? '',
      },
    );
  }
}

class StreamInfo {
  final String name;
  final String url;
  final String title;

  StreamInfo({required this.name, required this.url, required this.title});
}

class StremioRuntime {
  final http.Client _http;

  StremioRuntime({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Future<StremioManifest?> loadManifest(String manifestUrl) async {
    try {
      final response = await _http.get(Uri.parse(manifestUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return StremioManifest.fromJson(jsonDecode(response.body));
      }
    } catch (e) {}
    return null;
  }

  Future<List<StreamInfo>> resolveStream(String addonBehaviorUrl, String imdbId, String type) async {
    try {
      final url = '$addonBehaviorUrl?type=$type&imdb=$imdbId';
      final response = await _http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final streams = (json['streams'] as List?) ?? [];
        return streams.map((s) => StreamInfo(name: s['name'] ?? 'Unknown', url: s['url'] ?? '', title: imdbId)).toList();
      }
    } catch (e) {}
    return [];
  }

  Future<bool> testAddon(String url) async {
    try {
      final manifest = await loadManifest(url);
      return manifest != null;
    } catch (e) {
      return false;
    }
  }
}

class TorrServer {
  final String id;
  final String name;
  final String url;
  final bool isWorking;

  TorrServer({required this.id, required this.name, required this.url, this.isWorking = false});
}

class TorrServerRuntime {
  final http.Client _http;

  TorrServerRuntime({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Future<bool> testServer(String serverUrl) async {
    try {
      final response = await _http.get(Uri.parse(serverUrl)).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> search(String serverUrl, String query) async {
    try {
      final response = await _http.get(Uri.parse('$serverUrl/search?q=$query')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return (jsonDecode(response.body)['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      }
    } catch (e) {}
    return [];
  }
}

final stremioRuntimeProvider = Provider((ref) => StremioRuntime());
final torrServerRuntimeProvider = Provider((ref) => TorrServerRuntime());

final stremioAddonsProvider = FutureProvider<List<StremioAddon>>((ref) async => []);
final torrServersProvider = FutureProvider<List<TorrServer>>((ref) async => []);