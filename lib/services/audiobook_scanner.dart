// File: lib/services/audiobook_scanner.dart
import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/storage/user_preferences.dart';

class AudiobookScanner {
  final List<String> _supportedExtensions = [
    '.mp3', '.m4a', '.m4b', '.aac', '.flac', '.ogg', '.wma', '.wav', '.opus'
  ];
  
  // Directories to exclude from scanning
  final List<String> _excludedDirectories = [
    'To - DO',
    'To-DO',
    'ToDo',
    'To_DO',
    'temp',
    'temporary',
    'incomplete',
    'working',
    'in progress',
  ];
  
  // Common patterns for chapter or part indicators in filenames
  final List<RegExp> _chapterPatterns = [
    RegExp(r'^(?:Chapter|Kapitel|Ch)\s*(\d+)', caseSensitive: false),
    RegExp(r'^(\d+)(?:\s*|\.)(?:[ _\-]|$)', caseSensitive: false),
    RegExp(r'^Part\s*(\d+)', caseSensitive: false),
    RegExp(r'^Disc\s*(\d+)', caseSensitive: false),
    RegExp(r'^CD\s*(\d+)', caseSensitive: false),
    RegExp(r'^Track\s*(\d+)', caseSensitive: false),
    RegExp(r'^Book\s+\w+\s+[-\s]+Chapter\s+(\d+)', caseSensitive: false),
    // Patterns for multiple formats like "01 Track 01" or "01_Track_01"
    RegExp(r'^\d+\s*(?:Track|CD|Disc|Chapter|Part)\s*(\d+)', caseSensitive: false),
    // Patterns for "of X - Book name" format (common in series books)
    RegExp(r'^of\s+(\d+)', caseSensitive: false),
  ];
  
  // Patterns to identify book boundaries within a collection
  final List<RegExp> _bookBoundaryPatterns = [
    RegExp(r'^Book\s+(\d+)', caseSensitive: false),
    RegExp(r'^Volume\s+(\d+)', caseSensitive: false),
    RegExp(r'^Part\s+(\d+)', caseSensitive: false),
  ];
  
  // Common prefixes to remove when extracting book title from folder name
  final List<RegExp> _folderPrefixesToRemove = [
    RegExp(r'^[!_\d]+\s*[-_\s]+', caseSensitive: false), // Numbered or marked folders
    RegExp(r'^(?:The|A)\s+', caseSensitive: false), // Articles
  ];
  
  // Use nullable UserPreferences for backward compatibility
  final UserPreferences? _userPreferences;
  
  // Default constructor
  AudiobookScanner({UserPreferences? userPreferences})
    : _userPreferences = userPreferences;
  
  // Getter for supported extensions
  List<String> get supportedExtensions => _supportedExtensions;
  
  // Add or update the excluded directories
  void updateExcludedDirectories(List<String> directories) {
    // Add all directories from the provided list that aren't already in _excludedDirectories
    for (var dir in directories) {
      if (!_excludedDirectories.contains(dir)) {
        _excludedDirectories.add(dir);
      }
    }
  }
  
  // Check if a directory should be excluded from scanning
  bool _shouldExcludeDirectory(String dirPath) {
    final dirName = path_util.basename(dirPath);
    
    // Check against the excluded directories list
    for (var excludedDir in _excludedDirectories) {
      if (dirName.toLowerCase() == excludedDir.toLowerCase()) {
        print('LOG: Skipping excluded directory: $dirPath');
        return true;
      }
    }
    
    return false;
  }
  
  // Check if a file is a supported audiobook format
  bool isAudiobookFile(String filename) {
    String ext = path_util.extension(filename).toLowerCase();
    return _supportedExtensions.contains(ext);
  }
  
  // Detect if a filename is likely a chapter/part of a multi-file audiobook
  bool isLikelyChapter(String filename) {
    String name = path_util.basenameWithoutExtension(filename);
    return _chapterPatterns.any((pattern) => pattern.hasMatch(name));
  }
  
  // Extract chapter number from filename
  int? extractChapterNumber(String filename) {
    String name = path_util.basenameWithoutExtension(filename);
    
    for (var pattern in _chapterPatterns) {
      final match = pattern.firstMatch(name);
      if (match != null && match.groupCount >= 1) {
        try {
          return int.parse(match.group(1)!);
        } catch (e) {
          print('Error parsing chapter number: $e');
        }
      }
    }
    
    // If we couldn't extract a chapter number and the name is just a number,
    // use the whole name as the chapter number
    if (RegExp(r'^\d+$').hasMatch(name)) {
      try {
        return int.parse(name);
      } catch (e) {
        print('Error parsing numeric filename: $e');
      }
    }
    
    return null;
  }
  
  // Extract the common book title from a set of chapter filenames
  String extractBookTitleFromChapters(List<String> filenames, String directoryName) {
    if (filenames.isEmpty) return '';
    
    // First, check if we can use the directory name
    if (directoryName.isNotEmpty) {
      // Remove common prefixes (like numbers) from the folder name
      String cleanedDirName = directoryName;
      for (var pattern in _folderPrefixesToRemove) {
        cleanedDirName = cleanedDirName.replaceFirst(pattern, '');
      }
      
      // Remove common suffixes
      cleanedDirName = cleanedDirName
          .replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '') // Remove parentheses
          .replaceFirst(RegExp(r'\s+(?:Audiobook|Unabridged|Collection|Series)$', caseSensitive: false), '')
          .trim();
      
      if (cleanedDirName.isNotEmpty && 
          !RegExp(r'^(?:audio|audiobooks?|mp3|m4b|files?)$', caseSensitive: false).hasMatch(cleanedDirName)) {
        return cleanedDirName;
      }
    }
    
    // If we can't use the directory name, try to extract from filenames
    
    // Get the first filename as a starting point
    String firstName = path_util.basenameWithoutExtension(filenames.first);
    
    // Remove common chapter patterns
    for (var pattern in _chapterPatterns) {
      firstName = firstName.replaceFirst(pattern, '');
    }
    
    // Try to extract the part after hyphen or colon if present (common format)
    final hyphenMatch = RegExp(r'^\s*[_\-\.]\s*(.*?)(?:\s*[_\-\.]\s*\d+)?$').firstMatch(firstName);
    if (hyphenMatch != null && hyphenMatch.group(1) != null) {
      firstName = hyphenMatch.group(1)!;
    }
    
    // Clean up the remaining text
    String baseTitle = firstName
        .replaceAll(RegExp(r'^\s*[_\-\.]\s*'), '') // Remove leading separators
        .trim();
    
    // If we've stripped everything, just return the original name
    if (baseTitle.isEmpty) {
      baseTitle = path_util.basenameWithoutExtension(filenames.first);
    }
    
    return baseTitle;
  }
  
  // Scan a directory for audiobook files and group them by book/collection
  Future<Map<String, List<AudiobookFile>>> scanAndGroupFiles(String dirPath, {bool? recursive}) async {
    Map<String, List<AudiobookFile>> bookGroups = {};
    
    // First, scan for all audiobook files
    List<AudiobookFile> allFiles = await scanDirectory(dirPath, recursive: recursive);
    
    // Group files by directory first
    Map<String, List<AudiobookFile>> filesByDir = {};
    for (var file in allFiles) {
      String dir = path_util.dirname(file.path);
      filesByDir.putIfAbsent(dir, () => []).add(file);
    }
    
    // Process each directory
    filesByDir.forEach((dir, files) {
      // Skip if there's only one file in the directory
      if (files.length <= 1) {
        String baseName = path_util.basenameWithoutExtension(files.first.path);
        bookGroups[baseName] = files;
        return;
      }
      
      // Get directory name
      final dirName = path_util.basename(dir);
      
      // Check if these are likely chapters of the same book
      bool areChapters = files.any((file) => 
          isLikelyChapter(path_util.basename(file.path)));
      
      if (areChapters) {
        // These files are probably chapters of the same book
        List<String> filePaths = files.map((f) => f.path).toList();
        
        // Try to extract title from directory name, falling back to common elements in filenames
        String bookTitle = extractBookTitleFromChapters(filePaths, dirName);
        
        // Sort files by chapter number
        files.sort((a, b) {
          int? aNum = extractChapterNumber(path_util.basename(a.path));
          int? bNum = extractChapterNumber(path_util.basename(b.path));
          
          if (aNum == null && bNum == null) return 0;
          if (aNum == null) return -1;
          if (bNum == null) return 1;
          return aNum.compareTo(bNum);
        });
        
        bookGroups[bookTitle] = files;
        print('LOG: Grouped ${files.length} files as chapters of book: "$bookTitle"');
      } else {
        // Check if the directory name seems to be a book collection/series
        if (_isLikelySeriesDirectory(dirName)) {
          // Use the directory name as the book title for all files
          for (var file in files) {
            String baseName = path_util.basenameWithoutExtension(file.path);
            
            // Create an entry for each book in the collection
            bookGroups[baseName] = [file];
          }
        } else {
          // Treat each file as a separate audiobook
          for (var file in files) {
            String baseName = path_util.basenameWithoutExtension(file.path);
            bookGroups[baseName] = [file];
          }
        }
      }
    });
    
    return bookGroups;
  }
  
  // Check if a directory name suggests it contains a book series/collection
  bool _isLikelySeriesDirectory(String dirName) {
    return RegExp(r'(?:series|collection|omnibus|trilogy|saga|books|complete)', caseSensitive: false).hasMatch(dirName) ||
           RegExp(r'(?:Book|Volume|Part)\s+\d+', caseSensitive: false).hasMatch(dirName);
  }
  
  // Scan a directory for audiobook files (returns a Future)
  Future<List<AudiobookFile>> scanDirectory(String dirPath, {bool? recursive}) async {
    List<AudiobookFile> results = [];
    
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        print('LOG: Directory does not exist: $dirPath');
        return results;
      }
      
      // Skip this directory if it's in the excluded list
      if (_shouldExcludeDirectory(dirPath)) {
        return results;
      }
      
      // Determine if we should recurse
      bool shouldRecurse = recursive ?? true;
      if (recursive == null && _userPreferences != null) {
        shouldRecurse = await _userPreferences!.getIncludeSubfolders();
      }
      
      print('LOG: Scanning directory: $dirPath (recursive: $shouldRecurse)');
      
      // Save the last scanned directory if preferences are available
      if (_userPreferences != null) {
        await _userPreferences!.saveLastScanDirectory(dirPath);
      }
      
      // Function to check if a file is in an excluded directory
      bool isInExcludedDirectory(String path) {
        final parentDir = path_util.basename(path_util.dirname(path));
        return _excludedDirectories.any((excluded) => 
            parentDir.toLowerCase() == excluded.toLowerCase());
      }
      
      if (shouldRecurse) {
        // If recursive, we need to handle exclusions more carefully
        await for (FileSystemEntity entity in dir.list(recursive: false)) {
          if (entity is Directory) {
            // Skip excluded directories
            if (_shouldExcludeDirectory(entity.path)) {
              print('LOG: Skipping excluded subdirectory: ${entity.path}');
              continue;
            }
            
            // Recursively scan this valid directory
            final subDirResults = await scanDirectory(entity.path, recursive: true);
            results.addAll(subDirResults);
          } else if (entity is File && isAudiobookFile(entity.path)) {
            // Add files directly in this directory
            results.add(AudiobookFile.fromFile(entity));
            print('LOG: Found audiobook file: ${entity.path}');
          }
        }
      } else {
        // Non-recursive mode - simpler since we don't need to check subdirectories
        await for (FileSystemEntity entity in dir.list(recursive: false)) {
          if (entity is File && isAudiobookFile(entity.path)) {
            results.add(AudiobookFile.fromFile(entity));
            print('LOG: Found audiobook file: ${entity.path}');
          }
        }
      }
      
      print('LOG: Found ${results.length} audiobook files in directory: $dirPath');
    } catch (e) {
      print('ERROR: Error scanning directory: $e');
    }
    
    return results;
  }
  
  // Generate a directory listing for debugging
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
            // Check if this is an excluded directory
            if (_shouldExcludeDirectory(entity.path)) {
              buffer.writeln('$indent📁 $name (Excluded)');
              continue;
            }
            
            buffer.writeln('$indent📁 $name');
            if (shouldRecurse) {
              await listDir(entity, '$indent  ');
            }
          } else if (entity is File) {
            try {
              if (isAudiobookFile(entity.path)) {
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
  
  // Scan a directory and return a stream of audiobook files
  Stream<AudiobookFile> scanDirectoryStream(String dirPath, {bool? recursive}) async* {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        return;
      }
      
      // Skip this directory if it's in the excluded list
      if (_shouldExcludeDirectory(dirPath)) {
        return;
      }
      
      // Determine if we should recurse
      bool shouldRecurse = recursive ?? true;
      if (recursive == null && _userPreferences != null) {
        shouldRecurse = await _userPreferences!.getIncludeSubfolders();
      }
      
      // Save the last scanned directory if preferences are available
      if (_userPreferences != null) {
        await _userPreferences!.saveLastScanDirectory(dirPath);
      }
      
      // Handle recursion and exclusions for streaming
      if (shouldRecurse) {
        await for (FileSystemEntity entity in dir.list(recursive: false)) {
          if (entity is Directory) {
            // Skip excluded directories
            if (_shouldExcludeDirectory(entity.path)) {
              continue;
            }
            
            // Create a stream for this subdirectory and yield* from it
            Stream<AudiobookFile> subStream = scanDirectoryStream(entity.path, recursive: true);
            await for (var file in subStream) {
              yield file;
            }
          } else if (entity is File && isAudiobookFile(entity.path)) {
            yield AudiobookFile.fromFile(entity);
          }
        }
      } else {
        await for (FileSystemEntity entity in dir.list(recursive: false)) {
          if (entity is File && isAudiobookFile(entity.path)) {
            yield AudiobookFile.fromFile(entity);
          }
        }
      }
    } catch (e) {
      print('ERROR: Error scanning directory stream: $e');
    }
  }
  
  // Get a count of audiobook files in a directory (faster than scanning for full details)
  Future<int> countAudiobooksInDirectory(String dirPath, {bool? recursive}) async {
    int count = 0;
    
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        return count;
      }
      
      // Skip this directory if it's in the excluded list
      if (_shouldExcludeDirectory(dirPath)) {
        return 0;
      }
      
      // Determine if we should recurse
      bool shouldRecurse = recursive ?? true;
      if (recursive == null && _userPreferences != null) {
        shouldRecurse = await _userPreferences!.getIncludeSubfolders();
      }
      
      if (shouldRecurse) {
        await for (FileSystemEntity entity in dir.list(recursive: false)) {
          if (entity is Directory) {
            // Skip excluded directories
            if (_shouldExcludeDirectory(entity.path)) {
              continue;
            }
            
            // Count files in subdirectory
            count += await countAudiobooksInDirectory(entity.path, recursive: true);
          } else if (entity is File && isAudiobookFile(entity.path)) {
            count++;
          }
        }
      } else {
        await for (FileSystemEntity entity in dir.list(recursive: false)) {
          if (entity is File && isAudiobookFile(entity.path)) {
            count++;
          }
        }
      }
    } catch (e) {
      print('ERROR: Error counting audiobooks in directory: $e');
    }
    
    return count;
  }
}