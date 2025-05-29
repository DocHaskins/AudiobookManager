// lib/utils/system_optimization/hardware_detector.dart
import 'dart:io';
import 'package:audiobook_organizer/utils/audio_processors/base_audio_processor.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// System capabilities information
class SystemCapabilities {
  final int cpuCores;
  final int totalMemoryMB;
  final bool hasSsdStorage;
  final String platform;
  final bool hasHardwareAcceleration;
  
  const SystemCapabilities({
    required this.cpuCores,
    required this.totalMemoryMB,
    required this.hasSsdStorage,
    required this.platform,
    required this.hasHardwareAcceleration,
  });
  
  @override
  String toString() {
    return 'SystemCapabilities(cores: $cpuCores, memory: ${totalMemoryMB}MB, '
           'ssd: $hasSsdStorage, platform: $platform, hwAccel: $hasHardwareAcceleration)';
  }
}

/// Hardware detection and optimization recommendations
class HardwareDetector {
  /// Detect system capabilities
  static Future<SystemCapabilities> detectCapabilities() async {
    Logger.log('Detecting system capabilities...');
    
    final cpuCores = Platform.numberOfProcessors;
    final totalMemoryMB = await _detectMemory();
    final hasSsdStorage = await _detectSsdStorage();
    final platform = _getPlatformName();
    final hasHardwareAcceleration = await _detectHardwareAcceleration();
    
    final capabilities = SystemCapabilities(
      cpuCores: cpuCores,
      totalMemoryMB: totalMemoryMB,
      hasSsdStorage: hasSsdStorage,
      platform: platform,
      hasHardwareAcceleration: hasHardwareAcceleration,
    );
    
    Logger.log('Detected capabilities: $capabilities');
    return capabilities;
  }
  
  /// Get optimal configuration for a specific operation type
  static AudioProcessingConfig getOptimalConfig(
    SystemCapabilities capabilities,
    String operationType, {
    int? fileCount,
    AudioProcessingConfig? userPreferences,
  }) {
    Logger.log('Calculating optimal config for $operationType with ${capabilities.cpuCores} cores');
    
    // Base configuration
    int parallelJobs = _calculateOptimalParallelJobs(capabilities, operationType, fileCount);
    String? bitrate = _getOptimalBitrate(capabilities, operationType);
    bool useHardwareOptimization = capabilities.hasHardwareAcceleration;
    
    // Apply user preferences if provided
    if (userPreferences != null) {
      parallelJobs = userPreferences.parallelJobs > 0 ? userPreferences.parallelJobs : parallelJobs;
      bitrate = userPreferences.bitrate ?? bitrate;
      useHardwareOptimization = userPreferences.useHardwareOptimization;
    }
    
    final config = AudioProcessingConfig(
      parallelJobs: parallelJobs,
      bitrate: bitrate,
      useHardwareOptimization: useHardwareOptimization,
      customSettings: {
        'detected_cores': capabilities.cpuCores,
        'detected_memory_mb': capabilities.totalMemoryMB,
        'has_ssd': capabilities.hasSsdStorage,
        'platform': capabilities.platform,
        'operation_type': operationType,
        'file_count': fileCount ?? 0,
      },
    );
    
    Logger.log('Optimal config: ${parallelJobs} parallel jobs, bitrate: ${bitrate ?? "auto"}');
    return config;
  }
  
  /// Calculate optimal parallel jobs based on system capabilities
  static int _calculateOptimalParallelJobs(
    SystemCapabilities capabilities,
    String operationType,
    int? fileCount,
  ) {
    // Base calculation on CPU cores
    int baseJobs;
    
    if (capabilities.cpuCores >= 16) {
      baseJobs = 4;
    } else if (capabilities.cpuCores >= 8) {
      baseJobs = 3;
    } else if (capabilities.cpuCores >= 4) {
      baseJobs = 2;
    } else {
      baseJobs = 1;
    }
    
    // Adjust based on memory availability
    final availableMemoryGB = capabilities.totalMemoryMB / 1024;
    if (availableMemoryGB < 4) {
      baseJobs = (baseJobs * 0.5).round().clamp(1, baseJobs);
    } else if (availableMemoryGB < 8) {
      baseJobs = (baseJobs * 0.75).round().clamp(1, baseJobs);
    }
    
    // Adjust based on storage type
    if (!capabilities.hasSsdStorage) {
      // HDD storage - reduce parallel jobs to avoid I/O bottleneck
      baseJobs = (baseJobs * 0.6).round().clamp(1, baseJobs);
    }
    
    // Adjust based on operation type
    switch (operationType.toLowerCase()) {
      case 'batch_conversion':
        // Keep base calculation
        break;
      case 'merge':
        // Merge operations are less parallel-friendly
        baseJobs = (baseJobs * 0.5).round().clamp(1, 2);
        break;
      default:
        break;
    }
    
    // Adjust based on file count for batch operations
    if (fileCount != null && fileCount > 0) {
      if (fileCount < baseJobs) {
        // Don't use more parallel jobs than files
        baseJobs = fileCount;
      } else if (fileCount > 100) {
        // Large batch - be more conservative
        baseJobs = (baseJobs * 0.8).round().clamp(1, baseJobs);
      }
    }
    
    // Safety limits
    const maxSafeJobs = 8; // Prevent memory issues
    return baseJobs.clamp(1, maxSafeJobs);
  }
  
  /// Get optimal bitrate based on system capabilities
  static String? _getOptimalBitrate(SystemCapabilities capabilities, String operationType) {
    // For most systems, let the user or processor decide
    // Could be enhanced to recommend based on storage space, etc.
    return null; // Use default/preserve original
  }
  
  /// Detect available memory (approximate)
  static Future<int> _detectMemory() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('wmic', ['computersystem', 'get', 'TotalPhysicalMemory']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final lines = output.split('\n');
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty && RegExp(r'^\d+$').hasMatch(trimmed)) {
              final bytes = int.tryParse(trimmed);
              if (bytes != null) {
                return (bytes / (1024 * 1024)).round();
              }
            }
          }
        }
      } else if (Platform.isLinux) {
        final result = await Process.run('cat', ['/proc/meminfo']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(output);
          if (match != null) {
            final kb = int.tryParse(match.group(1)!);
            if (kb != null) {
              return (kb / 1024).round();
            }
          }
        }
      } else if (Platform.isMacOS) {
        final result = await Process.run('sysctl', ['-n', 'hw.memsize']);
        if (result.exitCode == 0) {
          final bytes = int.tryParse(result.stdout.toString().trim());
          if (bytes != null) {
            return (bytes / (1024 * 1024)).round();
          }
        }
      }
    } catch (e) {
      Logger.debug('Error detecting memory: $e');
    }
    
    // Fallback estimates based on common configurations
    final cores = Platform.numberOfProcessors;
    if (cores >= 16) return 32 * 1024; // 32GB
    if (cores >= 8) return 16 * 1024;  // 16GB
    if (cores >= 4) return 8 * 1024;   // 8GB
    return 4 * 1024; // 4GB minimum assumption
  }
  
  /// Detect if primary storage is SSD (approximate)
  static Future<bool> _detectSsdStorage() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('powershell', [
          '-Command',
          r'Get-PhysicalDisk | Where-Object {$_.DeviceID -eq 0} | Select-Object -ExpandProperty MediaType'
        ]);
        if (result.exitCode == 0) {
          final output = result.stdout.toString().toLowerCase();
          return output.contains('ssd') || output.contains('solid');
        }
      } else if (Platform.isLinux) {
        // Check if root filesystem is on SSD
        final result = await Process.run('lsblk', ['-d', '-o', 'name,rota']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          // ROTA=0 typically means SSD, ROTA=1 means rotational (HDD)
          if (output.contains('0')) {
            return true;
          }
        }
      } else if (Platform.isMacOS) {
        // Most modern Macs have SSD
        final result = await Process.run('system_profiler', ['SPStorageDataType']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString().toLowerCase();
          return output.contains('solid state') || output.contains('ssd');
        }
      }
    } catch (e) {
      Logger.debug('Error detecting SSD: $e');
    }
    
    // Conservative assumption - assume HDD unless detected otherwise
    return false;
  }
  
  /// Detect hardware acceleration capabilities
  static Future<bool> _detectHardwareAcceleration() async {
    try {
      if (Platform.isWindows) {
        // Check for hardware acceleration support
        final result = await Process.run('dxdiag', ['/t', 'temp_dxdiag.txt']);
        if (result.exitCode == 0) {
          return true; // DirectX available
        }
      } else if (Platform.isMacOS) {
        // Macs generally have good hardware acceleration
        return true;
      } else if (Platform.isLinux) {
        // Check for VAAPI or similar
        final result = await Process.run('vainfo', []);
        if (result.exitCode == 0) {
          return true;
        }
      }
    } catch (e) {
      Logger.debug('Error detecting hardware acceleration: $e');
    }
    
    // Assume basic hardware acceleration is available
    return true;
  }
  
  /// Get platform name
  static String _getPlatformName() {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }
  
  /// Get performance recommendations based on system capabilities
  static List<String> getPerformanceRecommendations(SystemCapabilities capabilities) {
    final recommendations = <String>[];
    
    // CPU recommendations
    if (capabilities.cpuCores >= 8) {
      recommendations.add('Your ${capabilities.cpuCores}-core CPU can handle 3-4 parallel conversions efficiently');
    } else if (capabilities.cpuCores >= 4) {
      recommendations.add('Your ${capabilities.cpuCores}-core CPU works best with 2 parallel conversions');
    } else {
      recommendations.add('Your ${capabilities.cpuCores}-core CPU should use 1 conversion at a time');
    }
    
    // Memory recommendations
    final memoryGB = capabilities.totalMemoryMB / 1024;
    if (memoryGB < 4) {
      recommendations.add('⚠️ Low memory (${memoryGB.toStringAsFixed(1)}GB) - use minimal parallel processing');
    } else if (memoryGB < 8) {
      recommendations.add('Moderate memory (${memoryGB.toStringAsFixed(1)}GB) - monitor usage during large batches');
    } else {
      recommendations.add('Good memory (${memoryGB.toStringAsFixed(1)}GB) - can handle multiple parallel conversions');
    }
    
    // Storage recommendations
    if (capabilities.hasSsdStorage) {
      recommendations.add('✅ SSD detected - expect 2-3x faster processing than HDD');
    } else {
      recommendations.add('💾 HDD detected - consider using fewer parallel jobs to avoid I/O bottleneck');
    }
    
    // Platform-specific recommendations
    switch (capabilities.platform) {
      case 'Windows':
        recommendations.add('Windows: Close other applications and disable real-time antivirus scanning on working folders');
        break;
      case 'macOS':
        recommendations.add('macOS: Ensure adequate cooling as thermal throttling can reduce performance');
        break;
      case 'Linux':
        recommendations.add('Linux: Monitor system resources with htop during processing');
        break;
    }
    
    // Hardware acceleration
    if (capabilities.hasHardwareAcceleration) {
      recommendations.add('Hardware acceleration available - encoding will be more efficient');
    }
    
    return recommendations;
  }
}