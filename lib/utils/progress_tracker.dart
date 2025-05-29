// lib/utils/progress_tracker.dart
import 'dart:async';
import 'audio_processors/base_audio_processor.dart';

class ProgressTracker {
  final StreamController<ProcessingUpdate> _controller = 
      StreamController<ProcessingUpdate>.broadcast();
  
  Stream<ProcessingUpdate> get stream => _controller.stream;
  
  final DateTime _startTime = DateTime.now();
  final List<Duration> _fileCompletionTimes = [];
  
  // Enhanced tracking for individual files
  final List<String> _completedFiles = [];
  final List<String> _startedFiles = [];
  final Map<String, String> _failedFiles = {}; // filename -> error message
  int _totalFiles = 0;
  String? _currentFile;

  void updateProgress({
    required String stage,
    required double progress,
    String? currentFile,
    int? completedFiles,
    int? totalFiles,
    String? speed,
    Map<String, dynamic>? metadata,
  }) {
    final elapsed = DateTime.now().difference(_startTime);
    Duration? eta;
    
    // Update tracking info
    if (totalFiles != null) _totalFiles = totalFiles;
    if (currentFile != null) _currentFile = currentFile;
    
    // Calculate ETA based on completed files and average time per file
    if (completedFiles != null && _totalFiles > 0 && completedFiles > 0) {
      if (_fileCompletionTimes.isNotEmpty) {
        final averageTimePerFile = _fileCompletionTimes.fold(
          Duration.zero, 
          (sum, time) => sum + time
        ) ~/ _fileCompletionTimes.length;
        
        final remainingFiles = _totalFiles - completedFiles;
        if (remainingFiles > 0) {
          eta = averageTimePerFile * remainingFiles;
        }
      }
    }
    
    // Calculate speed if not provided
    String effectiveSpeed = speed ?? '';
    if (effectiveSpeed.isEmpty && completedFiles != null && completedFiles > 0 && elapsed.inSeconds > 0) {
      final filesPerSecond = completedFiles / elapsed.inSeconds;
      if (filesPerSecond >= 1) {
        effectiveSpeed = '${filesPerSecond.toStringAsFixed(1)} files/sec';
      } else {
        final secondsPerFile = elapsed.inSeconds / completedFiles;
        effectiveSpeed = '${secondsPerFile.toStringAsFixed(1)} sec/file';
      }
    }
    
    // Merge provided metadata with our tracked data
    final enhancedMetadata = Map<String, dynamic>.from(metadata ?? {});
    enhancedMetadata.addAll({
      'completed_files': List<String>.from(_completedFiles),
      'failed_files': Map<String, String>.from(_failedFiles),
      'started_files': List<String>.from(_startedFiles),
      'success_count': _completedFiles.length,
      'failed_count': _failedFiles.length,
      'processing_rate': effectiveSpeed,
      'current_file': _currentFile,
    });
    
    final update = ProcessingUpdate(
      stage: stage,
      progress: progress.clamp(0.0, 1.0),
      currentFile: currentFile ?? _currentFile,
      completedFiles: completedFiles ?? _completedFiles.length,
      totalFiles: totalFiles ?? _totalFiles,
      elapsedTime: elapsed,
      estimatedTimeRemaining: eta,
      speed: effectiveSpeed,
      metadata: enhancedMetadata,
    );
    
    if (!_controller.isClosed) {
      _controller.add(update);
    }
  }
  
  void reportFileStarted(String fileName) {
    if (!_startedFiles.contains(fileName)) {
      _startedFiles.add(fileName);
      _currentFile = fileName;
    }
  }
  
  void reportFileCompleted(String fileName, Duration processingTime) {
    _fileCompletionTimes.add(processingTime);
    
    // Keep only recent completion times to adapt to changing speeds
    if (_fileCompletionTimes.length > 10) {
      _fileCompletionTimes.removeAt(0);
    }
    
    // Track completed file
    if (!_completedFiles.contains(fileName)) {
      _completedFiles.add(fileName);
    }
    
    // Remove from failed files if it was there
    _failedFiles.remove(fileName);
    
    // Clear current file if this was it
    if (_currentFile == fileName) {
      _currentFile = null;
    }
  }
  
  void reportFileFailed(String fileName, String errorMessage) {
    _failedFiles[fileName] = errorMessage;
    
    // Remove from completed files if it was there
    _completedFiles.remove(fileName);
    
    // Clear current file if this was it
    if (_currentFile == fileName) {
      _currentFile = null;
    }
  }
  
  void clearCurrentFile() {
    _currentFile = null;
  }
  
  // Getters for current state
  List<String> get completedFiles => List<String>.from(_completedFiles);
  List<String> get startedFiles => List<String>.from(_startedFiles);
  Map<String, String> get failedFiles => Map<String, String>.from(_failedFiles);
  String? get currentFile => _currentFile;
  int get successCount => _completedFiles.length;
  int get failedCount => _failedFiles.length;
  
  void dispose() {
    _controller.close();
  }
}