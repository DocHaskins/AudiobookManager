// File: lib/services/audiobook_organizer.dart
import 'dart:io';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// Service for organizing audiobook files based on metadata
class AudiobookOrganizer {
  // Pattern component constants
  static const String titlePattern = '{Title}';
  static const String authorPattern = '{Author}';
  static const String authorsPattern = '{Authors}';
  static const String yearPattern = '{Year}';
  static const String publisherPattern = '{Publisher}';
  static const String seriesPattern = '{Series}';
  static const String seriesPositionPattern = '{SeriesPosition}';
  
  // Common series formatting patterns
  static const List<String> seriesFormattingPatterns = [
    '{Series} {SeriesPosition} - ',
    '{Series} - ',
    '{Series} {SeriesPosition}',
    '{Series}'
  ];
  
  // Invalid filename characters regex
  static final RegExp _invalidCharsRegex = RegExp(r'[<>:"/\\|?*]');
  static final RegExp _multipleSpacesRegex = RegExp(r'\s+');
  static final RegExp _multipleDashesRegex = RegExp(r'--+');
  static final RegExp _multipleUnderscoresRegex = RegExp(r'__+');
  static final RegExp _spacedDashesRegex = RegExp(r'\s*-\s*-\s*');
  
  /// Generate a new filename based on a pattern and metadata
  String generateNewFilename(AudiobookFile file, String pattern) {
    try {
      if (file.metadata == null) {
        Logger.warning('No metadata available for file: ${file.filename}');
        return file.filename + file.extension;
      }
      
      // Replace pattern variables with metadata values
      String newName = pattern
        .replaceAll(titlePattern, file.metadata!.title)
        .replaceAll(authorPattern, file.metadata!.primaryAuthor)
        .replaceAll(authorsPattern, file.metadata!.authorsFormatted)
        .replaceAll(yearPattern, file.metadata!.year)
        .replaceAll(publisherPattern, file.metadata!.publisher);
        
      // Handle series information if available
      if (file.metadata!.series.isNotEmpty) {
        newName = newName.replaceAll(seriesPattern, file.metadata!.series);
        
        // Only include series position if it's available
        if (file.metadata!.seriesPosition.isNotEmpty) {
          newName = newName.replaceAll(seriesPositionPattern, file.metadata!.seriesPosition);
        } else {
          // Remove the series position placeholder and any surrounding formatting
          newName = newName
            .replaceAll(' $seriesPositionPattern', '')
            .replaceAll('$seriesPositionPattern ', '')
            .replaceAll(seriesPositionPattern, '');
        }
      } else {
        // Remove series and position placeholders and clean up formatting
        for (final pattern in seriesFormattingPatterns) {
          newName = newName.replaceAll(pattern, '');
        }
        newName = newName.replaceAll(seriesPositionPattern, '');
      }
      
      // Clean the filename
      newName = _cleanFilename(newName);
      
      return '$newName${file.extension}';
    } catch (e) {
      Logger.error('Error generating new filename', e);
      return file.filename + file.extension;
    }
  }
  
  /// Helper method to clean a filename
  String _cleanFilename(String filename) {
    return filename
      .replaceAll(_invalidCharsRegex, '_') // Remove invalid file characters
      .replaceAll(_multipleSpacesRegex, ' ') // Normalize whitespace
      .replaceAll(_multipleDashesRegex, '-') // Fix multiple dashes
      .replaceAll(_multipleUnderscoresRegex, '_') // Fix multiple underscores
      .replaceAll(_spacedDashesRegex, ' - ') // Fix spaced dashes
      .trim();
  }
  
  /// Rename a file
  Future<bool> renameFile(AudiobookFile file, String newName) async {
    try {
      final oldFile = File(file.path);
      if (!await oldFile.exists()) {
        Logger.warning('File does not exist: ${file.path}');
        return false;
      }
      
      final directory = path_util.dirname(file.path);
      final newPath = path_util.join(directory, newName);
      
      Logger.log('Renaming file: ${file.path} to $newPath');
      await oldFile.rename(newPath);
      Logger.log('Successfully renamed file');
      return true;
    } catch (e) {
      Logger.error('Error renaming file', e);
      return false;
    }
  }
  
  /// Move a file to a new location
  Future<bool> moveFile(AudiobookFile file, String destinationPath) async {
    try {
      final oldFile = File(file.path);
      if (!await oldFile.exists()) {
        Logger.warning('File does not exist: ${file.path}');
        return false;
      }
      
      final fileName = path_util.basename(file.path);
      final newPath = path_util.join(destinationPath, fileName);
      
      // Create the destination directory if it doesn't exist
      final destDir = Directory(destinationPath);
      if (!await destDir.exists()) {
        Logger.debug('Creating destination directory: $destinationPath');
        await destDir.create(recursive: true);
      }
      
      // Move the file
      Logger.log('Moving file: ${file.path} to $newPath');
      await oldFile.copy(newPath);
      await oldFile.delete();
      Logger.log('Successfully moved file');
      return true;
    } catch (e) {
      Logger.error('Error moving file', e);
      return false;
    }
  }
  
  /// Move and rename a file
  Future<bool> moveAndRenameFile(AudiobookFile file, String destinationPath, String newName) async {
    try {
      final oldFile = File(file.path);
      if (!await oldFile.exists()) {
        Logger.warning('File does not exist: ${file.path}');
        return false;
      }
      
      // Create the destination directory if it doesn't exist
      final destDir = Directory(destinationPath);
      if (!await destDir.exists()) {
        Logger.debug('Creating destination directory: $destinationPath');
        await destDir.create(recursive: true);
      }
      
      final newPath = path_util.join(destinationPath, newName);
      
      Logger.log('Moving and renaming file: ${file.path} to $newPath');
      await oldFile.copy(newPath);
      await oldFile.delete();
      Logger.log('Successfully moved and renamed file');
      return true;
    } catch (e) {
      Logger.error('Error moving and renaming file', e);
      return false;
    }
  }
  
  /// Batch organize multiple files
  Future<List<AudiobookFile>> batchOrganize(
    List<AudiobookFile> files,
    String destinationPath,
    String pattern,
  ) async {
    List<AudiobookFile> successfullyOrganized = [];
    
    Logger.log('Starting batch organization of ${files.length} files to $destinationPath');
    
    for (final file in files) {
      if (file.metadata == null) {
        Logger.warning('Skipping file without metadata: ${file.filename}');
        continue;
      }
      
      try {
        // Generate new filename
        final newFilename = generateNewFilename(file, pattern);
        
        // Create destination path (may include subdirectories based on metadata)
        String targetDir = destinationPath;
        
        // Ensure directory exists
        final destDir = Directory(targetDir);
        if (!await destDir.exists()) {
          Logger.debug('Creating destination directory: $targetDir');
          await destDir.create(recursive: true);
        }
        
        // Move and rename the file
        final oldFile = File(file.path);
        final newPath = path_util.join(targetDir, newFilename);
        
        Logger.debug('Organizing file: ${file.path} to $newPath');
        await oldFile.copy(newPath);
        await oldFile.delete();
        
        successfullyOrganized.add(file);
      } catch (e) {
        Logger.error('Error organizing file ${file.filename}', e);
      }
    }
    
    Logger.log('Successfully organized ${successfullyOrganized.length} out of ${files.length} files');
    
    return successfullyOrganized;
  }
  
  /// Organize files with optional custom directory structure
  Future<List<AudiobookFile>> organizeWithStructure(
    List<AudiobookFile> files,
    String baseDestinationPath,
    String filenamePattern,
    String? directoryPattern,
  ) async {
    List<AudiobookFile> successfullyOrganized = [];
    
    Logger.log('Starting organization with custom structure for ${files.length} files');
    
    for (final file in files) {
      if (file.metadata == null) {
        Logger.warning('Skipping file without metadata: ${file.filename}');
        continue;
      }
      
      try {
        // Generate new filename
        final newFilename = generateNewFilename(file, filenamePattern);
        
        // Create destination path (may include subdirectories based on metadata)
        String targetDir = baseDestinationPath;
        
        // If a directory pattern is provided, use it to create custom folder structure
        if (directoryPattern != null && directoryPattern.isNotEmpty) {
          final customDirPath = generateNewFilename(file, directoryPattern)
            .split(path_util.separator)
            .where((segment) => segment.isNotEmpty)
            .join(path_util.separator);
            
          targetDir = path_util.join(baseDestinationPath, customDirPath);
        }
        
        // Ensure directory exists
        final destDir = Directory(targetDir);
        if (!await destDir.exists()) {
          Logger.debug('Creating directory structure: $targetDir');
          await destDir.create(recursive: true);
        }
        
        // Move and rename the file
        final oldFile = File(file.path);
        final newPath = path_util.join(targetDir, newFilename);
        
        Logger.debug('Organizing file with structure: ${file.path} to $newPath');
        await oldFile.copy(newPath);
        await oldFile.delete();
        
        successfullyOrganized.add(file);
      } catch (e) {
        Logger.error('Error organizing file with structure: ${file.filename}', e);
      }
    }
    
    Logger.log('Successfully organized ${successfullyOrganized.length} out of ${files.length} files with custom structure');
    
    return successfullyOrganized;
  }
  
  /// Organize a collection of audiobooks
  Future<bool> organizeCollection(
    AudiobookCollection collection,
    String destinationPath,
    String pattern,
  ) async {
    if (collection.files.isEmpty) {
      Logger.warning('Collection has no files to organize: ${collection.title}');
      return false;
    }
    
    try {
      Logger.log('Organizing collection: ${collection.title} with ${collection.files.length} files');
      
      // Create a directory for the collection
      final collectionDir = path_util.join(
        destinationPath, 
        _cleanFilename(collection.displayName)
      );
      
      final dir = Directory(collectionDir);
      if (!await dir.exists()) {
        Logger.debug('Creating collection directory: $collectionDir');
        await dir.create(recursive: true);
      }
      
      // Organize each file in the collection
      int successCount = 0;
      for (final file in collection.files) {
        final newFilename = generateNewFilename(file, pattern);
        final oldFile = File(file.path);
        final newPath = path_util.join(collectionDir, newFilename);
        
        try {
          Logger.debug('Moving file in collection: ${file.path} to $newPath');
          await oldFile.copy(newPath);
          await oldFile.delete();
          successCount++;
        } catch (e) {
          Logger.error('Error moving file in collection', e);
        }
      }
      
      Logger.log('Successfully organized $successCount out of ${collection.files.length} files in collection');
      
      return successCount > 0;
    } catch (e) {
      Logger.error('Error organizing collection', e);
      return false;
    }
  }
}