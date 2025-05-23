// lib/services/metadata_service.dart - REFACTORED
import 'dart:io';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as path_util;
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
  
  // Primary method to extract metadata
  Future<AudiobookMetadata?> extractMetadata(String filePath, {bool forceRefresh = false}) async {
    try {
      // Check cache first
      if (!forceRefresh && _metadataCache.containsKey(filePath)) {
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
      
      // Create AudiobookMetadata object
      final audiobookMetadata = AudiobookMetadata(
        id: path_util.basename(filePath),
        title: title,
        authors: authors,
        description: '', // No comment field available
        publisher: '',
        publishedDate: metadata.year?.toString() ?? '',
        categories: metadata.genre != null ? [metadata.genre!] : [],
        thumbnailUrl: '', // Cover handling done by CoverArtManager
        language: '',
        series: series,
        seriesPosition: seriesPosition,
        audioDuration: metadata.durationMs != null ? Duration(milliseconds: metadata.durationMs!.toInt()) : null,
        bitrate: null,
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
      
      Logger.log('Successfully extracted metadata for: ${audiobookMetadata.title}');
      return audiobookMetadata;
    } catch (e) {
      Logger.error('Error extracting metadata from file: $filePath', e);
      return null;
    }
  }
  
  // Write metadata back to the file
  Future<bool> writeMetadata(String filePath, AudiobookMetadata metadata) async {
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
            
      // Create metadata_god Metadata object
      final newMetadata = Metadata(
        title: metadata.title,
        artist: metadata.authors.isNotEmpty ? metadata.authors.first : null,
        album: metadata.series,
        genre: metadata.categories.isNotEmpty ? metadata.categories.first : null,
        year: metadata.publishedDate.isNotEmpty ? int.tryParse(metadata.publishedDate) : null,
        trackNumber: metadata.seriesPosition.isNotEmpty ? int.tryParse(metadata.seriesPosition) : null,
        // Other fields that metadata_god supports
        albumArtist: metadata.authors.length > 1 ? metadata.authors[1] : null,
        durationMs: metadata.audioDuration?.inMilliseconds.toDouble(),
        picture: null,
        fileSize: null, // Optional
      );
      
      // Write the metadata to the file
      await MetadataGod.writeMetadata(
        file: filePath,
        metadata: newMetadata,
      );
      
      // Update the cache
      _metadataCache.remove(filePath);
      
      Logger.log('Successfully wrote metadata to file: $filePath');
      return true;
    } catch (e) {
      Logger.error('Error writing metadata to file: $filePath', e);
      return false;
    }
  }
  
  // Clear cache
  void clearCache() {
    _metadataCache.clear();
  }
}