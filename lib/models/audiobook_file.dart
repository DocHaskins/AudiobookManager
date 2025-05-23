// lib/models/audiobook_file.dart
import 'dart:io';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
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