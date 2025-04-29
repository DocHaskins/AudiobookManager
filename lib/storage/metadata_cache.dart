// File: lib/storage/metadata_cache.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:crypto/crypto.dart';

import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// Caches metadata for faster lookup in future sessions
class MetadataCache {
  // File name constants
  static const String _cacheFileName = 'metadata_cache.json';
  
  // Cache memory storage
  Map<String, AudiobookMetadata> _cache = {};
  bool _initialized = false;
  
  /// Initialize the cache
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await _loadCache();
      _initialized = true;
      Logger.log('Metadata cache initialized with ${_cache.length} entries');
    } catch (e) {
      Logger.error('Failed to initialize metadata cache', e);
      _cache = {};
      _initialized = true;
    }
  }
  
  /// Generate a unique key for each query
  String _generateKey(String query) {
    // Use a hash to ensure consistent keys
    final bytes = utf8.encode(query.toLowerCase().trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Get the cache file path
  Future<String> _getCacheFilePath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return path_util.join(directory.path, _cacheFileName);
    } catch (e) {
      Logger.error('Failed to get cache file path', e);
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
      Logger.error('Failed to create directory for cache', e);
      rethrow;
    }
  }
  
  /// Load the cache from disk
  Future<void> _loadCache() async {
    try {
      final filePath = await _getCacheFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        Logger.debug('No metadata cache found at $filePath');
        _cache = {};
        return;
      }
      
      final String content = await file.readAsString();
      final Map<String, dynamic> cacheJson = jsonDecode(content);
      
      _cache = {};
      cacheJson.forEach((key, value) {
        try {
          if (value is Map<String, dynamic>) {
            _cache[key] = AudiobookMetadata.fromMap(value);
          }
        } catch (e) {
          Logger.error('Failed to parse cached metadata for key "$key"', e);
        }
      });
      
      Logger.log('Loaded ${_cache.length} items from metadata cache');
    } catch (e) {
      Logger.error('Failed to load metadata cache', e);
      _cache = {};
    }
  }
  
  /// Save the cache to disk
  Future<void> _saveCache() async {
    try {
      final filePath = await _getCacheFilePath();
      await _ensureDirectoryExists(filePath);
      
      final file = File(filePath);
      
      // Convert cache to JSON
      final Map<String, dynamic> cacheJson = {};
      _cache.forEach((key, metadata) {
        cacheJson[key] = metadata.toMap();
      });
      
      // Write to file
      await file.writeAsString(jsonEncode(cacheJson));
      Logger.log('Saved ${_cache.length} items to metadata cache');
    } catch (e) {
      Logger.error('Failed to save metadata cache', e);
    }
  }
  
  /// Save metadata for a search query
  Future<void> saveMetadata(String query, AudiobookMetadata metadata) async {
    await initialize();
    
    try {
      final key = _generateKey(query);
      _cache[key] = metadata;
      
      await _saveCache();
    } catch (e) {
      Logger.error('Failed to save metadata for query: $query', e);
    }
  }
  
  /// Get metadata for a search query
  Future<AudiobookMetadata?> getMetadata(String query) async {
    await initialize();
    
    try {
      final key = _generateKey(query);
      return _cache[key];
    } catch (e) {
      Logger.error('Failed to get metadata for query: $query', e);
      return null;
    }
  }
  
  /// Check if metadata exists for a query
  Future<bool> hasMetadata(String query) async {
    await initialize();
    
    try {
      final key = _generateKey(query);
      return _cache.containsKey(key);
    } catch (e) {
      Logger.error('Failed to check metadata for query: $query', e);
      return false;
    }
  }
  
  /// Clear all cached metadata
  Future<void> clearCache() async {
    await initialize();
    
    try {
      _cache = {};
      
      final filePath = await _getCacheFilePath();
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        Logger.log('Metadata cache file deleted');
      }
    } catch (e) {
      Logger.error('Failed to delete metadata cache file', e);
    }
  }
  
  /// Save metadata for a specific file path
  Future<void> saveMetadataForFile(String filePath, AudiobookMetadata metadata) async {
    await initialize();
    
    try {
      final key = 'file:${_generateKey(filePath)}';
      _cache[key] = metadata;
      
      await _saveCache();
    } catch (e) {
      Logger.error('Failed to save metadata for file: $filePath', e);
    }
  }
  
  /// Get metadata for a specific file path
  Future<AudiobookMetadata?> getMetadataForFile(String filePath) async {
    await initialize();
    
    try {
      final key = 'file:${_generateKey(filePath)}';
      return _cache[key];
    } catch (e) {
      Logger.error('Failed to get metadata for file: $filePath', e);
      return null;
    }
  }
  
  /// Get current cache size
  Future<int> getCacheSize() async {
    await initialize();
    return _cache.length;
  }
}