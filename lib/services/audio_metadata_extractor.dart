// File: lib/services/audio_metadata_extractor.dart
import 'dart:io';
import 'package:path/path.dart' as path_util;
import 'package:id3/id3.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';

class AudioMetadataExtractor {
  // Check if the file type is supported for metadata extraction
  bool isSupported(String filePath) {
    String ext = path_util.extension(filePath).toLowerCase();
    return ['.mp3', '.m4a', '.m4b'].contains(ext);
  }
  
  // Extract metadata from the audio file
  Future<AudiobookMetadata?> extractMetadata(String filePath) async {
    try {
      if (!isSupported(filePath)) {
        print('LOG: File format not supported for metadata extraction: $filePath');
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
      print('ERROR: Failed to extract metadata from file: $e');
      return null;
    }
  }
  
  // Extract metadata from MP3 files
  Future<AudiobookMetadata?> _extractMp3Metadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      
      final bytes = await file.readAsBytes();
      final mp3Data = MP3Instance(bytes);
      
      if (!mp3Data.parseTagsSync()) {
        print('LOG: No ID3 tags found in file: $filePath');
        return null;
      }
      
      // Get metadata tags
      final metaTags = mp3Data.getMetaTags() ?? {};
      
      // Extract basic metadata - IDs can vary depending on ID3 version
      final title = _getTagValue(metaTags, ['Title', 'TIT2', 'TT2']);
      final artist = _getTagValue(metaTags, ['Artist', 'TPE1', 'TP1']);
      final album = _getTagValue(metaTags, ['Album', 'TALB', 'TAL']);
      final year = _getTagValue(metaTags, ['Year', 'TYER', 'TYE']);
      final genre = _getTagValue(metaTags, ['Genre', 'TCON', 'TCO']);
      final comment = _getTagValue(metaTags, ['Comment', 'COMM']);
      
      print('LOG: Extracted metadata from file: $filePath');
      print('LOG: Title: $title, Artist: $artist, Album: $album');
      
      // Try to extract series information from the album field
      String series = '';
      String seriesPosition = '';
      
      if (album.isNotEmpty) {
        // Look for patterns like "The Dresden Files Book 3" in album field
        final seriesMatch = RegExp(r'(.*?)(?:\s+Book\s+|#)(\d+)').firstMatch(album);
        if (seriesMatch != null) {
          series = seriesMatch.group(1)?.trim() ?? '';
          seriesPosition = seriesMatch.group(2) ?? '';
        } else {
          // Look for "Series Name" pattern
          final seriesNameMatch = RegExp(r'(.*?)\s+Series').firstMatch(album);
          if (seriesNameMatch != null) {
            series = seriesNameMatch.group(1)?.trim() ?? '';
          } else {
            // If no pattern matched, just use the album as series name
            series = album;
          }
        }
      }
      
      // Create a list of authors by splitting the artist field if it contains multiple authors
      List<String> authors = [];
      if (artist.isNotEmpty) {
        authors = artist.split(',')
                       .map((a) => a.trim())
                       .where((a) => a.isNotEmpty)
                       .toList();
      }
      
      // If authors list is empty but we have an artist, use that
      if (authors.isEmpty && artist.isNotEmpty) {
        authors = [artist];
      }
      
      return AudiobookMetadata(
        id: path_util.basename(filePath), // Use filename as ID for local metadata
        title: title.isNotEmpty ? title : path_util.basenameWithoutExtension(filePath),
        authors: authors,
        description: comment,
        publisher: '',
        publishedDate: year,
        categories: genre.isNotEmpty ? [genre] : [],
        averageRating: 0.0,
        ratingsCount: 0,
        thumbnailUrl: '',
        language: '',
        series: series,
        seriesPosition: seriesPosition,
        provider: 'File Metadata',
      );
    } catch (e) {
      print('ERROR: Failed to extract MP3 metadata: $e');
      return null;
    }
  }
  
  // Helper method to get a tag value from multiple possible ID3 tag names
  String _getTagValue(Map<String, dynamic> metaTags, List<String> tagNames) {
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
    return '';
  }
  
  // Extract metadata from M4A/M4B files
  Future<AudiobookMetadata?> _extractM4aMetadata(String filePath) async {
    try {
      // This implementation would typically use FFmpeg or another native plugin
      // Since we don't have direct access to implement that here,
      // we'll use a placeholder implementation that tries to extract info from the filename
      
      final filename = path_util.basenameWithoutExtension(filePath);
      
      // Try to extract author and title from filename patterns
      Map<String, String> parsedInfo = _parseFilenameForMetadata(filename);
      
      return AudiobookMetadata(
        id: path_util.basename(filePath),
        title: parsedInfo['title'] ?? filename,
        authors: parsedInfo['author']?.isNotEmpty == true ? [parsedInfo['author']!] : [],
        description: '',
        publisher: '',
        publishedDate: '',
        categories: [],
        averageRating: 0.0,
        ratingsCount: 0,
        thumbnailUrl: '',
        language: '',
        series: parsedInfo['series'] ?? '',
        seriesPosition: parsedInfo['seriesPosition'] ?? '',
        provider: 'Filename Analysis',
      );
    } catch (e) {
      print('ERROR: Failed to extract M4A/M4B metadata: $e');
      return null;
    }
  }
  
  // Helper method to parse a filename for potential metadata
  Map<String, String> _parseFilenameForMetadata(String filename) {
    Map<String, String> result = {};
    
    // Clean the filename for analysis
    String cleanName = filename
      .replaceAll(RegExp(r'\bAudiobook\b|\bUnabridged\b'), '')
      .replaceAll(RegExp(r'[_\.-]'), ' ')
      .trim();
    
    // Try to parse "Author - Title" pattern
    var authorTitleMatch = RegExp(r'^(.*?)\s+-\s+(.*)$').firstMatch(cleanName);
    if (authorTitleMatch != null) {
      result['author'] = authorTitleMatch.group(1)?.trim() ?? '';
      result['title'] = authorTitleMatch.group(2)?.trim() ?? '';
      return result;
    }
    
    // Try to parse "Title by Author" pattern
    var titleByAuthorMatch = RegExp(r'^(.*?)\s+by\s+(.*)$', caseSensitive: false).firstMatch(cleanName);
    if (titleByAuthorMatch != null) {
      result['title'] = titleByAuthorMatch.group(1)?.trim() ?? '';
      result['author'] = titleByAuthorMatch.group(2)?.trim() ?? '';
      return result;
    }
    
    // Try to parse "Series Name Book X - Title" pattern
    var seriesMatch = RegExp(r'^(.*?)\s+Book\s+(\d+)\s+-\s+(.*)$', caseSensitive: false).firstMatch(cleanName);
    if (seriesMatch != null) {
      result['series'] = seriesMatch.group(1)?.trim() ?? '';
      result['seriesPosition'] = seriesMatch.group(2)?.trim() ?? '';
      result['title'] = seriesMatch.group(3)?.trim() ?? '';
      return result;
    }
    
    // If no pattern matched, just use the whole string as title
    result['title'] = cleanName;
    return result;
  }
  
  // Write metadata back to an audio file
  Future<bool> writeMetadataToFile(String filePath, AudiobookMetadata metadata) async {
    try {
      final ext = path_util.extension(filePath).toLowerCase();
      
      if (ext == '.mp3') {
        return await _writeMetadataToMp3(filePath, metadata);
      } else if (ext == '.m4a' || ext == '.m4b') {
        return await _writeMetadataToM4a(filePath, metadata);
      }
      
      print('LOG: Unsupported file format for writing metadata: $ext');
      return false;
    } catch (e) {
      print('ERROR: Failed to write metadata to file: $e');
      return false;
    }
  }
  
  // Write metadata to MP3 files
  Future<bool> _writeMetadataToMp3(String filePath, AudiobookMetadata metadata) async {
    try {
      // This would typically use a method to write ID3 tags
      // Since we don't have direct access to implement that here,
      // we'll log what would be written
      
      print('LOG: Would write the following metadata to MP3 file: $filePath');
      print('LOG: Title: ${metadata.title}');
      print('LOG: Artist: ${metadata.authorsFormatted}');
      print('LOG: Album: ${metadata.series.isNotEmpty ? "${metadata.series} Book ${metadata.seriesPosition}" : ""}');
      print('LOG: Year: ${metadata.year}');
      print('LOG: Genre: ${metadata.categories.isNotEmpty ? metadata.categories.first : "Audiobook"}');
      print('LOG: Comment: ${metadata.description}');
      
      // Placeholder for actual implementation
      return true;
    } catch (e) {
      print('ERROR: Failed to write MP3 metadata: $e');
      return false;
    }
  }
  
  // Write metadata to M4A/M4B files
  Future<bool> _writeMetadataToM4a(String filePath, AudiobookMetadata metadata) async {
    try {
      // This would typically use FFmpeg or another native plugin
      // Since we don't have direct access to implement that here,
      // we'll log what would be written
      
      print('LOG: Would write the following metadata to M4A/M4B file: $filePath');
      print('LOG: Title: ${metadata.title}');
      print('LOG: Artist: ${metadata.authorsFormatted}');
      print('LOG: Album: ${metadata.series.isNotEmpty ? "${metadata.series} Book ${metadata.seriesPosition}" : ""}');
      print('LOG: Year: ${metadata.year}');
      print('LOG: Genre: ${metadata.categories.isNotEmpty ? metadata.categories.first : "Audiobook"}');
      print('LOG: Comment: ${metadata.description}');
      
      // Placeholder for actual implementation
      return true;
    } catch (e) {
      print('ERROR: Failed to write M4A/M4B metadata: $e');
      return false;
    }
  }
}