// lib/models/audiobook_file.dart
import 'dart:io';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class AudiobookFile {
  final String path;
  final DateTime lastModified;
  final int fileSize;
  AudiobookMetadata? metadata;
  
  AudiobookFile({
    required this.path,
    required this.lastModified,
    required this.fileSize,
    this.metadata,
  });
  
  // Get filename from path
  String get filename => path_util.basename(path);
  
  // Get file extension
  String get extension => path_util.extension(path).toLowerCase();
  
  // Check if this is an audiobook file based on extension
  bool get isAudiobookFile {
    const validExtensions = ['.mp3', '.m4a', '.m4b', '.aac', '.ogg', '.wma', '.flac', '.opus'];
    return validExtensions.contains(extension);
  }

  // Get a basic display title (filename or metadata title)
  String get displayTitle => metadata?.title ?? path_util.basenameWithoutExtension(filename);
  
  // Get authors for display
  String get displayAuthors => metadata?.authorsFormatted ?? 'Unknown Author';
  
  // Check if file has complete metadata
  bool get hasCompleteMetadata {
    return metadata != null && 
           metadata!.title.isNotEmpty && 
           metadata!.authors.isNotEmpty &&
           metadata!.audioDuration != null;
  }
  
  // Check if file has duration information
  bool get hasDuration => metadata?.audioDuration != null;
  
  // Get formatted file size
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Create from file with enhanced metadata extraction
  static Future<AudiobookFile?> fromFile(File file, {bool extractMetadata = false}) async {
    try {
      final stat = await file.stat();
      
      final audioFile = AudiobookFile(
        path: file.path,
        lastModified: stat.modified,
        fileSize: stat.size,
      );
      
      // Optionally extract metadata during creation
      if (extractMetadata) {
        try {
          final metadataService = MetadataService();
          final metadata = await metadataService.extractMetadata(file.path);
          audioFile.metadata = metadata;
          
          if (metadata != null) {
            Logger.debug('Extracted metadata during file creation: ${metadata.title}${metadata.audioDuration != null ? " (Duration: ${metadata.durationFormatted})" : " (No duration)"}');
          } else {
            Logger.debug('No metadata extracted for: ${audioFile.filename}');
          }
        } catch (e) {
          Logger.error('Error extracting metadata during file creation: ${file.path}', e);
          // Continue without metadata rather than failing
        }
      }
      
      return audioFile;
    } catch (e) {
      Logger.error('Error creating AudiobookFile from File: ${file.path}', e);
      return null;
    }
  }
  
  // Create from file with existing metadata
  static Future<AudiobookFile?> fromFileWithMetadata(
    File file, 
    AudiobookMetadata? existingMetadata
  ) async {
    try {
      final stat = await file.stat();
      
      return AudiobookFile(
        path: file.path,
        lastModified: stat.modified,
        fileSize: stat.size,
        metadata: existingMetadata,
      );
    } catch (e) {
      Logger.error('Error creating AudiobookFile with metadata: ${file.path}', e);
      return null;
    }
  }
  
  // Refresh metadata from file with enhanced logging
  Future<bool> refreshMetadata({bool forceRefresh = false}) async {
    try {
      Logger.debug('Refreshing metadata for: $filename (forceRefresh: $forceRefresh)');
      
      final metadataService = MetadataService();
      final newMetadata = await metadataService.extractMetadata(
        path, 
        forceRefresh: forceRefresh
      );
      
      if (newMetadata != null) {
        final oldDuration = metadata?.audioDuration;
        
        // If we have existing metadata, enhance it rather than replacing (unless forced)
        if (metadata != null && !forceRefresh) {
          metadata = metadata!.enhance(newMetadata);
          Logger.debug('Enhanced existing metadata for: $filename');
        } else {
          metadata = newMetadata;
          Logger.debug('Replaced metadata for: $filename');
        }
        
        // Log duration changes
        final newDuration = metadata?.audioDuration;
        if (oldDuration != newDuration) {
          Logger.debug('Duration changed for $filename: ${oldDuration != null ? _formatDuration(oldDuration) : "null"} -> ${newDuration != null ? _formatDuration(newDuration) : "null"}');
        }
        
        return true;
      } else {
        Logger.warning('Failed to refresh metadata for: $filename');
        return false;
      }
    } catch (e) {
      Logger.error('Error refreshing metadata for: $filename', e);
      return false;
    }
  }
  
  // Extract detailed info directly from the file (bypassing cache)
  Future<Map<String, dynamic>> extractDetailedInfoFromFile() async {
    try {
      final metadataService = MetadataService();
      final detailedInfo = await metadataService.extractDetailedAudioInfo(path);
      
      return {
        'file_info': getDetailedInfo(),
        'raw_metadata_god_info': detailedInfo,
        'metadata_extraction_successful': detailedInfo.isNotEmpty,
      };
    } catch (e) {
      Logger.error('Error extracting detailed info from file: $filename', e);
      return {
        'file_info': getDetailedInfo(),
        'error': e.toString(),
      };
    }
  }
  
  // Get detailed file information for debugging
  Map<String, dynamic> getDetailedInfo() {
    return {
      'filename': filename,
      'path': path,
      'size_bytes': fileSize,
      'size_formatted': formattedFileSize,
      'extension': extension,
      'last_modified': lastModified.toIso8601String(),
      'has_metadata': metadata != null,
      'has_duration': hasDuration,
      'has_complete_metadata': hasCompleteMetadata,
      'metadata_provider': metadata?.provider ?? 'none',
      'duration_seconds': metadata?.audioDuration?.inSeconds,
      'duration_formatted': metadata?.audioDuration != null ? metadata!.durationFormatted : 'none',
      'title': metadata?.title ?? 'none',
      'authors': metadata?.authors ?? [],
      'series': metadata?.series ?? 'none',
      'series_position': metadata?.seriesPosition ?? 'none',
      'file_format': metadata?.fileFormat ?? extension.toUpperCase(),
      'year': metadata?.publishedDate ?? 'none',
      'genre': metadata?.categories.isNotEmpty == true ? metadata!.categories.first : 'none',
      'has_cover': metadata?.thumbnailUrl.isNotEmpty ?? false,
      'user_rating': metadata?.userRating ?? 0,
      'is_favorite': metadata?.isFavorite ?? false,
      'bookmarks_count': metadata?.bookmarks.length ?? 0,
      'notes_count': metadata?.notes.length ?? 0,
    };
  }
  
  // Check if this file needs metadata repair
  bool get needsMetadataRepair {
    if (metadata == null) return true;
    
    // Check for critical missing information that should be available
    final issues = <String>[];
    
    if (metadata!.title.isEmpty) issues.add('title');
    if (metadata!.authors.isEmpty) issues.add('authors');
    if (metadata!.audioDuration == null) issues.add('duration');
    
    if (issues.isNotEmpty) {
      Logger.debug('File $filename needs metadata repair for: ${issues.join(", ")}');
      return true;
    }
    
    return false;
  }
  
  // Compare with another AudiobookFile for sorting
  int compareTo(AudiobookFile other) {
    // First compare by series
    final seriesComparison = (metadata?.series ?? '').compareTo(other.metadata?.series ?? '');
    if (seriesComparison != 0) return seriesComparison;
    
    // Then by series position
    final thisPosition = int.tryParse(metadata?.seriesPosition ?? '') ?? 0;
    final otherPosition = int.tryParse(other.metadata?.seriesPosition ?? '') ?? 0;
    final positionComparison = thisPosition.compareTo(otherPosition);
    if (positionComparison != 0) return positionComparison;
    
    // Finally by title
    return displayTitle.compareTo(other.displayTitle);
  }
  
  // Helper method to format duration
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  String toString() {
    return 'AudiobookFile($displayTitle by $displayAuthors${hasDuration ? " - ${metadata!.durationFormatted}" : ""})';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudiobookFile && other.path == path;
  }
  
  @override
  int get hashCode => path.hashCode;
}