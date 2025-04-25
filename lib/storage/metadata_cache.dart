// File: lib/storage/metadata_cache.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

import 'package:audiobook_organizer/models/audiobook_metadata.dart';

class MetadataCache {
  static const String _cacheFileName = 'metadata_cache.json';
  Map<String, AudiobookMetadata> _cache = {};
  bool _initialized = false;
  
  // Initialize the cache
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await _loadCache();
      _initialized = true;
      print('LOG: Metadata cache initialized with ${_cache.length} entries');
    } catch (e) {
      print('ERROR: Failed to initialize metadata cache: $e');
      _cache = {};
      _initialized = true;
    }
  }
  
  // Generate a unique key for each query
  String _generateKey(String query) {
    // Use a hash to ensure consistent keys
    final bytes = utf8.encode(query.toLowerCase().trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  Future<String> _getCacheFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return path.join(directory.path, _cacheFileName);
  }
  
  Future<void> _loadCache() async {
    try {
      final filePath = await _getCacheFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        print('LOG: No metadata cache found at $filePath');
        _cache = {};
        return;
      }
      
      final String content = await file.readAsString();
      final Map<String, dynamic> cacheJson = jsonDecode(content);
      
      _cache = {};
      cacheJson.forEach((key, value) {
        try {
          // Create metadata safely
          _cache[key] = _createMetadataFromMap(value);
        } catch (e) {
          print('ERROR: Failed to parse cached metadata for key "$key": $e');
        }
      });
      
      print('LOG: Loaded ${_cache.length} items from metadata cache');
    } catch (e) {
      print('ERROR: Failed to load metadata cache: $e');
      _cache = {};
    }
  }
  
  // Helper method to safely create AudiobookMetadata from Map
  AudiobookMetadata _createMetadataFromMap(Map<String, dynamic> map) {
    // Safely extract lists from serialized data
    List<String> extractStringList(String serialized) {
      if (serialized.isEmpty) return [];
      return serialized.split('|').where((s) => s.isNotEmpty).toList();
    }
    
    // Handle the categories and authors fields with safer parsing
    final String authorsStr = map['authors'] as String? ?? '';
    final String categoriesStr = map['categories'] as String? ?? '';
    
    return AudiobookMetadata(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Unknown Title',
      authors: extractStringList(authorsStr),
      description: map['description'] as String? ?? '',
      publisher: map['publisher'] as String? ?? '',
      publishedDate: map['publishedDate'] as String? ?? '',
      categories: extractStringList(categoriesStr),
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingsCount: (map['ratingsCount'] as num?)?.toInt() ?? 0,
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      language: map['language'] as String? ?? '',
      series: map['series'] as String? ?? '',
      seriesPosition: map['seriesPosition'] as String? ?? '',
      provider: map['provider'] as String? ?? 'Unknown',
    );
  }
  
  Future<void> _saveCache() async {
    try {
      final filePath = await _getCacheFilePath();
      final file = File(filePath);
      
      // Create directory if it doesn't exist
      final dir = Directory(path.dirname(filePath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Convert cache to JSON
      final Map<String, dynamic> cacheJson = {};
      _cache.forEach((key, metadata) {
        cacheJson[key] = metadata.toMap();
      });
      
      // Write to file
      await file.writeAsString(jsonEncode(cacheJson));
      print('LOG: Saved ${_cache.length} items to metadata cache');
    } catch (e) {
      print('ERROR: Failed to save metadata cache: $e');
    }
  }
  
  Future<void> saveMetadata(String query, AudiobookMetadata metadata) async {
    await initialize();
    
    final key = _generateKey(query);
    _cache[key] = metadata;
    
    await _saveCache();
  }
  
  Future<AudiobookMetadata?> getMetadata(String query) async {
    await initialize();
    
    final key = _generateKey(query);
    return _cache[key];
  }
  
  Future<bool> hasMetadata(String query) async {
    await initialize();
    
    final key = _generateKey(query);
    return _cache.containsKey(key);
  }
  
  Future<void> clearCache() async {
    await initialize();
    
    _cache = {};
    
    try {
      final filePath = await _getCacheFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('LOG: Metadata cache file deleted');
      }
    } catch (e) {
      print('ERROR: Failed to delete metadata cache file: $e');
    }
  }
  
  // Add a method to save metadata specifically for a file path
  Future<void> saveMetadataForFile(String filePath, AudiobookMetadata metadata) async {
    await initialize();
    
    final key = 'file:' + _generateKey(filePath);
    _cache[key] = metadata;
    
    await _saveCache();
  }
  
  // Get metadata specifically for a file path
  Future<AudiobookMetadata?> getMetadataForFile(String filePath) async {
    await initialize();
    
    final key = 'file:' + _generateKey(filePath);
    return _cache[key];
  }
  
  // Get current cache size
  Future<int> getCacheSize() async {
    await initialize();
    return _cache.length;
  }
}