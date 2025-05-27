// lib/services/metadata_service.dart
import 'dart:io';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as path_util;
import 'package:mime/mime.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/file_utils.dart';

class MetadataService {
  // Singleton pattern
  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;
  MetadataService._internal();

  final Map<String, AudiobookMetadata> _metadataCache = {};
  bool _isInitialized = false;
  
  // Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      Logger.log('Initializing MetadataService with metadata_god');
      _isInitialized = true;
      Logger.log('MetadataService initialized successfully');
      return true;
    } catch (e) {
      Logger.error('Failed to initialize MetadataService', e);
      return false;
    }
  }
  
  // Primary method to extract metadata with all available MetadataGod fields
  Future<AudiobookMetadata?> extractMetadata(String filePath, {bool forceRefresh = false}) async {
    try {
      // Check cache first
      if (!forceRefresh && _metadataCache.containsKey(filePath)) {
        Logger.debug('Retrieved metadata from cache for: $filePath');
        return _metadataCache[filePath];
      }
      
      // Ensure we're initialized
      if (!_isInitialized) {
        final success = await initialize();
        if (!success) {
          Logger.error('MetadataService not initialized before extraction attempt');
          return null;
        }
      }
      
      Logger.log('Extracting metadata from file: $filePath');
      
      // Use metadata_god to get metadata
      final metadata = await MetadataGod.readMetadata(file: filePath);
      
      // Extract the critical information
      final rawTitle = metadata.title ?? path_util.basenameWithoutExtension(filePath);
      final title = FileUtils.cleanAudiobookTitle(rawTitle);
      
      // Use utility to parse authors
      final List<String> authors = [];
      if (metadata.albumArtist != null && metadata.albumArtist!.isNotEmpty) {
        // Use album artist as the book author
        authors.addAll(FileUtils.parseAuthors(metadata.albumArtist!));
      } else if (metadata.artist != null && metadata.artist!.isNotEmpty) {
        // Fall back to artist if album artist isn't available
        authors.addAll(FileUtils.parseAuthors(metadata.artist!));
      }
      
      // Get series from album field
      final series = metadata.album ?? '';
      
      // Use utility to extract series position
      String seriesPosition = '';
      if (metadata.trackNumber != null) {
        seriesPosition = metadata.trackNumber.toString();
      } else {
        // Try to extract from title or filename
        seriesPosition = FileUtils.extractSeriesPosition(title) ?? 
                        FileUtils.extractSeriesPosition(path_util.basenameWithoutExtension(filePath)) ?? 
                        '';
      }
      
      // Extract duration with proper logging
      Duration? audioDuration;
      if (metadata.durationMs != null && metadata.durationMs! > 0) {
        audioDuration = Duration(milliseconds: metadata.durationMs!.toInt());
        Logger.debug('Duration extracted for $title: ${audioDuration.inSeconds}s (${_formatDuration(audioDuration)})');
      } else {
        Logger.warning('No duration found in metadata for: $title (durationMs: ${metadata.durationMs})');
      }
      
      // Create AudiobookMetadata object with all available MetadataGod fields
      final audiobookMetadata = AudiobookMetadata(
        id: path_util.basename(filePath),
        title: title,
        authors: authors,
        description: '', // MetadataGod doesn't have a comment/description field
        publisher: '',
        publishedDate: metadata.year?.toString() ?? '',
        categories: metadata.genre != null ? [metadata.genre!] : [],
        thumbnailUrl: '', // Cover handling done by CoverArtManager
        language: '',
        series: series,
        seriesPosition: seriesPosition,
        audioDuration: audioDuration,
        fileFormat: path_util.extension(filePath).toLowerCase().replaceFirst('.', '').toUpperCase(),
        provider: 'metadata_god',
        // Default values for other fields
        averageRating: 0.0,
        ratingsCount: 0,
        isFavorite: false,
        userRating: 0,
        userTags: const [],
        bookmarks: const [],
        notes: const [],
      );
      
      // Cache the result
      _metadataCache[filePath] = audiobookMetadata;
      
      Logger.log('Successfully extracted metadata for: ${audiobookMetadata.title}${audioDuration != null ? " (Duration: ${_formatDuration(audioDuration)})" : " (No duration)"}');
      return audiobookMetadata;
    } catch (e) {
      Logger.error('Error extracting metadata from file: $filePath', e);
      return null;
    }
  }
  
  // Method to write metadata from AudiobookMetadata object
  Future<bool> writeMetadataFromObject(String filePath, AudiobookMetadata metadata) async {
    return writeMetadata(filePath, metadata, coverImagePath: metadata.thumbnailUrl);
  }
  
  // Extract detailed audio information for debugging - only what MetadataGod actually provides
  Future<Map<String, dynamic>> extractDetailedAudioInfo(String filePath) async {
    try {
      final metadata = await MetadataGod.readMetadata(file: filePath);
      
      final info = {
        // All actual MetadataGod fields
        'title': metadata.title,
        'artist': metadata.artist,
        'album': metadata.album,
        'albumArtist': metadata.albumArtist,
        'genre': metadata.genre,
        'year': metadata.year,
        'trackNumber': metadata.trackNumber,
        'trackTotal': metadata.trackTotal,
        'discNumber': metadata.discNumber,
        'discTotal': metadata.discTotal,
        'durationMs': metadata.durationMs,
        'durationSeconds': metadata.durationMs != null ? (metadata.durationMs! / 1000).round() : null,
        'durationFormatted': metadata.durationMs != null ? _formatDuration(Duration(milliseconds: metadata.durationMs!.toInt())) : null,
        'fileSize': metadata.fileSize?.toString(),
        'hasPicture': metadata.picture != null,
        'pictureMimeType': metadata.picture?.mimeType,
        'pictureDataSize': metadata.picture?.data.length,
      };
      
      Logger.debug('Detailed audio info for ${path_util.basename(filePath)}: $info');
      return info;
    } catch (e) {
      Logger.error('Error extracting detailed audio info: $e');
      return {};
    }
  }
  
  // Write metadata back to the file using only MetadataGod supported fields
  Future<bool> writeMetadata(String filePath, AudiobookMetadata metadata, {String? coverImagePath}) async {
    try {
      // Ensure we're initialized
      if (!_isInitialized) {
        final success = await initialize();
        if (!success) {
          Logger.error('MetadataService not initialized before write attempt');
          return false;
        }
      }
      
      Logger.log('Writing metadata to file: $filePath');
      
      // Prepare the picture data if a cover image path is provided
      Picture? picture;
      if (coverImagePath != null && coverImagePath.isNotEmpty && !coverImagePath.startsWith('http')) {
        final coverFile = File(coverImagePath);
        if (await coverFile.exists()) {
          try {
            final imageBytes = await coverFile.readAsBytes();
            final mimeType = lookupMimeType(coverImagePath) ?? 'image/jpeg';
            
            picture = Picture(
              data: imageBytes,
              mimeType: mimeType,
            );
            
            Logger.log('Prepared cover image for embedding: ${path_util.basename(coverImagePath)}');
          } catch (e) {
            Logger.error('Error reading cover image file: $coverImagePath', e);
          }
        }
      } else if (metadata.thumbnailUrl.isNotEmpty && !metadata.thumbnailUrl.startsWith('http')) {
        // If no explicit cover path provided, try to use the thumbnail URL if it's a local path
        final coverFile = File(metadata.thumbnailUrl);
        if (await coverFile.exists()) {
          try {
            final imageBytes = await coverFile.readAsBytes();
            final mimeType = lookupMimeType(metadata.thumbnailUrl) ?? 'image/jpeg';
            
            picture = Picture(
              data: imageBytes,
              mimeType: mimeType,
            );
            
            Logger.log('Using existing cover from metadata for embedding');
          } catch (e) {
            Logger.error('Error reading cover image from metadata: ${metadata.thumbnailUrl}', e);
          }
        }
      }
      
      // Create metadata_god Metadata object using ONLY the fields that exist in the API
      final newMetadata = Metadata(
        title: metadata.title,
        artist: metadata.authors.isNotEmpty ? metadata.authors.first : null,
        album: metadata.series,
        albumArtist: metadata.authors.length > 1 ? metadata.authors[1] : metadata.authors.isNotEmpty ? metadata.authors.first : null,
        genre: metadata.categories.isNotEmpty ? metadata.categories.first : null,
        year: metadata.publishedDate.isNotEmpty ? int.tryParse(metadata.publishedDate) : null,
        trackNumber: metadata.seriesPosition.isNotEmpty ? int.tryParse(metadata.seriesPosition) : null,
        trackTotal: null, // We don't have this info in AudiobookMetadata
        discNumber: null, // We don't have this info in AudiobookMetadata
        discTotal: null, // We don't have this info in AudiobookMetadata
        durationMs: metadata.audioDuration?.inMilliseconds.toDouble(),
        picture: picture,
        fileSize: null, // Will be calculated by metadata_god
      );
      
      // Write the metadata to the file
      await MetadataGod.writeMetadata(
        file: filePath,
        metadata: newMetadata,
      );
      
      // Clear from cache to force refresh on next read
      _metadataCache.remove(filePath);
      
      Logger.log('Successfully wrote metadata to file: $filePath${picture != null ? ' (including cover)' : ''}');
      return true;
    } catch (e) {
      Logger.error('Error writing metadata to file: $filePath', e);
      return false;
    }
  }
  
  // Overload for backward compatibility
  Future<bool> writeMetadataWithCover(String filePath, AudiobookMetadata metadata, String coverImagePath) async {
    return writeMetadata(filePath, metadata, coverImagePath: coverImagePath);
  }
  
  // Extract just the cover art from a file
  Future<Picture?> extractCoverArt(String filePath) async {
    try {
      final metadata = await MetadataGod.readMetadata(file: filePath);
      return metadata.picture;
    } catch (e) {
      Logger.error('Error extracting cover art from file: $filePath', e);
      return null;
    }
  }
  
  // Write only the cover art to a file (preserves other metadata)
  Future<bool> writeCoverArt(String filePath, String coverImagePath) async {
    try {
      // First, read existing metadata
      final existingMetadata = await MetadataGod.readMetadata(file: filePath);
      
      // Prepare the new picture data
      final coverFile = File(coverImagePath);
      if (!await coverFile.exists()) {
        Logger.error('Cover image file does not exist: $coverImagePath');
        return false;
      }
      
      final imageBytes = await coverFile.readAsBytes();
      final mimeType = lookupMimeType(coverImagePath) ?? 'image/jpeg';
      
      final picture = Picture(
        data: imageBytes,
        mimeType: mimeType,
      );
      
      // Create new metadata with updated picture using all existing MetadataGod fields
      final newMetadata = Metadata(
        title: existingMetadata.title,
        artist: existingMetadata.artist,
        album: existingMetadata.album,
        albumArtist: existingMetadata.albumArtist,
        genre: existingMetadata.genre,
        year: existingMetadata.year,
        trackNumber: existingMetadata.trackNumber,
        trackTotal: existingMetadata.trackTotal,
        discNumber: existingMetadata.discNumber,
        discTotal: existingMetadata.discTotal,
        durationMs: existingMetadata.durationMs,
        picture: picture,
        fileSize: existingMetadata.fileSize,
      );
      
      // Write the metadata back to the file
      await MetadataGod.writeMetadata(
        file: filePath,
        metadata: newMetadata,
      );
      
      Logger.log('Successfully wrote cover art to file: $filePath');
      return true;
    } catch (e) {
      Logger.error('Error writing cover art to file: $filePath', e);
      return false;
    }
  }
  
  // Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_files': _metadataCache.length,
      'initialized': _isInitialized,
    };
  }
  
  // Helper method to format duration
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  // Clear cache
  void clearCache() {
    _metadataCache.clear();
    Logger.debug('Metadata cache cleared');
  }
}