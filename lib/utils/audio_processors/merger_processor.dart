// lib/utils/audio_processors/merger_processor.dart
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/chapter_info.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/utils/audio_processors/base_audio_processor.dart';
import 'package:audiobook_organizer/utils/progress_tracker.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class MergerProcessor extends BaseAudioProcessor {
  final List<ChapterInfo> _chapters;
  final String _outputPath;
  final AudiobookMetadata _bookMetadata;
  final AudioProcessingConfig _config;
  final MetadataService _metadataService;
  final ProgressTracker _progressTracker = ProgressTracker();
  
  bool _isCancelled = false;
  
  MergerProcessor({
    required List<ChapterInfo> chapters,
    required String outputPath,
    required AudiobookMetadata bookMetadata,
    required AudioProcessingConfig config,
    required MetadataService metadataService,
  }) : _chapters = chapters,
       _outputPath = outputPath,
       _bookMetadata = bookMetadata,
       _config = config,
       _metadataService = metadataService {
    
    // Forward progress tracker updates to our stream
    _progressTracker.stream.listen((update) {
      emitProgress(update);
    });
  }

  @override
  Future<ProcessingResult> execute() async {
    final startTime = DateTime.now();
    _isCancelled = false;

    try {
      Logger.log('Starting merge of ${_chapters.length} chapters to: ${path_util.basename(_outputPath)}');

      _progressTracker.updateProgress(
        stage: 'Preparing merge process...',
        progress: 0.0,
        totalFiles: _chapters.length,
      );

      // Execute the merge with progress tracking
      final success = await _metadataService.mergeMP3FilesToM4B(
        _chapters,
        _outputPath,
        _bookMetadata,
        onProgress: (stage, progress) {
          if (!_isCancelled) {
            _progressTracker.updateProgress(
              stage: stage,
              progress: progress,
              totalFiles: _chapters.length,
            );
          }
        },
      );

      final totalTime = DateTime.now().difference(startTime);

      if (success && !_isCancelled) {
        Logger.log('Successfully merged ${_chapters.length} chapters');
        
        _progressTracker.updateProgress(
          stage: 'Merge completed successfully!',
          progress: 1.0,
          totalFiles: _chapters.length,
        );

        return ProcessingResult(
          success: true,
          outputFiles: [_outputPath],
          totalTime: totalTime,
          statistics: {
            'total_chapters': _chapters.length,
            'output_file': _outputPath,
            'total_duration': _getTotalDuration().inSeconds,
            'merge_time': totalTime.inSeconds,
          },
        );
      } else {
        throw Exception(_isCancelled ? 'Merge cancelled' : 'Merge failed');
      }
    } catch (e) {
      Logger.error('Error in merge execution: $e');
      
      return ProcessingResult(
        success: false,
        errors: [ProcessingError(
          filePath: _outputPath,
          message: 'Merge failed: $e',
        )],
        totalTime: DateTime.now().difference(startTime),
      );
    }
  }

  Duration _getTotalDuration() {
    return _chapters.fold(Duration.zero, (total, chapter) => total + chapter.duration);
  }

  @override
  Future<void> cancel() async {
    Logger.log('Cancelling merge operation...');
    _isCancelled = true;
  }

  @override
  void dispose() {
    _progressTracker.dispose();
    super.dispose();
  }
}