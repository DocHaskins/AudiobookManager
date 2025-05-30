// Replace the batch_converter_processor.dart with this enhanced debug version

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/utils/audio_processors/base_audio_processor.dart';
import 'package:audiobook_organizer/utils/progress_tracker.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/ui/widgets/dialogs/conversion_progress_dialog.dart';

class Semaphore {
  final int _maxCount;
  int _currentCount = 0;
  final Queue<Completer<void>> _waiters = Queue();

  Semaphore(this._maxCount);

  Future<void> acquire() async {
    if (_currentCount < _maxCount) {
      _currentCount++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void release() {
    if (_waiters.isEmpty) {
      _currentCount--;
    } else {
      final completer = _waiters.removeFirst();
      completer.complete();
    }
  }
}

class BatchConverterProcessor extends BaseAudioProcessor {
  final List<AudiobookFile> _filesToConvert;
  final AudioProcessingConfig _config;
  final MetadataService _metadataService;
  final LibraryManager _libraryManager;
  final ProgressTracker _progressTracker = ProgressTracker();
  
  bool _isCancelled = false;
  int _completedCount = 0;
  final List<String> _successfulConversions = [];
  final List<ProcessingError> _errors = [];
  
  // Enhanced progress tracking with debug info
  final Map<String, String> _fileStatus = {}; // filePath -> status
  final Map<String, double> _fileProgress = {}; // filePath -> progress (0.0-1.0)
  final Map<String, String> _fileSpeed = {}; // filePath -> speed string
  final Map<String, DateTime> _fileStartTimes = {}; // filePath -> start time
  final List<String> _startedFiles = [];
  final List<String> _completedFiles = [];
  final Map<String, String> _failedFiles = {}; // filePath -> error message
  
  // Debug tracking
  final Map<String, StreamController<ConversionProgress>> _fileProgressControllers = {};
  
  // Progress monitoring
  Timer? _progressTimer;
  Timer? _detailUpdateTimer;
  
  BatchConverterProcessor({
    required List<AudiobookFile> files,
    required AudioProcessingConfig config,
    required MetadataService metadataService,
    required LibraryManager libraryManager,
  }) : _filesToConvert = files,
       _config = config,
       _metadataService = metadataService,
       _libraryManager = libraryManager {
    
    Logger.log('🔧 BatchConverterProcessor: Initializing with ${files.length} files');
    
    // Forward progress tracker updates to our stream
    _progressTracker.stream.listen((update) {
      Logger.log('🔄 BatchConverterProcessor: Received progress update - ${update.stage} (${(update.progress * 100).toStringAsFixed(1)}%)');
      
      // Enhance the update with our detailed tracking
      final enhancedUpdate = _enhanceProgressUpdate(update);
      Logger.log('📤 BatchConverterProcessor: Emitting enhanced progress update');
      emitProgress(enhancedUpdate);
    });
  }

  ProcessingUpdate _enhanceProgressUpdate(ProcessingUpdate baseUpdate) {
    // Create enhanced metadata with detailed file tracking
    final enhancedMetadata = Map<String, dynamic>.from(baseUpdate.metadata);
    
    // Add our detailed tracking information
    enhancedMetadata.addAll({
      'completed_files': List<String>.from(_completedFiles),
      'failed_files': Map<String, String>.from(_failedFiles),
      'started_files': List<String>.from(_startedFiles),
      'file_progress': Map<String, double>.from(_fileProgress),
      'file_status': Map<String, String>.from(_fileStatus),
      'file_speed': Map<String, String>.from(_fileSpeed),
      'success_count': _completedFiles.length,
      'failed_count': _failedFiles.length,
      'active_conversions': _startedFiles.length - _completedFiles.length - _failedFiles.length,
    });
    
    Logger.log('📊 Enhanced metadata: ${enhancedMetadata.keys.join(', ')}');
    
    return baseUpdate.copyWith(
      metadata: enhancedMetadata,
      completedFiles: _completedCount,
      totalFiles: _filesToConvert.length,
    );
  }

  @override
  Future<ProcessingResult> execute() async {
    final startTime = DateTime.now();
    Logger.log('🚀 BatchConverterProcessor: Starting execution');
    
    _isCancelled = false;
    _completedCount = 0;
    _successfulConversions.clear();
    _errors.clear();
    
    // Clear tracking maps
    _fileStatus.clear();
    _fileProgress.clear();
    _fileSpeed.clear();
    _fileStartTimes.clear();
    _startedFiles.clear();
    _completedFiles.clear();
    _failedFiles.clear();
    _fileProgressControllers.clear();

    try {
      Logger.log('🔧 Configuration: ${_config.parallelJobs} parallel jobs, bitrate: ${_config.bitrate ?? "auto"}');

      // Start progress monitoring
      _startProgressMonitoring();
      _startDetailedUpdateTimer();

      _progressTracker.updateProgress(
        stage: 'Initializing batch conversion...',
        progress: 0.0,
        totalFiles: _filesToConvert.length,
        completedFiles: 0,
      );

      // Initialize file status tracking
      for (final file in _filesToConvert) {
        final filePath = file.path;
        _fileStatus[filePath] = 'waiting';
        _fileProgress[filePath] = 0.0;
        _fileSpeed[filePath] = '';
        Logger.log('📁 Initialized tracking for: ${path_util.basename(filePath)}');
      }

      // Process files in parallel with controlled concurrency
      await _processFilesInParallel();

      final totalTime = DateTime.now().difference(startTime);
      final successCount = _successfulConversions.length;
      final errorCount = _errors.length;

      Logger.log('✅ Batch conversion completed: $successCount succeeded, $errorCount failed');
      Logger.log('⏱️ Total time: ${_formatDuration(totalTime)}');

      _progressTracker.updateProgress(
        stage: _isCancelled 
            ? 'Conversion cancelled: $successCount succeeded, $errorCount failed'
            : 'Conversion complete: $successCount succeeded, $errorCount failed',
        progress: 1.0,
        totalFiles: _filesToConvert.length,
        completedFiles: _completedCount,
      );

      return ProcessingResult(
        success: !_isCancelled && errorCount == 0,
        outputFiles: _successfulConversions,
        errors: _errors,
        totalTime: totalTime,
        statistics: {
          'total_files': _filesToConvert.length,
          'successful_conversions': successCount,
          'failed_conversions': errorCount,
          'cancelled': _isCancelled,
          'parallel_jobs_used': _config.parallelJobs,
          'average_time_per_file': successCount > 0 
              ? totalTime.inMilliseconds / successCount 
              : 0,
        },
      );

    } catch (e) {
      Logger.error('❌ Error in batch conversion execution: $e');
      _errors.add(ProcessingError(
        filePath: 'batch_operation',
        message: 'Batch conversion failed: $e',
      ));

      return ProcessingResult(
        success: false,
        errors: _errors,
        totalTime: DateTime.now().difference(startTime),
      );
    } finally {
      _progressTimer?.cancel();
      _detailUpdateTimer?.cancel();
      
      // Close all progress controllers
      for (final controller in _fileProgressControllers.values) {
        if (!controller.isClosed) {
          await controller.close();
        }
      }
      _fileProgressControllers.clear();
    }
  }

  void _startProgressMonitoring() {
    Logger.log('⏰ Starting progress monitoring timer');
    
    // Update progress every second to provide real-time feedback
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isCancelled && _completedCount < _filesToConvert.length) {
        // Calculate overall progress INCLUDING partial progress from active conversions
        double totalProgress = _completedCount.toDouble();
        
        // Add progress from files currently being converted
        for (final entry in _fileProgress.entries) {
          if (_fileStatus[entry.key] == 'converting') {
            totalProgress += entry.value;
          }
        }
        
        final overallProgress = totalProgress / _filesToConvert.length;
        final currentFileName = _getCurrentlyProcessingFile();
        
        Logger.log('⏰ Timer update: $_completedCount/${_filesToConvert.length} complete (${(overallProgress * 100).toStringAsFixed(1)}%)');
        Logger.log('⏰ Total progress including partial: ${totalProgress.toStringAsFixed(2)}/${_filesToConvert.length}');
        
        _progressTracker.updateProgress(
          stage: currentFileName != null 
              ? 'Converting: $currentFileName'
              : 'Processing files... ($_completedCount/${_filesToConvert.length} complete)',
          progress: overallProgress,
          currentFile: currentFileName,
          completedFiles: _completedCount,
          totalFiles: _filesToConvert.length,
        );
      }
    });
  }

  // Add this helper method:
  String? _getCurrentlyProcessingFile() {
    // Find the first file that's currently being converted
    for (final entry in _fileStatus.entries) {
      if (entry.value == 'converting') {
        return path_util.basename(entry.key);
      }
    }
    return null;
  }

  void _startDetailedUpdateTimer() {
    Logger.log('⏰ Starting detailed update timer');
    
    // Send detailed updates every 500ms for smoother UI updates
    _detailUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isCancelled) {
        _emitDetailedProgressUpdate();
      }
    });
  }

  void _emitDetailedProgressUpdate() {
    // Calculate overall progress INCLUDING partial progress
    double totalProgress = _completedCount.toDouble();
    
    // Add progress from files currently being converted
    for (final entry in _fileProgress.entries) {
      if (_fileStatus[entry.key] == 'converting') {
        totalProgress += entry.value;
      }
    }
    
    final overallProgress = totalProgress / _filesToConvert.length;
    
    // Calculate average speed across all active conversions
    final activeSpeedValues = _fileSpeed.values.where((speed) => speed.isNotEmpty).toList();
    String averageSpeed = '';
    if (activeSpeedValues.isNotEmpty) {
      averageSpeed = activeSpeedValues.first;
    }
    
    // Find current file being processed
    String? currentFile = _getCurrentlyProcessingFile();
    
    Logger.log('📊 Detailed update: Overall ${(overallProgress * 100).toStringAsFixed(1)}%, Active files: ${_fileStatus.values.where((s) => s == 'converting').length}');
    Logger.log('📊 Progress breakdown: completed=$_completedCount, partial=${(totalProgress - _completedCount).toStringAsFixed(2)}');
    
    final update = ProcessingUpdate(
      stage: currentFile != null 
          ? 'Converting: $currentFile (${_fileProgress.values.where((p) => p > 0).isNotEmpty ? (_fileProgress.values.reduce((a, b) => a > b ? a : b) * 100).toStringAsFixed(1) : '0'}%)'
          : 'Processing files... ($_completedCount/${_filesToConvert.length})',
      progress: overallProgress,
      currentFile: currentFile,
      completedFiles: _completedCount,
      totalFiles: _filesToConvert.length,
      speed: averageSpeed,
      metadata: {
        'completed_files': List<String>.from(_completedFiles.map((path) => path_util.basename(path))),
        'failed_files': Map<String, String>.from(_failedFiles.map((key, value) => MapEntry(path_util.basename(key), value))),
        'started_files': List<String>.from(_startedFiles.map((path) => path_util.basename(path))),
        'file_progress': Map<String, double>.from(_fileProgress.map((key, value) => MapEntry(path_util.basename(key), value))),
        'file_status': Map<String, String>.from(_fileStatus.map((key, value) => MapEntry(path_util.basename(key), value))),
        'file_speed': Map<String, String>.from(_fileSpeed.map((key, value) => MapEntry(path_util.basename(key), value))),
        'success_count': _completedFiles.length,
        'failed_count': _failedFiles.length,
        'active_conversions': _fileStatus.values.where((s) => s == 'converting').length,
        'overall_progress_details': {
          'completed_count': _completedCount,
          'total_progress': totalProgress,
          'calculated_progress': overallProgress,
        },
      },
    );
    
    emitProgress(update);
  }

  Future<void> _processFilesInParallel() async {
    Logger.log('🔄 Starting parallel processing with ${_config.parallelJobs} jobs');
    
    // Simple semaphore-like approach for controlling concurrency
    final semaphore = Semaphore(_config.parallelJobs);
    final futures = <Future<void>>[];

    for (final file in _filesToConvert) {
      if (_isCancelled) break;
      
      final future = semaphore.acquire().then((_) async {
        try {
          await _convertSingleFileWithTracking(file);
        } finally {
          semaphore.release();
        }
      });
      
      futures.add(future);
    }

    // Wait for all conversions to complete
    await Future.wait(futures);
    Logger.log('🔄 All parallel processing completed');
  }

  Future<void> _convertSingleFileWithTracking(AudiobookFile file) async {
    final fileName = path_util.basename(file.path);
    final filePath = file.path;
    final fileStartTime = DateTime.now();
    
    Logger.log('🎵 Starting conversion: $fileName');
    
    try {
      // Update tracking
      _fileStartTimes[filePath] = fileStartTime;
      _fileStatus[filePath] = 'converting';
      _fileProgress[filePath] = 0.0;
      _startedFiles.add(filePath);
      
      Logger.log('📊 Updated tracking for $fileName: status=converting, progress=0.0');
      
      // Report file started
      _progressTracker.reportFileStarted(fileName);
      
      _progressTracker.updateProgress(
        stage: 'Converting: $fileName',
        progress: _completedCount / _filesToConvert.length,
        currentFile: fileName,
        completedFiles: _completedCount,
        totalFiles: _filesToConvert.length,
      );

      // Create progress controller for individual file conversion
      final progressController = StreamController<ConversionProgress>();
      _fileProgressControllers[filePath] = progressController;
      
      Logger.log('🔗 Created progress controller for $fileName');
      
      // Listen to individual file progress with detailed logging
      progressController.stream.listen(
        (conversionProgress) {
          Logger.log('📈 Progress update for $fileName: ${(conversionProgress.percentage * 100).toStringAsFixed(1)}% (${conversionProgress.speed})');
          if (!_isCancelled) {
            _updateFileProgress(filePath, conversionProgress);
          }
        },
        onError: (error) {
          Logger.error('❌ Progress stream error for $fileName: $error');
        },
        onDone: () {
          Logger.log('✅ Progress stream completed for $fileName');
        },
      );

      Logger.log('🔄 Calling convertSingleFile for $fileName');
      final success = await _convertSingleFile(file, progressController);
      Logger.log('🔄 convertSingleFile returned: $success for $fileName');
      
      _completedCount++;
      final processingTime = DateTime.now().difference(fileStartTime);
      
      if (success) {
        // Add the M4B path to successful conversions
        final originalPath = file.path;
        final directory = path_util.dirname(originalPath);
        final baseName = path_util.basenameWithoutExtension(originalPath);
        final m4bPath = path_util.join(directory, '$baseName.m4b');
        _successfulConversions.add(m4bPath);
        
        // Update tracking for success
        _fileStatus[filePath] = 'completed';
        _fileProgress[filePath] = 1.0;
        _completedFiles.add(filePath);
        
        // Report successful completion
        _progressTracker.reportFileCompleted(fileName, processingTime);
        
        Logger.log('✅ Successfully converted: $fileName in ${_formatDuration(processingTime)}');
      } else {
        // Update tracking for failure
        _fileStatus[filePath] = 'failed';
        _failedFiles[filePath] = 'Conversion failed';
        
        // Report failure
        _progressTracker.reportFileFailed(fileName, 'Conversion failed');
        Logger.error('❌ Failed to convert: $fileName');
      }
      
      // Remove from started files
      _startedFiles.remove(filePath);
      
      // Close the progress controller
      if (!progressController.isClosed) {
        await progressController.close();
      }
      _fileProgressControllers.remove(filePath);
      
      _progressTracker.updateProgress(
        stage: 'Converting files... ($_completedCount/${_filesToConvert.length} complete)',
        progress: _completedCount / _filesToConvert.length,
        completedFiles: _completedCount,
        totalFiles: _filesToConvert.length,
      );
      
    } catch (e) {
      _completedCount++;
      final errorMessage = e.toString();
      
      Logger.error('❌ Error converting $fileName: $e');
      
      // Update tracking for error
      _fileStatus[filePath] = 'failed';
      _failedFiles[filePath] = errorMessage;
      _startedFiles.remove(filePath);
      
      // Report failure with error message
      _progressTracker.reportFileFailed(fileName, errorMessage);
      
      _errors.add(ProcessingError(
        filePath: file.path,
        message: errorMessage,
      ));
      
      _progressTracker.updateProgress(
        stage: 'Error processing $fileName',
        progress: _completedCount / _filesToConvert.length,
        completedFiles: _completedCount,
        totalFiles: _filesToConvert.length,
      );
    }
  }

  void _updateFileProgress(String filePath, ConversionProgress conversionProgress) {
    final fileName = path_util.basename(filePath);
    Logger.log('📈 Updating file progress for $fileName: ${(conversionProgress.percentage * 100).toStringAsFixed(1)}%');
    
    // Update file-specific progress tracking
    _fileProgress[filePath] = conversionProgress.percentage;
    
    // Update speed if available
    if (conversionProgress.speed.isNotEmpty) {
      _fileSpeed[filePath] = conversionProgress.speed;
      Logger.log('🏃 Speed update for $fileName: ${conversionProgress.speed}');
    }
    
    // Calculate overall progress including current file progress
    double totalProgress = _completedCount.toDouble();
    
    // Add progress from files currently being converted
    for (final entry in _fileProgress.entries) {
      if (_fileStatus[entry.key] == 'converting') {
        totalProgress += entry.value;
      }
    }
    
    final overallProgress = totalProgress / _filesToConvert.length;
    
    Logger.log('📊 Overall progress: ${(overallProgress * 100).toStringAsFixed(1)}% (completed: $_completedCount, total progress: ${totalProgress.toStringAsFixed(2)})');
    
    _progressTracker.updateProgress(
      stage: 'Converting: $fileName (${(conversionProgress.percentage * 100).toStringAsFixed(1)}%)',
      progress: overallProgress,
      currentFile: fileName,
      completedFiles: _completedCount,
      totalFiles: _filesToConvert.length,
      speed: conversionProgress.speed,
    );
  }

  Future<bool> _convertSingleFile(AudiobookFile file, StreamController<ConversionProgress> progressController) async {
    try {
      Logger.log('🔄 Converting: ${file.filename}');

      if (file.metadata == null) {
        throw Exception('No metadata available for conversion');
      }

      // Create M4B file path
      final originalPath = file.path;
      final directory = path_util.dirname(originalPath);
      final baseName = path_util.basenameWithoutExtension(originalPath);
      final m4bPath = path_util.join(directory, '$baseName.m4b');

      // Check if M4B file already exists
      if (await File(m4bPath).exists()) {
        throw Exception('M4B file already exists');
      }

      Logger.log('🔄 Calling MetadataService.convertMP3ToM4B for ${file.filename}');
      Logger.log('🔧 Parameters: input=$originalPath, output=$m4bPath, bitrate=${_config.bitrate}, preserve=${_config.preserveOriginalBitrate}');
      
      // Perform conversion with progress tracking
      final success = await _metadataService.convertMP3ToM4B(
        originalPath,
        m4bPath,
        file.metadata!,
        totalDuration: file.metadata!.audioDuration,
        bitrate: _config.bitrate,
        preserveOriginalBitrate: _config.preserveOriginalBitrate,
        progressController: progressController, // Pass the progress controller
      );

      Logger.log('🔄 MetadataService.convertMP3ToM4B returned: $success for ${file.filename}');

      if (success && !_isCancelled) {
        // Update library
        final updateSuccess = await _libraryManager.replaceFileInLibrary(
          originalPath,
          m4bPath,
          file.metadata!,
        );

        if (updateSuccess) {
          // Delete original MP3 file
          try {
            await File(originalPath).delete();
            Logger.log('🗑️ Deleted original MP3: ${file.filename}');
          } catch (e) {
            Logger.warning('⚠️ Failed to delete original file: $e');
          }

          return true;
        } else {
          throw Exception('Failed to update library after conversion');
        }
      } else {
        throw Exception(_isCancelled ? 'Cancelled' : 'Conversion failed');
      }
    } catch (e) {
      Logger.error('❌ Error converting ${file.filename}: $e');
      rethrow; // Re-throw to be handled by the calling method
    }
  }

  @override
  Future<void> cancel() async {
    Logger.log('🛑 Cancelling batch conversion...');
    _isCancelled = true;
    _progressTimer?.cancel();
    _detailUpdateTimer?.cancel();
    
    // Update all currently converting files to cancelled
    for (final filePath in _fileStatus.keys.toList()) {
      if (_fileStatus[filePath] == 'converting') {
        _fileStatus[filePath] = 'failed';
        _failedFiles[filePath] = 'Cancelled by user';
        _startedFiles.remove(filePath);
      }
    }
    
    // Close all progress controllers
    for (final controller in _fileProgressControllers.values) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
    _fileProgressControllers.clear();
    
    // Clear current file in progress tracker
    _progressTracker.clearCurrentFile();
    
    _progressTracker.updateProgress(
      stage: 'Cancelling conversion...',
      progress: _completedCount / _filesToConvert.length,
      completedFiles: _completedCount,
      totalFiles: _filesToConvert.length,
    );
  }

  @override
  void dispose() {
    Logger.log('🧹 Disposing BatchConverterProcessor');
    _progressTimer?.cancel();
    _detailUpdateTimer?.cancel();
    
    // Close all progress controllers
    for (final controller in _fileProgressControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _fileProgressControllers.clear();
    
    _progressTracker.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }
}