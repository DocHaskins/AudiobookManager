// lib/services/metadata_service.dart
import 'dart:io';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class MetadataService {
  // Singleton pattern
  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;
  MetadataService._internal();
  
  // Track initialization state
  bool _isInitialized = false;
  
  // Cache to avoid repeated processing
  final Map<String, AudiobookMetadata> _metadataCache = {};
  
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
      
      // Ensure we're initialized before proceeding
      if (!_isInitialized) {
        final success = await initialize();
        if (!success) {
          Logger.error('MetadataService not initialized before extraction attempt');
          return null;
        }
      }
      
      Logger.log('Extracting metadata from file: $filePath');
      
      // Use metadata_god to get metadata - note it's readMetadata not getMetadata
      final metadata = await MetadataGod.readMetadata(file: filePath);
      
      // Extract the critical information
      final title = metadata.title ?? path_util.basenameWithoutExtension(filePath);
      
      // Create a proper author list from artist string
      final List<String> authors = [];
      if (metadata.artist != null && metadata.artist!.isNotEmpty) {
        // Split by common author separators
        authors.addAll(metadata.artist!
            .split(RegExp(r',|;|\band\b|\s*&\s*'))
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList());
      }
      
      // If authors list is still empty, use a default
      if (authors.isEmpty && metadata.artist != null) {
        authors.add(metadata.artist!);
      }
      
      final series = metadata.album ?? '';
      
      // Try to extract series position from track number
      String seriesPosition = '';
      if (metadata.trackNumber != null) {
        seriesPosition = metadata.trackNumber.toString();
      }
      
      // Get file information
      final file = File(filePath);
      final fileStats = await file.stat();
      final extension = path_util.extension(filePath).toLowerCase().replaceFirst('.', '');
      
      // Handle cover art
      String thumbnailUrl = '';
      if (metadata.picture != null) {
        thumbnailUrl = await _saveCoverImage(metadata.picture!, filePath);
      }
      
      // Create AudiobookMetadata object - map the fields we have to our model
      final audiobookMetadata = AudiobookMetadata(
        id: path_util.basename(filePath),
        title: title,
        authors: authors,
        description: '', // No comment field in metadata_god's Metadata
        publisher: '', // No publisher field in metadata_god's Metadata
        publishedDate: metadata.year?.toString() ?? '',
        categories: metadata.genre != null ? [metadata.genre!] : [],
        thumbnailUrl: thumbnailUrl,
        language: '', // No language field in metadata_god's Metadata
        series: series,
        seriesPosition: seriesPosition,
        audioDuration: metadata.durationMs != null ? Duration(milliseconds: metadata.durationMs!.toInt()) : null,
        bitrate: null, // No bitrate info in metadata_god
        fileFormat: extension.toUpperCase(),
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
  
  // Save cover image to a local file
  Future<String> _saveCoverImage(Picture picture, String audioFilePath) async {
    try {
      final directory = path_util.dirname(audioFilePath);
      final filename = path_util.basenameWithoutExtension(audioFilePath);
      
      // Create covers directory if it doesn't exist
      final coversDir = Directory('$directory/covers');
      if (!await coversDir.exists()) {
        await coversDir.create();
      }
      
      // Determine file extension from mime type
      String extension = '.jpg'; // Default
      if (picture.mimeType == 'image/png') {
        extension = '.png';
      } else if (picture.mimeType == 'image/gif') {
        extension = '.gif';
      }
      
      // Create the cover file path
      final coverPath = '${coversDir.path}/$filename$extension';
      
      // Write the image data to file
      await File(coverPath).writeAsBytes(picture.data);
      
      Logger.log('Saved cover image to: $coverPath');
      return coverPath;
    } catch (e) {
      Logger.error('Error saving cover image', e);
      return '';
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
      
      // Prepare picture data if available
      Picture? picture;
      if (metadata.thumbnailUrl.isNotEmpty) {
        try {
          final imageFile = File(metadata.thumbnailUrl);
          if (await imageFile.exists()) {
            final imageBytes = await imageFile.readAsBytes();
            final mimeType = metadata.thumbnailUrl.toLowerCase().endsWith('.png') 
                ? 'image/png' 
                : 'image/jpeg';
            
            picture = Picture(
              data: imageBytes,
              mimeType: mimeType,
            );
          }
        } catch (e) {
          Logger.error('Error reading cover image', e);
        }
      }
      
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
        picture: picture,
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
}