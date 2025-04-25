// File: lib/models/audiobook_file.dart
import 'dart:io';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/audio_metadata_extractor.dart';

class AudiobookFile {
  final String path;
  final String filename;
  final String extension;
  final int size;
  final DateTime lastModified;
  AudiobookMetadata? metadata;      // Online or combined metadata
  AudiobookMetadata? fileMetadata;  // Metadata extracted directly from the file
  bool _fileMetadataAttempted = false; // Flag to track if we've tried extracting file metadata

  AudiobookFile({
    required this.path,
    required this.filename,
    required this.extension,
    required this.size,
    required this.lastModified,
    this.metadata,
    this.fileMetadata,
  });

  factory AudiobookFile.fromFile(File file) {
    // Create local variables for the values
    final filePath = file.path;
    final fileBasename = path_util.basenameWithoutExtension(filePath);
    final fileExtension = path_util.extension(filePath).toLowerCase();
    final fileSize = file.lengthSync();
    final fileLastModified = file.lastModifiedSync();
    
    return AudiobookFile(
      path: filePath,
      filename: fileBasename,
      extension: fileExtension,
      size: fileSize,
      lastModified: fileLastModified,
    );
  }
  
  // Basic getters
  bool get hasMetadata => metadata != null;
  bool get hasFileMetadata => fileMetadata != null;
  bool get hasAnyMetadata => metadata != null || fileMetadata != null;
  String get fullPath => path;
  
  // Display name based on available metadata
  String get displayName {
    // Use online metadata first if available
    if (metadata?.title.isNotEmpty == true) {
      return metadata!.title;
    }
    // Fall back to file metadata
    if (fileMetadata?.title.isNotEmpty == true) {
      return fileMetadata!.title;
    }
    // Last resort: clean the filename
    return _cleanFilenameForDisplay();
  }
  
  // Author based on available metadata
  String get author {
    // Use online metadata first
    if (metadata?.authors.isNotEmpty == true) {
      return metadata!.authors.first;
    }
    // Fall back to file metadata
    if (fileMetadata?.authors.isNotEmpty == true) {
      return fileMetadata!.authors.first;
    }
    // Last resort: try to extract from filename
    return _extractAuthorFromFilename();
  }
  
  // Series based on available metadata
  String get series {
    // Use online metadata first
    if (metadata?.series.isNotEmpty == true) {
      return metadata!.series;
    }
    // Fall back to file metadata
    if (fileMetadata?.series.isNotEmpty == true) {
      return fileMetadata!.series;
    }
    return '';
  }
  
  // Series position based on available metadata
  String get seriesPosition {
    // Use online metadata first
    if (metadata?.seriesPosition.isNotEmpty == true) {
      return metadata!.seriesPosition;
    }
    // Fall back to file metadata
    if (fileMetadata?.seriesPosition.isNotEmpty == true) {
      return fileMetadata!.seriesPosition;
    }
    return '';
  }
  
  // Check if metadata is complete enough for library view
  bool get hasCompleteMetadata {
    // Get the most complete metadata
    final metaToCheck = metadata ?? fileMetadata;
    if (metaToCheck == null) return false;
    
    // Check required fields
    return metaToCheck.title.isNotEmpty && 
           metaToCheck.authors.isNotEmpty &&
           (metaToCheck.series.isNotEmpty || 
            metaToCheck.description.isNotEmpty || 
            metaToCheck.publishedDate.isNotEmpty);
  }
  
  // Identify files that need metadata review
  bool get needsMetadataReview {
    return !hasCompleteMetadata;
  }

  // Extract metadata from the file
  Future<AudiobookMetadata?> extractFileMetadata() async {
    // If we already have file metadata or tried to extract it before, return what we have
    if (_fileMetadataAttempted) return fileMetadata;
    
    _fileMetadataAttempted = true;
    
    final extractor = AudioMetadataExtractor();
    if (!extractor.isSupported(path)) {
      print('LOG: File format not supported for metadata extraction: $path');
      return null;
    }
    
    try {
      fileMetadata = await extractor.extractMetadata(path);
      if (fileMetadata != null) {
        print('LOG: Successfully extracted metadata from file: $path');
      } else {
        print('LOG: No metadata found in file: $path');
      }
      return fileMetadata;
    } catch (e) {
      print('ERROR: Error extracting file metadata: $e');
      return null;
    }
  }
  
  // Write metadata back to the file
  Future<bool> writeMetadataToFile(AudiobookMetadata metadataToWrite) async {
    try {
      final extractor = AudioMetadataExtractor();
      final success = await extractor.writeMetadataToFile(path, metadataToWrite);
      
      if (success) {
        // Update our own metadata references
        fileMetadata = metadataToWrite;
        if (metadata == null) {
          metadata = metadataToWrite;
        }
        print('LOG: Successfully wrote metadata to file: $path');
      } else {
        print('LOG: Failed to write metadata to file: $path');
      }
      
      return success;
    } catch (e) {
      print('ERROR: Error writing metadata to file: $e');
      return false;
    }
  }

  // Clean up filename for display when metadata isn't available
  String _cleanFilenameForDisplay() {
    // Handle series numbering in filenames like "1 - Book Title" or "Book 1 - Title"
    final seriesMatch = RegExp(r'^(?:Book\s+)?(\d+)\s*[-_:]\s*(.+)$').firstMatch(filename);
    if (seriesMatch != null) {
      return seriesMatch.group(2) ?? filename;
    }
    
    // Remove common prefixes like "Chapter", "Track", etc.
    String cleaned = filename
      .replaceFirst(RegExp(r'^(?:Chapter|Track|Part|CD|Disc)\s*\d+\s*[-_:]\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^of\s+\d+\s*[-_:]\s*', caseSensitive: false), '') // "of 45 - Title" format
      .replaceFirst(RegExp(r'^\d+\s*[-_:]\s*', caseSensitive: false), ''); // "01 - Title" format
      
    // Special case for filenames with author - title format
    final authorMatch = RegExp(r'^(.*?)\s+-\s+(.*)$').firstMatch(cleaned);
    if (authorMatch != null) {
      // If we have both author and title components
      final authorPart = authorMatch.group(1);
      final titlePart = authorMatch.group(2);
      
      if (authorPart != null && titlePart != null) {
        // Check if the author part contains words that suggest it's part of the title
        // (to handle cases like "Harry Potter - The Sorcerer's Stone")
        final lowerAuthor = authorPart.toLowerCase();
        if (lowerAuthor.contains('book') || 
            lowerAuthor.contains('part') || 
            lowerAuthor.contains('volume') ||
            lowerAuthor.contains('chapter')) {
          // This is probably not an author but part of the title
          return cleaned;
        }
        // Otherwise return just the title part
        return titlePart;
      }
    }
    
    return cleaned;
  }
  
  // Try to extract author from filename
  String _extractAuthorFromFilename() {
    // Look for "Author - Title" pattern
    final authorMatch = RegExp(r'^(.*?)\s+-\s+.*$').firstMatch(filename);
    if (authorMatch != null && authorMatch.group(1) != null) {
      final authorPart = authorMatch.group(1)!;
      
      // Reject if this looks like part of title and not an author
      final lowerAuthor = authorPart.toLowerCase();
      if (lowerAuthor.contains('book') || 
          lowerAuthor.contains('part') || 
          lowerAuthor.contains('volume') ||
          lowerAuthor.contains('chapter')) {
        return 'Unknown Author';
      }
      
      return authorPart;
    }
    
    // Look for "Title by Author" pattern
    final byMatch = RegExp(r'.*\sby\s+(.*?)$', caseSensitive: false).firstMatch(filename);
    if (byMatch != null && byMatch.group(1) != null) {
      return byMatch.group(1)!;
    }
    
    // Try to extract from parent directory name
    try {
      final parentDir = path_util.basename(path_util.dirname(path));
      
      // Skip if parentDir is too generic
      if (['audio', 'audiobooks', 'books', 'files'].contains(parentDir.toLowerCase())) {
        return 'Unknown Author';
      }
      
      // Look for "Title - Author" pattern in directory name
      final dirMatch = RegExp(r'^.*?\s+-\s+(.*?)$').firstMatch(parentDir);
      if (dirMatch != null && dirMatch.group(1) != null) {
        return dirMatch.group(1)!;
      }
      
      // Look for "Author - Title" pattern in directory name
      final dirAuthorMatch = RegExp(r'^(.*?)\s+-\s+.*$').firstMatch(parentDir);
      if (dirAuthorMatch != null && dirAuthorMatch.group(1) != null) {
        // Check if this looks like a valid author name
        final authorPart = dirAuthorMatch.group(1)!;
        if (!authorPart.toLowerCase().contains('book') && 
            !authorPart.toLowerCase().contains('part') &&
            !authorPart.toLowerCase().contains('volume')) {
          return authorPart;
        }
      }
    } catch (_) {
      // Ignore errors in directory parsing
    }
    
    return 'Unknown Author';
  }

  // Extract potential title and author from filename
  Map<String, String> parseFilename() {
    String cleanName = filename
      .replaceAll(RegExp(r'\bAudiobook\b|\bUnabridged\b'), '')
      .replaceAll(RegExp(r'[_\.-]'), ' ')
      .trim();
    
    // Try to parse "Author - Title" pattern
    var authorTitleMatch = RegExp(r'^(.*?)\s+-\s+(.*)$').firstMatch(cleanName);
    if (authorTitleMatch != null) {
      final authorPart = authorTitleMatch.group(1)?.trim() ?? '';
      final titlePart = authorTitleMatch.group(2)?.trim() ?? '';
      
      // Check if the author part contains words that suggest it's not an author
      final lowerAuthor = authorPart.toLowerCase();
      if (lowerAuthor.contains('book') || 
          lowerAuthor.contains('part') || 
          lowerAuthor.contains('volume') ||
          lowerAuthor.contains('chapter')) {
        // This is probably not an author but part of the title
        return {
          'title': cleanName,
        };
      }
      
      return {
        'author': authorPart,
        'title': titlePart,
      };
    }
    
    // Try to parse "Title by Author" pattern
    var titleByAuthorMatch = RegExp(r'^(.*?)\s+by\s+(.*)$', caseSensitive: false).firstMatch(cleanName);
    if (titleByAuthorMatch != null) {
      return {
        'title': titleByAuthorMatch.group(1)?.trim() ?? '',
        'author': titleByAuthorMatch.group(2)?.trim() ?? '',
      };
    }
    
    // Try to parse "Series Name Book X - Title" pattern
    var seriesMatch = RegExp(r'^(.*?)\s+Book\s+(\d+)\s+-\s+(.*)$', caseSensitive: false).firstMatch(cleanName);
    if (seriesMatch != null) {
      return {
        'series': seriesMatch.group(1)?.trim() ?? '',
        'seriesPosition': seriesMatch.group(2)?.trim() ?? '',
        'title': seriesMatch.group(3)?.trim() ?? '',
      };
    }
    
    // Try to extract from parent directory name
    try {
      final dirPath = path_util.dirname(path);
      final parentDir = path_util.basename(dirPath);
      
      // Skip if parentDir is too generic
      if (!['audio', 'audiobooks', 'books', 'files'].contains(parentDir.toLowerCase())) {
        // If filename doesn't have author info but directory has "Author - Title" format,
        // use that information
        final dirMatch = RegExp(r'^(.*?)\s+-\s+(.*)$').firstMatch(parentDir);
        if (dirMatch != null) {
          final dirAuthor = dirMatch.group(1)?.trim();
          final dirTitle = dirMatch.group(2)?.trim();
          
          if (dirAuthor != null && dirTitle != null) {
            // Check if directory title matches our filename
            if (cleanName.toLowerCase().contains(dirTitle.toLowerCase()) ||
                dirTitle.toLowerCase().contains(cleanName.toLowerCase())) {
              return {
                'author': dirAuthor,
                'title': cleanName,
              };
            }
            
            // Otherwise, use both pieces of info
            return {
              'author': dirAuthor,
              'title': dirTitle,
            };
          }
        }
      }
    } catch (_) {
      // Ignore errors in directory parsing
    }
    
    // Default to assuming the whole string is the title
    return {
      'title': cleanName,
    };
  }

  // Generate a search query for online metadata
  String generateSearchQuery() {
    // First try to use file metadata if available
    if (fileMetadata != null) {
      List<String> queryParts = [];
      
      if (fileMetadata!.title.isNotEmpty) {
        queryParts.add(fileMetadata!.title);
      }
      
      if (fileMetadata!.authors.isNotEmpty) {
        queryParts.add(fileMetadata!.authors.join(' '));
      }
      
      if (fileMetadata!.series.isNotEmpty) {
        queryParts.add(fileMetadata!.series);
      }
      
      if (queryParts.isNotEmpty) {
        final query = queryParts.join(' ');
        print('LOG: Generated search query from file metadata: $query');
        return query;
      }
    }
    
    // Fall back to filename parsing if file metadata is unavailable
    var parsed = parseFilename();
    
    // If we have both author and title, use them
    if (parsed.containsKey('author') && parsed.containsKey('title')) {
      return '${parsed['title']} ${parsed['author']}';
    } 
    // If we have a series name, include that
    else if (parsed.containsKey('series') && parsed.containsKey('title')) {
      return '${parsed['series']} ${parsed['title']}';
    }
    // If we have just a title
    else if (parsed.containsKey('title')) {
      // Check if we can extract author from the folder name
      final folderAuthor = _extractAuthorFromFilename();
      if (folderAuthor != 'Unknown Author') {
        return '${parsed['title']} $folderAuthor';
      }
      return parsed['title'] ?? '';
    }
    
    // Clean up filename for search if we couldn't parse it
    String cleanFilename = filename
      .replaceAll(RegExp(r'\bAudiobook\b|\bUnabridged\b'), '')
      .replaceAll(RegExp(r'[_\.\-\(\)\[\]]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
      
    return cleanFilename;
  }
}