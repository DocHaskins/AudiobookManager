// lib/storage/metadata_cache.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// Cache for search queries only - file metadata is handled by AudiobookStorageManager
class MetadataCache {
  static const String _cacheFileName = 'search_cache.json';
  
  // In-memory cache for search queries
  final Map<String, AudiobookMetadata> _searchCache = {};
  
  // Path to cache directory
  late final String _cacheDirPath;
  
  // Constructor
  MetadataCache();
  
  // Initialize cache directory
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDirPath = path_util.join(appDir.path, 'audiobook_cache');
      
      // Create cache directory if it doesn't exist
      await Directory(_cacheDirPath).create(recursive: true);
      
      // Load cache from disk
      await _loadCache();
      
      Logger.log('Search cache initialized with ${_searchCache.length} items');
    } catch (e) {
      Logger.error('Error initializing search cache', e);
    }
  }
  
  // Load cache from disk
  Future<void> _loadCache() async {
    try {
      final cacheFile = File(path_util.join(_cacheDirPath, _cacheFileName));
      
      if (await cacheFile.exists()) {
        final String jsonString = await cacheFile.readAsString();
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        
        // Clear existing cache
        _searchCache.clear();
        
        // Load cache entries
        jsonMap.forEach((key, value) {
          _searchCache[key] = AudiobookMetadata.fromJson(value);
        });
        
        Logger.log('Loaded ${_searchCache.length} search results from cache');
      }
    } catch (e) {
      Logger.error('Error loading search cache', e);
    }
  }
  
  // Save cache to disk
  Future<void> _saveCache() async {
    try {
      final cacheFile = File(path_util.join(_cacheDirPath, _cacheFileName));
      
      // Convert cache to JSON
      final Map<String, dynamic> jsonMap = {};
      _searchCache.forEach((key, value) {
        jsonMap[key] = value.toJson();
      });
      
      // Write to file
      await cacheFile.writeAsString(json.encode(jsonMap));
      
      Logger.debug('Saved ${_searchCache.length} search results to cache');
    } catch (e) {
      Logger.error('Error saving search cache', e);
    }
  }
  
  // Get metadata for a search query
  AudiobookMetadata? getMetadata(String query) {
    return _searchCache[query.toLowerCase()];
  }
  
  // Save metadata for a search query
  Future<void> saveMetadata(String query, AudiobookMetadata metadata) async {
    _searchCache[query.toLowerCase()] = metadata;
    await _saveCache();
  }
  
  // Clear search cache
  Future<void> clearCache() async {
    _searchCache.clear();
    
    try {
      // Delete cache file
      final cacheFile = File(path_util.join(_cacheDirPath, _cacheFileName));
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
      
      Logger.log('Search cache cleared');
    } catch (e) {
      Logger.error('Error clearing search cache', e);
    }
  }
  
  // Get cache size
  int get cacheSize => _searchCache.length;
}