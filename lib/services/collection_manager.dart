// lib/services/collection_manager.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class CollectionManager {
  final LibraryManager _libraryManager;
  
  // Collections storage
  List<Collection> _collections = [];
  final _collectionsFile = 'collections.json';
  late final String _storagePath;
  
  // Stream controllers
  final _collectionsChangedController = StreamController<List<Collection>>.broadcast();
  Stream<List<Collection>> get collectionsChanged => _collectionsChangedController.stream;
  
  // Constructor
  CollectionManager({required LibraryManager libraryManager}) 
      : _libraryManager = libraryManager;
  
  // Initialize
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _storagePath = path_util.join(appDir.path, 'audiobooks', _collectionsFile);
      
      // Load existing collections
      await _loadCollections();
      
      // Listen to library changes to auto-update collections
      _libraryManager.libraryChanged.listen((_) {
        _updateAutoCollections();
      });
      
      // Initial auto-collection creation
      await _updateAutoCollections();
      
      Logger.log('CollectionManager initialized with ${_collections.length} collections');
    } catch (e) {
      Logger.error('Error initializing CollectionManager', e);
    }
  }
  
  // Load collections from storage
  Future<void> _loadCollections() async {
    try {
      final file = File(_storagePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        final collectionsList = jsonData['collections'] as List;
        
        _collections = collectionsList
            .map((json) => Collection.fromJson(json))
            .toList();
            
        Logger.log('Loaded ${_collections.length} collections from storage');
      }
    } catch (e) {
      Logger.error('Error loading collections', e);
      _collections = [];
    }
  }
  
  // Save collections to storage
  Future<void> _saveCollections() async {
    try {
      final file = File(_storagePath);
      await file.create(recursive: true);
      
      final jsonData = {
        'collections': _collections.map((c) => c.toJson()).toList(),
      };
      
      await file.writeAsString(json.encode(jsonData));
      Logger.log('Saved ${_collections.length} collections to storage');
    } catch (e) {
      Logger.error('Error saving collections', e);
    }
  }
  
  // Update auto-collections based on series
  Future<void> _updateAutoCollections() async {
    try {
      final books = _libraryManager.files;
      
      // Group books by series
      final Map<String, List<AudiobookFile>> booksBySeries = {};
      
      for (final book in books) {
        if (book.metadata?.series.isNotEmpty ?? false) {
          final series = book.metadata!.series;
          booksBySeries[series] ??= [];
          booksBySeries[series]!.add(book);
        }
      }
      
      // Update or create series collections
      for (final entry in booksBySeries.entries) {
        final seriesName = entry.key;
        final seriesBooks = entry.value;
        
        // Skip if only one book in series
        if (seriesBooks.length < 2) continue;
        
        // Check if collection already exists
        final existingIndex = _collections.indexWhere(
          (c) => c.type == CollectionType.series && 
                 c.metadata['seriesName'] == seriesName
        );
        
        if (existingIndex >= 0) {
          // Update existing collection
          final existing = _collections[existingIndex];
          final updatedPaths = seriesBooks.map((b) => b.path).toList();
          
          // Only update if paths changed
          if (!_listEquals(existing.bookPaths, updatedPaths)) {
            _collections[existingIndex] = existing.copyWith(
              bookPaths: updatedPaths,
              updatedAt: DateTime.now(),
            );
            Logger.log('Updated series collection: $seriesName');
          }
        } else {
          // Create new collection
          final collection = Collection.fromSeries(seriesName, seriesBooks);
          _collections.add(collection);
          Logger.log('Created series collection: $seriesName with ${seriesBooks.length} books');
        }
      }
      
      // Remove auto-collections for series that no longer exist
      _collections.removeWhere((collection) {
        if (collection.type == CollectionType.series && 
            (collection.metadata['autoCreated'] == true)) {
          final seriesName = collection.metadata['seriesName'];
          return !booksBySeries.containsKey(seriesName);
        }
        return false;
      });
      
      await _saveCollections();
      _notifyListeners();
    } catch (e) {
      Logger.error('Error updating auto-collections', e);
    }
  }
  
  // Create custom collection
  Future<Collection?> createCollection({
    required String name,
    String? description,
    List<String>? bookPaths,
    CollectionType type = CollectionType.custom,
  }) async {
    try {
      // Check if collection with same name exists
      if (_collections.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
        Logger.warning('Collection with name "$name" already exists');
        return null;
      }
      
      final collection = Collection.create(
        name: name,
        description: description,
        bookPaths: bookPaths,
        type: type,
      );
      
      _collections.add(collection);
      await _saveCollections();
      _notifyListeners();
      
      Logger.log('Created collection: $name');
      return collection;
    } catch (e) {
      Logger.error('Error creating collection', e);
      return null;
    }
  }
  
  // Update collection
  Future<bool> updateCollection(Collection collection) async {
    try {
      final index = _collections.indexWhere((c) => c.id == collection.id);
      if (index < 0) {
        Logger.warning('Collection not found: ${collection.id}');
        return false;
      }
      
      _collections[index] = collection.copyWith(updatedAt: DateTime.now());
      await _saveCollections();
      _notifyListeners();
      
      Logger.log('Updated collection: ${collection.name}');
      return true;
    } catch (e) {
      Logger.error('Error updating collection', e);
      return false;
    }
  }
  
  // Delete collection
  Future<bool> deleteCollection(String collectionId) async {
    try {
      final initialLength = _collections.length;
      _collections.removeWhere((c) => c.id == collectionId);
      final removedCount = initialLength - _collections.length;
      
      if (removedCount > 0) {
        await _saveCollections();
        _notifyListeners();
        Logger.log('Deleted collection: $collectionId');
        return true;
      }
      
      return false;
    } catch (e) {
      Logger.error('Error deleting collection', e);
      return false;
    }
  }
  
  // Add book to collection
  Future<bool> addBookToCollection(String collectionId, String bookPath) async {
    try {
      final index = _collections.indexWhere((c) => c.id == collectionId);
      if (index < 0) return false;
      
      _collections[index] = _collections[index].addBook(bookPath);
      await _saveCollections();
      _notifyListeners();
      
      return true;
    } catch (e) {
      Logger.error('Error adding book to collection', e);
      return false;
    }
  }
  
  // Remove book from collection
  Future<bool> removeBookFromCollection(String collectionId, String bookPath) async {
    try {
      final index = _collections.indexWhere((c) => c.id == collectionId);
      if (index < 0) return false;
      
      _collections[index] = _collections[index].removeBook(bookPath);
      await _saveCollections();
      _notifyListeners();
      
      return true;
    } catch (e) {
      Logger.error('Error removing book from collection', e);
      return false;
    }
  }
  
  // Get collection by ID
  Collection? getCollection(String collectionId) {
    try {
      return _collections.firstWhere((c) => c.id == collectionId);
    } catch (e) {
      return null;
    }
  }
  
  // Get collections for a book
  List<Collection> getCollectionsForBook(String bookPath) {
    return _collections.where((c) => c.containsBook(bookPath)).toList();
  }
  
  // Get all collections
  List<Collection> get collections => List.unmodifiable(_collections);
  
  // Get collections by type
  List<Collection> getCollectionsByType(CollectionType type) {
    return _collections.where((c) => c.type == type).toList();
  }
  
  // Search collections
  List<Collection> searchCollections(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _collections.where((c) {
      return c.name.toLowerCase().contains(lowercaseQuery) ||
             (c.description?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }
  
  // Get collection statistics
  Map<String, dynamic> getCollectionStats() {
    final stats = <String, dynamic>{};
    
    stats['totalCollections'] = _collections.length;
    stats['seriesCollections'] = _collections.where((c) => c.type == CollectionType.series).length;
    stats['customCollections'] = _collections.where((c) => c.type == CollectionType.custom).length;
    stats['totalBooksInCollections'] = _collections.fold<int>(
      0, (sum, c) => sum + c.bookCount
    );
    
    return stats;
  }
  
  // Notify listeners
  void _notifyListeners() {
    _collectionsChangedController.add(List.unmodifiable(_collections));
  }
  
  // Helper to compare lists
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  
  // Dispose
  void dispose() {
    _collectionsChangedController.close();
  }
}