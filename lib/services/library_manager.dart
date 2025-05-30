// lib/services/library_manager.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/services/directory_scanner.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/storage/audiobook_storage_manager.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/file_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audiobook_organizer/services/cover_art_manager.dart';

/// Manages the library of audiobooks
class LibraryManager {
  // Dependencies
  final DirectoryScanner _scanner;
  final MetadataMatcher _metadataMatcher;
  final AudiobookStorageManager _storageManager;
  final MetadataCache _cache;
  final CoverArtManager _coverArtManager = CoverArtManager();
  CollectionManager? _collectionManager;

  final Set<String> _updatingFiles = <String>{};
  final StreamController<Set<String>> _updatingFilesController = StreamController<Set<String>>.broadcast();
  bool isFileUpdating(String filePath) {
    return _updatingFiles.contains(filePath);
  }

  Set<String> get updatingFiles => Set.from(_updatingFiles);

  // Stream for listening to updating files changes
  Stream<Set<String>> get updatingFilesChanged => _updatingFilesController.stream;
  // Library data
  List<AudiobookFile> _files = [];
  List<String> _watchedDirectories = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  
  // Event streams
  final _libraryChangedController = StreamController<List<AudiobookFile>>.broadcast();
  Stream<List<AudiobookFile>> get libraryChanged => _libraryChangedController.stream;
  
  // Constructor
  LibraryManager({
    required DirectoryScanner scanner,
    required MetadataMatcher metadataMatcher,
    required AudiobookStorageManager storageManager,
    required MetadataCache cache,
  }) : _scanner = scanner,
       _metadataMatcher = metadataMatcher,
       _storageManager = storageManager,
       _cache = cache;

  set collectionManager(CollectionManager? manager) {
    _collectionManager = manager;
  }

  CollectionManager? get collectionManager => _collectionManager;

  // Initialize the library
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _isLoading = true;
      
      // Initialize cover art manager
      await _coverArtManager.initialize();
      
      // Initialize metadata matcher with covers disabled by default
      await _metadataMatcher.initialize();
      
      // Load watched directories
      await _loadWatchedDirectories();
      
      // Load library from storage
      _files = await _storageManager.loadLibrary();
      
      // Ensure all files have their cover paths properly set from embedded covers
      await _ensureCoversForExistingFiles();
      
      // Notify listeners
      _notifyLibraryChanged();
      
      _isInitialized = true;
      _isLoading = false;
      
      Logger.log('LibraryManager initialized with ${_files.length} files');
    } catch (e) {
      _isLoading = false;
      Logger.error('Error initializing LibraryManager', e);
      rethrow;
    }
  }

  Future<void> _ensureCoversForExistingFiles() async {
    bool hasUpdates = false;
    
    for (final file in _files) {
      if (file.metadata != null) {
        // Use centralized cover handling from CoverArtManager
        final coverPath = await _coverArtManager.ensureCoverForFile(file.path, file.metadata);
        
        if (coverPath != null && coverPath != file.metadata!.thumbnailUrl) {
          Logger.log('Updated cover path for existing file: ${file.filename}');
          
          final updatedMetadata = file.metadata!.copyWith(thumbnailUrl: coverPath);
          await _storageManager.updateMetadataForFile(file.path, updatedMetadata, force: true);
          file.metadata = updatedMetadata;
          hasUpdates = true;
        }
      }
    }
    
    if (hasUpdates) {
      Logger.log('Updated cover paths for existing files');
    }
  }

  void _notifyLibraryChanged() {
    _libraryChangedController.add(List<AudiobookFile>.from(_files));
  }
  
  // Load watched directories from storage
  Future<void> _loadWatchedDirectories() async {
    try {
      final dirFile = File(path_util.join(
        _storageManager.libraryFilePath, 
        '../watched_directories.json'
      ));
      
      if (await dirFile.exists()) {
        final content = await dirFile.readAsString();
        final data = Map<String, dynamic>.from(json.decode(content));
        _watchedDirectories = List<String>.from(data['directories'] ?? []);
      } else {
        _watchedDirectories = [];
      }
      
      Logger.log('Loaded ${_watchedDirectories.length} watched directories');
    } catch (e) {
      Logger.error('Error loading watched directories', e);
      _watchedDirectories = [];
    }
  }
  
  // Save watched directories to storage
  Future<void> _saveWatchedDirectories() async {
    try {
      final dirFile = File(path_util.join(
        _storageManager.libraryFilePath, 
        '../watched_directories.json'
      ));
      
      await dirFile.writeAsString(json.encode({
        'directories': _watchedDirectories,
      }));
      
      Logger.log('Saved ${_watchedDirectories.length} watched directories');
    } catch (e) {
      Logger.error('Error saving watched directories', e);
    }
  }
  
  // Add a directory to watch
  Future<void> addDirectory(String directoryPath) async {
    if (_watchedDirectories.contains(directoryPath)) {
      Logger.log('Directory already being watched: $directoryPath');
      return;
    }
    
    _watchedDirectories.add(directoryPath);
    await _saveWatchedDirectories();
    
    // Scan the new directory
    await scanDirectory(directoryPath);
  }
  
  // Remove a watched directory
  Future<void> removeDirectory(String directoryPath) async {
    if (!_watchedDirectories.contains(directoryPath)) {
      return;
    }
    
    _watchedDirectories.remove(directoryPath);
    await _saveWatchedDirectories();
    
    // Remove files from this directory
    final removedFiles = _files.where((file) => file.path.startsWith(directoryPath)).toList();
    _files.removeWhere((file) => file.path.startsWith(directoryPath));
    
    // Clean up covers for removed files
    for (final file in removedFiles) {
      await _coverArtManager.removeCover(file.path);
    }
    
    // IMPORTANT: Also clean up metadata for removed files
    for (final file in removedFiles) {
      await _storageManager.deleteMetadataForFile(file.path);
      Logger.debug('Deleted metadata for removed file: ${file.path}');
    }
    
    // Update storage
    await _storageManager.saveLibrary(_files);
    
    // Notify listeners
    _libraryChangedController.add(_files);
    
    Logger.log('Removed directory, cleaned up ${removedFiles.length} files and their metadata: $directoryPath');
  }
  
  /// COMPREHENSIVE library clearing - clears ALL caches and data
  Future<void> clearLibrary({bool keepWatchedDirectories = false}) async {
    try {
      Logger.log('Starting comprehensive library clear (keepWatchedDirectories: $keepWatchedDirectories)');
      
      // 1. Clean up all cover art
      Logger.log('Clearing cover art cache...');
      _coverArtManager.clearCache();
      
      // 2. Clear search cache
      Logger.log('Clearing search cache...');
      await _cache.clearCache();
      
      // 3. Clear metadata service cache
      Logger.log('Clearing metadata service cache...');
      final metadataService = MetadataService();
      metadataService.clearCache();
      
      // 4. Delete all stored metadata files
      Logger.log('Deleting all stored metadata...');
      final currentFilePaths = _files.map((f) => f.path).toList();
      for (final filePath in currentFilePaths) {
        await _storageManager.deleteMetadataForFile(filePath);
      }
      
      // 5. Clear the in-memory library
      _files.clear();
      
      // 6. Optionally clear watched directories
      if (!keepWatchedDirectories) {
        Logger.log('Clearing watched directories...');
        _watchedDirectories.clear();
        await _saveWatchedDirectories();
      }
      
      // 7. Save empty library state
      await _storageManager.saveLibrary(_files);
      
      // 8. Notify listeners
      _notifyLibraryChanged();
      
      Logger.log('Library cleared successfully. All caches and metadata have been removed.');
    } catch (e) {
      Logger.error('Error clearing library', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cleanLibrary() async {
  try {
    Logger.log('Starting library cleanup...');
    
    final List<AudiobookFile> missingFiles = [];
    final List<AudiobookFile> validFiles = [];
    int orphanedMetadataCount = 0;
    
    // Check each audiobook file in the library by its actual path
    Logger.log('Checking ${_files.length} audiobook files for existence...');
    
    for (final file in _files) {
      // Check if the actual audiobook file exists at its stored path
      final audioFile = File(file.path);
      final fileExists = await audioFile.exists();
      
      if (fileExists) {
        validFiles.add(file);
        Logger.debug('✓ File exists: ${file.path}');
      } else {
        missingFiles.add(file);
        Logger.log('✗ Missing file detected: ${file.path}');
      }
    }
    
    // If there are missing files, clean them up
    if (missingFiles.isNotEmpty) {
      Logger.log('Found ${missingFiles.length} missing files to remove');
      
      // Clean up metadata and covers for missing files
      for (final file in missingFiles) {
        // Delete metadata
        await _storageManager.deleteMetadataForFile(file.path);
        Logger.debug('Deleted metadata for missing file: ${file.path}');
        
        // Remove cover art
        await _coverArtManager.removeCover(file.path);
        Logger.debug('Removed cover for missing file: ${file.path}');
        
        // Remove from collections if collection manager is available
        if (_collectionManager != null) {
          final collections = _collectionManager!.getCollectionsForBook(file.path);
          for (final collection in collections) {
            await _collectionManager!.removeBookFromCollection(collection.id, file.path);
          }
        }
      }
      
      // Update the files list with only valid files
      _files = validFiles;
      
      // Save the cleaned library
      await _storageManager.saveLibrary(_files);
      
      // Notify listeners
      _notifyLibraryChanged();
    }
    
    // Check for orphaned metadata (metadata files without corresponding library entries)
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final metadataDir = Directory('${appDir.path}/audiobook_metadata');
      
      if (await metadataDir.exists()) {
        await for (final entity in metadataDir.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            // Extract the file path from metadata filename
            final metadataFilename = path_util.basenameWithoutExtension(entity.path);
            final decodedPath = Uri.decodeComponent(metadataFilename);
            
            // Check if this metadata belongs to any file in our library
            final hasCorrespondingFile = _files.any((f) => 
              Uri.encodeComponent(f.path) == metadataFilename || 
              f.path == decodedPath
            );
            
            if (!hasCorrespondingFile) {
              // This is orphaned metadata
              await entity.delete();
              orphanedMetadataCount++;
              Logger.debug('Deleted orphaned metadata file: ${entity.path}');
            }
          }
        }
      }
    } catch (e) {
      Logger.error('Error checking for orphaned metadata', e);
    }
    
    // Check for orphaned cover art
    int orphanedCoversCount = 0;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDir.path}/audiobook_covers');
      
      if (await coversDir.exists()) {
        await for (final entity in coversDir.list()) {
          if (entity is File) {
            final coverFilename = path_util.basename(entity.path);
            
            // Check if any file in library references this cover
            final isReferencedCover = _files.any((f) => 
              f.metadata?.thumbnailUrl.contains(coverFilename) ?? false
            );
            
            if (!isReferencedCover) {
              // This is an orphaned cover
              await entity.delete();
              orphanedCoversCount++;
              Logger.debug('Deleted orphaned cover file: ${entity.path}');
            }
          }
        }
      }
    } catch (e) {
      Logger.error('Error checking for orphaned covers', e);
    }
    
    final cleanupResults = {
      'missingFilesRemoved': missingFiles.length,
      'missingFiles': missingFiles.map((f) => f.path).toList(),
      'orphanedMetadataRemoved': orphanedMetadataCount,
      'orphanedCoversRemoved': orphanedCoversCount,
      'totalCleaned': missingFiles.length + orphanedMetadataCount + orphanedCoversCount,
      'remainingFiles': _files.length,
    };
    
    Logger.log('Library cleanup completed: ${cleanupResults['totalCleaned']} items cleaned');
    Logger.log('- Missing files removed: ${cleanupResults['missingFilesRemoved']}');
    Logger.log('- Orphaned metadata removed: ${cleanupResults['orphanedMetadataRemoved']}');
    Logger.log('- Orphaned covers removed: ${cleanupResults['orphanedCoversRemoved']}');
    Logger.log('- Remaining files in library: ${cleanupResults['remainingFiles']}');
    
    return cleanupResults;
  } catch (e) {
    Logger.error('Error during library cleanup', e);
    throw Exception('Failed to clean library: ${e.toString()}');
  }
}
  
  /// Clear library but keep watched directories (UI convenience method)
  Future<void> clearLibraryKeepingDirectories() async {
    await clearLibrary(keepWatchedDirectories: true);
  }
  
  /// Clear everything including watched directories (complete reset)
  Future<void> clearLibraryCompletely() async {
    await clearLibrary(keepWatchedDirectories: false);
  }
  
  // Scan a directory for audiobooks
  Future<List<AudiobookFile>> scanDirectory(String directoryPath, {bool forceReprocess = false}) async {
    if (_isLoading) {
      Logger.warning('Scan already in progress, please wait');
      return [];
    }
    
    _isLoading = true;
    
    try {
      Logger.log('Scanning directory: $directoryPath (forceReprocess: $forceReprocess)');
      
      // Scan for files
      final newFiles = await _scanner.scanDirectory(directoryPath);
      
      // Filter out files we already have (unless forcing reprocess)
      final filesToAdd = newFiles.where((newFile) {
        return forceReprocess || !_files.any((existingFile) => existingFile.path == newFile.path);
      }).toList();
      
      if (filesToAdd.isEmpty) {
        Logger.log('No new files found in directory: $directoryPath');
        _isLoading = false;
        return [];
      }
      
      Logger.log('Found ${filesToAdd.length} ${forceReprocess ? "files to reprocess" : "new files"} in directory: $directoryPath');
      
      // If reprocessing, remove old entries first
      if (forceReprocess) {
        final oldFiles = _files.where((f) => f.path.startsWith(directoryPath)).toList();
        for (final oldFile in oldFiles) {
          await _storageManager.deleteMetadataForFile(oldFile.path);
          await _coverArtManager.removeCover(oldFile.path);
        }
        _files.removeWhere((f) => f.path.startsWith(directoryPath));
      }
      
      // Process files in batches to prevent UI freezes
      const int batchSize = 5;
      for (int i = 0; i < filesToAdd.length; i += batchSize) {
        final end = (i + batchSize < filesToAdd.length) ? i + batchSize : filesToAdd.length;
        final batch = filesToAdd.sublist(i, end);
        
        // Process batch
        await _processBatch(batch, forceReprocess: forceReprocess);
        
        // Add processed batch to library
        _files.addAll(batch);
        
        // Save progress
        await _storageManager.saveLibrary(_files);
        
        // Notify listeners about partial progress
        _libraryChangedController.add(_files);
      }
      
      Logger.log('Finished scanning directory: $directoryPath');
      _isLoading = false;
      return filesToAdd;
    } catch (e) {
      _isLoading = false;
      Logger.error('Error scanning directory: $directoryPath', e);
      rethrow;
    }
  }
  
  // Process a batch of files - CORRECTED FLOW with force reprocess option
  Future<void> _processBatch(List<AudiobookFile> batch, {bool forceReprocess = false}) async {
    final metadataService = MetadataService();
    await metadataService.initialize();

    for (final file in batch) {
      try {
        Logger.debug('Processing file: ${file.path} (forceReprocess: $forceReprocess)');
        
        // Try to load metadata from storage first (unless forcing reprocess)
        if (!forceReprocess) {
          final storedMetadata = await _storageManager.getMetadataForFile(file.path);
          if (storedMetadata != null) {
            file.metadata = storedMetadata;
            Logger.debug('Loaded stored metadata for: ${file.filename}');
            continue;
          }
        }
        
        // Extract basic metadata (no cover)
        final fileMetadata = await metadataService.extractMetadata(file.path, forceRefresh: forceReprocess);
        
        if (fileMetadata != null) {
          Logger.debug('Extracted ${forceReprocess ? "fresh " : ""}file metadata for: ${file.filename}');
          
          // Use centralized cover handling
          final coverPath = await _coverArtManager.ensureCoverForFile(file.path, fileMetadata);
          
          // Update metadata with cover path if found
          final metadataWithCover = coverPath != null 
              ? fileMetadata.copyWith(thumbnailUrl: coverPath)
              : fileMetadata;
          
          if (file.metadata?.series.isNotEmpty ?? false) {
            Logger.log('Book "${file.metadata!.title}" is part of series: ${file.metadata!.series}');
          }

          // Store the metadata
          await _storageManager.updateMetadataForFile(file.path, metadataWithCover, force: forceReprocess);
          file.metadata = metadataWithCover;
          
          // Try to enhance with online metadata (keeping embedded cover)
          final enhancedMetadata = await _metadataMatcher.matchWithOnlineSources(
            metadataWithCover, 
            file.path
          );
          
          if (enhancedMetadata != null) {
            file.metadata = enhancedMetadata;
            Logger.debug('Enhanced metadata for: ${file.filename}');
          }
        }
      } catch (e) {
        Logger.error('Error processing file: ${file.path}', e);
      }
    }
  }

  /// Re-scan all watched directories and force reprocess all files
  Future<void> refreshLibraryCompletely() async {
    try {
      Logger.log('Starting complete library refresh...');
      
      // Clear all data first
      await clearLibraryKeepingDirectories();
      
      // Re-scan all watched directories with force reprocess
      for (final directory in _watchedDirectories) {
        if (await Directory(directory).exists()) {
          Logger.log('Re-scanning directory: $directory');
          await scanDirectory(directory, forceReprocess: true);
        } else {
          Logger.warning('Watched directory no longer exists: $directory');
        }
      }
      
      Logger.log('Complete library refresh finished');
    } catch (e) {
      Logger.error('Error during complete library refresh', e);
      rethrow;
    }
  }

  Future<bool> _updateFileMetadata(
    AudiobookFile file,
    AudiobookMetadata Function(AudiobookMetadata) updateFunction,
  ) async {
    try {
      if (file.metadata == null) {
        Logger.warning('Cannot update metadata for file without existing metadata: ${file.filename}');
        return false;
      }
      
      final updatedMetadata = updateFunction(file.metadata!);
      
      // Don't call updateMetadata here to avoid double tracking - handle directly
      Logger.log('Updating file metadata for: ${file.filename}');
      
      // Update the metadata in storage first
      final success = await _storageManager.updateMetadataForFile(
        file.path, 
        updatedMetadata, 
        force: true
      );
      
      if (success) {
        // Update the file object
        file.metadata = updatedMetadata;

        await _storageManager.saveLibrary(_files);
        
        final fileIndex = _files.indexWhere((f) => f.path == file.path);
        if (fileIndex != -1) {
          _files[fileIndex] = file;
        }
        
        // Notify listeners about the change
        _notifyLibraryChanged();
        
        Logger.log('Successfully updated file metadata for: ${file.filename}');
        return true;
      }
      
      Logger.error('Failed to update file metadata in storage for: ${file.filename}');
      return false;
    } catch (e) {
      Logger.error('Error in _updateFileMetadata for ${file.filename}', e);
      return false;
    }
  }

  Future<bool> updateMetadata(AudiobookFile file, AudiobookMetadata metadata) async {
    final filePath = file.path;
    
    try {
      // Mark file as updating
      _setFileUpdating(filePath, true);
      
      Logger.log('Updating metadata for file: ${file.filename}');
      
      // Update the metadata in storage first
      final success = await _storageManager.updateMetadataForFile(
        file.path, 
        metadata, 
        force: true
      );
      
      if (success) {
        // Update the file object
        file.metadata = metadata;

        await _storageManager.saveLibrary(_files);
        
        final fileIndex = _files.indexWhere((f) => f.path == file.path);
        if (fileIndex != -1) {
          _files[fileIndex] = file;
        }
        
        // Notify listeners about the change
        _notifyLibraryChanged();
        
        Logger.log('Successfully updated metadata for: ${file.filename}');
        return true;
      }
      
      Logger.error('Failed to update metadata in storage for: ${file.filename}');
      return false;
    } catch (e) {
      Logger.error('Error updating metadata for ${file.filename}', e);
      return false;
    } finally {
      // Always mark file as no longer updating
      _setFileUpdating(filePath, false);
    }
  }

  // Get the current library
  List<AudiobookFile> get files => _files;
  
  // Get watched directories
  List<String> get watchedDirectories => _watchedDirectories;
  
  // Get loading state
  bool get isLoading => _isLoading;
  
  // Update cover image for a specific file
  Future<bool> updateCoverImage(AudiobookFile file, String coverSource) async {
    final filePath = file.path;
    
    try {
      // Mark file as updating
      _setFileUpdating(filePath, true);
      
      Logger.log('Updating cover image for: ${file.filename} from source: $coverSource');
      
      String? localCoverPath;
      
      if (coverSource.startsWith('http://') || coverSource.startsWith('https://')) {
        // Download from URL using CoverArtManager (handles all cache management)
        localCoverPath = await _coverArtManager.updateCoverFromUrl(file.path, coverSource);
      } else {
        // Update from local file using CoverArtManager (handles all cache management)
        localCoverPath = await _coverArtManager.updateCoverFromLocalFile(file.path, coverSource);
      }
      
      if (localCoverPath == null) {
        Logger.error('CoverArtManager failed to update cover from: $coverSource');
        return false;
      }
      
      // Update the metadata with the new cover path (CoverArtManager gives us unique path)
      if (file.metadata != null) {
        final updatedMetadata = file.metadata!.copyWith(thumbnailUrl: localCoverPath);
        
        // Use the standard updateMetadata method to ensure proper persistence
        // Note: updateMetadata will handle its own _setFileUpdating, so we need to avoid double-tracking
        _setFileUpdating(filePath, false); // Clear our tracking first
        final success = await updateMetadata(file, updatedMetadata);
        
        if (success) {
          Logger.log('Successfully updated cover image for: ${file.filename} -> $localCoverPath');
          return true;
        } else {
          Logger.error('Failed to update metadata with new cover path');
          return false;
        }
      } else {
        Logger.error('Cannot update cover for file without metadata: ${file.filename}');
        return false;
      }
    } catch (e) {
      Logger.error('Error updating cover image for file: ${file.path}', e);
      return false;
    } finally {
      // Always mark file as no longer updating
      _setFileUpdating(filePath, false);
    }
  }
  
  // Enable auto-download of covers from online sources
  Future<void> enableAutoDownloadCovers() async {
    _metadataMatcher.autoDownloadCovers = true;
    Logger.log('Auto-download covers enabled');
  }
  
  // Disable auto-download of covers from online sources
  Future<void> disableAutoDownloadCovers() async {
    _metadataMatcher.autoDownloadCovers = false;
    Logger.log('Auto-download covers disabled');
  }
  
  // Update user data for a file
  Future<bool> updateUserData(AudiobookFile file, {
    int? userRating,
    DateTime? lastPlayedPosition,
    Duration? playbackPosition,
    List<String>? userTags,
    bool? isFavorite,
    List<AudiobookBookmark>? bookmarks,
    List<AudiobookNote>? notes,
  }) async {
    final filePath = file.path;
    
    try {
      _setFileUpdating(filePath, true);
      
      return await _updateFileMetadata(file, (metadata) => metadata.copyWith(
        userRating: userRating ?? metadata.userRating,
        lastPlayedPosition: lastPlayedPosition ?? metadata.lastPlayedPosition,
        playbackPosition: playbackPosition ?? metadata.playbackPosition,
        userTags: userTags ?? metadata.userTags,
        isFavorite: isFavorite ?? metadata.isFavorite,
        bookmarks: bookmarks ?? metadata.bookmarks,
        notes: notes ?? metadata.notes,
      ));
    } catch (e) {
      Logger.error('Error updating user data for ${file.filename}', e);
      return false;
    } finally {
      _setFileUpdating(filePath, false);
    }
  }
  
  // REFACTORED: Analyze library structure with utilities
  Future<void> analyzeLibraryStructure() async {
    Logger.log('Analyzing library folder structure for series detection');
    
    // Group files by folder
    final groupedFiles = _scanner.groupFilesByFolder(_files);
    
    for (final folder in groupedFiles.keys) {
      final files = groupedFiles[folder]!;
      final folderName = path_util.basename(folder);
      
      // Skip if too few files or generic folder name
      if (files.length < 2 || ['audiobooks', 'books', 'library'].contains(folderName.toLowerCase())) {
        continue;
      }
      
      Logger.debug('Analyzing folder: $folderName with ${files.length} files');
      
      // Check if files in this folder have a common series
      final seriesSet = <String>{};
      for (final file in files) {
        if (file.metadata?.series.isNotEmpty ?? false) {
          seriesSet.add(file.metadata!.series);
        }
      }
      
      // If more than one series or no series found, use the folder name
      if (seriesSet.length != 1) {
        Logger.debug('Setting folder name as series: $folderName');
        
        // Update files without series info
        for (final file in files) {
          if (file.metadata != null && file.metadata!.series.isEmpty) {
            // Use utility to extract series position
            final position = FileUtils.extractSeriesPosition(file.filename) ?? 
                            FileUtils.extractSeriesPosition(file.path) ?? '';
            
            // Update metadata using generic method
            await _updateFileMetadata(file, (metadata) => metadata.copyWith(
              series: folderName,
              seriesPosition: position,
            ));
            
            Logger.debug('Updated series info for: ${file.filename}');
          }
        }
      }
    }
    
    Logger.log('Library structure analysis complete');
  }

  Future<bool> writeMetadataToFile(AudiobookFile file) async {
    final filePath = file.path;
    
    if (file.metadata == null) {
      Logger.warning('No metadata to write for file: ${file.filename}');
      return false;
    }

    try {
      // Mark file as updating
      _setFileUpdating(filePath, true);
      
      Logger.log('Writing metadata to file: ${file.filename}');
      final currentMetadata = file.metadata!;
      final metadataService = MetadataService();
      await metadataService.initialize();
      
      String? coverImagePath;
      if (currentMetadata.thumbnailUrl.isNotEmpty && 
          !currentMetadata.thumbnailUrl.startsWith('http')) {
        final coverFile = File(currentMetadata.thumbnailUrl);
        if (await coverFile.exists()) {
          coverImagePath = currentMetadata.thumbnailUrl;
          Logger.log('Using cover image for embedding: ${path_util.basename(coverImagePath)}');
        } else {
          Logger.warning('Cover file does not exist: ${currentMetadata.thumbnailUrl}');
        }
      }

      final success = await metadataService.writeMetadata(
        file.path, 
        currentMetadata,
        coverImagePath: coverImagePath,
      );
      
      if (success) {
        Logger.log('Successfully wrote metadata to file: ${file.filename}${coverImagePath != null ? ' (including cover)' : ''}');
        
        final freshMetadata = await metadataService.extractMetadata(
          file.path, 
          forceRefresh: true
        );
        
        if (freshMetadata != null) {
          final preservedMetadata = currentMetadata.copyWith(
            audioDuration: freshMetadata.audioDuration,
            fileFormat: freshMetadata.fileFormat,
          );
          
          file.metadata = preservedMetadata;
          
          await _storageManager.updateMetadataForFile(file.path, preservedMetadata, force: true);
          
          Logger.log('Metadata written to file and rich metadata preserved for: ${file.filename}');
        } else {
          Logger.warning('Could not verify file write, keeping all current metadata for: ${file.filename}');
        }

        _notifyLibraryChanged();
        
        return true;
      } else {
        Logger.error('Failed to write metadata to file: ${file.filename}');
        return false;
      }
    } catch (e) {
      Logger.error('Error writing metadata to file: ${file.filename}', e);
      return false;
    } finally {
      // Always mark file as no longer updating
      _setFileUpdating(filePath, false);
    }
  }

  /// Get detailed metadata statistics for debugging
  Future<Map<String, dynamic>> getMetadataStatistics() async {
    int totalFiles = _files.length;
    int filesWithDuration = 0;
    int filesWithMetadata = 0;
    int filesWithCovers = 0;
    Duration totalDuration = Duration.zero;
    List<String> filesWithoutDuration = [];
    
    for (final file in _files) {
      if (file.metadata != null) {
        filesWithMetadata++;
        
        if (file.metadata!.audioDuration != null) {
          filesWithDuration++;
          totalDuration += file.metadata!.audioDuration!;
        } else {
          filesWithoutDuration.add(file.filename);
        }
        
        if (file.metadata!.thumbnailUrl.isNotEmpty) {
          filesWithCovers++;
        }
      }
    }
    
    final stats = {
      'total_files': totalFiles,
      'files_with_metadata': filesWithMetadata,
      'files_with_duration': filesWithDuration,
      'files_with_covers': filesWithCovers,
      'total_duration_hours': totalDuration.inHours,
      'total_duration_formatted': _formatDuration(totalDuration),
      'files_without_duration': filesWithoutDuration,
      'duration_coverage_percent': totalFiles > 0 ? (filesWithDuration / totalFiles * 100).toStringAsFixed(1) : '0',
      'metadata_coverage_percent': totalFiles > 0 ? (filesWithMetadata / totalFiles * 100).toStringAsFixed(1) : '0',
      'cover_coverage_percent': totalFiles > 0 ? (filesWithCovers / totalFiles * 100).toStringAsFixed(1) : '0',
    };
    
    Logger.log('Metadata Statistics: $stats');
    return stats;
  }

  /// Helper method to format duration
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  // Add a bookmark
  Future<bool> addBookmark(AudiobookFile file, AudiobookBookmark bookmark) async {
    try {
      final success = await _storageManager.addBookmark(file.path, bookmark);
      
      if (success) {
        // Reload metadata to update the file object
        file.metadata = await _storageManager.getMetadataForFile(file.path);
        
        // Notify listeners
        _libraryChangedController.add(_files);
      }
      
      return success;
    } catch (e) {
      Logger.error('Error adding bookmark for file: ${file.path}', e);
      return false;
    }
  }
  
  // Remove a bookmark
  Future<bool> removeBookmark(AudiobookFile file, String bookmarkId) async {
    try {
      final success = await _storageManager.removeBookmark(file.path, bookmarkId);
      
      if (success) {
        // Reload metadata to update the file object
        file.metadata = await _storageManager.getMetadataForFile(file.path);
        
        // Notify listeners
        _libraryChangedController.add(_files);
      }
      
      return success;
    } catch (e) {
      Logger.error('Error removing bookmark for file: ${file.path}', e);
      return false;
    }
  }
  
  // Add a note
  Future<bool> addNote(AudiobookFile file, AudiobookNote note) async {
    try {
      final success = await _storageManager.addNote(file.path, note);
      
      if (success) {
        // Reload metadata to update the file object
        file.metadata = await _storageManager.getMetadataForFile(file.path);
        
        // Notify listeners
        _libraryChangedController.add(_files);
      }
      
      return success;
    } catch (e) {
      Logger.error('Error adding note for file: ${file.path}', e);
      return false;
    }
  }
  
  // Remove a note
  Future<bool> removeNote(AudiobookFile file, String noteId) async {
    try {
      final success = await _storageManager.removeNote(file.path, noteId);
      
      if (success) {
        // Reload metadata to update the file object
        file.metadata = await _storageManager.getMetadataForFile(file.path);
        
        // Notify listeners
        _libraryChangedController.add(_files);
      }
      
      return success;
    } catch (e) {
      Logger.error('Error removing note for file: ${file.path}', e);
      return false;
    }
  }

  Future<bool> replaceFileInLibrary(
    String oldFilePath,
    String newFilePath,
    AudiobookMetadata metadata,
  ) async {
    try {
      Logger.log('Replacing file in library: $oldFilePath -> $newFilePath');
      
      // Find the existing file in the library
      final existingFileIndex = _files.indexWhere((f) => f.path == oldFilePath);
      if (existingFileIndex == -1) {
        Logger.error('Original file not found in library: $oldFilePath');
        return false;
      }
      
      final existingFile = _files[existingFileIndex];
      
      // Verify the new file exists
      final newFile = File(newFilePath);
      if (!await newFile.exists()) {
        Logger.error('New file does not exist: $newFilePath');
        return false;
      }
      
      // Create new AudiobookFile object
      final stat = await newFile.stat();
      final newAudiobookFile = AudiobookFile(
        path: newFilePath,
        lastModified: stat.modified,
        fileSize: stat.size,
        metadata: metadata.copyWith(
          fileFormat: path_util.extension(newFilePath).toLowerCase().replaceFirst('.', '').toUpperCase(),
        ),
      );
      
      // Update metadata in storage for new file path
      final metadataSuccess = await _storageManager.updateMetadataForFile(
        newFilePath,
        newAudiobookFile.metadata!,
        force: true,
      );
      
      if (!metadataSuccess) {
        Logger.error('Failed to store metadata for new file: $newFilePath');
        return false;
      }
      
      // Handle cover art transfer
      if (existingFile.metadata?.thumbnailUrl.isNotEmpty ?? false) {
        final oldCoverPath = existingFile.metadata!.thumbnailUrl;
        if (!oldCoverPath.startsWith('http') && await File(oldCoverPath).exists()) {
          // Update cover art manager with new file path
          final newCoverPath = await _coverArtManager.transferCover(oldFilePath, newFilePath, oldCoverPath);
          if (newCoverPath != null) {
            newAudiobookFile.metadata = newAudiobookFile.metadata!.copyWith(thumbnailUrl: newCoverPath);
            await _storageManager.updateMetadataForFile(newFilePath, newAudiobookFile.metadata!, force: true);
          }
        }
      }
      
      // Update collections if the file is in any
      if (_collectionManager != null) {
        final collections = _collectionManager!.getCollectionsForBook(oldFilePath);
        for (final collection in collections) {
          await _collectionManager!.removeBookFromCollection(collection.id, oldFilePath);
          await _collectionManager!.addBookToCollection(collection.id, newFilePath);
        }
        Logger.log('Updated ${collections.length} collections with new file path');
      }
      
      // Replace the file in the library list
      _files[existingFileIndex] = newAudiobookFile;
      
      // Clean up old metadata
      await _storageManager.deleteMetadataForFile(oldFilePath);
      
      // Clean up old cover
      await _coverArtManager.removeCover(oldFilePath);
      
      // Save the updated library
      await _storageManager.saveLibrary(_files);
      
      // Notify listeners
      _notifyLibraryChanged();
      
      Logger.log('Successfully replaced file in library: $oldFilePath -> $newFilePath');
      return true;
      
    } catch (e) {
      Logger.error('Error replacing file in library: $oldFilePath -> $newFilePath', e);
      return false;
    }
  }

  Future<bool> addSingleFile(AudiobookFile file) async {
    try {
      Logger.log('Adding single file to library: ${file.filename}');
      
      // Check if file already exists in library
      final existingIndex = _files.indexWhere((f) => f.path == file.path);
      if (existingIndex != -1) {
        Logger.log('File already exists in library, updating: ${file.filename}');
        _files[existingIndex] = file;
      } else {
        Logger.log('Adding new file to library: ${file.filename}');
        _files.add(file);
      }
      
      // Ensure the file has metadata
      if (file.metadata != null) {
        // Store metadata using storage manager
        final metadataSuccess = await _storageManager.updateMetadataForFile(
          file.path, 
          file.metadata!, 
          force: true,
          operation: MetadataUpdateOperation.directSave,
        );
        
        if (!metadataSuccess) {
          Logger.error('Failed to store metadata for new file: ${file.filename}');
          return false;
        }
        
        // Handle cover art if present
        if (file.metadata!.thumbnailUrl.isNotEmpty && 
            !file.metadata!.thumbnailUrl.startsWith('http')) {
          final coverPath = await _coverArtManager.ensureCoverForFile(file.path, file.metadata!);
          if (coverPath != null && coverPath != file.metadata!.thumbnailUrl) {
            // Update metadata with the proper cover path
            file.metadata = file.metadata!.copyWith(thumbnailUrl: coverPath);
            await _storageManager.updateMetadataForFile(
              file.path, 
              file.metadata!, 
              force: true,
              operation: MetadataUpdateOperation.directSave,
            );
          }
        }
      } else {
        Logger.warning('Adding file without metadata: ${file.filename}');
      }
      
      // Save the updated library
      await _storageManager.saveLibrary(_files);
      
      // Notify listeners about the change
      _notifyLibraryChanged();
      
      Logger.log('Successfully added single file to library: ${file.filename}');
      return true;
      
    } catch (e) {
      Logger.error('Error adding single file to library: ${file.filename}', e);
      return false;
    }
  }

  void _setFileUpdating(String filePath, bool isUpdating) {
    if (isUpdating) {
      if (_updatingFiles.add(filePath)) {
        _updatingFilesController.add(Set.from(_updatingFiles));
        Logger.debug('File marked as updating: $filePath');
      }
    } else {
      if (_updatingFiles.remove(filePath)) {
        _updatingFilesController.add(Set.from(_updatingFiles));
        Logger.debug('File no longer updating: $filePath');
      }
    }
  }
  
  // Get file by path
  AudiobookFile? getFileByPath(String path) {
    try {
      return _files.firstWhere((file) => file.path == path);
    } catch (e) {
      return null;
    }
  }
  
  // Get files by series
  List<AudiobookFile> getFilesBySeries(String series) {
    return _files.where((file) {
      return file.metadata?.series.toLowerCase() == series.toLowerCase();
    }).toList();
  }
  
  // Get files by author
  List<AudiobookFile> getFilesByAuthor(String author) {
    return _files.where((file) {
      return file.metadata?.authors.any((a) => 
        a.toLowerCase().contains(author.toLowerCase())) ?? false;
    }).toList();
  }
  
  // Get files by tag
  List<AudiobookFile> getFilesByTag(String tag) {
    return _files.where((file) {
      return file.metadata?.userTags.contains(tag) ?? false;
    }).toList();
  }
  
  // Get all series
  List<String> getAllSeries() {
    final Set<String> series = {};
    
    for (final file in _files) {
      if (file.metadata?.series.isNotEmpty ?? false) {
        series.add(file.metadata!.series);
      }
    }
    
    return series.toList()..sort();
  }
  
  // Get all authors
  List<String> getAllAuthors() {
    final Set<String> authors = {};
    
    for (final file in _files) {
      if (file.metadata?.authors.isNotEmpty ?? false) {
        authors.addAll(file.metadata!.authors);
      }
    }
    
    return authors.toList()..sort();
  }
  
  // Get all tags
  List<String> getAllTags() {
    final Set<String> tags = {};
    
    for (final file in _files) {
      if (file.metadata?.userTags.isNotEmpty ?? false) {
        tags.addAll(file.metadata!.userTags);
      }
    }
    
    return tags.toList()..sort();
  }

  List<AudiobookFile> getBooksForCollection(Collection collection) {
    return _files.where((file) => collection.bookPaths.contains(file.path)).toList();
  }

  Future<bool> searchAndUpdateMetadata(AudiobookFile file) async {
    final filePath = file.path;
    
    try {
      // Mark file as updating
      _setFileUpdating(filePath, true);
      
      Logger.log('Starting metadata search for: ${file.filename}');
      
      if (file.metadata == null) {
        Logger.warning('Cannot search metadata for file without existing metadata: ${file.filename}');
        return false;
      }
      
      // Search for enhanced metadata using your existing matcher
      final enhancedMetadata = await _metadataMatcher.matchWithOnlineSources(
        file.metadata!,
        file.path,
      );
      
      if (enhancedMetadata != null) {
        // Update directly to avoid double tracking
        Logger.log('Updating with enhanced metadata for: ${file.filename}');
        
        // Update the metadata in storage first
        final success = await _storageManager.updateMetadataForFile(
          file.path, 
          enhancedMetadata, 
          force: true
        );
        
        if (success) {
          // Update the file object
          file.metadata = enhancedMetadata;

          await _storageManager.saveLibrary(_files);
          
          final fileIndex = _files.indexWhere((f) => f.path == file.path);
          if (fileIndex != -1) {
            _files[fileIndex] = file;
          }
          
          // Notify listeners about the change
          _notifyLibraryChanged();
          
          Logger.log('Successfully updated metadata from search for: ${file.filename}');
          return true;
        } else {
          Logger.error('Failed to save searched metadata for: ${file.filename}');
          return false;
        }
      } else {
        Logger.log('No enhanced metadata found for: ${file.filename}');
        return false;
      }
    } catch (e) {
      Logger.error('Error in metadata search for $filePath', e);
      return false;
    } finally {
      // Always mark file as no longer updating
      _setFileUpdating(filePath, false);
    }
  }
  
  // Get all series with 2+ books
  Map<String, List<AudiobookFile>> getSeriesWithMultipleBooks() {
    final Map<String, List<AudiobookFile>> series = {};
    
    for (final file in _files) {
      if (file.metadata?.series.isNotEmpty ?? false) {
        final seriesName = file.metadata!.series;
        series[seriesName] ??= [];
        series[seriesName]!.add(file);
      }
    }
    
    // Filter out series with only one book
    series.removeWhere((key, value) => value.length < 2);
    
    return series;
  }
  
  // Check if a book is part of any series
  bool isBookInSeries(AudiobookFile book) {
    return book.metadata?.series.isNotEmpty ?? false;
  }
  
  // Get series info for a book
  Map<String, dynamic>? getSeriesInfoForBook(AudiobookFile book) {
    if (!isBookInSeries(book)) return null;
    
    final seriesName = book.metadata!.series;
    final seriesBooks = getFilesBySeries(seriesName);
    
    return {
      'seriesName': seriesName,
      'position': book.metadata!.seriesPosition,
      'totalBooks': seriesBooks.length,
      'books': seriesBooks,
    };
  }
  
  // Dispose resources
  void dispose() {
    _libraryChangedController.close();
    _coverArtManager.dispose();
  }
}