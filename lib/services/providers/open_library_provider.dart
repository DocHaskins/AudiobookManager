import 'dart:convert';
import 'dart:async'; // For timeout handling
import 'package:http/http.dart' as http;
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class OpenLibraryProvider implements MetadataProvider {
  final http.Client _client;
  final String searchUrl = 'https://openlibrary.org/search.json';
  final String workUrl = 'https://openlibrary.org/works/';
  final String coverUrl = 'https://covers.openlibrary.org/b';
  
  // Default timeout duration
  final Duration _timeout = const Duration(seconds: 10);
  
  OpenLibraryProvider({http.Client? client})
      : _client = client ?? http.Client();
  
  @override
  Future<List<AudiobookMetadata>> search(String query) async {
    if (query.isEmpty) return [];
    
    try {
      // Add timeout to the request
      final response = await _client.get(
        Uri.parse('$searchUrl?q=${Uri.encodeComponent(query)}&limit=10')
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('API request timed out after ${_timeout.inSeconds} seconds');
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final docs = data['docs'] as List<dynamic>?;
        
        if (docs == null || docs.isEmpty) return [];
        
        return docs
          .map((doc) => _parseOpenLibraryBook(doc))
          .where((metadata) => metadata != null)
          .cast<AudiobookMetadata>()
          .toList();
      } else {
        Logger.debug('API Error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } on TimeoutException catch (e) {
      Logger.debug('API request timed out: $e');
      return []; // Return empty list instead of throwing to prevent UI lockups
    } catch (e) {
      Logger.debug('Error searching Open Library: $e');
      return []; // Return empty list instead of throwing to prevent UI lockups
    }
  }
  
  @override
  Future<AudiobookMetadata?> getById(String id) async {
    if (id.isEmpty) return null;
    
    try {
      // Add timeout to the request
      final response = await _client.get(
        Uri.parse('$workUrl$id.json')
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('API request timed out after ${_timeout.inSeconds} seconds');
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseOpenLibraryBookDetails(data, id);
      } else {
        Logger.debug('API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on TimeoutException catch (e) {
      Logger.debug('API request timed out: $e');
      return null;
    } catch (e) {
      Logger.debug('Error fetching book by ID: $e');
      return null;
    }
  }
  
  AudiobookMetadata? _parseOpenLibraryBook(Map<String, dynamic> doc) {
    try {
      // Extract author names
      List<String> authors = [];
      if (doc.containsKey('author_name') && doc['author_name'] is List) {
        authors = (doc['author_name'] as List).map((a) => a.toString()).toList();
      }
      
      // Extract cover image
      String thumbnailUrl = '';
      if (doc.containsKey('cover_i')) {
        final coverId = doc['cover_i'];
        if (coverId != null) {
          // Use large cover when available
          thumbnailUrl = '$coverUrl/id/$coverId-L.jpg';
          Logger.debug('LOG: OpenLibrary thumbnail URL: $thumbnailUrl');
        }
      } else if (doc.containsKey('cover_edition_key')) {
        final editionKey = doc['cover_edition_key'];
        if (editionKey != null) {
          thumbnailUrl = '$coverUrl/olid/$editionKey-L.jpg';
          Logger.debug('LOG: OpenLibrary edition thumbnail URL: $thumbnailUrl');
        }
      }
      
      // Extract categories/subjects
      List<String> categories = [];
      if (doc.containsKey('subject') && doc['subject'] is List) {
        categories = (doc['subject'] as List).map((s) => s.toString()).toList();
      }
      
      // Extract publisher
      String publisher = '';
      if (doc.containsKey('publisher') && doc['publisher'] is List && (doc['publisher'] as List).isNotEmpty) {
        publisher = (doc['publisher'] as List).first.toString();
      }
      
      // Extract published date
      String publishedDate = '';
      if (doc.containsKey('first_publish_year')) {
        publishedDate = doc['first_publish_year'].toString();
      }
      
      // Try to extract series and position
      final seriesInfo = _extractSeriesInfo(doc['title'] as String? ?? '');
      
      return AudiobookMetadata(
        id: doc['key'] as String? ?? '',
        title: doc['title'] as String? ?? 'Unknown Title',
        authors: authors,
        description: '', // Not provided in search results
        publisher: publisher,
        publishedDate: publishedDate,
        categories: categories,
        averageRating: 0.0, // Not provided by Open Library
        ratingsCount: 0, // Not provided by Open Library
        thumbnailUrl: thumbnailUrl,
        language: '', // Not easily accessible in search results
        series: seriesInfo['series'] ?? '',
        seriesPosition: seriesInfo['position'] ?? '',
        provider: 'Open Library',
      );
    } catch (e) {
      Logger.debug('Error parsing OpenLibrary book: $e');
      return null;
    }
  }
  
  AudiobookMetadata? _parseOpenLibraryBookDetails(Map<String, dynamic> data, String id) {
    try {
      // Extract title
      final title = data['title'] as String? ?? 'Unknown Title';
      
      // Extract description
      String description = '';
      if (data.containsKey('description')) {
        if (data['description'] is String) {
          description = data['description'] as String;
        } else if (data['description'] is Map && data['description']['value'] is String) {
          description = data['description']['value'] as String;
        }
      }
      
      // Extract subjects/categories
      List<String> categories = [];
      if (data.containsKey('subjects') && data['subjects'] is List) {
        categories = (data['subjects'] as List).map((s) => s.toString()).toList();
      }
      
      // Try to extract series information
      final seriesInfo = _extractSeriesInfo(title);
      
      // Try to extract cover URL from more sources
      String thumbnailUrl = '';
      
      // First try covers by work ID
      thumbnailUrl = '$coverUrl/olid/$id-L.jpg';
      
      // If available, use the cover ID for better results
      if (data.containsKey('covers') && data['covers'] is List && (data['covers'] as List).isNotEmpty) {
        final coverId = (data['covers'] as List).first;
        thumbnailUrl = '$coverUrl/id/$coverId-L.jpg';
        Logger.debug('LOG: Using OpenLibrary work cover ID: $coverId');
      }
      
      Logger.debug('LOG: OpenLibrary details thumbnail URL: $thumbnailUrl');
      
      // Creating a basic metadata object with available info
      return AudiobookMetadata(
        id: id,
        title: title,
        authors: [], // Would need an additional API call to get author names
        description: description,
        publisher: '', // Not directly available in work details
        publishedDate: '', // Not directly available in work details
        categories: categories,
        averageRating: 0.0,
        ratingsCount: 0,
        thumbnailUrl: thumbnailUrl,
        language: '',
        series: seriesInfo['series'] ?? '',
        seriesPosition: seriesInfo['position'] ?? '',
        provider: 'Open Library',
      );
    } catch (e) {
      Logger.debug('Error parsing OpenLibrary book details: $e');
      return null;
    }
  }
  
  // Helper method to extract series information from title
  Map<String, String?> _extractSeriesInfo(String title) {
    final result = <String, String?>{
      'series': null,
      'position': null,
    };
    
    // Common patterns for series in titles
    final patterns = [
      RegExp(r'^(.*?)\s*(?:Series)?\s*Book\s*(\d+)'), // "Series Name Book 1"
      RegExp(r'^(.*?)\s*#(\d+)'), // "Series Name #1"
      RegExp(r'^(.*?)\s*\(Book\s*(\d+)\)'), // "Series Name (Book 1)"
      RegExp(r'^(.*?)\s*\[Book\s*(\d+)\]'), // "Series Name [Book 1]"
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(title);
      if (match != null && match.groupCount >= 2) {
        result['series'] = match.group(1)?.trim();
        result['position'] = match.group(2);
        break;
      }
    }
    
    return result;
  }
}