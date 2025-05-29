// lib/services/hardware_cache_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class HardwareInfo {
  final int cpuCores;
  final int totalMemoryMB;
  final int maxParallelJobs;
  final bool hasSSD;
  final String cpuArchitecture;
  final DateTime detectedAt;

  const HardwareInfo({
    required this.cpuCores,
    required this.totalMemoryMB,
    required this.maxParallelJobs,
    required this.hasSSD,
    required this.cpuArchitecture,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'cpuCores': cpuCores,
      'totalMemoryMB': totalMemoryMB,
      'maxParallelJobs': maxParallelJobs,
      'hasSSD': hasSSD,
      'cpuArchitecture': cpuArchitecture,
      'detectedAt': detectedAt.millisecondsSinceEpoch,
    };
  }

  factory HardwareInfo.fromJson(Map<String, dynamic> json) {
    return HardwareInfo(
      cpuCores: json['cpuCores'] ?? 4,
      totalMemoryMB: json['totalMemoryMB'] ?? 8192,
      maxParallelJobs: json['maxParallelJobs'] ?? 4,
      hasSSD: json['hasSSD'] ?? false,
      cpuArchitecture: json['cpuArchitecture'] ?? 'unknown',
      detectedAt: DateTime.fromMillisecondsSinceEpoch(json['detectedAt'] ?? 0),
    );
  }
}

class HardwareCacheService {
  static const String _cacheKey = 'hardware_info_cache';
  static const Duration _cacheValidityDuration = Duration(days: 30); // Re-detect after 30 days
  
  static HardwareCacheService? _instance;
  static HardwareCacheService get instance => _instance ??= HardwareCacheService._();
  
  HardwareCacheService._();
  
  HardwareInfo? _cachedInfo;
  bool _initialized = false;

  /// Get cached hardware info or detect if not available
  Future<HardwareInfo> getHardwareInfo({bool forceRefresh = false}) async {
    if (!_initialized) {
      await _initialize();
    }

    if (forceRefresh || _cachedInfo == null || _isCacheExpired(_cachedInfo!)) {
      Logger.log('Detecting hardware capabilities...');
      _cachedInfo = await _detectHardware();
      await _saveToCache(_cachedInfo!);
      Logger.log('Hardware detection complete and cached');
    } else {
      Logger.log('Using cached hardware info from ${_cachedInfo!.detectedAt}');
    }

    return _cachedInfo!;
  }

  /// Initialize the service and load cached data from SharedPreferences
  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      
      if (cachedJson != null) {
        final jsonData = jsonDecode(cachedJson) as Map<String, dynamic>;
        _cachedInfo = HardwareInfo.fromJson(jsonData);
        Logger.log('Loaded cached hardware info: ${_cachedInfo!.cpuCores} cores, ${_cachedInfo!.totalMemoryMB}MB RAM');
      }
    } catch (e) {
      Logger.warning('Failed to load cached hardware info: $e');
      _cachedInfo = null;
    }
    
    _initialized = true;
  }

  /// Save hardware info to SharedPreferences
  Future<void> _saveToCache(HardwareInfo info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(info.toJson());
      await prefs.setString(_cacheKey, jsonString);
      Logger.debug('Hardware info cached to SharedPreferences');
    } catch (e) {
      Logger.error('Failed to cache hardware info: $e');
    }
  }

  /// Check if cached data is expired
  bool _isCacheExpired(HardwareInfo info) {
    final now = DateTime.now();
    final age = now.difference(info.detectedAt);
    return age > _cacheValidityDuration;
  }

  /// Detect current hardware capabilities
  Future<HardwareInfo> _detectHardware() async {
    int cpuCores = 4; // Default fallback
    int totalMemoryMB = 8192; // Default fallback
    bool hasSSD = false;
    String cpuArchitecture = 'unknown';

    try {
      // Detect CPU cores
      if (Platform.isWindows) {
        final result = await Process.run('wmic', ['cpu', 'get', 'NumberOfCores', '/format:value']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final match = RegExp(r'NumberOfCores=(\d+)').firstMatch(output);
          if (match != null) {
            cpuCores = int.parse(match.group(1)!);
          }
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        final result = await Process.run('nproc', []);
        if (result.exitCode == 0) {
          cpuCores = int.tryParse(result.stdout.toString().trim()) ?? cpuCores;
        }
      }

      // Detect total memory
      if (Platform.isWindows) {
        final result = await Process.run('wmic', ['computersystem', 'get', 'TotalPhysicalMemory', '/format:value']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final match = RegExp(r'TotalPhysicalMemory=(\d+)').firstMatch(output);
          if (match != null) {
            final bytes = int.parse(match.group(1)!);
            totalMemoryMB = (bytes / (1024 * 1024)).round();
          }
        }
      } else if (Platform.isLinux) {
        final result = await Process.run('free', ['-m']);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          for (final line in lines) {
            if (line.startsWith('Mem:')) {
              final parts = line.split(RegExp(r'\s+'));
              if (parts.length > 1) {
                totalMemoryMB = int.tryParse(parts[1]) ?? totalMemoryMB;
              }
              break;
            }
          }
        }
      } else if (Platform.isMacOS) {
        final result = await Process.run('sysctl', ['hw.memsize']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final match = RegExp(r'hw\.memsize: (\d+)').firstMatch(output);
          if (match != null) {
            final bytes = int.parse(match.group(1)!);
            totalMemoryMB = (bytes / (1024 * 1024)).round();
          }
        }
      }

      // Detect CPU architecture
      if (Platform.isWindows) {
        final result = await Process.run('wmic', ['cpu', 'get', 'Architecture', '/format:value']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final match = RegExp(r'Architecture=(\d+)').firstMatch(output);
          if (match != null) {
            final arch = match.group(1)!;
            cpuArchitecture = arch == '9' ? 'x64' : (arch == '0' ? 'x86' : 'unknown');
          }
        }
      } else {
        final result = await Process.run('uname', ['-m']);
        if (result.exitCode == 0) {
          cpuArchitecture = result.stdout.toString().trim();
        }
      }

      // Simple SSD detection
      hasSSD = await _detectSSD();

    } catch (e) {
      Logger.warning('Hardware detection failed, using defaults: $e');
    }

    // Calculate optimal parallel jobs based on hardware
    final maxParallelJobs = _calculateOptimalParallelJobs(cpuCores, totalMemoryMB);

    final info = HardwareInfo(
      cpuCores: cpuCores,
      totalMemoryMB: totalMemoryMB,
      maxParallelJobs: maxParallelJobs,
      hasSSD: hasSSD,
      cpuArchitecture: cpuArchitecture,
      detectedAt: DateTime.now(),
    );

    Logger.log('Hardware detected: ${cpuCores} cores, ${totalMemoryMB}MB RAM, max parallel jobs: ${maxParallelJobs}');
    return info;
  }

  /// Basic SSD detection
  Future<bool> _detectSSD() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('wmic', ['diskdrive', 'get', 'MediaType', '/format:value']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString().toLowerCase();
          return output.contains('ssd') || output.contains('solid state');
        }
      }
      // For other platforms, this is more complex and might require different approaches
      return false;
    } catch (e) {
      Logger.debug('SSD detection failed: $e');
      return false;
    }
  }

  /// Calculate optimal parallel jobs based on hardware
  int _calculateOptimalParallelJobs(int cpuCores, int totalMemoryMB) {
    // Base calculation: start with CPU cores
    int optimal = cpuCores;

    // Adjust based on memory (each job uses ~300MB on average)
    final memoryBasedLimit = (totalMemoryMB * 0.6) ~/ 300; // Use 60% of available memory
    optimal = optimal.clamp(1, memoryBasedLimit);

    // Conservative limits to prevent system overload
    if (totalMemoryMB < 4096) {
      optimal = optimal.clamp(1, 2); // Low memory systems
    } else if (totalMemoryMB < 8192) {
      optimal = optimal.clamp(1, 4); // Medium memory systems
    } else {
      optimal = optimal.clamp(1, 8); // High memory systems
    }

    return optimal;
  }

  /// Clear cached hardware info from SharedPreferences (force re-detection on next access)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      _cachedInfo = null;
      Logger.log('Hardware cache cleared from SharedPreferences');
    } catch (e) {
      Logger.error('Failed to clear hardware cache: $e');
    }
  }

  /// Get cache status for debugging
  Map<String, dynamic> getCacheStatus() {
    return {
      'cached': _cachedInfo != null,
      'detectedAt': _cachedInfo?.detectedAt.toIso8601String(),
      'isExpired': _cachedInfo != null ? _isCacheExpired(_cachedInfo!) : null,
      'cpuCores': _cachedInfo?.cpuCores,
      'totalMemoryMB': _cachedInfo?.totalMemoryMB,
      'maxParallelJobs': _cachedInfo?.maxParallelJobs,
    };
  }
}