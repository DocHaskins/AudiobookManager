// lib/utils/audio_processors/base_audio_processor.dart
import 'dart:async';

/// Base class for all audio processing operations
abstract class BaseAudioProcessor {
  /// Progress stream for UI updates
  Stream<ProcessingUpdate> get progressStream => _progressController.stream;
  final StreamController<ProcessingUpdate> _progressController = 
      StreamController<ProcessingUpdate>.broadcast();

  /// Cancel the current operation
  Future<void> cancel();
  
  /// Execute the processing operation
  Future<ProcessingResult> execute();
  
  /// Clean up resources
  void dispose() {
    _progressController.close();
  }
  
  /// Emit progress update
  void emitProgress(ProcessingUpdate update) {
    if (!_progressController.isClosed) {
      _progressController.add(update);
    }
  }
}

/// Configuration for audio processing operations
class AudioProcessingConfig {
  final int parallelJobs;
  final String? bitrate;
  final bool preserveOriginalBitrate;
  final bool useHardwareOptimization;
  final String? outputDirectory;
  final Map<String, dynamic> customSettings;

  const AudioProcessingConfig({
    this.parallelJobs = 1,
    this.bitrate,
    this.preserveOriginalBitrate = false,
    this.useHardwareOptimization = true,
    this.outputDirectory,
    this.customSettings = const {},
  });

  AudioProcessingConfig copyWith({
    int? parallelJobs,
    String? bitrate,
    bool? preserveOriginalBitrate,
    bool? useHardwareOptimization,
    String? outputDirectory,
    Map<String, dynamic>? customSettings,
  }) {
    return AudioProcessingConfig(
      parallelJobs: parallelJobs ?? this.parallelJobs,
      bitrate: bitrate ?? this.bitrate,
      preserveOriginalBitrate: preserveOriginalBitrate ?? this.preserveOriginalBitrate,
      useHardwareOptimization: useHardwareOptimization ?? this.useHardwareOptimization,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      customSettings: customSettings ?? this.customSettings,
    );
  }
}

/// Progress update for audio processing operations
class ProcessingUpdate {
  final String stage;
  final double progress; // 0.0 to 1.0
  final String? currentFile;
  final int? completedFiles;
  final int? totalFiles;
  final Duration? elapsedTime;
  final Duration? estimatedTimeRemaining;
  final String? speed;
  final Map<String, dynamic> metadata;

  const ProcessingUpdate({
    required this.stage,
    required this.progress,
    this.currentFile,
    this.completedFiles,
    this.totalFiles,
    this.elapsedTime,
    this.estimatedTimeRemaining,
    this.speed,
    this.metadata = const {},
  });

  static ProcessingUpdate initial() => const ProcessingUpdate(
    stage: 'Initializing...',
    progress: 0.0,
  );

  static ProcessingUpdate completed() => const ProcessingUpdate(
    stage: 'Completed',
    progress: 1.0,
  );

  ProcessingUpdate copyWith({
    String? stage,
    double? progress,
    String? currentFile,
    int? completedFiles,
    int? totalFiles,
    Duration? elapsedTime,
    Duration? estimatedTimeRemaining,
    String? speed,
    Map<String, dynamic>? metadata,
  }) {
    return ProcessingUpdate(
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      currentFile: currentFile ?? this.currentFile,
      completedFiles: completedFiles ?? this.completedFiles,
      totalFiles: totalFiles ?? this.totalFiles,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      estimatedTimeRemaining: estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      speed: speed ?? this.speed,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Result of an audio processing operation
class ProcessingResult {
  final bool success;
  final List<String> outputFiles;
  final List<ProcessingError> errors;
  final Duration totalTime;
  final Map<String, dynamic> statistics;

  const ProcessingResult({
    required this.success,
    this.outputFiles = const [],
    this.errors = const [],
    this.totalTime = Duration.zero,
    this.statistics = const {},
  });

  bool get hasErrors => errors.isNotEmpty;
  int get successCount => outputFiles.length;
  int get errorCount => errors.length;
}

/// Error information for processing operations
class ProcessingError {
  final String filePath;
  final String message;
  final String? details;
  final DateTime timestamp;

  ProcessingError({
    required this.filePath,
    required this.message,
    this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}