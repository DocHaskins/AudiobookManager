// lib/utils/audio_processors/batch_converter_processor.dart
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
  
  // Progress monitoring
  Timer? _progressTimer;
  
  BatchConverterProcessor({
    required List<AudiobookFile> files,
    required AudioProcessingConfig config,
    required MetadataService metadataService,
    required LibraryManager libraryManager,
  }) : _filesToConvert = files,
       _config = config,
       _metadataService = metadataService,
       _libraryManager = libraryManager {
    
    // Forward progress tracker updates to our stream
    _progressTracker.stream.listen((update) {
      emitProgress(update);
    });
  }

  @override
  Future<ProcessingResult> execute() async {
    final startTime = DateTime.now();
    _isCancelled = false;
    _completedCount = 0;
    _successfulConversions.clear();
    _errors.clear();

    try {
      Logger.log('Starting batch conversion of ${_filesToConvert.length} files');
      Logger.log('Configuration: ${_config.parallelJobs} parallel jobs, bitrate: ${_config.bitrate ?? "auto"}');

      // Start progress monitoring
      _startProgressMonitoring();

      _progressTracker.updateProgress(
        stage: 'Initializing batch conversion...',
        progress: 0.0,
        totalFiles: _filesToConvert.length,
        completedFiles: 0,
      );

      // Process files in parallel with controlled concurrency
      await _processFilesInParallel();

      final totalTime = DateTime.now().difference(startTime);
      final successCount = _successfulConversions.length;
      final errorCount = _errors.length;

      Logger.log('Batch conversion completed: $successCount succeeded, $errorCount failed');
      Logger.log('Total time: ${_formatDuration(totalTime)}');

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
      Logger.error('Error in batch conversion execution: $e');
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
    }
  }

  void _startProgressMonitoring() {
    // Update progress every second to provide real-time feedback
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isCancelled && _completedCount < _filesToConvert.length) {
        final currentFileName = _progressTracker.currentFile;
        _progressTracker.updateProgress(
          stage: currentFileName != null 
              ? 'Converting: $currentFileName'
              : 'Converting files... ($_completedCount/${_filesToConvert.length} complete)',
          progress: _completedCount / _filesToConvert.length,
          currentFile: currentFileName,
          completedFiles: _completedCount,
          totalFiles: _filesToConvert.length,
        );
      }
    });
  }

  Future<void> _processFilesInParallel() async {
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
  }

  Future<void> _convertSingleFileWithTracking(AudiobookFile file) async {
    final fileName = path_util.basename(file.path);
    final fileStartTime = DateTime.now();
    
    try {
      Logger.log('Starting conversion: $fileName');
      
      // Report file started
      _progressTracker.reportFileStarted(fileName);
      
      _progressTracker.updateProgress(
        stage: 'Converting: $fileName',
        progress: _completedCount / _filesToConvert.length,
        currentFile: fileName,
        completedFiles: _completedCount,
        totalFiles: _filesToConvert.length,
      );

      final success = await _convertSingleFile(file);
      
      _completedCount++;
      final processingTime = DateTime.now().difference(fileStartTime);
      
      if (success) {
        // Add the M4B path to successful conversions
        final originalPath = file.path;
        final directory = path_util.dirname(originalPath);
        final baseName = path_util.basenameWithoutExtension(originalPath);
        final m4bPath = path_util.join(directory, '$baseName.m4b');
        _successfulConversions.add(m4bPath);
        
        // Report successful completion
        _progressTracker.reportFileCompleted(fileName, processingTime);
        
        Logger.log('Successfully converted: $fileName in ${_formatDuration(processingTime)}');
      } else {
        // Report failure
        _progressTracker.reportFileFailed(fileName, 'Conversion failed');
        Logger.error('Failed to convert: $fileName');
      }
      
      _progressTracker.updateProgress(
        stage: 'Converting files... ($_completedCount/${_filesToConvert.length} complete)',
        progress: _completedCount / _filesToConvert.length,
        completedFiles: _completedCount,
        totalFiles: _filesToConvert.length,
      );
      
    } catch (e) {
      _completedCount++;
      final errorMessage = e.toString();
      
      // Report failure with error message
      _progressTracker.reportFileFailed(fileName, errorMessage);
      
      Logger.error('Error converting $fileName: $e');
      
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

  Future<bool> _convertSingleFile(AudiobookFile file) async {
    try {
      Logger.log('Converting: ${file.filename}');

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

      // Perform conversion
      final success = await _metadataService.convertMP3ToM4B(
        originalPath,
        m4bPath,
        file.metadata!,
        totalDuration: file.metadata!.audioDuration,
        bitrate: _config.bitrate,
        preserveOriginalBitrate: _config.preserveOriginalBitrate,
      );

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
            Logger.log('Deleted original MP3: ${file.filename}');
          } catch (e) {
            Logger.warning('Failed to delete original file: $e');
          }

          return true;
        } else {
          throw Exception('Failed to update library after conversion');
        }
      } else {
        throw Exception(_isCancelled ? 'Cancelled' : 'Conversion failed');
      }
    } catch (e) {
      Logger.error('Error converting ${file.filename}: $e');
      throw e; // Re-throw to be handled by the calling method
    }
  }

  @override
  Future<void> cancel() async {
    Logger.log('Cancelling batch conversion...');
    _isCancelled = true;
    _progressTimer?.cancel();
    
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
    _progressTimer?.cancel();
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