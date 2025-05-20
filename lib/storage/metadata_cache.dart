import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class MetadataCache {
  static const String _cacheFileName = 'metadata_cache.json';
  static const String _fileMetadataDir = 'file_metadata';
  
  // In-memory cache
  final Map<String, AudiobookMetadata> _cache = {};
  
  // Path to cache directory
  late final String _cacheDirPath;
  late final String _fileMetadataDirPath;
  
  // Constructor initializes the cache directory
  MetadataCache();
  
  // Initialize cache directory
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDirPath = path_util.join(appDir.path, 'audiobook_cache');
      _fileMetadataDirPath = path_util.join(_cacheDirPath, _fileMetadataDir);
      
      // Create cache directories if they don't exist
      await Directory(_cacheDirPath).create(recursive: true);
      await Directory(_fileMetadataDirPath).create(recursive: true);
      
      // Load cache from disk
      await _loadCache();
      
      Logger.log('Metadata cache initialized with ${_cache.length} items');
    } catch (e) {
      Logger.error('Error initializing metadata cache', e);
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
        _cache.clear();
        
        // Load cache entries
        jsonMap.forEach((key, value) {
          _cache[key] = AudiobookMetadata.fromJson(value);
        });
        
        Logger.log('Loaded ${_cache.length} items from cache file');
      } else {
        Logger.log('Cache file does not exist, creating a new one');
      }
    } catch (e) {
      Logger.error('Error loading metadata cache', e);
    }
  }
  
  // Save cache to disk
  Future<void> _saveCache() async {
    try {
      final cacheFile = File(path_util.join(_cacheDirPath, _cacheFileName));
      
      // Convert cache to JSON
      final Map<String, dynamic> jsonMap = {};
      _cache.forEach((key, value) {
        jsonMap[key] = value.toJson();
      });
      
      // Write to file
      await cacheFile.writeAsString(json.encode(jsonMap));
      
      Logger.log('Saved ${_cache.length} items to cache file');
    } catch (e) {
      Logger.error('Error saving metadata cache', e);
    }
  }
  
  // Get metadata for a search query
  AudiobookMetadata? getMetadata(String query) {
    return _cache[query.toLowerCase()];
  }
  
  // Save metadata for a search query
  Future<void> saveMetadata(String query, AudiobookMetadata metadata) async {
    _cache[query.toLowerCase()] = metadata;
    await _saveCache();
  }
  
  // Get metadata for a specific file
  Future<AudiobookMetadata?> getMetadataForFile(String filePath) async {
    try {
      // Generate a hash of the file path for the filename
      final String fileHash = _generateFileHash(filePath);
      final String metadataFilePath = path_util.join(_fileMetadataDirPath, '$fileHash.json');
      
      final File metadataFile = File(metadataFilePath);
      if (await metadataFile.exists()) {
        final String jsonString = await metadataFile.readAsString();
        return AudiobookMetadata.fromJson(json.decode(jsonString));
      }
      
      return null;
    } catch (e) {
      Logger.error('Error getting metadata for file: $filePath', e);
      return null;
    }
  }
  
  // Save metadata for a specific file
  Future<void> saveMetadataForFile(String filePath, AudiobookMetadata metadata) async {
    try {
      // Generate a hash of the file path for the filename
      final String fileHash = _generateFileHash(filePath);
      final String metadataFilePath = path_util.join(_fileMetadataDirPath, '$fileHash.json');
      
      final File metadataFile = File(metadataFilePath);
      await metadataFile.writeAsString(json.encode(metadata.toJson()));
      
      Logger.debug('Saved metadata for file: $filePath');
    } catch (e) {
      Logger.error('Error saving metadata for file: $filePath', e);
    }
  }
  
  // Generate a hash for a file path
  String _generateFileHash(String filePath) {
    // Simple hash function - in a real app, you might want to use something more robust
    int hash = 0;
    for (int i = 0; i < filePath.length; i++) {
      hash = ((hash << 5) - hash) + filePath.codeUnitAt(i);
      hash &= hash; // Convert to 32bit integer
    }
    return hash.abs().toString();
  }
  
  // Clear cache
  Future<void> clearCache() async {
    _cache.clear();
    
    try {
      // Delete cache file
      final cacheFile = File(path_util.join(_cacheDirPath, _cacheFileName));
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
      
      // Delete file metadata directory
      final metadataDir = Directory(_fileMetadataDirPath);
      if (await metadataDir.exists()) {
        await metadataDir.delete(recursive: true);
        await Directory(_fileMetadataDirPath).create();
      }
      
      Logger.log('Cache cleared');
    } catch (e) {
      Logger.error('Error clearing cache', e);
    }
  }
}