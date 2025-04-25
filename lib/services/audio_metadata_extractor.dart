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
      // Try different potential tag names
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
  // (This would require a different approach, possibly using FFmpeg
  // or another library that can read AAC container metadata)
  Future<AudiobookMetadata?> _extractM4aMetadata(String filePath) async {
    // This would require a different library for M4A/M4B files
    print('LOG: M4A/M4B metadata extraction not yet implemented');
    return null;
  }
}