// File: lib/services/providers/google_books_provider.dart
import 'dart:convert';
import 'dart:async'; // For timeout handling
import 'package:http/http.dart' as http;
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class GoogleBooksProvider implements MetadataProvider {
  String apiKey = '';
  final http.Client _client;
  final String baseUrl = 'https://www.googleapis.com/books/v1/volumes';
  
  // Default timeout duration
  final Duration _timeout = const Duration(seconds: 10);
  
  GoogleBooksProvider({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();
  
  // Method to update the API key at runtime
  void updateApiKey(String newApiKey) {
    apiKey = newApiKey;
  }
  
  @override
  Future<List<AudiobookMetadata>> search(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final Uri uri = apiKey.isEmpty 
          ? Uri.parse('$baseUrl?q=${Uri.encodeComponent(query)}&maxResults=10')
          : Uri.parse('$baseUrl?q=${Uri.encodeComponent(query)}&key=$apiKey&maxResults=10');
      
      // Add timeout to prevent UI freezes
      final response = await _client.get(uri)
          .timeout(_timeout, onTimeout: () {
            throw TimeoutException('API request timed out after ${_timeout.inSeconds} seconds');
          });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>?;
        
        if (items == null) return [];
        
        return items
          .map((item) => _parseBookData(item))
          .where((metadata) => metadata != null) // Filter out any null results
          .cast<AudiobookMetadata>() // Cast to the correct type
          .toList();
      } else {
        Logger.error('API Error: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 403 || response.statusCode == 401) {
          throw Exception('API key is invalid or quota exceeded');
        }
        return [];
      }
    } on TimeoutException catch (e) {
      Logger.error('API request timed out', e);
      throw Exception('Connection timed out. Please check your internet connection and try again.');
    } catch (e) {
      Logger.error('Error searching Google Books', e);
      rethrow; // Rethrow to allow callers to handle the error
    }
  }
  
  @override
  Future<AudiobookMetadata?> getById(String id) async {
    if (id.isEmpty) return null;
    
    try {
      final Uri uri = apiKey.isEmpty 
          ? Uri.parse('$baseUrl/$id')
          : Uri.parse('$baseUrl/$id?key=$apiKey');
      
      // Add timeout to prevent UI freezes
      final response = await _client.get(uri)
          .timeout(_timeout, onTimeout: () {
            throw TimeoutException('API request timed out after ${_timeout.inSeconds} seconds');
          });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseBookData(data);
      } else {
        Logger.error('API Error: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 403 || response.statusCode == 401) {
          throw Exception('API key is invalid or quota exceeded');
        }
        return null;
      }
    } on TimeoutException catch (e) {
      Logger.error('API request timed out', e);
      throw Exception('Connection timed out. Please check your internet connection and try again.');
    } catch (e) {
      Logger.error('Error fetching book by ID', e);
      rethrow; // Rethrow to allow callers to handle the error
    }
  }
  
  // Parse book data from Google Books API response
  AudiobookMetadata? _parseBookData(Map<String, dynamic> data) {
    try {
      var volumeInfo = data['volumeInfo'] ?? {};
      if (volumeInfo.isEmpty) return null;
      
      // Extract image links
      var imageLinks = volumeInfo['imageLinks'] ?? {};
      
      // Prioritize larger images when available
      String thumbnailUrl = '';
      if (imageLinks.isNotEmpty) {
        // Try to get the best quality image, falling back to smaller ones
        thumbnailUrl = imageLinks['extraLarge'] ?? 
                      imageLinks['large'] ?? 
                      imageLinks['medium'] ?? 
                      imageLinks['small'] ?? 
                      imageLinks['thumbnail'] ?? 
                      imageLinks['smallThumbnail'] ?? '';
        
        // Ensure URL uses HTTPS (Google Books sometimes returns HTTP URLs)
        if (thumbnailUrl.isNotEmpty && thumbnailUrl.startsWith('http:')) {
          thumbnailUrl = thumbnailUrl.replaceFirst('http:', 'https:');
        }
        
        // Log the thumbnail URL for debugging
        Logger.debug('Extracted thumbnail URL: $thumbnailUrl');
      } else {
        Logger.debug('No image links found in Google Books response');
      }
      
      // Extract authors list safely
      List<String> authors = [];
      if (volumeInfo['authors'] != null && volumeInfo['authors'] is List) {
        authors = List<String>.from(volumeInfo['authors']);
      }
      
      // Extract categories safely
      List<String> categories = [];
      if (volumeInfo['categories'] != null && volumeInfo['categories'] is List) {
        categories = List<String>.from(volumeInfo['categories']);
      }
      
      // Try to extract series information
      String series = '';
      String seriesPosition = '';
      
      // Look for series info in title
      final title = volumeInfo['title'] as String? ?? '';
      final seriesMatch = RegExp(r'(.*?)\s*(?:\(|\[)?(Book|#)?\s*(\d+)(?:\)|\])?\s*$').firstMatch(title);
      if (seriesMatch != null) {
        series = seriesMatch.group(1)?.trim() ?? '';
        seriesPosition = seriesMatch.group(3) ?? '';
      }
      
      // Look for series info in subtitle
      final subtitle = volumeInfo['subtitle'] as String? ?? '';
      if (series.isEmpty && subtitle.isNotEmpty) {
        final subtitleMatch = RegExp(r'(.*?)\s*(?:\(|\[)?(Book|#)?\s*(\d+)(?:\)|\])?\s*$').firstMatch(subtitle);
        if (subtitleMatch != null) {
          series = subtitleMatch.group(1)?.trim() ?? '';
          seriesPosition = subtitleMatch.group(3) ?? '';
        }
      }
      
      return AudiobookMetadata(
        id: data['id'] ?? '',
        title: volumeInfo['title'] ?? 'Unknown Title',
        authors: authors,
        description: volumeInfo['description'] ?? '',
        publisher: volumeInfo['publisher'] ?? '',
        publishedDate: volumeInfo['publishedDate'] ?? '',
        categories: categories,
        averageRating: (volumeInfo['averageRating'] as num?)?.toDouble() ?? 0.0,
        ratingsCount: volumeInfo['ratingsCount'] ?? 0,
        thumbnailUrl: thumbnailUrl,
        language: volumeInfo['language'] ?? '',
        series: series,
        seriesPosition: seriesPosition,
        provider: 'Google Books',
      );
    } catch (e) {
      Logger.error('Error parsing Google Books data', e);
      return null;
    }
  }
}