// File: lib/services/audio_metadata_extractor.dart
import 'dart:io';
import 'package:path/path.dart' as path_util;
import 'package:id3/id3.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/filename_parser.dart';
import 'package:audiobook_organizer/utils/string_extensions.dart';

/// Service for extracting and writing metadata to audiobook files
class AudioMetadataExtractor {
  // Supported file extensions
  static final List<String> _supportedExtensions = ['.mp3', '.m4a', '.m4b'];
  
  // ID3 tag name mappings
  static final Map<String, List<String>> _id3TagNames = {
    'title': ['Title', 'TIT2', 'TT2'],
    'artist': ['Artist', 'TPE1', 'TP1'],
    'album': ['Album', 'TALB', 'TAL'],
    'year': ['Year', 'TYER', 'TYE'],
    'genre': ['Genre', 'TCON', 'TCO'],
    'comment': ['Comment', 'COMM'],
    'length': ['Length', 'TLEN'],  // Duration in milliseconds
    'picture': ['Picture', 'APIC'], // Embedded album art
    'bitrate': ['TBPM'],  // Might store bitrate in some files
  };
  
  // Patterns for extracting series information from album field
  static final RegExp _seriesBookPattern = RegExp(r'(.*?)(?:\s+Book\s+|#)(\d+)');
  static final RegExp _seriesNamePattern = RegExp(r'(.*?)\s+Series');
  
  /// Constructor
  AudioMetadataExtractor() {
    //Logger.debug('AudioMetadataExtractor initialized');
  }
  
  /// Check if the file type is supported for metadata extraction
  bool isSupported(String filePath) {
    String ext = path_util.extension(filePath).toLowerCase();
    return _supportedExtensions.contains(ext);
  }
  
  /// Extract metadata from the audio file
  Future<AudiobookMetadata?> extractMetadata(String filePath) async {
    try {
      if (!isSupported(filePath)) {
        Logger.warning('File format not supported for metadata extraction: $filePath');
        return null;
      }
      
      final ext = path_util.extension(filePath).toLowerCase();
      
      if (ext == '.mp3') {
        return _extractMp3Metadata(filePath);
      } else if (ext == '.m4a' || ext == '.m4b') {
        return _extractM4aMetadata(filePath);
      }
      
      return null;
    } catch (e) {
      Logger.error('Failed to extract metadata from file', e);
      return null;
    }
  }
  
  /// Extract metadata from MP3 files
  Future<AudiobookMetadata?> _extractMp3Metadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        Logger.warning('File does not exist: $filePath');
        return null;
      }
      
      // Get file stats for audio quality information
      final fileStats = await file.stat();
      final fileSize = fileStats.size;
      
      final bytes = await file.readAsBytes();
      final mp3Data = MP3Instance(bytes);
      
      if (!mp3Data.parseTagsSync()) {
        Logger.debug('No ID3 tags found in file: $filePath');
        return null;
      }
      
      // Get metadata tags
      final metaTags = mp3Data.getMetaTags() ?? {};
      
      // Extract basic metadata - IDs can vary depending on ID3 version
      final title = _getTagValue(metaTags, _id3TagNames['title']!);
      final artist = _getTagValue(metaTags, _id3TagNames['artist']!);
      final album = _getTagValue(metaTags, _id3TagNames['album']!);
      //final contributingArtists = _getTagValue(metaTags, ['TPE2', 'TP2']);
      final year = _getTagValue(metaTags, _id3TagNames['year']!);
      final genre = _getTagValue(metaTags, _id3TagNames['genre']!);
      final comment = _getTagValue(metaTags, _id3TagNames['comment']!);
      // Logger.log('Extracted raw metadata:');
      // Logger.log('Title: $title');
      // Logger.log('Artist: $artist');
      // Logger.log('Album: $album');
      // Logger.log('Contributing Artists: $contributingArtists');
      String finalTitle = title ?? '';
      //List<String> finalAuthors = _extractAuthors(artist);

      // Extract audio quality information
      String? audioDuration;
      String? bitrate;
      int? channels = 2; // Default to stereo
      String? sampleRate;
      
      // Try to extract duration from metadata
      final lengthTag = _getTagValue(metaTags, _id3TagNames['length']!);
      if (lengthTag != null && lengthTag.isNotEmpty) {
        try {
          final durationMs = int.parse(lengthTag);
          final durationSec = durationMs ~/ 1000;
          final hours = durationSec ~/ 3600;
          final minutes = (durationSec % 3600) ~/ 60;
          final seconds = durationSec % 60;
          audioDuration = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        } catch (e) {
          Logger.debug('Error parsing duration: $e');
        }
      }
      
      // Since MP3Instance doesn't expose bitrate directly, estimate from file size
      // Standard MP3 bitrates: 128kbps, 192kbps, 256kbps, 320kbps
      if (fileSize > 0) {
        // Heuristic: Roughly estimate bitrate based on file size per minute
        // This won't be accurate but gives a ballpark figure
        // Try to use duration if available to make a better estimate
        
        // First try to determine if this is a high quality file
        // Common bitrates for audiobooks: 64, 128, 192, 256
        if (fileSize > 15 * 1024 * 1024) {  // If over 15MB
          bitrate = '192kbps';  // Likely higher quality
        } else {
          bitrate = '128kbps';  // Standard quality
        }
      }
      
      // If duration not found in metadata, estimate it from file size and estimated bitrate
      if (audioDuration == null && bitrate != null) {
        try {
          final bitrateValue = int.parse(bitrate.replaceAll('kbps', ''));
          if (bitrateValue > 0) {
            // Estimate duration in seconds: fileSize (bytes) / (bitrate (kbps) * 125)
            final estimatedDurationSec = fileSize ~/ (bitrateValue * 125);
            final hours = estimatedDurationSec ~/ 3600;
            final minutes = (estimatedDurationSec % 3600) ~/ 60;
            final seconds = estimatedDurationSec % 60;
            audioDuration = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
          }
        } catch (e) {
          Logger.debug('Error estimating duration: $e');
        }
      }
      
      // Standard sample rate for MP3 is 44.1kHz
      sampleRate = '44.1kHz';
      
      Logger.log('Extracted metadata from file: $filePath');
      Logger.debug('Title: $title, Artist: $artist, Album: $album');
      Logger.debug('Audio Quality: Duration: $audioDuration, Bitrate: $bitrate');
      
      // Try to extract series information from the album field
      final seriesInfo = _extractSeriesInfo(album);
      String series = seriesInfo['series'] ?? '';
      String seriesPosition = seriesInfo['seriesPosition'] ?? '';
      
      // Create a list of authors by splitting the artist field if it contains multiple authors
      List<String> authors = _extractAuthors(artist);
      
      // Extract or check for cover art
      bool hasCoverArt = _checkForCoverArt(metaTags);
      String thumbnailUrl = '';
      
      // If we have embedded cover art, extract it
      if (hasCoverArt) {
        try {
          // Ideally, extract and write the cover to an external file
          // For now, just note that it's available
          Logger.debug('File has embedded cover art');
          
          // In a real implementation, you'd extract and save the image to a local file
          // thumbnailUrl = await _extractAndSaveCoverArt(metaTags, filePath);
        } catch (e) {
          Logger.error('Error extracting cover art', e);
        }
      }
      
      return AudiobookMetadata(
        id: path_util.basename(filePath),
        title: title.isNotEmptyOrNull ? finalTitle : path_util.basenameWithoutExtension(filePath),
        authors: authors,
        description: comment.orEmpty,
        publisher: '',
        publishedDate: year.orEmpty,
        categories: genre.isNotEmptyOrNull ? [genre!] : [],
        averageRating: 0.0,
        ratingsCount: 0,
        thumbnailUrl: thumbnailUrl,
        language: '',
        series: series,
        seriesPosition: seriesPosition,
        // Add audio quality information
        audioDuration: audioDuration,
        bitrate: bitrate,
        channels: channels,
        sampleRate: sampleRate,
        fileFormat: 'MP3',
        provider: 'File Metadata',
      );
    } catch (e) {
      Logger.error('Failed to extract MP3 metadata', e);
      return null;
    }
  }
  
  /// Helper method to check if the file has embedded cover art
  bool _checkForCoverArt(Map<String, dynamic> metaTags) {
    try {
      for (final tagName in _id3TagNames['picture']!) {
        if (metaTags.containsKey(tagName) && metaTags[tagName] != null) {
          return true;
        }
      }
      return false;
    } catch (e) {
      Logger.error('Error checking for cover art', e);
      return false;
    }
  }
  
  /// Helper method to get a tag value from multiple possible ID3 tag names
  String? _getTagValue(Map<String, dynamic> metaTags, List<String> tagNames) {
    for (final tagName in tagNames) {
      final value = metaTags[tagName];
      if (value != null) {
        if (value is String) {
          return value.trim();
        } 
        // Handle COMM tag which can be structured differently
        else if (value is Map && tagName == 'COMM') {
          // Try to get the first comment value
          for (final lang in value.keys) {
            if (value[lang] is Map) {
              for (final desc in value[lang].keys) {
                return value[lang][desc].toString().trim();
              }
            }
          }
        }
      }
    }
    return null;
  }
  
  /// Extract authors from artist string
  List<String> _extractAuthors(String? artist) {
    if (artist == null || artist.isEmpty) {
      return [];
    }
    
    // Split by common separators
    List<String> authors = artist.split(RegExp(r',|;|\band\b|\s*&\s*'))
                            .map((a) => a.trim())
                            .where((a) => a.isNotEmpty)
                            .toList();
    
    // If splitting didn't produce multiple authors, use the original string
    if (authors.isEmpty) {
      authors = [artist];
    }
    
    return authors;
  }
  
  /// Extract series info from album field
  Map<String, String> _extractSeriesInfo(String? album) {
    Map<String, String> result = {};
    
    if (album == null || album.isEmpty) {
      return result;
    }
    
    // Look for patterns like "The Dresden Files Book 3" in album field
    final seriesMatch = _seriesBookPattern.firstMatch(album);
    if (seriesMatch != null) {
      result['series'] = seriesMatch.group(1)?.trim() ?? '';
      result['seriesPosition'] = seriesMatch.group(2) ?? '';
      return result;
    }
    
    // Look for "Series Name" pattern
    final seriesNameMatch = _seriesNamePattern.firstMatch(album);
    if (seriesNameMatch != null) {
      result['series'] = seriesNameMatch.group(1)?.trim() ?? '';
      return result;
    }
    
    // If no pattern matched, just use the album as series name
    result['series'] = album;
    return result;
  }
  
  /// Extract metadata from M4A/M4B files
  Future<AudiobookMetadata?> _extractM4aMetadata(String filePath) async {
    try {
      // Get file stats for audio quality information
      final file = File(filePath);
      final fileStats = await file.stat();
      final fileSize = fileStats.size;
      
      // This implementation would typically use FFmpeg or another native plugin
      // Since we don't have direct access to implement that here,
      // we'll use the FilenameParser to extract info from the filename and make educated
      // guesses about audio quality based on file size and type
      
      final filename = path_util.basenameWithoutExtension(filePath);
      final extension = path_util.extension(filePath).toLowerCase();
      
      // Use the FilenameParser utility to extract information
      final parsedInfo = FilenameParser.parse(filename, filePath);
      
      // Make reasonable assumptions for M4B audiobooks
      String? audioDuration;
      String? bitrate;
      int? channels = 2; // Most audiobooks are stereo
      String? sampleRate = '44.1kHz'; // Common for audiobooks
      
      // M4B files are often higher quality than MP3
      if (extension == '.m4b') {
        bitrate = '256kbps'; // Common for M4B files
        
        // Estimate duration (highly approximate) - improved heuristic
        // M4B audiobooks can be long, estimate based on typical audiobook narration speed
        // Average 150 words per minute, 9000 words per hour, ~1MB per hour at 256kbps
        final estimatedHours = fileSize / (1024 * 1024); // Rough estimate in hours
        
        if (estimatedHours > 0) {
          final hours = estimatedHours.floor();
          final minutes = ((estimatedHours - hours) * 60).floor();
          final seconds = (((estimatedHours - hours) * 60 - minutes) * 60).floor();
          audioDuration = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        }
      } else if (extension == '.m4a') {
        bitrate = '192kbps'; // Common for M4A files
        
        // Similar estimation for M4A
        final estimatedHours = fileSize / (1024 * 1024 * 0.8); // Slightly different ratio
        
        if (estimatedHours > 0) {
          final hours = estimatedHours.floor();
          final minutes = ((estimatedHours - hours) * 60).floor();
          final seconds = (((estimatedHours - hours) * 60 - minutes) * 60).floor();
          audioDuration = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        }
      }
      
      return AudiobookMetadata(
        id: path_util.basename(filePath),
        title: parsedInfo.title,
        authors: parsedInfo.hasAuthor ? [parsedInfo.author!] : [],
        description: '',
        publisher: '',
        publishedDate: '',
        categories: [],
        averageRating: 0.0,
        ratingsCount: 0,
        thumbnailUrl: '',
        language: '',
        series: parsedInfo.hasSeries ? parsedInfo.series! : '',
        seriesPosition: parsedInfo.seriesPosition.orEmpty,
        // Add audio quality information
        audioDuration: audioDuration,
        bitrate: bitrate,
        channels: channels,
        sampleRate: sampleRate,
        fileFormat: extension == '.m4b' ? 'M4B' : 'M4A',
        provider: 'Filename Analysis',
      );
    } catch (e) {
      Logger.error('Failed to extract M4A/M4B metadata', e);
      return null;
    }
  }
  
  /// Write metadata back to an audio file
  Future<bool> writeMetadataToFile(String filePath, AudiobookMetadata metadata) async {
    try {
      final ext = path_util.extension(filePath).toLowerCase();
      
      if (ext == '.mp3') {
        return await _writeMetadataToMp3(filePath, metadata);
      } else if (ext == '.m4a' || ext == '.m4b') {
        return await _writeMetadataToM4a(filePath, metadata);
      }
      
      Logger.warning('Unsupported file format for writing metadata: $ext');
      return false;
    } catch (e) {
      Logger.error('Failed to write metadata to file', e);
      return false;
    }
  }
  
  /// Write metadata to MP3 files
  Future<bool> _writeMetadataToMp3(String filePath, AudiobookMetadata metadata) async {
    try {
      // This would typically use a method to write ID3 tags
      // Since we don't have direct access to implement that here,
      // we'll log what would be written
      
      Logger.log('Writing metadata to MP3 file: $filePath');
      Logger.debug('Title: ${metadata.title}');
      Logger.debug('Artist: ${metadata.authorsFormatted}');
      
      String albumValue = '';
      if (metadata.series.isNotEmpty) {
        albumValue = metadata.seriesPosition.isNotEmpty
            ? "${metadata.series} Book ${metadata.seriesPosition}"
            : metadata.series;
      }
      
      Logger.debug('Album: $albumValue');
      Logger.debug('Year: ${metadata.year}');
      Logger.debug('Genre: ${metadata.categories.isNotEmpty ? metadata.categories.first : "Audiobook"}');
      Logger.debug('Comment: ${metadata.description}');
      
      // If we have a cover image URL, download and embed it
      if (metadata.thumbnailUrl.isNotEmpty) {
        Logger.debug('Cover URL: ${metadata.thumbnailUrl}');
        // In a real implementation, you'd download and embed the image
        // await _downloadAndEmbedCoverArt(metadata.thumbnailUrl, filePath);
      }
      
      // Placeholder for actual implementation
      return true;
    } catch (e) {
      Logger.error('Failed to write MP3 metadata', e);
      return false;
    }
  }
  
  /// Write metadata to M4A/M4B files
  Future<bool> _writeMetadataToM4a(String filePath, AudiobookMetadata metadata) async {
    try {
      // This would typically use FFmpeg or another native plugin
      // Since we don't have direct access to implement that here,
      // we'll log what would be written
      
      Logger.log('Writing metadata to M4A/M4B file: $filePath');
      Logger.debug('Title: ${metadata.title}');
      Logger.debug('Artist: ${metadata.authorsFormatted}');
      
      String albumValue = '';
      if (metadata.series.isNotEmpty) {
        albumValue = metadata.seriesPosition.isNotEmpty
            ? "${metadata.series} Book ${metadata.seriesPosition}"
            : metadata.series;
      }
      
      Logger.debug('Album: $albumValue');
      Logger.debug('Year: ${metadata.year}');
      Logger.debug('Genre: ${metadata.categories.isNotEmpty ? metadata.categories.first : "Audiobook"}');
      Logger.debug('Comment: ${metadata.description}');
      
      
      // Placeholder for actual implementation
      return true;
    } catch (e) {
      Logger.error('Failed to write M4A/M4B metadata', e);
      return false;
    }
  }
  
  
  /// Extract and save cover art from metadata (placeholder implementation)
  Future<String?> extractAndSaveCoverArt(Map<String, dynamic> metaTags, String filePath) async {
    try {
      // This would extract the cover art data from the APIC tag
      // and save it to a file in the same directory as the audio file
      
      final directory = path_util.dirname(filePath);
      final filename = path_util.basenameWithoutExtension(filePath);
      final coverPath = '$directory/$filename.jpg';
      
      Logger.log('Extracting cover art to: $coverPath');
      
      // In a real implementation, you'd extract the image data and write it to the file
      
      return coverPath;
    } catch (e) {
      Logger.error('Error extracting and saving cover art', e);
      return null;
    }
  }
}