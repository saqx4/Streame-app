import 'dart:io';
import 'package:flutter/services.dart';
import 'package:streame_core/utils/app_logger.dart';

/// Simple in-memory environment variable storage
final _envMap = <String, String>{};

/// Robust environment variable loader that tries multiple .env file locations.
class EnvLoader {
  EnvLoader._();

  /// Get an environment variable value
  static String get(String key) {
    // Check --dart-define first
    final fromDefine = String.fromEnvironment(key);
    if (fromDefine.isNotEmpty) return fromDefine;
    // Check our loaded map
    return _envMap[key] ?? '';
  }

  /// Load .env file from multiple possible locations.
  /// Tries in order:
  /// 1. Flutter assets (for mobile)
  /// 2. Current directory (./.env) - for desktop
  /// 3. Parent directory (../.env) - for monorepo structure
  /// 4. Root of monorepo (../../.env) - for packages/mobile, etc.
  ///
  /// Returns true if .env was loaded successfully, false otherwise.
  static Future<bool> loadEnv() async {
    // Try loading from Flutter assets first (for mobile)
    try {
      final envString = await rootBundle.loadString('.env');
      _parseEnvString(envString);
      log.info('[EnvLoader] .env loaded from Flutter assets with ${_envMap.length} variables');
      return true;
    } catch (e) {
      log.info('[EnvLoader] Failed to load .env from assets: $e');
    }

    // Fallback to file system (for desktop)
    final currentDir = Directory.current.path;
    log.info('[EnvLoader] Current directory: $currentDir');

    final paths = ['.env', '../.env', '../../.env', '../../../.env'];

    for (final path in paths) {
      try {
        // Resolve to absolute path
        final dir = Directory.current;
        final envFile = File(dir.absolute.path + Platform.pathSeparator + path);
        
        if (await envFile.exists()) {
          log.info('[EnvLoader] .env file exists at: ${envFile.absolute.path}');
          
          // Read file contents and manually parse
          final contents = await envFile.readAsString();
          _parseEnvString(contents);
          
          log.info('[EnvLoader] .env loaded successfully from: ${envFile.absolute.path} with ${_envMap.length} variables');
          return true;
        }
      } catch (e) {
        log.info('[EnvLoader] Failed to load from $path: $e');
      }
    }

    log.info('[EnvLoader] No .env file found in any location (using --dart-define or defaults)');
    return false;
  }

  static void _parseEnvString(String contents) {
    for (final line in contents.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      
      final parts = trimmed.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();
        if (value.isNotEmpty && value != '""') {
          _envMap[key] = value;
        }
      }
    }
  }
}
