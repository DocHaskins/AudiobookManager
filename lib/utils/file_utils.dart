// lib/utils/file_utils.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utility class for file-related operations
class FileUtils {
  /// Generate a consistent ID for a file path
  /// This ensures the same file always gets the same ID across the app
  static String generateFileId(String filePath) {
    final bytes = utf8.encode(filePath);
    final digest = sha256.convert(bytes);
    // Use first 16 characters of the hash for a shorter ID
    return digest.toString().substring(0, 16);
  }
  
  /// Parse authors from a string containing multiple authors
  static List<String> parseAuthors(String authorString) {
    if (authorString.isEmpty) return [];
    
    return authorString
        .split(RegExp(r',|;|\band\b|\s*&\s*'))
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
  }
  
  /// Extract series position from text (title, filename, etc.)
  static String? extractSeriesPosition(String text) {
    final patterns = [
      RegExp(r'Book\s*(\d+)', caseSensitive: false),
      RegExp(r'#(\d+)', caseSensitive: false),
      RegExp(r'\b(\d+)\s*(?:st|nd|rd|th)\s*(?:book|volume)', caseSensitive: false),
      RegExp(r'(?:book|volume)\s*(\d+)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }
    
    return null;
  }
  
  /// Clean audiobook title by removing common markers
  static String cleanAudiobookTitle(String title) {
    return title
        .replaceAll(RegExp(r'\(unabridged\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bunabridged\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(abridged\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\babridged\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}