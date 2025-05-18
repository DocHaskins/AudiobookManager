// File: lib/storage/audiobook_storage_manager.dart
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/storage/library_storage.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// Coordinates between LibraryStorage and MetadataCache to avoid redundant operations
/// and ensure consistent data across storage mechanisms.
class AudiobookStorageManager {
  final LibraryStorage libraryStorage;
  final MetadataCache metadataCache;
  
  // Performance tracking
  DateTime? _lastOperationStart;
  String _lastOperationType = '';
  
  // In-memory processing tracking to avoid duplicates
  final Set<String> _filesBeingProcessed = {};
  
  // Batch size for processing metadata
  static const int _batchSize = 20;
  
  /// Constructor requiring both storage components
  AudiobookStorageManager({
    required this.libraryStorage,
    required this.metadataCache,
  }) {
    Logger.log('AudiobookStorageManager initialized');
  }
  
  /// Save a single audiobook with metadata
  Future<void> saveAudiobook(AudiobookFile audiobook) async {
    // Check if this file is already being processed
    if (_filesBeingProcessed.contains(audiobook.path)) {
      Logger.debug('Skipping duplicate save request for: ${audiobook.filename}');
      return;
    }
    
    _startOperation('save_audiobook');
    _filesBeingProcessed.add(audiobook.path);
    
    try {
      // Save to library storage first
      await libraryStorage.saveAudiobooks([audiobook]);
      
      // Then save metadata if available
      if (audiobook.metadata != null) {
        await metadataCache.saveMetadataForFile(audiobook.path, audiobook.metadata!);
      }
      
      Logger.debug('Saved audiobook: ${audiobook.filename}');
    } catch (e) {
      Logger.error('Failed to save audiobook', e);
    } finally {
      _filesBeingProcessed.remove(audiobook.path);
      _endOperation();
    }
  }
  
  /// Save multiple audiobooks efficiently using batched operations
  Future<void> saveAudiobooks(List<AudiobookFile> audiobooks) async {
    if (audiobooks.isEmpty) return;
    
    _startOperation('save_audiobooks');
    
    try {
      // Filter out files that are already being processed
      final List<AudiobookFile> uniqueBooks = audiobooks.where(
        (book) => !_filesBeingProcessed.contains(book.path)
      ).toList();
      
      if (uniqueBooks.isEmpty) {
        Logger.debug('All ${audiobooks.length} books are already being processed, skipping');
        return;
      }
      
      // Mark all as being processed
      for (var book in uniqueBooks) {
        _filesBeingProcessed.add(book.path);
      }
      
      // First save to library storage
      await libraryStorage.saveAudiobooks(uniqueBooks);
      
      // Then save metadata for books with metadata in batches
      int metadataSaved = 0;
      List<AudiobookFile> booksWithMetadata = uniqueBooks
          .where((book) => book.metadata != null)
          .toList();
          
      if (booksWithMetadata.isNotEmpty) {
        // Process in batches to avoid memory issues with large libraries
        for (int i = 0; i < booksWithMetadata.length; i += _batchSize) {
          int end = (i + _batchSize < booksWithMetadata.length) 
              ? i + _batchSize 
              : booksWithMetadata.length;
              
          List<AudiobookFile> batch = booksWithMetadata.sublist(i, end);
          
          // Process each batch concurrently for better performance
          await Future.wait(
            batch.map((book) => metadataCache.saveMetadataForFile(book.path, book.metadata!))
          );
          
          metadataSaved += batch.length;
        }
      }
      
      Logger.log('Saved ${uniqueBooks.length} audiobooks ($metadataSaved with metadata)');
    } catch (e) {
      Logger.error('Failed to save audiobooks', e);
    } finally {
      // Clear processing flags
      for (var book in audiobooks) {
        _filesBeingProcessed.remove(book.path);
      }
      _endOperation();
    }
  }
  
  /// Save collections efficiently with parallel metadata processing
  Future<void> saveCollections(List<AudiobookCollection> collections) async {
    if (collections.isEmpty) return;
    
    _startOperation('save_collections');
    
    try {
      // Save to library storage
      await libraryStorage.saveCollections(collections);
      
      // For each collection, save metadata for its files if needed
      int collectionsWithMetadata = 0;
      int totalFilesUpdated = 0;
      
      // Process collections in batches
      for (int i = 0; i < collections.length; i += _batchSize) {
        int end = (i + _batchSize < collections.length) 
            ? i + _batchSize 
            : collections.length;
            
        List<AudiobookCollection> batch = collections.sublist(i, end);
        
        // Process each batch
        for (var collection in batch) {
          if (collection.metadata != null) {
            collectionsWithMetadata++;
            
            // Find files that need metadata updates
            List<AudiobookFile> filesToUpdate = collection.files
                .where((file) => 
                    file.metadata == null && 
                    collection.metadata != null && 
                    !_filesBeingProcessed.contains(file.path)
                )
                .toList();
                
            if (filesToUpdate.isNotEmpty) {
              // Mark files as being processed
              for (var file in filesToUpdate) {
                _filesBeingProcessed.add(file.path);
              }
              
              // Update file metadata
              for (var file in filesToUpdate) {
                file.metadata = collection.metadata;
              }
              
              // Save updates in parallel
              try {
                await Future.wait(
                  filesToUpdate.map((file) => 
                      metadataCache.saveMetadataForFile(file.path, file.metadata!))
                );
              } finally {
                // Clear processing flags
                for (var file in filesToUpdate) {
                  _filesBeingProcessed.remove(file.path);
                }
              }
              
              totalFilesUpdated += filesToUpdate.length;
            }
          }
        }
      }
      
      Logger.log('Saved ${collections.length} collections ($collectionsWithMetadata with metadata, updated $totalFilesUpdated files)');
    } catch (e) {
      Logger.error('Failed to save collections', e);
    } finally {
      _endOperation();
    }
  }
  
  /// Load an audiobook and its metadata with improved error handling
  Future<AudiobookFile?> loadAudiobook(String path) async {
    _startOperation('load_audiobook');
    try {
      // First check if book exists in library storage
      final audiobooks = await libraryStorage.loadAudiobooks();
      
      AudiobookFile? existingBook;
      for (var book in audiobooks) {
        if (book.path == path) {
          existingBook = book;
          break;
        }
      }
      
      if (existingBook == null) {
        return null;
      }
      
      // If no metadata, try to get from cache
      if (!existingBook.hasMetadata) {
        final metadata = await metadataCache.getMetadataForFile(path);
        if (metadata != null) {
          existingBook.metadata = metadata;
          Logger.debug('Retrieved cached metadata for: ${existingBook.filename}');
        }
      }
      
      return existingBook;
    } catch (e) {
      Logger.error('Failed to load audiobook', e);
      return null;
    } finally {
      _endOperation();
    }
  }
  
  /// Save the complete library in one operation with optimized batching
  Future<void> saveLibrary(List<AudiobookFile> audiobooks, List<AudiobookCollection> collections) async {
    _startOperation('save_library');
    try {
      Logger.log('Saving complete library to storage via manager (${audiobooks.length} books, ${collections.length} collections)');
      
      // First save to library storage
      await libraryStorage.saveLibrary(audiobooks, collections);
      
      // Count books with metadata to process
      List<AudiobookFile> booksWithMetadata = audiobooks
          .where((book) => 
              book.metadata != null && 
              !_filesBeingProcessed.contains(book.path)
          )
          .toList();
          
      int metadataToSave = booksWithMetadata.length;
      int metadataSaved = 0;
      
      // Process metadata in batches using parallel operations
      if (metadataToSave > 0) {
        // Mark all files as being processed to prevent duplicate saves
        for (var book in booksWithMetadata) {
          _filesBeingProcessed.add(book.path);
        }
        
        try {
          for (int i = 0; i < booksWithMetadata.length; i += _batchSize) {
            int end = (i + _batchSize < booksWithMetadata.length) 
                ? i + _batchSize 
                : booksWithMetadata.length;
                
            List<AudiobookFile> batch = booksWithMetadata.sublist(i, end);
            
            // Process batch in parallel
            await Future.wait(
              batch.map((book) => metadataCache.saveMetadataForFile(book.path, book.metadata!))
            );
            
            metadataSaved += batch.length;
            
            // Log progress for large libraries
            if (metadataToSave > 100 && (i + _batchSize) % 100 == 0) {
              Logger.debug('Metadata saving progress: $metadataSaved of $metadataToSave');
            }
          }
        } finally {
          // Clear processing flags
          for (var book in booksWithMetadata) {
            _filesBeingProcessed.remove(book.path);
          }
        }
      }
      
      Logger.log('Library saved successfully. Metadata saved for $metadataSaved books');
    } catch (e) {
      Logger.error('Failed to save library', e);
    } finally {
      _endOperation();
    }
  }
  
  /// Load the complete library with metadata using optimized batch processing
  Future<Map<String, dynamic>> loadLibrary() async {
    _startOperation('load_library');
    try {
      Logger.log('Loading library from storage via manager');
      
      // First load from library storage
      final libraryData = await libraryStorage.loadLibrary();
      List<AudiobookFile> audiobooks = libraryData['audiobooks'];
      List<AudiobookCollection> collections = libraryData['collections'];
      
      // Update with metadata from cache if needed - find books needing metadata
      List<AudiobookFile> booksNeedingMetadata = audiobooks
          .where((book) => !book.hasMetadata)
          .toList();
            
      int metadataToUpdate = booksNeedingMetadata.length;
      int metadataUpdates = 0;
      
      // Process in batches
      if (metadataToUpdate > 0) {
        for (int i = 0; i < booksNeedingMetadata.length; i += _batchSize) {
          int end = (i + _batchSize < booksNeedingMetadata.length) 
              ? i + _batchSize 
              : booksNeedingMetadata.length;
              
          List<AudiobookFile> batch = booksNeedingMetadata.sublist(i, end);
          
          // Process batch - but maintain book index reference in original list
          List<Future<void>> futures = [];
          for (var book in batch) {
            futures.add(_updateBookMetadata(book));
          }
          
          await Future.wait(futures);
          
          // Count successful updates
          metadataUpdates += batch.where((book) => book.hasMetadata).length;
        }
      }
      
      Logger.log('Library loaded successfully. Updated metadata for $metadataUpdates books');
      
      return {
        'audiobooks': audiobooks,
        'collections': collections,
      };
    } catch (e) {
      Logger.error('Failed to load library', e);
      return {
        'audiobooks': <AudiobookFile>[],
        'collections': <AudiobookCollection>[],
      };
    } finally {
      _endOperation();
    }
  }
  
  /// Update a book's metadata from cache
  Future<void> _updateBookMetadata(AudiobookFile book) async {
    try {
      if (!book.hasMetadata) {
        final metadata = await metadataCache.getMetadataForFile(book.path);
        if (metadata != null) {
          book.metadata = metadata;
        }
      }
    } catch (e) {
      Logger.error('Failed to update metadata for book: ${book.path}', e);
    }
  }
  
  /// Check if a file exists in the library
  Future<bool> hasAudiobook(String path) async {
    return libraryStorage.hasAudiobook(path);
  }
  
  /// Check if a collection exists in the library
  Future<bool> hasCollection(String title) async {
    return libraryStorage.hasCollection(title);
  }
  
  /// Get metadata for a file from cache
  Future<AudiobookMetadata?> getMetadataForFile(String path) async {
    _startOperation('get_metadata');
    try {
      return await metadataCache.getMetadataForFile(path);
    } catch (e) {
      Logger.error('Failed to get metadata for file: $path', e);
      return null;
    } finally {
      _endOperation();
    }
  }
  
  /// Update metadata for a specific file
  Future<bool> updateMetadataForFile(String path, AudiobookMetadata metadata, {bool force = false}) async {
    if (!force && _filesBeingProcessed.contains(path)) {
      Logger.warning('File is already being processed, use force=true to override: $path');
      return false;
    }
    
    _startOperation('update_metadata');
    _filesBeingProcessed.add(path);
    
    try {
      // First check if the book exists in library
      if (!await hasAudiobook(path)) {
        Logger.warning('Cannot update metadata for file not in library: $path');
        return false;
      }
      
      // Log the original thumbnail URL for debugging
      Logger.log('Updating metadata for file: $path');
      Logger.log('Original thumbnail URL: ${metadata.thumbnailUrl}');
      
      // If there's a thumbnail URL, make sure it's copied to the standard location
      String thumbnailUrl = metadata.thumbnailUrl;
      if (thumbnailUrl.isNotEmpty) {
        // Always normalize path separators 
        thumbnailUrl = thumbnailUrl.replaceAll('/', Platform.isWindows ? '\\' : '/');
        
        // Ensure the cover image is in the standard location
        final standardPath = await ensureCoverImage(path, thumbnailUrl, force: force);
        if (standardPath.isNotEmpty) {
          thumbnailUrl = standardPath;
          Logger.log('Standardized thumbnail URL: $thumbnailUrl');
        }
      }
      
      // Create updated metadata with the correct thumbnail path
      final updatedMetadata = metadata.copyWith(thumbnailUrl: thumbnailUrl);
      
      // Save to metadata cache
      Logger.log('Saving metadata to cache with thumbnail: ${updatedMetadata.thumbnailUrl}');
      await metadataCache.saveMetadataForFile(path, updatedMetadata);
      
      // Also update in library storage
      final audiobooks = await libraryStorage.loadAudiobooks();
      for (var book in audiobooks) {
        if (book.path == path) {
          Logger.log('Updating book in library storage');
          book.metadata = updatedMetadata;
          await libraryStorage.saveAudiobooks([book]);
          break;
        }
      }
      
      Logger.log('Successfully updated metadata for file: $path');
      return true;
    } catch (e) {
      Logger.error('Failed to update metadata', e);
      return false;
    } finally {
      _filesBeingProcessed.remove(path);
      _endOperation();
    }
  }

  /// Clear all data from both storage mechanisms
  Future<void> clearAll() async {
    _startOperation('clear_all');
    try {
      await libraryStorage.clearLibrary();
      await metadataCache.clearCache();
      Logger.log('Cleared all library and metadata storage');
    } catch (e) {
      Logger.error('Failed to clear storage', e);
    } finally {
      _endOperation();
    }
  }
  
  /// Check if a file is currently being processed
  bool isFileBeingProcessed(String path) {
    return _filesBeingProcessed.contains(path);
  }
  
  /// Performance tracking - start operation
  void _startOperation(String operationType) {
    _lastOperationStart = DateTime.now();
    _lastOperationType = operationType;
  }
  
  /// Performance tracking - end operation and log if slow
  void _endOperation() {
    if (_lastOperationStart != null) {
      final duration = DateTime.now().difference(_lastOperationStart!);
      
      // Only log slow operations (over 500ms)
      if (duration.inMilliseconds > 500) {
        Logger.debug('Storage operation $_lastOperationType took ${duration.inMilliseconds}ms');
      }
      
      _lastOperationStart = null;
    }
  }

  /// Copy a cover image to the standard location for an audiobook file
  /// Returns the standardized path if successful, or empty string if not
  Future<String> ensureCoverImage(String filePath, String? currentImagePath, {bool force = false}) async {
    try {
      Logger.log('ensureCoverImage for $filePath with image: $currentImagePath (force: $force)');
      
      // If no image, return empty
      if (currentImagePath == null || currentImagePath.isEmpty) {
        Logger.log('No image path provided, returning empty string');
        return '';
      }

      // Normalize path separators for consistent handling
      final normalizedImagePath = currentImagePath.replaceAll('/', path.separator);
      Logger.log('Normalized image path: $normalizedImagePath');
      
      // Check if the image exists
      final imageFile = File(normalizedImagePath);
      final exists = await imageFile.exists();
      
      if (!exists) {
        // Try alternate path separators as diagnostic
        final alternateImagePath = currentImagePath.replaceAll('\\', '/');
        final alternateFile = File(alternateImagePath);
        final alternateExists = await alternateFile.exists();
        
        if (alternateExists) {
          Logger.log('Image exists with alternate separators, using: $alternateImagePath');
          return alternateImagePath;
        }
        
        Logger.warning('Cover image does not exist with any path format: $normalizedImagePath');
        return '';
      }

      // Create the covers directory path in the same folder as the audio file
      final audioDir = path.dirname(filePath);
      final coversDir = path.join(audioDir, 'covers');
      final coversDirRef = Directory(coversDir);
      
      // Create the directory if it doesn't exist
      if (!await coversDirRef.exists()) {
        Logger.log('Creating covers directory: $coversDir');
        await coversDirRef.create(recursive: true);
      }
      
      // Create a consistent filename for the cover
      final audioFilename = path.basenameWithoutExtension(filePath);
      final coverFilename = '$audioFilename.jpg';
      final coverPath = path.join(coversDir, coverFilename);
      Logger.log('Target cover path: $coverPath');
      
      // If the image is already in the correct location, just return its path
      if (normalizedImagePath == coverPath) {
        Logger.log('Image already in correct location');
        return coverPath;
      }
      
      // If force is true or the destination doesn't exist, copy the file
      final destFile = File(coverPath);
      if (force || !await destFile.exists()) {
        // If forcing and file exists, delete it first
        if (force && await destFile.exists()) {
          await destFile.delete();
          Logger.log('Deleted existing cover for forced update');
        }
        
        try {
          await imageFile.copy(coverPath);
          Logger.log('Successfully copied cover image to: $coverPath');
        } catch (e) {
          // If the file already exists, no need to copy again
          if (e is FileSystemException && e.message.contains('already exists')) {
            Logger.log('Cover image already exists at destination: $coverPath');
          } else {
            Logger.error('Error copying image:', e);
            throw e;
          }
        }
        
        return coverPath;
      } else {
        Logger.log('Keeping existing cover image at: $coverPath (force=false)');
        return coverPath;
      }
    } catch (e) {
      Logger.error('Error ensuring cover image: $e', e);
      return '';
    }
  }
  
  /// Verify and repair image references in the library
  Future<int> verifyAndRepairImageReferences() async {
    try {
      Logger.log('Starting verification of image references');
      final libraryData = await loadLibrary();
      final audiobooks = libraryData['audiobooks'] as List<AudiobookFile>;
      
      int repaired = 0;
      
      for (final book in audiobooks) {
        if (book.metadata != null && book.metadata!.thumbnailUrl.isNotEmpty) {
          final imageFile = File(book.metadata!.thumbnailUrl);
          if (!await imageFile.exists()) {
            final expectedPath = path.join(
              path.dirname(book.path), 
              'covers', 
              '${path.basenameWithoutExtension(book.path)}.jpg'
            );
            final expectedFile = File(expectedPath);
            if (await expectedFile.exists()) {
              book.metadata = book.metadata!.copyWith(thumbnailUrl: expectedPath);
              repaired++;
              
              // Also update the metadata cache
              await metadataCache.saveMetadataForFile(book.path, book.metadata!);
            }
          }
        }
      }
      
      Logger.log('Image reference verification complete. Repaired $repaired images.');
      return repaired;
    } catch (e) {
      Logger.error('Error verifying image references', e);
      return 0;
    }
  }
  
  /// Get stats about the library storage
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final audiobooks = await libraryStorage.loadAudiobooks();
      final collections = await libraryStorage.loadCollections();
      final cacheSize = await metadataCache.getCacheSize();
      
      return {
        'audiobooks_count': audiobooks.length,
        'collections_count': collections.length,
        'metadata_cache_size': cacheSize,
        'audiobooks_with_metadata': audiobooks.where((book) => book.hasMetadata).length,
        'audiobooks_with_file_metadata': audiobooks.where((book) => book.hasFileMetadata).length,
        'files_being_processed': _filesBeingProcessed.length,
      };
    } catch (e) {
      Logger.error('Failed to get storage stats', e);
      return {
        'error': 'Failed to get storage stats',
      };
    }
  }
}