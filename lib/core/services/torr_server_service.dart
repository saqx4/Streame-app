import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// TorrServer service for resolving magnet links to stream URLs
/// Supports adding torrents, getting file lists, and building stream URLs
class TorrServerService {
  final String baseUrl;
  final http.Client _http;

  TorrServerService({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Add a magnet link to TorrServer
  /// Returns the torrent hash
  Future<String?> addMagnet(String magnetLink) async {
    try {
      final url = Uri.parse('$baseUrl/torrents/add');
      final response = await _http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'link=${Uri.encodeComponent(magnetLink)}',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['hash'] as String?;
      }
    } catch (e) {
      debugPrint('TorrServer addMagnet error: $e');
    }
    return null;
  }

  /// Get file list for a torrent
  Future<List<TorrServerFile>> getFiles(String hash) async {
    try {
      final url = Uri.parse('$baseUrl/torrents/$hash');
      final response = await _http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = data['files'] as List? ?? [];
        return files.map((f) => TorrServerFile.fromJson(f as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('TorrServer getFiles error: $e');
    }
    return [];
  }

  /// Build stream URL for a specific file
  /// Format: {baseUrl}/stream/{hash}/{index}
  String buildStreamUrl(String hash, int fileIndex) {
    return '$baseUrl/stream/$hash/$fileIndex';
  }

  /// Remove a torrent from TorrServer
  Future<bool> removeTorrent(String hash) async {
    try {
      final url = Uri.parse('$baseUrl/torrents/rem?hash=$hash&delete=true');
      final response = await _http.get(url).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('TorrServer removeTorrent error: $e');
      return false;
    }
  }

  /// Check if TorrServer is accessible
  Future<bool> checkConnection() async {
    try {
      final url = Uri.parse('$baseUrl');
      final response = await _http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// File metadata from TorrServer
class TorrServerFile {
  final int id;
  final String path;
  final int size;
  final int? sizeBytes;

  TorrServerFile({
    required this.id,
    required this.path,
    required this.size,
    this.sizeBytes,
  });

  factory TorrServerFile.fromJson(Map<String, dynamic> json) => TorrServerFile(
        id: json['id'] as int? ?? 0,
        path: json['path'] as String? ?? '',
        size: json['size'] as int? ?? 0,
        sizeBytes: json['size_bytes'] as int?,
      );

  /// Try to identify the main video file from a list
  static TorrServerFile? findMainVideo(List<TorrServerFile> files) {
    // Prefer largest file with video extension
    final videoFiles = files.where((f) => _isVideoFile(f.path)).toList();
    if (videoFiles.isEmpty) return null;

    videoFiles.sort((a, b) => (b.sizeBytes ?? b.size).compareTo(a.sizeBytes ?? a.size));
    return videoFiles.first;
  }

  static bool _isVideoFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m4v');
  }
}
