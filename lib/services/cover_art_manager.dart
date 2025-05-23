// lib/services/cover_art_manager.dart - FIXED SINGLETON VERSION
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:metadata_god/metadata_god.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/file_utils.dart';

/// Manages cover art for audiobooks - single source of truth for cover handling
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
  
  /// Centralized method to ensure a file has a cover
  /// Checks in order: cache, existing metadata, embedded in file
  Future<String?> ensureCoverForFile(String filePath, AudiobookMetadata? metadata) async {
    if (!_isInitialized) {
      Logger.warning('CoverArtManager not initialized, initializing now');
      await initialize();
    }
    
    try {
      // Check cache first
      if (_coverCache.containsKey(filePath)) {
        return _coverCache[filePath];
      }
      
      // Check if we already have a cover path
      String? coverPath = await getCoverPath(filePath);
      
      if (coverPath == null && metadata?.thumbnailUrl != null && metadata!.thumbnailUrl.isNotEmpty) {
        // Use existing thumbnail URL if it's a local path
        if (!metadata.thumbnailUrl.startsWith('http')) {
          final coverFile = File(metadata.thumbnailUrl);
          if (await coverFile.exists()) {
            coverPath = metadata.thumbnailUrl;
            _coverCache[filePath] = coverPath;
          }
        }
      }
      
      if (coverPath == null) {
        // Try to extract embedded cover
        coverPath = await extractCoverFromFile(filePath);
        if (coverPath != null) {
          _coverCache[filePath] = coverPath;
          Logger.log('Extracted embedded cover for: ${path_util.basename(filePath)}');
        }
      }
      
      return coverPath;
    } catch (e) {
      Logger.error('Error ensuring cover for file: $filePath', e);
      return null;
    }
  }
  
  /// Get the cover path for a file
  Future<String?> getCoverPath(String filePath) async {
    if (!_isInitialized) {
      Logger.warning('CoverArtManager not initialized, initializing now');
      await initialize();
    }
    
    try {
      final fileId = FileUtils.generateFileId(filePath);
      
      // Check for existing cover files
      final extensions = ['.jpg', '.jpeg', '.png', '.webp'];
      for (final ext in extensions) {
        final coverPath = path_util.join(_coversDir!, '$fileId$ext');
        if (await File(coverPath).exists()) {
          return coverPath;
        }
      }
      
      return null;
    } catch (e) {
      Logger.error('Error getting cover path for file: $filePath', e);
      return null;
    }
  }
  
  /// Extract cover from audio file using metadata_god
  Future<String?> extractCoverFromFile(String filePath) async {
    if (!_isInitialized) {
      Logger.warning('CoverArtManager not initialized, initializing now');
      await initialize();
    }
    
    try {
      Logger.debug('Attempting to extract embedded cover from: ${path_util.basename(filePath)}');
      
      // Use metadata_god to read metadata including picture
      final metadata = await MetadataGod.readMetadata(file: filePath);
      
      // Check if there's an embedded picture
      if (metadata.picture == null) {
        Logger.debug('No embedded cover found in: ${path_util.basename(filePath)}');
        return null;
      }
      
      // Get the picture data
      final pictureData = metadata.picture!.data;
      if (pictureData.isEmpty) {
        Logger.debug('Embedded cover data is empty for: ${path_util.basename(filePath)}');
        return null;
      }
      
      // Determine the image format from mime type or default to jpg
      String extension = '.jpg';
      final mimeType = metadata.picture!.mimeType?.toLowerCase();
      if (mimeType != null) {
        if (mimeType.contains('png')) {
          extension = '.png';
        } else if (mimeType.contains('jpeg') || mimeType.contains('jpg')) {
          extension = '.jpg';
        } else if (mimeType.contains('webp')) {
          extension = '.webp';
        } else if (mimeType.contains('bmp')) {
          extension = '.bmp';
        }
      }
      
      // Generate cover file path
      final fileId = FileUtils.generateFileId(filePath);
      final coverPath = path_util.join(_coversDir!, '$fileId$extension');
      
      // Write the cover image to disk
      final coverFile = File(coverPath);
      await coverFile.writeAsBytes(pictureData);
      
      // Cache the cover path
      _coverCache[filePath] = coverPath;
      
      Logger.log('Successfully extracted embedded cover for: ${path_util.basename(filePath)}');
      Logger.debug('Cover saved to: $coverPath (${pictureData.length} bytes)');
      
      return coverPath;
    } catch (e) {
      Logger.error('Error extracting cover from file: $filePath', e);
      return null;
    }
  }
  
  /// Download a cover from URL
  Future<String?> downloadCover(String filePath, String imageUrl) async {
    if (!_isInitialized) {
      Logger.warning('CoverArtManager not initialized, initializing now');
      await initialize();
    }
    
    try {
      final fileId = FileUtils.generateFileId(filePath);
      final uri = Uri.parse(imageUrl);
      
      // Determine file extension from URL or default to jpg
      String extension = '.jpg';
      if (imageUrl.contains('.png')) extension = '.png';
      else if (imageUrl.contains('.webp')) extension = '.webp';
      else if (imageUrl.contains('.jpeg')) extension = '.jpeg';
      
      final coverPath = path_util.join(_coversDir!, '$fileId$extension');
      
      // Download the image
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        await File(coverPath).writeAsBytes(bytes);
        
        _coverCache[filePath] = coverPath;
        Logger.log('Downloaded cover for: ${path_util.basename(filePath)}');
        return coverPath;
      }
      
      return null;
    } catch (e) {
      Logger.error('Error downloading cover: $imageUrl', e);
      return null;
    }
  }
  
  /// Update cover for a file (from URL or local path)
  Future<String?> updateCover(String filePath, {String? downloadUrl, String? localImagePath}) async {
    if (!_isInitialized) {
      Logger.warning('CoverArtManager not initialized, initializing now');
      await initialize();
    }
    
    try {
      if (downloadUrl != null) {
        return await downloadCover(filePath, downloadUrl);
      } else if (localImagePath != null) {
        final fileId = FileUtils.generateFileId(filePath);
        final sourceFile = File(localImagePath);
        
        if (await sourceFile.exists()) {
          final extension = path_util.extension(localImagePath).toLowerCase();
          final coverPath = path_util.join(_coversDir!, '$fileId$extension');
          
          await sourceFile.copy(coverPath);
          _coverCache[filePath] = coverPath;
          
          Logger.log('Updated cover from local file for: ${path_util.basename(filePath)}');
          return coverPath;
        }
      }
      
      return null;
    } catch (e) {
      Logger.error('Error updating cover for file: $filePath', e);
      return null;
    }
  }
  
  /// Remove cover for a file
  Future<void> removeCover(String filePath) async {
    if (!_isInitialized) {
      Logger.warning('CoverArtManager not initialized, initializing now');
      await initialize();
    }
    
    try {
      final fileId = FileUtils.generateFileId(filePath);
      
      // Remove all possible cover files
      final extensions = ['.jpg', '.jpeg', '.png', '.webp'];
      for (final ext in extensions) {
        final coverPath = path_util.join(_coversDir!, '$fileId$ext');
        final coverFile = File(coverPath);
        if (await coverFile.exists()) {
          await coverFile.delete();
          Logger.debug('Removed cover file: $coverPath');
        }
      }
      
      // Remove from cache
      _coverCache.remove(filePath);
    } catch (e) {
      Logger.error('Error removing cover for file: $filePath', e);
    }
  }
  
  /// Consolidate HttpClientResponse bytes
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
  
  /// Clear cache
  void clearCache() {
    _coverCache.clear();
  }
  
  /// Dispose resources
  void dispose() {
    clearCache();
  }
}