import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:audiobook_organizer/models/audiobook_file.dart';

class AudiobookOrganizer {
  // Generate a new filename based on a pattern and metadata
  String generateNewFilename(AudiobookFile file, String pattern) {
    if (file.metadata == null) return file.filename + file.extension;
    
    // Replace pattern variables with metadata values
    String newName = pattern
      .replaceAll('{Title}', file.metadata!.title)
      .replaceAll('{Author}', file.metadata!.primaryAuthor)
      .replaceAll('{Authors}', file.metadata!.authorsFormatted)
      .replaceAll('{Year}', file.metadata!.year)
      .replaceAll('{Publisher}', file.metadata!.publisher);
      
    // Handle series information if available
    if (file.metadata!.series.isNotEmpty) {
      newName = newName.replaceAll('{Series}', file.metadata!.series);
      
      // Only include series position if it's available
      if (file.metadata!.seriesPosition.isNotEmpty) {
        newName = newName.replaceAll('{SeriesPosition}', file.metadata!.seriesPosition);
      } else {
        // Remove the series position placeholder and any surrounding formatting
        newName = newName
          .replaceAll(' {SeriesPosition}', '')
          .replaceAll('{SeriesPosition} ', '')
          .replaceAll('{SeriesPosition}', '');
      }
    } else {
      // Remove series and position placeholders and clean up formatting
      newName = newName
        .replaceAll('{Series} {SeriesPosition} - ', '')
        .replaceAll('{Series} - ', '')
        .replaceAll('{Series} {SeriesPosition}', '')
        .replaceAll('{Series}', '')
        .replaceAll('{SeriesPosition}', '');
    }
    
    // Clean the filename
    newName = newName
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_') // Remove invalid file characters
      .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
      .replaceAll(RegExp(r'--+'), '-') // Fix multiple dashes
      .replaceAll(RegExp(r'__+'), '_') // Fix multiple underscores
      .replaceAll(RegExp(r'\s*-\s*-\s*'), ' - ') // Fix spaced dashes
      .trim();
    
    return '$newName${file.extension}';
  }
  
  // Rename a file
  Future<bool> renameFile(AudiobookFile file, String newName) async {
    try {
      final oldFile = File(file.path);
      if (!await oldFile.exists()) {
        return false;
      }
      
      final directory = path.dirname(file.path);
      final newPath = path.join(directory, newName);
      
      await oldFile.rename(newPath);
      return true;
    } catch (e) {
      print('Error renaming file: $e');
      return false;
    }
  }
  
  // Move a file to a new location
  Future<bool> moveFile(AudiobookFile file, String destinationPath) async {
    try {
      final oldFile = File(file.path);
      if (!await oldFile.exists()) {
        return false;
      }
      
      final fileName = path.basename(file.path);
      final newPath = path.join(destinationPath, fileName);
      
      // Create the destination directory if it doesn't exist
      final destDir = Directory(destinationPath);
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }
      
      // Move the file
      await oldFile.copy(newPath);
      await oldFile.delete();
      return true;
    } catch (e) {
      print('Error moving file: $e');
      return false;
    }
  }
  
  // Batch organize multiple files
  Future<List<AudiobookFile>> batchOrganize(
    List<AudiobookFile> files,
    String destinationPath,
    String pattern,
  ) async {
    List<AudiobookFile> successfullyOrganized = [];
    
    for (final file in files) {
      if (file.metadata == null) continue;
      
      try {
        // Generate new filename
        final newFilename = generateNewFilename(file, pattern);
        
        // Create destination path (may include subdirectories based on metadata)
        String targetDir = destinationPath;
        
        // Ensure directory exists
        final destDir = Directory(targetDir);
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }
        
        // Move and rename the file
        final oldFile = File(file.path);
        final newPath = path.join(targetDir, newFilename);
        await oldFile.copy(newPath);
        await oldFile.delete();
        
        successfullyOrganized.add(file);
      } catch (e) {
        print('Error organizing file ${file.filename}: $e');
      }
    }
    
    return successfullyOrganized;
  }
}