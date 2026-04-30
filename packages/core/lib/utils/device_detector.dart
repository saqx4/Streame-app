import 'dart:io';
import '../utils/app_logger.dart';
import 'package:flutter/widgets.dart';

/// Platform detection helpers for adaptive UI layouts.
class PlatformInfo {
  PlatformInfo._();

  /// True on Android TV only (not tablets).
  /// Heuristic: Android + shortestSide >= 960 (TVs use 10-foot UI at high dp)
  /// + landscape-only. Tablets are typically 600–800dp shortestSide.
  static bool isTv(BuildContext context) {
    if (!Platform.isAndroid) return false;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return false;
    final mq = MediaQuery.maybeOf(context);
    if (mq == null) return false;
    final shortestSide = mq.size.shortestSide;
    // Android TV devices have very large dp screens (≥960) and are landscape-only.
    // Tablets typically have shortestSide 600–800dp and support portrait.
    return shortestSide >= 960;
  }

  /// True on phone/tablet (Android/iOS) or narrow screens.
  static bool isMobile(BuildContext context) {
    if (Platform.isIOS) return true;
    if (Platform.isAndroid && !isTv(context)) return true;
    final mq = MediaQuery.maybeOf(context);
    if (mq == null) return false;
    return mq.size.width < 800;
  }

  /// True on desktop platforms (Windows, Linux, macOS).
  static bool get isDesktopOS =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

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

    try {
      if (Platform.isAndroid) {
        await _detectAndroid();
      } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        await _detectGPU();
        await _detectCPU();
        await _detectRAM();
      }
      _detectHwDecSupport();
      _detected = true;

      log.info('[DeviceDetector] Detection complete:');
      log.info('[DeviceDetector]   GPU: $_gpuVendor');
      log.info('[DeviceDetector]   CPU: $_cpuInfo');
      log.info('[DeviceDetector]   RAM: ${_ramGb?.toStringAsFixed(1)} GB');
      log.info('[DeviceDetector]   HW Dec: $_hwDecSupported');
    } catch (e) {
      log.info('[DeviceDetector] Detection error: $e');
      _detected = true; // Don't retry
    }
  }

  /// Android-specific detection via /proc filesystem
  Future<void> _detectAndroid() async {
    // CPU / GPU info from /proc/cpuinfo
    try {
      final cpuinfo = await File('/proc/cpuinfo').readAsString();
      final lines = cpuinfo.split('\n');
      for (final line in lines) {
        if (line.startsWith('Hardware')) {
          _cpuInfo = line.split(':').skip(1).join(':').trim();
          break;
        }
        if (line.startsWith('model name')) {
          _cpuInfo = line.split(':').skip(1).join(':').trim();
        }
      }
      // Infer GPU from CPU info — common Android GPU vendors
      final cpuLower = (_cpuInfo ?? '').toLowerCase();
      if (cpuLower.contains('mali')) {
        _gpuVendor = 'ARM';
      } else if (cpuLower.contains('adreno')) {
        _gpuVendor = 'Qualcomm';
      } else if (cpuLower.contains('powervr') || cpuLower.contains('imgtec')) {
        _gpuVendor = 'Imagination';
      }
      // Also check /sys/class/kgsl/kgsl-3d0/gpu_model for Adreno (Qualcomm)
      if (_gpuVendor == null) {
        try {
          final gpuModel = await File('/sys/class/kgsl/kgsl-3d0/gpu_model').readAsString();
          if (gpuModel.toLowerCase().contains('adreno')) {
            _gpuVendor = 'Qualcomm';
          }
        } catch (_) {}
      }
    } catch (e) {
      log.info('[DeviceDetector] Android cpuinfo error: $e');
    }

    // RAM from /proc/meminfo
    try {
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
    } catch (e) {
      log.info('[DeviceDetector] Android meminfo error: $e');
    }
  }

  /// Detect GPU vendor
  Future<void> _detectGPU() async {
    try {
      if (Platform.isLinux) {
        // Try to read from /sys/class/drm
        const drmPath = '/sys/class/drm';
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
        // Try PowerShell (wmic is deprecated and may not be available)
        final result = await Process.run('powershell', ['-Command', 'Get-WmiObject Win32_VideoController | Select-Object -ExpandProperty Name']);
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
      log.info('[DeviceDetector] GPU detection error: $e');
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
        final result = await Process.run('powershell', ['-Command', 'Get-WmiObject Win32_Processor | Select-Object -ExpandProperty Name']);
        if (result.exitCode == 0) {
          _cpuInfo = result.stdout.toString().trim();
        }
      } else if (Platform.isMacOS) {
        final result = await Process.run('sysctl', ['-n', 'machdep.cpu.brand_string']);
        if (result.exitCode == 0) {
          _cpuInfo = result.stdout.toString().trim();
        }
      }
    } catch (e) {
      log.info('[DeviceDetector] CPU detection error: $e');
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
        final result = await Process.run('powershell', ['-Command', '(Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory']);
        if (result.exitCode == 0) {
          final bytes = int.tryParse(result.stdout.toString().trim());
          if (bytes != null) {
            _ramGb = bytes / 1024 / 1024 / 1024;
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
      log.info('[DeviceDetector] RAM detection error: $e');
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
    
    // If low RAM (< 4GB), use software decoding to save memory
    if (_ramGb != null && _ramGb! < 4) {
      return 'software';
    }
    
    // If no GPU detected, still try hardware decoding (may work via dxva2/d3d11va)
    // Only fall back to software if we're confident it won't work
    // Default to autoHw for best performance
    if (_gpuVendor == null) {
      return 'autoHw';
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

    // Android GPU vendors — auto-safe is best for MediaCodec
    if (_gpuVendor == 'ARM' || _gpuVendor == 'Qualcomm' || _gpuVendor == 'Imagination') {
      return 'autoSafe';
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

    // Android GPU vendors — audio sync is most reliable on mobile
    if (_gpuVendor == 'ARM' || _gpuVendor == 'Qualcomm' || _gpuVendor == 'Imagination') {
      return 'audio';
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
