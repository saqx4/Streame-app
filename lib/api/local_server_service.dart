import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:flutter/foundation.dart';

class LocalServerService {
  static final LocalServerService _instance = LocalServerService._internal();
  factory LocalServerService() => _instance;
  LocalServerService._internal();

  HttpServer? _server;
  final Router _router = Router();
  int _port = 0;

  // HTTP client with connection limits to prevent network resource contention
  final http.Client _httpClient = http.Client();

  int get port => _port;
  String get baseUrl => 'http://localhost:$_port';

  Future<void> start() async {
    if (_server != null) return;

    _setupRoutes();

    try {
      _server = await io.serve(_router.call, InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      debugPrint('[LocalServer] Started on $baseUrl');
    } catch (e) {
      debugPrint('[LocalServer] Error starting server: $e');
    }
  }

  void _setupRoutes() {
    _router.add('GET', '/proxy', _handleProxyRequest);
    _router.add('HEAD', '/proxy', _handleProxyRequest);

    // --- HLS-aware streaming proxy (rewrites m3u8 segment URLs) ---
    _router.add('GET', '/hls-proxy', _handleHlsProxy);
    _router.add('HEAD', '/hls-proxy', _handleHlsProxy);

    _router.get('/health', (Request request) {
      return Response.ok(json.encode({'status': 'ok', 'port': _port}), headers: {'content-type': 'application/json'});
    });
  }

  Future<Response> _handleProxyRequest(Request request) async {
    final params = request.url.queryParameters;
    final targetUrl = params['url'];
    if (targetUrl == null) return Response.notFound('Missing url parameter');
    final decodedUrl = Uri.decodeComponent(targetUrl);
    Map<String, String> customHeaders = {};
    if (params['headers'] != null) {
      try {
        customHeaders = Map<String, String>.from(json.decode(params['headers']!));
      } catch (e) {
        // Ignore invalid JSON headers
      }
    }

    try {
      final proxyHeaders = <String, String>{
        'User-Agent': customHeaders['User-Agent'] ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': customHeaders['Referer'] ?? 'https://www.youtube.com/',
        if (customHeaders.containsKey('Origin')) 'Origin': customHeaders['Origin']!,
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'identity',
        'Connection': 'keep-alive',
      };

      final range = request.headers['range'];
      if (range != null) {
        proxyHeaders['Range'] = range;
        debugPrint('[LocalProxy] Range: $range');
      }

      final req = http.Request(request.method, Uri.parse(decodedUrl));
      req.headers.addAll(proxyHeaders);
      
      final streamedResponse = await _httpClient.send(req);

      final responseHeaders = <String, String>{
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS, POST',
        'Access-Control-Allow-Headers': '*',
        'Accept-Ranges': 'bytes',
        'Connection': 'keep-alive',
        'Content-Type': streamedResponse.headers['content-type'] ?? 'audio/mpeg',
      };

      // Forward these critical headers for seeking
      if (streamedResponse.headers.containsKey('content-length')) {
        responseHeaders['Content-Length'] = streamedResponse.headers['content-length']!;
      }
      if (streamedResponse.headers.containsKey('content-range')) {
        responseHeaders['Content-Range'] = streamedResponse.headers['content-range']!;
      }
      if (streamedResponse.headers.containsKey('accept-ranges')) {
        responseHeaders['Accept-Ranges'] = streamedResponse.headers['accept-ranges']!;
      }

      return Response(streamedResponse.statusCode, body: streamedResponse.stream, headers: responseHeaders);
    } catch (e) {
      return Response.internalServerError(body: 'Proxy error: $e');
    }
  }

  /// HLS-aware proxy: fetches with custom headers, rewrites m3u8 playlists
  /// so that segment/sub-playlist URLs also go through the proxy.
  Future<Response> _handleHlsProxy(Request request) async {
    final params = request.url.queryParameters;
    final targetUrl = params['url'];
    final headersJson = params['headers'];

    if (targetUrl == null) {
      return Response(400, body: 'Missing url parameter');
    }

    final decodedUrl = Uri.decodeComponent(targetUrl);
    final targetUri = Uri.parse(decodedUrl);
    final serverBase = '${targetUri.scheme}://${targetUri.host}${targetUri.hasPort ? ':${targetUri.port}' : ''}';

    Map<String, String> customHeaders = {};
    if (headersJson != null) {
      try {
        customHeaders = Map<String, String>.from(json.decode(headersJson));
      } catch (_) {}
    }

    final proxyHeaders = <String, String>{
      'User-Agent': customHeaders['User-Agent'] ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
      if (customHeaders.containsKey('Referer')) 'Referer': customHeaders['Referer']!,
      if (customHeaders.containsKey('Origin')) 'Origin': customHeaders['Origin']!,
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
      'Connection': 'keep-alive',
    };

    final range = request.headers['range'];
    if (range != null) proxyHeaders['Range'] = range;

    try {
      final req = http.Request(request.method, targetUri);
      req.headers.addAll(proxyHeaders);
      final streamedResponse = await _httpClient.send(req);

      if (streamedResponse.statusCode >= 400) {
        debugPrint('[HlsProxy] Upstream ${streamedResponse.statusCode} for $decodedUrl');
      }

      final contentType = streamedResponse.headers['content-type'] ?? '';

      // HLS playlist? Rewrite URLs so sub-playlists & segments also go through proxy
      if (contentType.contains('mpegurl') ||
          contentType.contains('x-mpegurl') ||
          decodedUrl.contains('.m3u8')) {
        final body = await streamedResponse.stream.bytesToString();
        final basePath = decodedUrl.substring(0, decodedUrl.lastIndexOf('/') + 1);

        final rewrittenLines = body.split('\n').map((line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) {
            // Rewrite URI= attributes inside EXT tags
            if (trimmed.contains('URI="')) {
              return trimmed.replaceAllMapped(
                RegExp(r'URI="([^"]+)"'),
                (m) {
                  final uri = m.group(1)!;
                  final fullUri = uri.startsWith('http') ? uri
                      : uri.startsWith('/') ? '$serverBase$uri'
                      : '$basePath$uri';
                  return 'URI="${getHlsProxyUrl(fullUri, customHeaders)}"';
                },
              );
            }
            return line;
          }
          // Non-comment line = segment or sub-playlist URL
          final fullUrl = trimmed.startsWith('http') ? trimmed
              : trimmed.startsWith('/') ? '$serverBase$trimmed'
              : '$basePath$trimmed';
          return getHlsProxyUrl(fullUrl, customHeaders);
        }).toList();

        return Response.ok(
          rewrittenLines.join('\n'),
          headers: {
            'Content-Type': 'application/vnd.apple.mpegurl',
            'Access-Control-Allow-Origin': '*',
          },
        );
      }

      // Non-HLS (segments, mp4, etc.) — stream through
      final responseHeaders = <String, String>{
        'Access-Control-Allow-Origin': '*',
        'Accept-Ranges': 'bytes',
        'Connection': 'keep-alive',
      };
      for (final h in ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
        final v = streamedResponse.headers[h];
        if (v != null) responseHeaders[h] = v;
      }

      return Response(streamedResponse.statusCode, body: streamedResponse.stream, headers: responseHeaders);
    } catch (e) {
      debugPrint('[HlsProxy] Error: $e');
      return Response.internalServerError(body: 'HLS proxy error: $e');
    }
  }

  /// Returns a local proxy URL for an HLS stream with custom headers.
  String getHlsProxyUrl(String targetUrl, Map<String, String> headers) {
    return '$baseUrl/hls-proxy'
        '?url=${Uri.encodeComponent(targetUrl)}'
        '&headers=${Uri.encodeComponent(json.encode(headers))}';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
  }
}
