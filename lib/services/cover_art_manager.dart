// PROPER: CoverArtManager that handles ALL cache management internally
import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:metadata_god/metadata_god.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/file_utils.dart';

/// Manages cover art for audiobooks - single source of truth for cover handling
/// Handles ALL caching (both file and Flutter cache) internally
class CoverArtManager {
  // Singleton pattern
  static final CoverArtManager _instance = CoverArtManager._internal();
  factory CoverArtManager() => _instance;
  CoverArtManager._internal();
  
  String? _coversDir;
  final Map<String, String> _coverCache = {};
  bool _isInitialized = false;
  
  // Initialize the cover art manager
  Future<void> initialize() async {
    if (_isInitialized) {
      Logger.debug('CoverArtManager already initialized, skipping');
      return;
    }
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _coversDir = path_util.join(appDir.path, 'audiobooks', 'covers');
      
      // Ensure covers directory exists
      await Directory(_coversDir!).create(recursive: true);
      
      _isInitialized = true;
      Logger.log('CoverArtManager initialized');
    } catch (e) {
      Logger.error('Error initializing CoverArtManager', e);
      rethrow;
    }
  }
  
  /// MAIN API: Get cover path for a file (handles all caching internally)
  /// Returns a unique path that changes when cover is updated
  Future<String?> getCoverPath(String filePath) async {
    if (!_isInitialized) await initialize();
    
    try {
      // Check memory cache first
      if (_coverCache.containsKey(filePath)) {
        final cachedPath = _coverCache[filePath]!;
        if (await File(cachedPath).exists()) {
          return cachedPath;
        } else {
          _coverCache.remove(filePath);
        }
      }
      
      // Look for existing cover file
      final existingCover = await _findExistingCoverFile(filePath);
      if (existingCover != null) {
        _coverCache[filePath] = existingCover;
        return existingCover;
      }
      
      return null;
    } catch (e) {
      Logger.error('Error getting cover path for file: $filePath', e);
      return null;
    }
  }
  
  /// MAIN API: Update cover from URL (handles all cache management)
  Future<String?> updateCoverFromUrl(String filePath, String imageUrl) async {
    if (!_isInitialized) await initialize();
    
    try {
      Logger.log('Updating cover from URL for: ${path_util.basename(filePath)}');
      
      // STEP 1: Clear old cover from Flutter cache
      await _clearFlutterCacheForFile(filePath);
      
      // STEP 2: Remove old cover files
      await _removeExistingCovers(filePath);
      
      // STEP 3: Download new cover with unique timestamp
      final newCoverPath = await _downloadCoverWithTimestamp(filePath, imageUrl);
      
      if (newCoverPath != null) {
        // STEP 4: Update memory cache
        _coverCache[filePath] = newCoverPath;
        Logger.log('Successfully updated cover from URL: $newCoverPath');
        return newCoverPath;
      }
      
      return null;
    } catch (e) {
      Logger.error('Error updating cover from URL: $imageUrl', e);
      return null;
    }
  }
  
  /// MAIN API: Update cover from local file (handles all cache management)
  Future<String?> updateCoverFromLocalFile(String filePath, String localImagePath) async {
    if (!_isInitialized) await initialize();
    
    try {
      Logger.log('Updating cover from local file for: ${path_util.basename(filePath)}');
      
      final sourceFile = File(localImagePath);
      if (!await sourceFile.exists()) {
        Logger.error('Source file does not exist: $localImagePath');
        return null;
      }
      
      // STEP 1: Clear old cover from Flutter cache
      await _clearFlutterCacheForFile(filePath);
      
      // STEP 2: Remove old cover files
      await _removeExistingCovers(filePath);
      
      // STEP 3: Copy to new timestamped file
      final newCoverPath = await _copyToTimestampedFile(filePath, localImagePath);
      
      if (newCoverPath != null) {
        // STEP 4: Update memory cache
        _coverCache[filePath] = newCoverPath;
        Logger.log('Successfully updated cover from local file: $newCoverPath');
        return newCoverPath;
      }
      
      return null;
    } catch (e) {
      Logger.error('Error updating cover from local file: $localImagePath', e);
      return null;
    }
  }
  
  /// MAIN API: Ensure cover exists (extract from file if needed)
  Future<String?> ensureCoverForFile(String filePath, AudiobookMetadata? metadata) async {
    if (!_isInitialized) await initialize();
    
    try {
      // Check if we already have a cover
      String? coverPath = await getCoverPath(filePath);
      if (coverPath != null) return coverPath;
      
      // Check metadata for existing local path
      if (metadata?.thumbnailUrl != null && 
          metadata!.thumbnailUrl.isNotEmpty && 
          !metadata.thumbnailUrl.startsWith('http')) {
        final metadataFile = File(metadata.thumbnailUrl);
        if (await metadataFile.exists()) {
          // Copy to our managed location with timestamp
          coverPath = await _copyToTimestampedFile(filePath, metadata.thumbnailUrl);
          if (coverPath != null) {
            _coverCache[filePath] = coverPath;
            return coverPath;
          }
        }
      }
      
      // Try to extract embedded cover
      coverPath = await _extractEmbeddedCover(filePath);
      if (coverPath != null) {
        _coverCache[filePath] = coverPath;
        Logger.log('Extracted embedded cover for: ${path_util.basename(filePath)}');
        return coverPath;
      }
      
      return null;
    } catch (e) {
      Logger.error('Error ensuring cover for file: $filePath', e);
      return null;
    }
  }

  Future<String?> transferCover(String oldFilePath, String newFilePath, String oldCoverPath) async {
    try {
      Logger.log('Transferring cover from $oldFilePath to $newFilePath');
      
      // Verify old cover exists
      final oldCoverFile = File(oldCoverPath);
      if (!await oldCoverFile.exists()) {
        Logger.warning('Old cover file does not exist: $oldCoverPath');
        return null;
      }
      
      // Generate new cover path based on new file path
      final newFileId = FileUtils.generateFileId(newFilePath);
      final coverExtension = path_util.extension(oldCoverPath);
      final newCoverPath = path_util.join(_coversDir!, '$newFileId$coverExtension');
      
      // Copy the cover file to new location
      await oldCoverFile.copy(newCoverPath);
      
      // Update internal cache
      _coverCache[newFilePath] = newCoverPath;
      _coverCache.remove(oldFilePath);
      
      Logger.log('Successfully transferred cover: $oldCoverPath -> $newCoverPath');
      return newCoverPath;
      
    } catch (e) {
      Logger.error('Error transferring cover from $oldFilePath to $newFilePath: $e');
      return null;
    }
  }
  
  Future<void> removeCover(String filePath) async {
    if (!_isInitialized) await initialize();
    
    try {
      // Clear Flutter cache
      await _clearFlutterCacheForFile(filePath);
      
      // Remove files
      await _removeExistingCovers(filePath);
      
      // Clear memory cache
      _coverCache.remove(filePath);
      
      Logger.log('Removed cover for: ${path_util.basename(filePath)}');
    } catch (e) {
      Logger.error('Error removing cover for file: $filePath', e);
    }
  }
  
  // ========== INTERNAL METHODS ==========
  
  /// Find existing cover file (with or without timestamp)
  Future<String?> _findExistingCoverFile(String filePath) async {
    try {
      final fileId = FileUtils.generateFileId(filePath);
      final coversDirectory = Directory(_coversDir!);
      
      if (!await coversDirectory.exists()) return null;
      
      final files = await coversDirectory.list().toList();
      String? mostRecentCover;
      int mostRecentTimestamp = 0;
      
      for (final file in files) {
        if (file is File) {
          final fileName = path_util.basename(file.path);
          if (fileName.startsWith(fileId)) {
            // Extract timestamp if present
            final timestampMatch = RegExp(r'_(\d+)\.').firstMatch(fileName);
            if (timestampMatch != null) {
              final timestamp = int.tryParse(timestampMatch.group(1)!) ?? 0;
              if (timestamp > mostRecentTimestamp) {
                mostRecentTimestamp = timestamp;
                mostRecentCover = file.path;
              }
            } else {
              // Legacy non-timestamped file
              mostRecentCover = file.path;
            }
          }
        }
      }
      
      return mostRecentCover;
    } catch (e) {
      Logger.error('Error finding existing cover file', e);
      return null;
    }
  }
  
  /// Clear Flutter's image cache for a specific file
  Future<void> _clearFlutterCacheForFile(String filePath) async {
    try {
      // Get current cover path
      final currentCoverPath = _coverCache[filePath];
      if (currentCoverPath != null) {
        final file = File(currentCoverPath);
        await FileImage(file).evict();
        Logger.debug('Evicted Flutter cache for: $currentCoverPath');
      }
      
      // Also clear general cache as a safety measure
      PaintingBinding.instance.imageCache.clear();
      
    } catch (e) {
      Logger.debug('Error clearing Flutter cache: $e');
    }
  }
  
  /// Download cover with timestamp
  Future<String?> _downloadCoverWithTimestamp(String filePath, String imageUrl) async {
    try {
      final fileId = FileUtils.generateFileId(filePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse(imageUrl);
      
      // Determine extension
      String extension = '.jpg';
      if (imageUrl.contains('.png')) {
        extension = '.png';
      } else if (imageUrl.contains('.webp')) extension = '.webp';
      else if (imageUrl.contains('.jpeg')) extension = '.jpeg';
      
      final coverPath = path_util.join(_coversDir!, '${fileId}_$timestamp$extension');
      
      // Download
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        
        if (response.statusCode == 200) {
          final bytes = await consolidateHttpClientResponseBytes(response);
          await File(coverPath).writeAsBytes(bytes);
          return coverPath;
        }
      } finally {
        client.close();
      }
      
      return null;
    } catch (e) {
      Logger.error('Error downloading cover', e);
      return null;
    }
  }
  
  /// Copy local file to timestamped location
  Future<String?> _copyToTimestampedFile(String filePath, String sourcePath) async {
    try {
      final fileId = FileUtils.generateFileId(filePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path_util.extension(sourcePath).toLowerCase();
      final coverPath = path_util.join(_coversDir!, '${fileId}_$timestamp$extension');
      
      await File(sourcePath).copy(coverPath);
      return coverPath;
    } catch (e) {
      Logger.error('Error copying to timestamped file', e);
      return null;
    }
  }
  
  /// Extract embedded cover
  Future<String?> _extractEmbeddedCover(String filePath) async {
    try {
      Logger.debug('Extracting embedded cover from: ${path_util.basename(filePath)}');
      
      final metadata = await MetadataGod.readMetadata(file: filePath);
      if (metadata.picture == null || metadata.picture!.data.isEmpty) {
        return null;
      }
      
      // Determine extension
      String extension = '.jpg';
      final mimeType = metadata.picture!.mimeType.toLowerCase();
      if (mimeType != null) {
        if (mimeType.contains('png')) {
          extension = '.png';
        } else if (mimeType.contains('webp')) extension = '.webp';
      }
      
      // Save with timestamp
      final fileId = FileUtils.generateFileId(filePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final coverPath = path_util.join(_coversDir!, '${fileId}_$timestamp$extension');
      
      await File(coverPath).writeAsBytes(metadata.picture!.data);
      return coverPath;
    } catch (e) {
      Logger.error('Error extracting embedded cover', e);
      return null;
    }
  }
  
  /// Remove all existing cover files for a file
  Future<void> _removeExistingCovers(String filePath) async {
    try {
      final fileId = FileUtils.generateFileId(filePath);
      final coversDirectory = Directory(_coversDir!);
      
      if (!await coversDirectory.exists()) return;
      
      final files = await coversDirectory.list().toList();
      for (final file in files) {
        if (file is File) {
          final fileName = path_util.basename(file.path);
          if (fileName.startsWith(fileId)) {
            await file.delete();
            Logger.debug('Removed cover file: ${file.path}');
          }
        }
      }
    } catch (e) {
      Logger.error('Error removing existing covers', e);
    }
  }
  
  /// Consolidate HTTP response bytes
  Future<List<int>> consolidateHttpClientResponseBytes(HttpClientResponse response) async {
    final chunks = <List<int>>[];
    await for (final chunk in response) {
      chunks.add(chunk);
    }
    
    if (chunks.length == 1) return chunks.first;
    
    int totalLength = 0;
    for (final chunk in chunks) {
      totalLength += chunk.length;
    }
    
    final result = List<int>.filled(totalLength, 0);
    int offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    
    return result;
  }
  
  /// Clear all caches
  void clearCache() {
    _coverCache.clear();
    PaintingBinding.instance.imageCache.clear();
    Logger.debug('All caches cleared');
  }
  
  /// Get cache info for debugging
  Map<String, String> getCacheInfo() {
    return Map<String, String>.from(_coverCache);
  }
  
  /// Dispose resources
  void dispose() {
    clearCache();
  }
}