// File: lib/utils/filename_parser.dart
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/utils/logger.dart';

/// Result class for parsed filename components
class ParsedFilename {
  final String title;
  final String? author;
  final String? series;
  final String? seriesPosition;
  
  ParsedFilename({
    required this.title,
    this.author,
    this.series,
    this.seriesPosition,
  });
  
  bool get hasAuthor => author != null && author!.isNotEmpty;
  bool get hasSeries => series != null && series!.isNotEmpty;
}

/// Utility class for parsing filenames to extract metadata information
class FilenameParser {
  // Common RegExp patterns as static constants
  static final RegExp _authorTitlePattern = RegExp(r'^(.*?)\s+-\s+(.*)$');
  static final RegExp _titleByAuthorPattern = RegExp(r'^(.*?)\s+by\s+(.*)$', caseSensitive: false);
  static final RegExp _seriesBookPattern = RegExp(r'^(.*?)\s+Book\s+(\d+)\s+-\s+(.*)$', caseSensitive: false);
  static final RegExp _seriesNumberTitlePattern = RegExp(r'^(?:Book\s+)?(\d+)\s*[-_:]\s*(.+)$');
  static final RegExp _chapterPrefixPattern = RegExp(r'^(?:Chapter|Track|Part|CD|Disc)\s*\d+\s*[-_:]\s*', caseSensitive: false);
  static final RegExp _ofPrefixPattern = RegExp(r'^of\s+\d+\s*[-_:]\s*', caseSensitive: false);
  static final RegExp _numberPrefixPattern = RegExp(r'^\d+\s*[-_:]\s*', caseSensitive: false);
  
  // List of generic folder names to ignore for directory parsing
  static final List<String> _genericFolders = ['audio', 'audiobooks', 'books', 'files', 'media', 'library'];
  
  // List of keywords that suggest text is part of title, not author
  static final List<String> _titleKeywords = ['book', 'part', 'volume', 'chapter', 'series'];
  
  /// Parse a filename to extract potential metadata components
  static ParsedFilename parse(String filename, String filePath) {
    // Clean the filename for parsing
    String cleanName = filename
      .replaceAll(RegExp(r'\bAudiobook\b|\bUnabridged\b'), '')
      .replaceAll(RegExp(r'[_\.-]'), ' ')
      .trim();
    
    // Try different parsing patterns
    
    // 1. Try "Author - Title" pattern
    var authorTitleMatch = _authorTitlePattern.firstMatch(cleanName);
    if (authorTitleMatch != null) {
      final authorPart = authorTitleMatch.group(1)?.trim() ?? '';
      final titlePart = authorTitleMatch.group(2)?.trim() ?? '';
      
      // Check if the author part contains words that suggest it's not an author
      if (!_looksLikeTitle(authorPart)) {
        return ParsedFilename(
          title: titlePart,
          author: authorPart,
        );
      }
    }
    
    // 2. Try "Title by Author" pattern
    var titleByAuthorMatch = _titleByAuthorPattern.firstMatch(cleanName);
    if (titleByAuthorMatch != null) {
      return ParsedFilename(
        title: titleByAuthorMatch.group(1)?.trim() ?? '',
        author: titleByAuthorMatch.group(2)?.trim() ?? '',
      );
    }
    
    // 3. Try "Series Name Book X - Title" pattern
    var seriesMatch = _seriesBookPattern.firstMatch(cleanName);
    if (seriesMatch != null) {
      return ParsedFilename(
        title: seriesMatch.group(3)?.trim() ?? '',
        series: seriesMatch.group(1)?.trim() ?? '',
        seriesPosition: seriesMatch.group(2)?.trim() ?? '',
      );
    }
    
    // 4. Try to extract from directory name
    ParsedFilename? dirResult = _extractFromDirectory(filePath);
    if (dirResult != null) {
      // If we got author from directory, use it with our filename as title
      return ParsedFilename(
        title: cleanName,
        author: dirResult.author,
        series: dirResult.series,
        seriesPosition: dirResult.seriesPosition,
      );
    }
    
    // 5. Default to the whole string as title
    return ParsedFilename(
      title: cleanName,
    );
  }
  
  /// Clean a filename for display purposes removing common prefixes
  static String cleanForDisplay(String filename) {
    // Handle series numbering in filenames
    final seriesMatch = _seriesNumberTitlePattern.firstMatch(filename);
    if (seriesMatch != null) {
      return seriesMatch.group(2) ?? filename;
    }
    
    // Remove common prefixes
    String cleaned = filename
      .replaceFirst(_chapterPrefixPattern, '')
      .replaceFirst(_ofPrefixPattern, '')
      .replaceFirst(_numberPrefixPattern, '');
      
    // Try to extract just the title part if in "Author - Title" format
    final authorMatch = _authorTitlePattern.firstMatch(cleaned);
    if (authorMatch != null) {
      final authorPart = authorMatch.group(1);
      final titlePart = authorMatch.group(2);
      
      if (authorPart != null && titlePart != null) {
        // Only use title part if author doesn't look like part of title
        if (!_looksLikeTitle(authorPart)) {
          return titlePart;
        }
      }
    }
    
    return cleaned;
  }
  
  /// Extract author information from a filename or path
  static String extractAuthor(String filename, String filePath) {
    // 1. Look for "Author - Title" pattern
    final authorMatch = _authorTitlePattern.firstMatch(filename);
    if (authorMatch != null && authorMatch.group(1) != null) {
      final authorPart = authorMatch.group(1)!;
      
      // Skip if author part looks like title component
      if (!_looksLikeTitle(authorPart)) {
        return authorPart;
      }
    }
    
    // 2. Look for "Title by Author" pattern
    final byMatch = RegExp(r'.*\sby\s+(.*?)$', caseSensitive: false).firstMatch(filename);
    if (byMatch != null && byMatch.group(1) != null) {
      return byMatch.group(1)!;
    }
    
    // 3. Try to extract from parent directory name
    try {
      final dirResult = _extractFromDirectory(filePath);
      if (dirResult != null && dirResult.hasAuthor) {
        return dirResult.author!;
      }
    } catch (e) {
      Logger.error("Error extracting author from directory", e);
    }
    
    return 'Unknown Author';
  }
  
  /// Check if a string likely contains title components rather than author name
  static bool _looksLikeTitle(String text) {
    final lowerText = text.toLowerCase();
    return _titleKeywords.any((keyword) => lowerText.contains(keyword));
  }
  
  /// Try to extract metadata from the directory name
  static ParsedFilename? _extractFromDirectory(String filePath) {
    try {
      final parentDir = path_util.basename(path_util.dirname(filePath));
      
      // Skip if directory is too generic
      if (_genericFolders.contains(parentDir.toLowerCase())) {
        return null;
      }
      
      // Look for "Title - Author" pattern in directory name
      final dirMatch = RegExp(r'^(.*?)\s+-\s+(.*?)$').firstMatch(parentDir);
      if (dirMatch != null) {
        final firstPart = dirMatch.group(1)?.trim();
        final secondPart = dirMatch.group(2)?.trim();
        
        if (firstPart != null && secondPart != null) {
          // Check if first part looks like an author name (doesn't contain title keywords)
          if (!_looksLikeTitle(firstPart)) {
            return ParsedFilename(
              title: secondPart,
              author: firstPart,
            );
          } 
          // Maybe it's "Title - Author" format
          else if (!_looksLikeTitle(secondPart)) {
            return ParsedFilename(
              title: firstPart,
              author: secondPart,
            );
          }
        }
      }
      
      // No patterns matched
      return null;
    } catch (e) {
      Logger.error("Error parsing directory", e);
      return null;
    }
  }
  
  /// Generate a search query for online metadata based on parsed filename
  static String generateSearchQuery(ParsedFilename parsed) {
    List<String> queryParts = [];
    
    if (parsed.title.isNotEmpty) {
      queryParts.add(parsed.title);
    }
    
    if (parsed.hasAuthor) {
      queryParts.add(parsed.author!);
    }
    
    if (parsed.hasSeries) {
      queryParts.add(parsed.series!);
    }
    
    if (queryParts.isEmpty) {
      return '';
    }
    
    final query = queryParts.join(' ');
    Logger.debug('Generated search query: $query');
    return query;
  }
}