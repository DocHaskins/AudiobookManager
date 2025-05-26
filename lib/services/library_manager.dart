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
import 'package:audiobook_organizer/utils/filename_parser.dart';
import 'package:audiobook_organizer/utils/file_utils.dart';
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

  // Add this getter (THIS IS WHAT'S MISSING)
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
    
    // Update storage
    await _storageManager.saveLibrary(_files);
    
    // Notify listeners
    _libraryChangedController.add(_files);
    
    Logger.log('Removed directory and cleaned up ${removedFiles.length} covers: $directoryPath');
  }
  
  // Scan a directory for audiobooks
  Future<List<AudiobookFile>> scanDirectory(String directoryPath) async {
    if (_isLoading) {
      Logger.warning('Scan already in progress, please wait');
      return [];
    }
    
    _isLoading = true;
    
    try {
      Logger.log('Scanning directory: $directoryPath');
      
      // Scan for files
      final newFiles = await _scanner.scanDirectory(directoryPath);
      
      // Filter out files we already have
      final filesToAdd = newFiles.where((newFile) {
        return !_files.any((existingFile) => existingFile.path == newFile.path);
      }).toList();
      
      if (filesToAdd.isEmpty) {
        Logger.log('No new files found in directory: $directoryPath');
        _isLoading = false;
        return [];
      }
      
      Logger.log('Found ${filesToAdd.length} new files in directory: $directoryPath');
      
      // Process files in batches to prevent UI freezes
      const int batchSize = 5;
      for (int i = 0; i < filesToAdd.length; i += batchSize) {
        final end = (i + batchSize < filesToAdd.length) ? i + batchSize : filesToAdd.length;
        final batch = filesToAdd.sublist(i, end);
        
        // Process batch
        await _processBatch(batch);
        
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
  
  // Process a batch of files - CORRECTED FLOW
  Future<void> _processBatch(List<AudiobookFile> batch) async {
    final metadataService = MetadataService();
    await metadataService.initialize();

    for (final file in batch) {
      try {
        Logger.debug('Processing file: ${file.path}');
        
        // Try to load metadata from storage first
        final storedMetadata = await _storageManager.getMetadataForFile(file.path);
        if (storedMetadata != null) {
          file.metadata = storedMetadata;
          Logger.debug('Loaded stored metadata for: ${file.filename}');
          continue;
        }
        
        // Extract basic metadata (no cover)
        final fileMetadata = await metadataService.extractMetadata(file.path);
        
        if (fileMetadata != null) {
          Logger.debug('Extracted file metadata for: ${file.filename}');
          
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
          await _storageManager.updateMetadataForFile(file.path, metadataWithCover);
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
      
      return await updateMetadata(file, updatedMetadata);
    } catch (e) {
      Logger.error('Error in _updateFileMetadata for ${file.filename}', e);
      return false;
    }
  }

  Future<bool> updateMetadata(AudiobookFile file, AudiobookMetadata metadata) async {
    try {
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
        
        // CRITICAL: Save the entire library to ensure persistence
        await _storageManager.saveLibrary(_files);
        
        // Find and update the file in the library list
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
    try {
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
    return _updateFileMetadata(file, (metadata) => metadata.copyWith(
      userRating: userRating ?? metadata.userRating,
      lastPlayedPosition: lastPlayedPosition ?? metadata.lastPlayedPosition,
      playbackPosition: playbackPosition ?? metadata.playbackPosition,
      userTags: userTags ?? metadata.userTags,
      isFavorite: isFavorite ?? metadata.isFavorite,
      bookmarks: bookmarks ?? metadata.bookmarks,
      notes: notes ?? metadata.notes,
    ));
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