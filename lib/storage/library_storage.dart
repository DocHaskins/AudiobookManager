// File: lib/storage/library_storage.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;

import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// Manages persistent storage of audiobook library data
class LibraryStorage {
  // File name constants
  static const String _libraryFileName = 'audiobook_library.json';
  static const String _collectionsFileName = 'audiobook_collections.json';
  
  // In-memory cache of path-to-book mappings to prevent duplicates
  final Map<String, AudiobookFile> _pathToBookCache = {};
  final Map<String, AudiobookCollection> _titleToCollectionCache = {};
  
  /// Get the application documents directory
  Future<Directory> _getApplicationDirectory() async {
    try {
      // Use the app documents directory for persistent storage
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      Logger.error('Failed to get application directory', e);
      rethrow;
    }
  }
  
  /// Get the path for the library file
  Future<String> _getLibraryFilePath() async {
    try {
      final directory = await _getApplicationDirectory();
      return path_util.join(directory.path, _libraryFileName);
    } catch (e) {
      Logger.error('Failed to get library file path', e);
      rethrow;
    }
  }
  
  /// Get the path for the collections file
  Future<String> _getCollectionsFilePath() async {
    try {
      final directory = await _getApplicationDirectory();
      return path_util.join(directory.path, _collectionsFileName);
    } catch (e) {
      Logger.error('Failed to get collections file path', e);
      rethrow;
    }
  }
  
  /// Ensure the directory exists for the given file path
  Future<void> _ensureDirectoryExists(String filePath) async {
    try {
      final dir = Directory(path_util.dirname(filePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      Logger.error('Failed to create directory', e);
      rethrow;
    }
  }
  
  /// Convert AudiobookFile to JSON
  Map<String, dynamic> _audiobookToJson(AudiobookFile book) {
    return {
      'path': book.path,
      'filename': book.filename,
      'extension': book.extension,
      'size': book.size,
      'lastModified': book.lastModified.toIso8601String(),
      'metadata': book.metadata?.toMap(),
      'fileMetadata': book.fileMetadata?.toMap(),
    };
  }
  
  /// Create AudiobookFile from JSON
  AudiobookFile _jsonToAudiobook(Map<String, dynamic> json) {
    return AudiobookFile(
      path: json['path'],
      filename: json['filename'],
      extension: json['extension'],
      size: json['size'] as int,
      lastModified: DateTime.parse(json['lastModified']),
      metadata: json['metadata'] != null 
          ? AudiobookMetadata.fromMap(json['metadata']) 
          : null,
      fileMetadata: json['fileMetadata'] != null 
          ? AudiobookMetadata.fromMap(json['fileMetadata']) 
          : null,
    );
  }
  
  /// Save individual audiobooks
  Future<void> saveAudiobooks(List<AudiobookFile> audiobooks) async {
    try {
      final filePath = await _getLibraryFilePath();
      await _ensureDirectoryExists(filePath);
      
      // First, load existing books if the cache is empty
      if (_pathToBookCache.isEmpty) {
        await loadAudiobooks();
      }
      
      // Add new books to the cache, avoiding duplicates
      int newBooks = 0;
      for (final book in audiobooks) {
        if (!_pathToBookCache.containsKey(book.path)) {
          _pathToBookCache[book.path] = book;
          newBooks++;
        } else {
          // Update metadata if it's changed
          final existingBook = _pathToBookCache[book.path]!;
          if (book.metadata != null && 
             (existingBook.metadata == null || 
              existingBook.metadata!.id != book.metadata!.id)) {
            _pathToBookCache[book.path] = book;
            Logger.debug('Updated metadata for existing book: ${book.path}');
          }
        }
      }
      
      final file = File(filePath);
      
      // Convert only the unique books in the cache to JSON
      final List<Map<String, dynamic>> audiobooksJson = 
          _pathToBookCache.values.map(_audiobookToJson).toList();
      
      // Write to file
      await file.writeAsString(jsonEncode(audiobooksJson));
      
      Logger.log('Saved library with ${_pathToBookCache.length} audiobooks (${newBooks} new)');
    } catch (e) {
      Logger.error('Failed to save audiobooks', e);
    }
  }
  
  /// Save collections
  Future<void> saveCollections(List<AudiobookCollection> collections) async {
    try {
      final filePath = await _getCollectionsFilePath();
      await _ensureDirectoryExists(filePath);
      
      // First, load existing collections if the cache is empty
      if (_titleToCollectionCache.isEmpty) {
        await loadCollections();
      }
      
      // Add new collections to the cache, avoiding duplicates
      int newCollections = 0;
      for (final collection in collections) {
        // Use a unique key based on title and file paths
        final key = collection.title;
        if (!_titleToCollectionCache.containsKey(key)) {
          _titleToCollectionCache[key] = collection;
          newCollections++;
        } else {
          // Update if metadata has changed
          if (collection.metadata != null && 
              _titleToCollectionCache[key]!.metadata?.id != collection.metadata?.id) {
            _titleToCollectionCache[key] = collection;
            Logger.debug('Updated metadata for existing collection: ${collection.title}');
          }
        }
      }
      
      final file = File(filePath);
      
      // Convert each AudiobookCollection to JSON
      final List<Map<String, dynamic>> collectionsJson = _titleToCollectionCache.values.map((collection) {
        return {
          'title': collection.title,
          'directoryPath': collection.directoryPath,
          'metadata': collection.metadata?.toMap(),
          'files': collection.files.map(_audiobookToJson).toList(),
        };
      }).toList();
      
      // Write to file
      await file.writeAsString(jsonEncode(collectionsJson));
      Logger.log('Saved ${_titleToCollectionCache.length} collections to storage (${newCollections} new)');
    } catch (e) {
      Logger.error('Failed to save collections', e);
    }
  }
  
  /// Load individual audiobooks
  Future<List<AudiobookFile>> loadAudiobooks() async {
    try {
      final filePath = await _getLibraryFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        Logger.debug('No saved audiobooks found at $filePath');
        // Clear the cache if file doesn't exist
        _pathToBookCache.clear();
        return [];
      }
      
      final String content = await file.readAsString();
      final List<dynamic> audiobooksJson = jsonDecode(content);
      
      // Clear existing cache
      _pathToBookCache.clear();
      
      final audiobooks = audiobooksJson
          .map<AudiobookFile>((json) => _jsonToAudiobook(json))
          .toList();
      
      // Rebuild the cache
      for (final book in audiobooks) {
        _pathToBookCache[book.path] = book;
      }
      
      Logger.log('Loaded ${audiobooks.length} audiobooks from storage');
      return audiobooks;
    } catch (e) {
      Logger.error('Failed to load audiobooks', e);
      _pathToBookCache.clear();
      return [];
    }
  }
  
  /// Load collections
  Future<List<AudiobookCollection>> loadCollections() async {
    try {
      final filePath = await _getCollectionsFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        Logger.debug('No saved collections found at $filePath');
        // Clear the cache if file doesn't exist
        _titleToCollectionCache.clear();
        return [];
      }
      
      final String content = await file.readAsString();
      final List<dynamic> collectionsJson = jsonDecode(content);
      
      // Clear existing cache
      _titleToCollectionCache.clear();
      
      final collections = collectionsJson.map<AudiobookCollection>((json) {
        final List<AudiobookFile> files = (json['files'] as List)
            .map<AudiobookFile>((fileJson) => _jsonToAudiobook(fileJson))
            .toList();
        
        final collection = AudiobookCollection(
          title: json['title'],
          files: files,
          directoryPath: json['directoryPath'],
          metadata: json['metadata'] != null 
              ? AudiobookMetadata.fromMap(json['metadata']) 
              : null,
        );
        
        // Add to cache
        _titleToCollectionCache[collection.title] = collection;
        
        return collection;
      }).toList();
      
      Logger.log('Loaded ${collections.length} collections from storage');
      return collections;
    } catch (e) {
      Logger.error('Failed to load collections', e);
      _titleToCollectionCache.clear();
      return [];
    }
  }
  
  /// Check if files still exist and return valid ones
  Future<List<AudiobookFile>> validateAudiobooks(List<AudiobookFile> audiobooks) async {
    try {
      final List<AudiobookFile> validBooks = [];
      final Set<String> invalidPaths = {};
      
      for (var book in audiobooks) {
        final file = File(book.path);
        if (await file.exists()) {
          validBooks.add(book);
        } else {
          Logger.debug('File no longer exists: ${book.path}');
          invalidPaths.add(book.path);
        }
      }
      
      // Also remove invalid paths from the cache
      for (final path in invalidPaths) {
        _pathToBookCache.remove(path);
      }
      
      Logger.log('Validated ${validBooks.length} of ${audiobooks.length} audiobooks');
      return validBooks;
    } catch (e) {
      Logger.error('Error validating audiobooks', e);
      return audiobooks; // Return original list on error
    }
  }
  
  /// Check if collection files still exist and return valid collections
  Future<List<AudiobookCollection>> validateCollections(List<AudiobookCollection> collections) async {
    try {
      List<AudiobookCollection> validCollections = [];
      Set<String> invalidCollectionTitles = {};
      
      for (var collection in collections) {
        final List<AudiobookFile> validFiles = [];
        
        for (var book in collection.files) {
          final file = File(book.path);
          if (await file.exists()) {
            validFiles.add(book);
          } else {
            Logger.debug('File in collection no longer exists: ${book.path}');
          }
        }
        
        if (validFiles.isNotEmpty) {
          validCollections.add(AudiobookCollection(
            title: collection.title,
            files: validFiles,
            directoryPath: collection.directoryPath,
            metadata: collection.metadata,
          ));
        } else {
          Logger.debug('Collection has no valid files: ${collection.title}');
          invalidCollectionTitles.add(collection.title);
        }
      }
      
      // Remove invalid collections from cache
      for (final title in invalidCollectionTitles) {
        _titleToCollectionCache.remove(title);
      }
      
      Logger.log('Validated ${validCollections.length} of ${collections.length} collections');
      return validCollections;
    } catch (e) {
      Logger.error('Error validating collections', e);
      return collections; // Return original list on error
    }
  }
  
  /// Save the complete library (audiobooks and collections)
  Future<void> saveLibrary(List<AudiobookFile> audiobooks, List<AudiobookCollection> collections) async {
    try {
      Logger.log('Saving complete library to storage');
      await saveAudiobooks(audiobooks);
      await saveCollections(collections);
      Logger.log('Library saved successfully');
    } catch (e) {
      Logger.error('Failed to save library', e);
    }
  }
  
  /// Load and validate the complete library
  Future<Map<String, dynamic>> loadLibrary() async {
    try {
      Logger.log('Loading library from storage');
      
      final audiobooks = await loadAudiobooks();
      final collections = await loadCollections();
      
      // Validate to ensure files still exist
      final validAudiobooks = await validateAudiobooks(audiobooks);
      final validCollections = await validateCollections(collections);
      
      Logger.log('Library loaded and validated successfully');
      
      return {
        'audiobooks': validAudiobooks,
        'collections': validCollections,
      };
    } catch (e) {
      Logger.error('Failed to load library', e);
      return {
        'audiobooks': <AudiobookFile>[],
        'collections': <AudiobookCollection>[],
      };
    }
  }
  
  /// Check if a file is already in the library
  bool hasAudiobook(String filePath) {
    return _pathToBookCache.containsKey(filePath);
  }
  
  /// Check if a collection is already in the library
  bool hasCollection(String title) {
    return _titleToCollectionCache.containsKey(title);
  }
  
  /// Clear the entire library
  Future<void> clearLibrary() async {
    try {
      Logger.log('Clearing library storage');
      
      final audiobooksPath = await _getLibraryFilePath();
      final collectionsPath = await _getCollectionsFilePath();
      
      final audiobooksFile = File(audiobooksPath);
      final collectionsFile = File(collectionsPath);
      
      if (await audiobooksFile.exists()) {
        await audiobooksFile.delete();
        Logger.log('Deleted audiobooks storage file');
      }
      
      if (await collectionsFile.exists()) {
        await collectionsFile.delete();
        Logger.log('Deleted collections storage file');
      }
      
      // Clear in-memory caches
      _pathToBookCache.clear();
      _titleToCollectionCache.clear();
      
      Logger.log('Library storage cleared successfully');
    } catch (e) {
      Logger.error('Failed to clear library', e);
      rethrow;
    }
  }
}