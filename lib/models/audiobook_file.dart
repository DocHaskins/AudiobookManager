// File: lib/models/audiobook_file.dart
import 'dart:io';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/audio_metadata_extractor.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/filename_parser.dart';
import 'package:audiobook_organizer/utils/metadata_manager.dart';

/// Represents an audiobook file in the system
class AudiobookFile {
  // File properties
  final String path;
  final String filename;
  final String extension;
  final int size;
  final DateTime lastModified;
  
  // Metadata properties
  AudiobookMetadata? metadata;      // Online or combined metadata
  AudiobookMetadata? fileMetadata;  // Metadata extracted directly from the file
  bool _fileMetadataAttempted = false; // Flag to track if we've tried extracting file metadata

  /// Constructor requiring basic file properties
  AudiobookFile({
    required this.path,
    required this.filename,
    required this.extension,
    required this.size,
    required this.lastModified,
    this.metadata,
    this.fileMetadata,
  });

  /// Create an AudiobookFile from a File object
  factory AudiobookFile.fromFile(File file) {
    // Create local variables for the values
    final filePath = file.path;
    final fileBasename = path_util.basenameWithoutExtension(filePath);
    final fileExtension = path_util.extension(filePath).toLowerCase();
    final fileSize = file.lengthSync();
    final fileLastModified = file.lastModifiedSync();
    
    return AudiobookFile(
      path: filePath,
      filename: fileBasename,
      extension: fileExtension,
      size: fileSize,
      lastModified: fileLastModified,
    );
  }
  
  // Basic getters
  bool get hasMetadata => metadata != null;
  bool get hasFileMetadata => fileMetadata != null;
  bool get hasAnyMetadata => metadata != null || fileMetadata != null;
  String get fullPath => path;
  
  /// Get the display name using metadata or cleaned filename
  String get displayName {
    return MetadataManager.getStringWithPriority(
      metadata,
      fileMetadata,
      (meta) => meta.title,
      FilenameParser.cleanForDisplay(filename),
    );
  }
  
  /// Get the author using metadata or extracted from filename
  String get author {
    return MetadataManager.getAuthor(
      metadata,
      fileMetadata,
      FilenameParser.extractAuthor(filename, path),
    );
  }
  
  /// Get the series information from metadata
  String get series {
    return MetadataManager.getStringWithPriority(
      metadata,
      fileMetadata,
      (meta) => meta.series,
      '',
    );
  }
  
  /// Get the series position information from metadata
  String get seriesPosition {
    return MetadataManager.getStringWithPriority(
      metadata, 
      fileMetadata,
      (meta) => meta.seriesPosition,
      '',
    );
  }
  
  /// Check if metadata is complete enough for library view
  bool get hasCompleteMetadata {
    return MetadataManager.isMetadataComplete(metadata) || 
           MetadataManager.isMetadataComplete(fileMetadata);
  }
  
  /// Identify files that need metadata review
  bool get needsMetadataReview {
    // Check for complete metadata using MetadataManager
    return !MetadataManager.isMetadataComplete(metadata) && 
          !MetadataManager.isMetadataComplete(fileMetadata);
  }

  /// Extract metadata from the file
  Future<AudiobookMetadata?> extractFileMetadata() async {
    // If we already have file metadata or tried to extract it before, return what we have
    if (_fileMetadataAttempted) return fileMetadata;
    
    _fileMetadataAttempted = true;
    
    final extractor = AudioMetadataExtractor();
    if (!extractor.isSupported(path)) {
      Logger.warning('File format not supported for metadata extraction: $path');
      return null;
    }
    
    try {
      fileMetadata = await extractor.extractMetadata(path);
      if (fileMetadata != null) {
        Logger.log('Successfully extracted metadata from file: $path');
      } else {
        Logger.debug('No metadata found in file: $path');
      }
      return fileMetadata;
    } catch (e) {
      Logger.error('Error extracting file metadata', e);
      return null;
    }
  }
  
  /// Write metadata back to the file
  Future<bool> writeMetadataToFile(AudiobookMetadata metadataToWrite) async {
    try {
      final extractor = AudioMetadataExtractor();
      final success = await extractor.writeMetadataToFile(path, metadataToWrite);
      
      if (success) {
        // Update our own metadata references
        fileMetadata = metadataToWrite;
        if (metadata == null) {
          metadata = metadataToWrite;
        }
        Logger.log('Successfully wrote metadata to file: $path');
      } else {
        Logger.warning('Failed to write metadata to file: $path');
      }
      
      return success;
    } catch (e) {
      Logger.error('Error writing metadata to file', e);
      return false;
    }
  }

  /// Extract potential title and author from filename
  Map<String, String> parseFilename() {
    final parsed = FilenameParser.parse(filename, path);
    
    // Convert to map for backward compatibility
    Map<String, String> result = {};
    
    if (parsed.title.isNotEmpty) {
      result['title'] = parsed.title;
    }
    
    if (parsed.hasAuthor) {
      result['author'] = parsed.author!;
    }
    
    if (parsed.hasSeries) {
      result['series'] = parsed.series!;
    }
    
    if (parsed.seriesPosition != null && parsed.seriesPosition!.isNotEmpty) {
      result['seriesPosition'] = parsed.seriesPosition!;
    }
    
    return result;
  }

  /// Generate a search query for online metadata
  String generateSearchQuery() {
    // First try to use file metadata if available
    if (fileMetadata != null) {
      List<String> queryParts = [];
      
      if (fileMetadata!.title.isNotEmpty) {
        queryParts.add(fileMetadata!.title);
      }
      
      if (fileMetadata!.authors.isNotEmpty) {
        queryParts.add(fileMetadata!.authors.join(' '));
      }
      
      if (fileMetadata!.series.isNotEmpty) {
        queryParts.add(fileMetadata!.series);
      }
      
      if (queryParts.isNotEmpty) {
        final query = queryParts.join(' ');
        Logger.debug('Generated search query from file metadata: $query');
        return query;
      }
    }
    
    // Fall back to filename parsing if file metadata is unavailable
    final parsed = FilenameParser.parse(filename, path);
    return FilenameParser.generateSearchQuery(parsed);
  }
}