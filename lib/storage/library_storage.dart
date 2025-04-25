// File: lib/storage/library_storage.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';

class LibraryStorage {
  static const String _libraryFileName = 'audiobook_library.json';
  static const String _collectionsFileName = 'audiobook_collections.json';
  
  Future<Directory> _getApplicationDirectory() async {
    // Use the app documents directory for persistent storage
    return await getApplicationDocumentsDirectory();
  }
  
  Future<String> _getLibraryFilePath() async {
    final directory = await _getApplicationDirectory();
    return path.join(directory.path, _libraryFileName);
  }
  
  Future<String> _getCollectionsFilePath() async {
    final directory = await _getApplicationDirectory();
    return path.join(directory.path, _collectionsFileName);
  }
  
  // Save individual audiobooks
  Future<void> saveAudiobooks(List<AudiobookFile> audiobooks) async {
    try {
      final filePath = await _getLibraryFilePath();
      final file = File(filePath);
      
      // Create directory if it doesn't exist
      final dir = Directory(path.dirname(filePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Convert each AudiobookFile to JSON
      final List<Map<String, dynamic>> audiobooksJson = audiobooks.map((book) {
        return {
          'path': book.path,
          'filename': book.filename,
          'extension': book.extension,
          'size': book.size,
          'lastModified': book.lastModified.toIso8601String(),
          'metadata': book.metadata?.toMap(),
        };
      }).toList();
      
      // Write to file
      await file.writeAsString(jsonEncode(audiobooksJson));
      print('LOG: Saved ${audiobooks.length} audiobooks to $filePath');
    } catch (e) {
      print('ERROR: Failed to save audiobooks: $e');
    }
  }
  
  // Save collections
  Future<void> saveCollections(List<AudiobookCollection> collections) async {
    try {
      final filePath = await _getCollectionsFilePath();
      final file = File(filePath);
      
      // Create directory if it doesn't exist
      final dir = Directory(path.dirname(filePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Convert each AudiobookCollection to JSON
      final List<Map<String, dynamic>> collectionsJson = collections.map((collection) {
        return {
          'title': collection.title,
          'directoryPath': collection.directoryPath,
          'metadata': collection.metadata?.toMap(),
          'files': collection.files.map((book) {
            return {
              'path': book.path,
              'filename': book.filename,
              'extension': book.extension,
              'size': book.size,
              'lastModified': book.lastModified.toIso8601String(),
              'metadata': book.metadata?.toMap(),
            };
          }).toList(),
        };
      }).toList();
      
      // Write to file
      await file.writeAsString(jsonEncode(collectionsJson));
      print('LOG: Saved ${collections.length} collections to $filePath');
    } catch (e) {
      print('ERROR: Failed to save collections: $e');
    }
  }
  
  // Load individual audiobooks
  Future<List<AudiobookFile>> loadAudiobooks() async {
    try {
      final filePath = await _getLibraryFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        print('LOG: No saved audiobooks found at $filePath');
        return [];
      }
      
      final String content = await file.readAsString();
      final List<dynamic> audiobooksJson = jsonDecode(content);
      
      return audiobooksJson.map<AudiobookFile>((json) {
        return AudiobookFile(
          path: json['path'],
          filename: json['filename'],
          extension: json['extension'],
          size: json['size'],
          lastModified: DateTime.parse(json['lastModified']),
          metadata: json['metadata'] != null 
              ? AudiobookMetadata.fromMap(json['metadata']) 
              : null,
        );
      }).toList();
    } catch (e) {
      print('ERROR: Failed to load audiobooks: $e');
      return [];
    }
  }
  
  // Load collections
  Future<List<AudiobookCollection>> loadCollections() async {
    try {
      final filePath = await _getCollectionsFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        print('LOG: No saved collections found at $filePath');
        return [];
      }
      
      final String content = await file.readAsString();
      final List<dynamic> collectionsJson = jsonDecode(content);
      
      return collectionsJson.map<AudiobookCollection>((json) {
        final List<AudiobookFile> files = (json['files'] as List).map<AudiobookFile>((fileJson) {
          return AudiobookFile(
            path: fileJson['path'],
            filename: fileJson['filename'],
            extension: fileJson['extension'],
            size: fileJson['size'],
            lastModified: DateTime.parse(fileJson['lastModified']),
            metadata: fileJson['metadata'] != null 
                ? AudiobookMetadata.fromMap(fileJson['metadata']) 
                : null,
          );
        }).toList();
        
        return AudiobookCollection(
          title: json['title'],
          files: files,
          directoryPath: json['directoryPath'],
          metadata: json['metadata'] != null 
              ? AudiobookMetadata.fromMap(json['metadata']) 
              : null,
        );
      }).toList();
    } catch (e) {
      print('ERROR: Failed to load collections: $e');
      return [];
    }
  }
  
  // Check if files still exist
  Future<List<AudiobookFile>> validateAudiobooks(List<AudiobookFile> audiobooks) async {
    return audiobooks.where((book) {
      final file = File(book.path);
      return file.existsSync();
    }).toList();
  }
  
  // Check if collection files still exist
  Future<List<AudiobookCollection>> validateCollections(List<AudiobookCollection> collections) async {
    List<AudiobookCollection> validCollections = [];
    
    for (var collection in collections) {
      final List<AudiobookFile> validFiles = collection.files.where((book) {
        final file = File(book.path);
        return file.existsSync();
      }).toList();
      
      if (validFiles.isNotEmpty) {
        validCollections.add(AudiobookCollection(
          title: collection.title,
          files: validFiles,
          directoryPath: collection.directoryPath,
          metadata: collection.metadata,
        ));
      }
    }
    
    return validCollections;
  }
  
  // Save the complete library (audiobooks and collections)
  Future<void> saveLibrary(List<AudiobookFile> audiobooks, List<AudiobookCollection> collections) async {
    await saveAudiobooks(audiobooks);
    await saveCollections(collections);
  }
  
  // Load and validate the complete library
  Future<Map<String, dynamic>> loadLibrary() async {
    final audiobooks = await loadAudiobooks();
    final collections = await loadCollections();
    
    final validAudiobooks = await validateAudiobooks(audiobooks);
    final validCollections = await validateCollections(collections);
    
    return {
      'audiobooks': validAudiobooks,
      'collections': validCollections,
    };
  }
  
  // Clear the entire library
  Future<void> clearLibrary() async {
    try {
      final audiobooksPath = await _getLibraryFilePath();
      final collectionsPath = await _getCollectionsFilePath();
      
      final audiobooksFile = File(audiobooksPath);
      final collectionsFile = File(collectionsPath);
      
      if (await audiobooksFile.exists()) {
        await audiobooksFile.delete();
        print('LOG: Deleted audiobooks storage file');
      }
      
      if (await collectionsFile.exists()) {
        await collectionsFile.delete();
        print('LOG: Deleted collections storage file');
      }
    } catch (e) {
      print('ERROR: Failed to clear library: $e');
      rethrow;
    }
  }
}