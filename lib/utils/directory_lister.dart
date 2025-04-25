// File: lib/utils/directory_lister.dart
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/services/audiobook_scanner.dart';

/// Utility class to list directory contents for debugging purposes
class DirectoryLister {
  final AudiobookScanner _scanner;
  
  DirectoryLister(this._scanner);
  
  /// Generate a text representation of the directory structure
  Future<String> generateDirectoryListing(String dirPath, {bool? recursive}) async {
    StringBuffer buffer = StringBuffer();
    
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        return 'Directory does not exist: $dirPath';
      }
      
      bool shouldRecurse = recursive ?? true;
      buffer.writeln('Directory listing for: $dirPath (recursive: $shouldRecurse)\n');
      
      // Use a local recursive function to print the directory tree
      Future<void> listDir(Directory dir, String indent) async {
        List<FileSystemEntity> entities = await dir.list().toList();
        
        // Sort: directories first, then files
        entities.sort((a, b) {
          bool aIsDir = a is Directory;
          bool bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return path_util.basename(a.path).compareTo(path_util.basename(b.path));
        });
        
        for (var entity in entities) {
          String name = path_util.basename(entity.path);
          
          if (entity is Directory) {
            buffer.writeln('$indent📁 $name');
            if (shouldRecurse) {
              await listDir(entity, '$indent  ');
            }
          } else if (entity is File) {
            try {
              if (_scanner.isAudiobookFile(entity.path)) {
                String size = (await entity.length() / (1024 * 1024)).toStringAsFixed(2) + ' MB';
                String modified = entity.lastModifiedSync().toString().split('.')[0];
                buffer.writeln('$indent🔊 $name ($size, $modified)');
              } else {
                buffer.writeln('$indent📄 $name');
              }
            } catch (e) {
              buffer.writeln('$indent⚠️ $name (Error: $e)');
            }
          }
        }
      }
      
      await listDir(dir, '');
      
    } catch (e) {
      buffer.writeln('Error generating directory listing: $e');
    }
    
    return buffer.toString();
  }
  
  /// Save the directory listing to a file
  Future<File> saveDirectoryListingToFile(String dirPath, String outputPath, {bool? recursive}) async {
    final listing = await generateDirectoryListing(dirPath, recursive: recursive);
    final file = File(outputPath);
    return await file.writeAsString(listing);
  }
  
  /// Generate a list of audiobooks in the directory with grouping information
  Future<String> generateAudiobookReport(String dirPath, {bool? recursive}) async {
    StringBuffer buffer = StringBuffer();
    
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        return 'Directory does not exist: $dirPath';
      }
      
      bool shouldRecurse = recursive ?? true;
      buffer.writeln('Audiobook Report for: $dirPath (recursive: $shouldRecurse)\n');
      buffer.writeln('Generated: ${DateTime.now()}\n');
      
      // Scan and group files
      final fileGroups = await _scanner.scanAndGroupFiles(dirPath, recursive: shouldRecurse);
      
      buffer.writeln('Found ${fileGroups.length} audiobooks/collections:\n');
      
      // List each book/collection
      int bookNum = 1;
      fileGroups.forEach((title, files) {
        buffer.writeln('$bookNum. 📚 $title');
        buffer.writeln('   📁 ${path_util.dirname(files.first.path)}');
        buffer.writeln('   📊 ${files.length} file(s), ${(files.fold<int>(0, (sum, file) => sum + file.size) / (1024 * 1024)).toStringAsFixed(2)} MB total');
        
        // List files in the collection
        if (files.length > 1) {
          buffer.writeln('   Files:');
          for (var i = 0; i < files.length; i++) {
            var file = files[i];
            buffer.writeln('      ${i+1}. ${path_util.basename(file.path)} (${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB)');
          }
        }
        
        buffer.writeln('');
        bookNum++;
      });
      
    } catch (e) {
      buffer.writeln('Error generating audiobook report: $e');
    }
    
    return buffer.toString();
  }
  
  /// Save the audiobook report to a file
  Future<File> saveAudiobookReportToFile(String dirPath, String outputPath, {bool? recursive}) async {
    final report = await generateAudiobookReport(dirPath, recursive: recursive);
    final file = File(outputPath);
    return await file.writeAsString(report);
  }
}