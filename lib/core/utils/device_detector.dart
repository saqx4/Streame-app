import 'dart:io';
import 'package:flutter/foundation.dart';

/// Device capability detection for optimal player settings
class DeviceDetector {
  static final DeviceDetector _instance = DeviceDetector._internal();
  factory DeviceDetector() => _instance;
  DeviceDetector._internal();

  /// Detected GPU vendor
  String? _gpuVendor;
  
  /// Detected CPU info
  String? _cpuInfo;
  
  /// Available RAM in GB
  double? _ramGb;
  
  /// Whether hardware decoding is supported
  bool? _hwDecSupported;
  
  /// Detection already performed
  bool _detected = false;

  /// Perform device detection
  Future<void> detect() async {
    if (_detected) return;
    
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      _detected = true;
      return;
    }

    try {
      await _detectGPU();
      await _detectCPU();
      await _detectRAM();
      _detectHwDecSupport();
      _detected = true;
      
      debugPrint('[DeviceDetector] Detection complete:');
      debugPrint('[DeviceDetector]   GPU: $_gpuVendor');
      debugPrint('[DeviceDetector]   CPU: $_cpuInfo');
      debugPrint('[DeviceDetector]   RAM: ${_ramGb?.toStringAsFixed(1)} GB');
      debugPrint('[DeviceDetector]   HW Dec: $_hwDecSupported');
    } catch (e) {
      debugPrint('[DeviceDetector] Detection error: $e');
      _detected = true; // Don't retry
    }
  }

  /// Detect GPU vendor
  Future<void> _detectGPU() async {
    try {
      if (Platform.isLinux) {
        // Try to read from /sys/class/drm
        final drmPath = '/sys/class/drm';
        final drmDir = Directory(drmPath);
        if (await drmDir.exists()) {
          final entities = await drmDir.list().toList();
          for (final entity in entities) {
            if (entity.path.contains('card0')) {
              final ueventPath = '${entity.path}/device/uevent';
              final ueventFile = File(ueventPath);
              if (await ueventFile.exists()) {
                final uevent = await ueventFile.readAsString();
                if (uevent.contains('Intel')) {
                  _gpuVendor = 'Intel';
                  return;
                } else if (uevent.contains('NVIDIA')) {
                  _gpuVendor = 'NVIDIA';
                  return;
                } else if (uevent.contains('AMD')) {
                  _gpuVendor = 'AMD';
                  return;
                }
              }
            }
          }
        }
        
        // Fallback: try lspci
        final result = await Process.run('lspci', ['-nn', '-d', '::0300']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          if (output.contains('Intel')) {
            _gpuVendor = 'Intel';
          } else if (output.contains('NVIDIA')) {
            _gpuVendor = 'NVIDIA';
          } else if (output.contains('AMD')) {
            _gpuVendor = 'AMD';
          }
        }
      } else if (Platform.isWindows) {
        // Try wmic
        final result = await Process.run('wmic', ['path', 'win32_VideoController', 'get', 'name']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          if (output.contains('Intel')) {
            _gpuVendor = 'Intel';
          } else if (output.contains('NVIDIA')) {
            _gpuVendor = 'NVIDIA';
          } else if (output.contains('AMD')) {
            _gpuVendor = 'AMD';
          }
        }
      } else if (Platform.isMacOS) {
        // Try system_profiler
        final result = await Process.run('system_profiler', ['SPDisplaysDataType']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          if (output.contains('Intel')) {
            _gpuVendor = 'Intel';
          } else if (output.contains('AMD')) {
            _gpuVendor = 'AMD';
          } else if (output.contains('Apple')) {
            _gpuVendor = 'Apple';
          }
        }
      }
    } catch (e) {
      debugPrint('[DeviceDetector] GPU detection error: $e');
    }
  }

  /// Detect CPU info
  Future<void> _detectCPU() async {
    try {
      if (Platform.isLinux) {
        final cpuinfo = await File('/proc/cpuinfo').readAsString();
        final lines = cpuinfo.split('\n');
        for (final line in lines) {
          if (line.startsWith('model name')) {
            _cpuInfo = line.split(':')[1].trim();
            break;
          }
        }
      } else if (Platform.isWindows) {
        final result = await Process.run('wmic', ['cpu', 'get', 'name']);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          if (lines.length > 1) {
            _cpuInfo = lines[1].trim();
          }
        }
      } else if (Platform.isMacOS) {
        final result = await Process.run('sysctl', ['-n', 'machdep.cpu.brand_string']);
        if (result.exitCode == 0) {
          _cpuInfo = result.stdout.toString().trim();
        }
      }
    } catch (e) {
      debugPrint('[DeviceDetector] CPU detection error: $e');
    }
  }

  /// Detect available RAM
  Future<void> _detectRAM() async {
    try {
      if (Platform.isLinux) {
        final meminfo = await File('/proc/meminfo').readAsString();
        final lines = meminfo.split('\n');
        for (final line in lines) {
          if (line.startsWith('MemTotal')) {
            final parts = line.split(':');
            if (parts.length > 1) {
              final kb = int.tryParse(parts[1].trim().split(' ')[0]);
              if (kb != null) {
                _ramGb = kb / 1024 / 1024;
              }
            }
            break;
          }
        }
      } else if (Platform.isWindows) {
        final result = await Process.run('wmic', ['OS', 'get', 'TotalVisibleMemorySize']);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          if (lines.length > 1) {
            final kb = int.tryParse(lines[1].trim());
            if (kb != null) {
              _ramGb = kb / 1024 / 1024;
            }
          }
        }
      } else if (Platform.isMacOS) {
        final result = await Process.run('sysctl', ['-n', 'hw.memsize']);
        if (result.exitCode == 0) {
          final bytes = int.tryParse(result.stdout.toString().trim());
          if (bytes != null) {
            _ramGb = bytes / 1024 / 1024 / 1024;
          }
        }
      }
    } catch (e) {
      debugPrint('[DeviceDetector] RAM detection error: $e');
    }
  }

  /// Detect if hardware decoding is supported
  void _detectHwDecSupport() {
    // Assume hardware decoding is supported if we detected a GPU
    _hwDecSupported = _gpuVendor != null;
  }

  /// Get recommended hardware decode mode
  String getRecommendedHwDecMode() {
    if (!_detected) return 'autoHw';
    
    // If no GPU detected, use software decoding
    if (_gpuVendor == null) {
      return 'software';
    }
    
    // If low RAM (< 4GB), use software decoding to save memory
    if (_ramGb != null && _ramGb! < 4) {
      return 'software';
    }
    
    // Intel GPU: use auto for VA-API support
    if (_gpuVendor == 'Intel') {
      return 'autoHw';
    }
    
    // AMD GPU: use auto-copy for better compatibility
    if (_gpuVendor == 'AMD') {
      return 'autoCopy';
    }
    
    // NVIDIA GPU: use auto
    if (_gpuVendor == 'NVIDIA') {
      return 'autoHw';
    }
    
    // Apple Silicon: use auto
    if (_gpuVendor == 'Apple') {
      return 'autoHw';
    }
    
    // Default to auto
    return 'autoHw';
  }

  /// Get recommended video sync mode
  String getRecommendedVideoSyncMode() {
    if (!_detected) return 'displayAdrop';
    
    // If software decoding, use display-adrop
    if (_gpuVendor == null || _hwDecSupported == false) {
      return 'displayAdrop';
    }
    
    // If low RAM (< 4GB), use audio sync to save memory
    if (_ramGb != null && _ramGb! < 4) {
      return 'audio';
    }
    
    // Intel GPU: use display-resample for best VSync
    if (_gpuVendor == 'Intel') {
      return 'displayResample';
    }
    
    // AMD GPU: use display-adrop for stability
    if (_gpuVendor == 'AMD') {
      return 'displayAdrop';
    }
    
    // NVIDIA GPU: use display-resample
    if (_gpuVendor == 'NVIDIA') {
      return 'displayResample';
    }
    
    // Apple Silicon: use display-resample
    if (_gpuVendor == 'Apple') {
      return 'displayResample';
    }
    
    // Default to display-adrop for stability
    return 'displayAdrop';
  }

  /// Get device info summary
  Map<String, dynamic> getDeviceInfo() {
    return {
      'gpuVendor': _gpuVendor,
      'cpuInfo': _cpuInfo,
      'ramGb': _ramGb,
      'hwDecSupported': _hwDecSupported,
      'recommendedHwDecMode': getRecommendedHwDecMode(),
      'recommendedVideoSyncMode': getRecommendedVideoSyncMode(),
    };
  }
}
