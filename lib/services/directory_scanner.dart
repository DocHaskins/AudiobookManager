import 'dart:io';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class DirectoryScanner {
  final List<String> _audioExtensions = ['.mp3', '.m4a', '.m4b', '.aac', '.ogg', '.wma', '.flac', '.opus'];
  
  // Scan a directory for audiobook files
  Future<List<AudiobookFile>> scanDirectory(String directoryPath) async {
    final List<AudiobookFile> files = [];
    
    try {
      Logger.log('Scanning directory: $directoryPath');
      
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        Logger.error('Directory does not exist: $directoryPath');
        return [];
      }
      
      // List all files in the directory and subdirectories
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final extension = path_util.extension(entity.path).toLowerCase();
          if (_audioExtensions.contains(extension)) {
            final audioFile = await AudiobookFile.fromFile(entity);
            if (audioFile != null) {
              files.add(audioFile);
              Logger.debug('Found audiobook file: ${entity.path}');
            }
          }
        }
      }
      
      Logger.log('Found ${files.length} audiobook files in directory: $directoryPath');
      return files;
    } catch (e) {
      Logger.error('Error scanning directory: $directoryPath', e);
      return [];
    }
  }
  
  // Group files by folder (useful for series detection)
  Map<String, List<AudiobookFile>> groupFilesByFolder(List<AudiobookFile> files) {
    final Map<String, List<AudiobookFile>> groupedFiles = {};
    
    for (final file in files) {
      final folder = path_util.dirname(file.path);
      if (!groupedFiles.containsKey(folder)) {
        groupedFiles[folder] = [];
      }
      groupedFiles[folder]!.add(file);
    }
    
    return groupedFiles;
  }
  
  // Sort files by series and number (useful for ordered presentation)
  List<AudiobookFile> sortFilesBySeriesAndNumber(List<AudiobookFile> files) {
    // Create a copy of the list to avoid modifying the original
    final sortedFiles = List<AudiobookFile>.from(files);
    
    // Sort by series and then by series position
    sortedFiles.sort((a, b) {
      // Compare series
      final seriesComparison = (a.metadata?.series ?? '')
          .compareTo(b.metadata?.series ?? '');
      
      if (seriesComparison != 0) {
        return seriesComparison;
      }
      
      // Compare series position if series is the same
      final aPos = int.tryParse(a.metadata?.seriesPosition ?? '') ?? 0;
      final bPos = int.tryParse(b.metadata?.seriesPosition ?? '') ?? 0;
      
      return aPos.compareTo(bPos);
    });
    
    return sortedFiles;
  }
}