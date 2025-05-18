// File: lib/services/audiobook_scanner.dart
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/storage/user_preferences.dart';
import 'package:audiobook_organizer/storage/audiobook_storage_manager.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// Service for scanning directories and finding audiobook files
class AudiobookScanner {
  final Map<String, List<AudiobookFile>> _cachedScans = {};
  
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
    'covers',
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
  
  // Use nullable UserPreferences for backward compatibility
  final UserPreferences? _userPreferences;
  
  // Optional metadata matcher
  final MetadataMatcher? metadataMatcher;
  
  // Use storage manager instead of library storage
  final AudiobookStorageManager? storageManager;
  
  /// Default constructor
  AudiobookScanner({
    UserPreferences? userPreferences,
    this.metadataMatcher,
    this.storageManager,
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
  
  /// Improved scan method for library view that avoids duplicates and doesn't save to storage
  Future<Map<String, List<AudiobookFile>>> scanForLibraryView(
    String dirPath, 
    {bool? recursive, bool matchOnline = true}
  ) async {
    Map<String, List<AudiobookFile>> completeBooks = {};
    
    try {
      // Get all audiobook files
      List<AudiobookFile> allFiles = await scanDirectory(dirPath, recursive: recursive);
      
      // Filter out files that are already in the library if storage manager is available
      if (storageManager != null) {
        List<AudiobookFile> newFiles = [];
        int skippedCount = 0;
        
        for (var file in allFiles) {
          if (!await storageManager!.hasAudiobook(file.path)) {
            newFiles.add(file);
          } else {
            skippedCount++;
          }
        }
        
        if (skippedCount > 0) {
          Logger.log('Skipped $skippedCount files that are already in the library');
          allFiles = newFiles;
        }
      }
      
      // If no new files to process, return early
      if (allFiles.isEmpty) {
        Logger.log('No new audiobook files to process');
        
        // Load existing books from storage if available
        if (storageManager != null) {
          final libraryData = await storageManager!.loadLibrary();
          final existingBooks = libraryData['audiobooks'] as List<AudiobookFile>;
          
          // Group existing books by their title/series
          for (var book in existingBooks) {
            if (book.hasCompleteMetadata) {
              final metadata = book.metadata ?? book.fileMetadata!;
              
              String key;
              if (metadata.series.isNotEmpty) {
                key = '${metadata.series}${metadata.seriesPosition.isNotEmpty ? " ${metadata.seriesPosition}" : ""} - ${metadata.title}';
              } else {
                key = metadata.title;
              }
              
              completeBooks.putIfAbsent(key, () => []).add(book);
            }
          }
          
          return completeBooks;
        }
        
        return {};
      }
      
      // First, extract basic metadata from all files
      Logger.log('Extracting file metadata for ${allFiles.length} files');
      for (var file in allFiles) {
        await file.extractFileMetadata();
      }
      
      // Then match with online metadata if requested
      if (matchOnline && metadataMatcher != null) {
        Logger.log('Looking up online metadata for files');
        
        for (var file in allFiles) {
          // Always try to match online, regardless of file metadata completeness
          // This ensures we get the best metadata possible
          await metadataMatcher!.matchFile(file);
        }
      }
      
      // Group files by metadata
      for (var file in allFiles) {
        // Group complete metadata files
        if (file.hasCompleteMetadata) {
          Logger.log('File has complete metadata: ${file.path}');
          
          final metadata = file.metadata ?? file.fileMetadata!;
          
          // Group by series+title or just title - more comprehensive than before
          String key;
          if (metadata.series.isNotEmpty) {
            key = '${metadata.series}${metadata.seriesPosition.isNotEmpty ? " ${metadata.seriesPosition}" : ""} - ${metadata.title}';
          } else {
            key = metadata.title;
          }
          
          completeBooks.putIfAbsent(key, () => []).add(file);
        } else {
          // Log what's missing for debugging
          Logger.log('File still needs metadata: ${file.path}');
          
          // Debug what's missing
          if (file.metadata != null) {
            final meta = file.metadata!;
            Logger.debug('Online metadata: title=${meta.title.isNotEmpty}, '
                      'authors=${meta.authors.isNotEmpty}, '
                      'thumbnail=${meta.thumbnailUrl.isNotEmpty}, '
                      'desc=${meta.description.isNotEmpty}, '
                      'series=${meta.series.isNotEmpty}');
          }
          if (file.fileMetadata != null) {
            final meta = file.fileMetadata!;
            Logger.debug('File metadata: title=${meta.title.isNotEmpty}, '
                      'authors=${meta.authors.isNotEmpty}, '
                      'thumbnail=${meta.thumbnailUrl.isNotEmpty}, '
                      'desc=${meta.description.isNotEmpty}, '
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

  /// View for files with incomplete metadata that need attention
  Future<List<AudiobookFile>> scanForFilesView(
    String dirPath, 
    {bool? recursive}
  ) async {
    List<AudiobookFile> incompleteFiles = [];
    
    try {
      // Get all audiobook files
      List<AudiobookFile> allFiles = await scanDirectory(dirPath, recursive: recursive);
      
      // Filter out files that already have complete metadata in the library
      if (storageManager != null) {
        List<AudiobookFile> filesToCheck = [];
        int skippedCount = 0;
        
        for (var file in allFiles) {
          if (!await storageManager!.hasAudiobook(file.path)) {
            filesToCheck.add(file);
          } else {
            skippedCount++;
          }
        }
        
        if (skippedCount > 0) {
          Logger.log('Skipped $skippedCount files that are already in the library');
          allFiles = filesToCheck;
        }
      }
      
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
        // Always try to match online, regardless of current metadata status
        final metadata = await metadataMatcher!.matchFile(file);
        if (metadata != null) {
          processedCount++;
        }
      }
      
      
      Logger.log('Successfully processed $processedCount files with online metadata');
    } catch (e) {
      Logger.error('Error processing files with online metadata', e);
    }
    
    return processedCount;
  }
  
  /// Scan a directory for audiobook files
  Future<List<AudiobookFile>> scanDirectory(String dirPath, {bool? recursive}) async {
    // Check if we already scanned this directory with the same recursion settings
    final cacheKey = "$dirPath:${recursive ?? true}";
    if (_cachedScans.containsKey(cacheKey)) {
      Logger.log('Using cached scan results for: $dirPath');
      return _cachedScans[cacheKey]!;
    }
    
    // Original scanning code
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
      
      // Cache the results
      _cachedScans[cacheKey] = results;
    } catch (e) {
      Logger.error('Error scanning directory', e);
    }
    
    return results;
  }
  
  /// Create AudiobookCollection objects from groups of files
  List<AudiobookCollection> createCollections(Map<String, List<AudiobookFile>> groupedFiles) {
    List<AudiobookCollection> collections = [];
    
    try {
      for (var entry in groupedFiles.entries) {
        final title = entry.key;
        final files = entry.value;
        
        // Skip if no files (shouldn't happen but just in case)
        if (files.isEmpty) continue;
        
        // Create collection
        final collection = AudiobookCollection.fromFiles(files, title);
        
        // Sort files by chapter if applicable
        collection.sortFiles();
        
        // Find the best metadata among all files in the collection
        AudiobookMetadata? bestMetadata;
        
        // First, check if any file has online metadata
        for (var file in files) {
          if (file.hasMetadata) {
            bestMetadata = file.metadata;
            break;
          }
        }
        
        // If no file has online metadata, use the first file with file metadata
        if (bestMetadata == null) {
          for (var file in files) {
            if (file.hasFileMetadata) {
              bestMetadata = file.fileMetadata;
              break;
            }
          }
        }
        
        // Set the collection metadata
        if (bestMetadata != null) {
          collection.metadata = bestMetadata;
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