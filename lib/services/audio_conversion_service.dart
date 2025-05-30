// lib/services/audio_conversion_service.dart
import 'dart:async';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/chapter_info.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/hardware_cache_service.dart';
import 'package:audiobook_organizer/utils/audio_processors/base_audio_processor.dart';
import 'package:audiobook_organizer/utils/audio_processors/batch_converter_processor.dart';
import 'package:audiobook_organizer/utils/audio_processors/merger_processor.dart';
import 'package:audiobook_organizer/utils/system_optimization/hardware_detector.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// Main orchestrator service for all audio conversion operations
class AudioConversionService {
  final MetadataService _metadataService;
  final LibraryManager _libraryManager;
  
  SystemCapabilities? _systemCapabilities;
  HardwareInfo? _hardwareInfo;
  BaseAudioProcessor? _currentProcessor;

  AudioConversionService({
    required MetadataService metadataService,
    required LibraryManager libraryManager,
  }) : _metadataService = metadataService,
       _libraryManager = libraryManager;

  /// Initialize the service and detect system capabilities using cached hardware info
  Future<void> initialize() async {
    Logger.log('Initializing AudioConversionService...');
    
    await _metadataService.initialize();
    
    // Get hardware info from cache (fast if already cached)
    _hardwareInfo = await HardwareCacheService.instance.getHardwareInfo();
    
    // Convert cached hardware info to SystemCapabilities format for existing code compatibility
    _systemCapabilities = await _convertToSystemCapabilities(_hardwareInfo!);
    
    Logger.log('AudioConversionService initialized successfully');
    Logger.log('Using cached hardware profile: ${_hardwareInfo!.cpuCores} cores, ${_hardwareInfo!.totalMemoryMB}MB RAM');
  }

  /// Convert HardwareInfo to SystemCapabilities for backward compatibility
  Future<SystemCapabilities> _convertToSystemCapabilities(HardwareInfo hardwareInfo) async {
    // This maintains compatibility with your existing HardwareDetector system
    // while using the cached data
    return SystemCapabilities(
      cpuCores: hardwareInfo.cpuCores,
      totalMemoryMB: hardwareInfo.totalMemoryMB,
      hasSsdStorage: hardwareInfo.hasSSD,
      platform: hardwareInfo.cpuArchitecture, // Map architecture to platform
      hasHardwareAcceleration: _detectHardwareAcceleration(hardwareInfo),
      // You can add other fields as needed based on your SystemCapabilities class
    );
  }

  /// Detect if hardware acceleration is available based on hardware info
  bool _detectHardwareAcceleration(HardwareInfo hardwareInfo) {
    // Simple heuristic - assume modern systems with good specs have hardware acceleration
    // You can make this more sophisticated based on your needs
    return hardwareInfo.cpuCores >= 4 && 
           hardwareInfo.totalMemoryMB >= 8192 && 
           (hardwareInfo.cpuArchitecture.contains('64') || 
            hardwareInfo.cpuArchitecture.toLowerCase().contains('x64'));
  }

  /// Get system capabilities
  SystemCapabilities? get systemCapabilities => _systemCapabilities;

  /// Get cached hardware info
  HardwareInfo? get hardwareInfo => _hardwareInfo;

  /// Force refresh hardware detection (useful for settings)
  Future<void> refreshHardwareInfo() async {
    try {
      Logger.log('AudioConversionService: Refreshing hardware detection...');
      _hardwareInfo = await HardwareCacheService.instance.getHardwareInfo(forceRefresh: true);
      _systemCapabilities = await _convertToSystemCapabilities(_hardwareInfo!);
      Logger.log('AudioConversionService: Hardware info refreshed');
    } catch (e) {
      Logger.error('AudioConversionService: Failed to refresh hardware info', e);
    }
  }

  /// Get optimal configuration for the specified operation
  AudioProcessingConfig getOptimalConfig(
    String operationType, {
    int? fileCount,
    AudioProcessingConfig? userPreferences,
  }) {
    if (_systemCapabilities == null) {
      throw StateError('AudioConversionService not initialized');
    }

    return HardwareDetector.getOptimalConfig(
      _systemCapabilities!,
      operationType,
      fileCount: fileCount,
      userPreferences: userPreferences,
    );
  }

  /// Start batch conversion of MP3 files to M4B
  Future<ProcessingResult> startBatchConversion({
    required List<AudiobookFile> files,
    AudioProcessingConfig? config,
  }) async {
    if (_currentProcessor != null) {
      throw StateError('Another operation is already in progress');
    }

    try {
      final effectiveConfig = config ?? getOptimalConfig('batch_conversion', fileCount: files.length);
      
      Logger.log('Starting batch conversion with configuration:');
      Logger.log('- Files: ${files.length}');
      Logger.log('- Parallel jobs: ${effectiveConfig.parallelJobs}');
      Logger.log('- Bitrate: ${effectiveConfig.bitrate ?? "auto"}');
      Logger.log('- Preserve original bitrate: ${effectiveConfig.preserveOriginalBitrate}');
      Logger.log('- Using cached hardware profile from: ${_hardwareInfo?.detectedAt}');

      _currentProcessor = BatchConverterProcessor(
        files: files,
        config: effectiveConfig,
        metadataService: _metadataService,
        libraryManager: _libraryManager,
      );

      final result = await _currentProcessor!.execute();
      return result;
    } finally {
      _currentProcessor?.dispose();
      _currentProcessor = null;
    }
  }

  /// Start merging multiple MP3 files into a single M4B
  Future<ProcessingResult> startMergeOperation({
    required List<ChapterInfo> chapters,
    required String outputPath,
    required AudiobookMetadata bookMetadata,
    AudioProcessingConfig? config,
  }) async {
    if (_currentProcessor != null) {
      throw StateError('Another operation is already in progress');
    }

    try {
      final effectiveConfig = config ?? getOptimalConfig('merge', fileCount: chapters.length);
      
      Logger.log('Starting merge operation with configuration:');
      Logger.log('- Chapters: ${chapters.length}');
      Logger.log('- Output: $outputPath');
      Logger.log('- Book: ${bookMetadata.title}');
      Logger.log('- Using cached hardware profile from: ${_hardwareInfo?.detectedAt}');

      _currentProcessor = MergerProcessor(
        chapters: chapters,
        outputPath: outputPath,
        bookMetadata: bookMetadata,
        config: effectiveConfig,
        metadataService: _metadataService,
      );

      final result = await _currentProcessor!.execute();
      return result;
    } finally {
      _currentProcessor?.dispose();
      _currentProcessor = null;
    }
  }

  /// Get progress stream for the current operation
  Stream<ProcessingUpdate>? get progressStream => _currentProcessor?.progressStream;

  /// Cancel the current operation
  Future<void> cancelCurrentOperation() async {
    if (_currentProcessor != null) {
      Logger.log('Cancelling current audio conversion operation');
      await _currentProcessor!.cancel();
    }
  }

  /// Check if an operation is currently in progress
  bool get isOperationInProgress => _currentProcessor != null;

  /// Validate that required tools are available
  Future<ValidationResult> validateEnvironment() async {
    final issues = <String>[];
    
    // Check FFmpeg availability
    final ffmpegAvailable = await _metadataService.isFFmpegAvailableForConversion();
    if (!ffmpegAvailable) {
      issues.add('FFmpeg is not available. Please install FFmpeg and add it to your system PATH.');
    }

    // Check system capabilities
    if (_systemCapabilities == null) {
      issues.add('System capabilities not detected. Please reinitialize the service.');
    }

    return ValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
      recommendations: _getRecommendations(),
    );
  }

  /// Get hardware optimization recommendations
  List<String> _getRecommendations() {
    final recommendations = <String>[];
    
    if (_systemCapabilities != null && _hardwareInfo != null) {
      if (!_systemCapabilities!.hasSsdStorage) {
        recommendations.add('Consider using SSD storage for 2-3x faster conversion times.');
      }
      
      if (_systemCapabilities!.cpuCores >= 8) {
        recommendations.add('Your system has ${_systemCapabilities!.cpuCores} CPU cores. You can safely use 3-4 parallel conversions.');
      } else if (_systemCapabilities!.cpuCores >= 4) {
        recommendations.add('Your system has ${_systemCapabilities!.cpuCores} CPU cores. Consider using 2 parallel conversions for better performance.');
      }
      
      if (_hardwareInfo!.totalMemoryMB < 4096) {
        recommendations.add('Low memory detected (${_hardwareInfo!.totalMemoryMB}MB). Consider using 1-2 parallel conversions only.');
      } else if (_hardwareInfo!.totalMemoryMB < 8192) {
        recommendations.add('Moderate memory (${_hardwareInfo!.totalMemoryMB}MB). Up to 4 parallel conversions recommended.');
      }
      
      recommendations.add('Close other applications to free up memory for optimal performance.');
      recommendations.add('Disable antivirus scanning on working directories for faster file operations.');
      
      // Add cache-specific recommendation
      final cacheAge = DateTime.now().difference(_hardwareInfo!.detectedAt);
      if (cacheAge.inDays > 7) {
        recommendations.add('Hardware profile is ${cacheAge.inDays} days old. Consider refreshing if you\'ve upgraded your system.');
      }
    }
    
    return recommendations;
  }

  /// Get hardware cache status for debugging/settings
  Map<String, dynamic> getHardwareCacheStatus() {
    return {
      'cached': _hardwareInfo != null,
      'detectedAt': _hardwareInfo?.detectedAt.toIso8601String(),
      'cpuCores': _hardwareInfo?.cpuCores,
      'totalMemoryMB': _hardwareInfo?.totalMemoryMB,
      'maxParallelJobs': _hardwareInfo?.maxParallelJobs,
      'hasSSD': _hardwareInfo?.hasSSD,
      'architecture': _hardwareInfo?.cpuArchitecture,
      'cacheAge': _hardwareInfo != null ? DateTime.now().difference(_hardwareInfo!.detectedAt).inDays : null,
    };
  }

  void dispose() {
    _currentProcessor?.dispose();
  }
}

class ValidationResult {
  final bool isValid;
  final List<String> issues;
  final List<String> recommendations;

  const ValidationResult({
    required this.isValid,
    this.issues = const [],
    this.recommendations = const [],
  });
}