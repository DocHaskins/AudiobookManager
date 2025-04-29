// File: lib/services/audiobook_scanner.dart
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/storage/user_preferences.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/metadata_manager.dart';

/// Service for scanning directories and finding audiobook files
class AudiobookScanner {
  // Static constants for supported file formats
  static final List<String> _supportedExtensions = [
    '.mp3', '.m4a', '.m4b', '.aac', '.flac', '.ogg', '.wma', '.wav', '.opus'
  ];
  
  // Static constants for directories to exclude from scanning
  static final List<String> _defaultExcludedDirectories = [
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
  
  // Actual list of excluded directories (can be modified at runtime)
  final List<String> _excludedDirectories = [..._defaultExcludedDirectories];
  
  // Static RegExp patterns for chapter identification
  static final List<RegExp> _chapterPatterns = [
    RegExp(r'^(?:Chapter|Kapitel|Ch)\s*(\d+)', caseSensitive: false),
    RegExp(r'^(\d+)(?:\s*|\.)(?:[ _\-]|$)', caseSensitive: false),
    RegExp(r'^Part\s*(\d+)', caseSensitive: false),
    RegExp(r'^Disc\s*(\d+)', caseSensitive: false),
    RegExp(r'^CD\s*(\d+)', caseSensitive: false),
    RegExp(r'^Track\s*(\d+)', caseSensitive: false),
    RegExp(r'^Book\s+\w+\s+[-\s]+Chapter\s+(\d+)', caseSensitive: false),
    RegExp(r'^\d+\s*(?:Track|CD|Disc|Chapter|Part)\s*(\d+)', caseSensitive: false),
    RegExp(r'^of\s+(\d+)', caseSensitive: false),
  ];
  
  // Pattern for cleaning directory names
  static final List<RegExp> _folderPrefixPatterns = [
    RegExp(r'^[!_\d]+\s*[-_\s]+', caseSensitive: false), // Numbered or marked folders
    RegExp(r'^(?:The|A)\s+', caseSensitive: false), // Articles
  ];
  
  // Use nullable UserPreferences for backward compatibility
  final UserPreferences? _userPreferences;
  
  // Optional metadata matcher
  final MetadataMatcher? metadataMatcher;
  
  /// Default constructor
  AudiobookScanner({
    UserPreferences? userPreferences,
    this.metadataMatcher
  }) : _userPreferences = userPreferences {
    Logger.log('AudiobookScanner initialized');
  }
  
  /// Getter for supported extensions
  List<String> get supportedExtensions => _supportedExtensions;
  
  /// Add or update the excluded directories
  void updateExcludedDirectories(List<String> directories) {
    // Add all directories from the provided list that aren't already in _excludedDirectories
    for (var dir in directories) {
      if (!_excludedDirectories.contains(dir)) {
        _excludedDirectories.add(dir);
        Logger.debug('Added directory to exclusion list: $dir');
      }
    }
  }
  
  /// Check if a directory should be excluded from scanning
  bool _shouldExcludeDirectory(String dirPath) {
    try {
      final dirName = path_util.basename(dirPath);
      
      // Check against the excluded directories list
      for (var excludedDir in _excludedDirectories) {
        if (dirName.toLowerCase() == excludedDir.toLowerCase()) {
          Logger.debug('Skipping excluded directory: $dirPath');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      Logger.error('Error checking directory exclusion', e);
      return false;
    }
  }
  
  /// Check if a file is a supported audiobook format
  bool isAudiobookFile(String filename) {
    String ext = path_util.extension(filename).toLowerCase();
    return _supportedExtensions.contains(ext);
  }
  
  /// Detect if a filename is likely a chapter/part of a multi-file audiobook
  bool isLikelyChapter(String filename) {
    try {
      String name = path_util.basenameWithoutExtension(filename);
      return _chapterPatterns.any((pattern) => pattern.hasMatch(name));
    } catch (e) {
      Logger.error('Error checking if file is a chapter', e);
      return false;
    }
  }
  
  /// Extract chapter number from filename
  int? extractChapterNumber(String filename) {
    try {
      String name = path_util.basenameWithoutExtension(filename);
      
      // Try to match against chapter patterns
      for (var pattern in _chapterPatterns) {
        final match = pattern.firstMatch(name);
        if (match != null && match.groupCount >= 1) {
          try {
            return int.parse(match.group(1)!);
          } catch (e) {
            Logger.debug('Could not parse chapter number: ${match.group(1)}');
          }
        }
      }
      
      // If we couldn't extract a chapter number and the name is just a number,
      // use the whole name as the chapter number
      if (RegExp(r'^\d+$').hasMatch(name)) {
        try {
          return int.parse(name);
        } catch (e) {
          Logger.debug('Could not parse numeric filename: $name');
        }
      }
      
      return null;
    } catch (e) {
      Logger.error('Error extracting chapter number', e);
      return null;
    }
  }
  
  /// Scan for files with complete metadata (for Library view)
  /// [matchOnline] parameter controls when online matching happens
  Future<Map<String, List<AudiobookFile>>> scanForLibraryView(
    String dirPath, 
    {bool? recursive, bool matchOnline = true} // Set default to true
  ) async {
    Map<String, List<AudiobookFile>> completeBooks = {};
    
    try {
      // Get all audiobook files
      List<AudiobookFile> allFiles = await scanDirectory(dirPath, recursive: recursive);
      
      // First, extract metadata from all files
      Logger.log('Extracting file metadata for ${allFiles.length} files');
      for (var file in allFiles) {
        await file.extractFileMetadata();
      }
      
      // Always try to match with online metadata by default
      if (matchOnline && metadataMatcher != null) {
        Logger.log('Looking up online metadata for files');
        for (var file in allFiles) {
          if (!file.hasCompleteMetadata) {
            await metadataMatcher!.matchFile(file);
          }
        }
      }
      
      // Group files by metadata
      for (var file in allFiles) {
        // Debug log to see why files aren't being included
        if (file.hasCompleteMetadata) {
          Logger.log('File has complete metadata: ${file.path}');
          final meta = file.metadata ?? file.fileMetadata!;
          
          // Group by series+title or just title
          final key = meta.series.isNotEmpty ? '${meta.series} - ${meta.title}' : meta.title;
          completeBooks.putIfAbsent(key, () => []).add(file);
        } else {
          Logger.log('File still needs metadata: ${file.path}');
          // Debug what's missing
          if (file.metadata != null) {
            final meta = file.metadata!;
            Logger.log('Online metadata: title=${meta.title.isNotEmpty}, ' +
                      'authors=${meta.authors.isNotEmpty}, ' +
                      'thumbnail=${meta.thumbnailUrl.isNotEmpty}, ' +
                      'desc=${meta.description.isNotEmpty}, ' +
                      'series=${meta.series.isNotEmpty}');
          }
          if (file.fileMetadata != null) {
            final meta = file.fileMetadata!;
            Logger.log('File metadata: title=${meta.title.isNotEmpty}, ' +
                      'authors=${meta.authors.isNotEmpty}, ' +
                      'thumbnail=${meta.thumbnailUrl.isNotEmpty}, ' +
                      'desc=${meta.description.isNotEmpty}, ' +
                      'series=${meta.series.isNotEmpty}');
          }
        }
      }
      
      Logger.log('Found ${completeBooks.length} books with complete metadata');
    } catch (e) {
      Logger.error('Error scanning for library view', e);
    }
    
    return completeBooks;
  }

  /// Helper method to determine which metadata to use (file or online)
  AudiobookMetadata _getPreferredMetadata(AudiobookFile file) {
    // If file has both types of metadata
    if (file.hasFileMetadata && file.hasMetadata) {
      // Use file metadata if it's reasonably complete
      if (MetadataManager.isMetadataComplete(file.fileMetadata)) {
        return file.fileMetadata!;
      } else {
        // Otherwise use online metadata
        return file.metadata!;
      }
    }
    
    // If only one type is available, use whichever is available
    return file.fileMetadata ?? file.metadata!;
  }
  
  /// Get files needing metadata review (for Files view)
  Future<List<AudiobookFile>> scanForFilesView(
    String dirPath, 
    {bool? recursive}
  ) async {
    List<AudiobookFile> incompleteFiles = [];
    
    try {
      // Get all audiobook files
      List<AudiobookFile> allFiles = await scanDirectory(dirPath, recursive: recursive);
      
      // Extract metadata from all files (but don't do online matching yet)
      Logger.log('Extracting metadata for ${allFiles.length} files');
      for (var file in allFiles) {
        await file.extractFileMetadata();
      }
      
      // Filter for files needing metadata review
      for (var file in allFiles) {
        if (!file.hasCompleteMetadata) {
          incompleteFiles.add(file);
        }
      }
      
      Logger.log('Found ${incompleteFiles.length} files needing metadata review');
    } catch (e) {
      Logger.error('Error scanning for files view', e);
    }
    
    return incompleteFiles;
  }
  
  /// Process pending files with online metadata
  Future<int> processFilesWithOnlineMetadata(List<AudiobookFile> files) async {
    if (metadataMatcher == null) return 0;
    
    int processedCount = 0;
    
    try {
      Logger.log('Processing ${files.length} files for online metadata');
      
      for (var file in files) {
        if (!file.hasCompleteMetadata) {
          final metadata = await metadataMatcher!.matchFile(file);
          if (metadata != null) {
            processedCount++;
          }
        }
      }
      
      Logger.log('Successfully processed $processedCount files with online metadata');
    } catch (e) {
      Logger.error('Error processing files with online metadata', e);
    }
    
    return processedCount;
  }
  
  /// Original scan method for backward compatibility
  Future<Map<String, List<AudiobookFile>>> scanAndGroupFiles(
    String dirPath, 
    {bool? recursive}
  ) async {
    Map<String, List<AudiobookFile>> bookGroups = {};
    
    try {
      // First, scan for all audiobook files
      List<AudiobookFile> allFiles = await scanDirectory(dirPath, recursive: recursive);
      
      // First extract file metadata
      for (var file in allFiles) {
        await file.extractFileMetadata();
      }
      
      // If we have a metadata matcher, only try to match files with incomplete metadata
      if (metadataMatcher != null) {
        for (var file in allFiles) {
          if (!file.hasCompleteMetadata) {
            await metadataMatcher!.matchFile(file);
          }
        }
      }
      
      // First try to group by metadata
      Map<String, List<AudiobookFile>> metadataGroups = {};
      for (var file in allFiles) {
        if (file.hasMetadata || file.hasFileMetadata) {
          // Use the preferred metadata for grouping
          final meta = _getPreferredMetadata(file);
          final key = meta.title;
          metadataGroups.putIfAbsent(key, () => []).add(file);
        }
      }
      
      // Add all metadata-grouped files to the result
      bookGroups.addAll(metadataGroups);
      
      // Get the remaining files (without metadata)
      List<AudiobookFile> remainingFiles = allFiles.where(
        (file) => !metadataGroups.values.any((list) => list.contains(file))
      ).toList();
      
      // Group remaining files by directory
      Map<String, List<AudiobookFile>> filesByDir = {};
      for (var file in remainingFiles) {
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
          Logger.log('Grouped ${files.length} files as chapters of book: "$bookTitle"');
        } else {
          // Treat each file as a separate audiobook
          for (var file in files) {
            String baseName = path_util.basenameWithoutExtension(file.path);
            bookGroups[baseName] = [file];
          }
        }
      });
      
      Logger.log('Found ${bookGroups.length} book groups total');
    } catch (e) {
      Logger.error('Error scanning and grouping files', e);
    }
    
    return bookGroups;
  }
  
  /// Extract the common book title from a set of chapter filenames
  String extractBookTitleFromChapters(List<String> filenames, String directoryName) {
    if (filenames.isEmpty) return '';
    
    try {
      // First, check if we can use the directory name
      if (directoryName.isNotEmpty) {
        // Remove common prefixes from the folder name
        String cleanedDirName = directoryName;
        
        for (var pattern in _folderPrefixPatterns) {
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
    } catch (e) {
      Logger.error('Error extracting book title from chapters', e);
      return path_util.basenameWithoutExtension(filenames.first);
    }
  }
  
  /// Scan a directory for audiobook files
  Future<List<AudiobookFile>> scanDirectory(String dirPath, {bool? recursive}) async {
    List<AudiobookFile> results = [];
    
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        Logger.warning('Directory does not exist: $dirPath');
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
      
      Logger.log('Scanning directory: $dirPath (recursive: $shouldRecurse)');
      
      // Save the last scanned directory if preferences are available
      if (_userPreferences != null) {
        await _userPreferences!.saveLastScanDirectory(dirPath);
      }
      
      if (shouldRecurse) {
        // If recursive, we need to handle exclusions more carefully
        await for (FileSystemEntity entity in dir.list(recursive: false)) {
          if (entity is Directory) {
            // Skip excluded directories
            if (_shouldExcludeDirectory(entity.path)) {
              Logger.debug('Skipping excluded subdirectory: ${entity.path}');
              continue;
            }
            
            // Recursively scan this valid directory
            final subDirResults = await scanDirectory(entity.path, recursive: true);
            results.addAll(subDirResults);
          } else if (entity is File && isAudiobookFile(entity.path)) {
            // Add files directly in this directory
            results.add(AudiobookFile.fromFile(entity));
            Logger.debug('Found audiobook file: ${entity.path}');
          }
        }
      } else {
        // Non-recursive mode - simpler since we don't need to check subdirectories
        await for (FileSystemEntity entity in dir.list(recursive: false)) {
          if (entity is File && isAudiobookFile(entity.path)) {
            results.add(AudiobookFile.fromFile(entity));
            Logger.debug('Found audiobook file: ${entity.path}');
          }
        }
      }
      
      Logger.log('Found ${results.length} audiobook files in directory: $dirPath');
    } catch (e) {
      Logger.error('Error scanning directory', e);
    }
    
    return results;
  }
  
  /// Scan a directory and return a stream of audiobook files
  Stream<AudiobookFile> scanDirectoryStream(String dirPath, {bool? recursive}) async* {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        Logger.warning('Directory does not exist: $dirPath');
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
      
      Logger.debug('Streaming files from directory: $dirPath (recursive: $shouldRecurse)');
      
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
      Logger.error('Error scanning directory stream', e);
    }
  }
  
  /// Create AudiobookCollection objects from groups of files
  List<AudiobookCollection> createCollections(Map<String, List<AudiobookFile>> groupedFiles) {
    List<AudiobookCollection> collections = [];
    
    try {
      for (var entry in groupedFiles.entries) {
        final title = entry.key;
        final files = entry.value;
        
        // Create collection
        final collection = AudiobookCollection.fromFiles(files, title);
        
        // Sort files by chapter if applicable
        collection.sortFiles();
        
        // Try to set metadata from the first file with metadata
        for (var file in files) {
          if (file.hasAnyMetadata) {
            collection.metadata = _getPreferredMetadata(file);
            break;
          }
        }
        
        collections.add(collection);
      }
      
      Logger.log('Created ${collections.length} audiobook collections');
    } catch (e) {
      Logger.error('Error creating collections', e);
    }
    
    return collections;
  }
}