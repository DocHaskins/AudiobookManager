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
  
  // Extract metadata using the MetadataService
  Future<AudiobookMetadata?> extractFileMetadata() async {
    try {
      final metadataService = MetadataService();
      // Ensure the service is initialized before usage
      final initialized = await metadataService.initialize();
      if (!initialized) {
        Logger.error('Failed to initialize MetadataService for file: $path');
        // Create basic metadata from filename as fallback
        return _createBasicMetadataFromFilename();
      }
      
      metadata = await metadataService.extractMetadata(path);
      return metadata;
    } catch (e) {
      Logger.error('Error extracting metadata for file: $path', e);
      // Create basic metadata from filename as fallback
      return _createBasicMetadataFromFilename();
    }
  }

  AudiobookMetadata _createBasicMetadataFromFilename() {
    final filename = path_util.basenameWithoutExtension(path);
    
    // Parse book number and title
    final RegExp bookPattern = RegExp(r'Book\s+(\d+)\s*[-:_]\s*(.+)', caseSensitive: false);
    final match = bookPattern.firstMatch(filename);
    
    String title = filename;
    String seriesPosition = '';
    String series = '';
    
    if (match != null && match.groupCount >= 2) {
      seriesPosition = match.group(1) ?? '';
      title = match.group(2) ?? filename;
      
      // Try to extract series from parent folder
      final folder = path_util.basename(path_util.dirname(path));
      if (folder.length > 3) {
        series = folder;
      }
    }
    
    return AudiobookMetadata(
      id: path_util.basename(path),
      title: title,
      authors: [],
      series: series,
      seriesPosition: seriesPosition,
      fileFormat: path_util.extension(path).toLowerCase().replaceFirst('.', '').toUpperCase(),
      provider: 'filename_parser',
    );
  }
  
  // Create from file
  static Future<AudiobookFile?> fromFile(File file) async {
    try {
      final stat = await file.stat();
      
      return AudiobookFile(
        path: file.path,
        lastModified: stat.modified,
        fileSize: stat.size,
      );
    } catch (e) {
      Logger.error('Error creating AudiobookFile from File: ${file.path}', e);
      return null;
    }
  }
}