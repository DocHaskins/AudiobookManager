// File: lib/services/providers/google_books_provider.dart
import 'dart:convert';
import 'dart:async';
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
        
        // Optimize image URL for better quality
        if (thumbnailUrl.isNotEmpty) {
          thumbnailUrl = _optimizeImageUrl(thumbnailUrl);
        }
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
      
      // Extract series information from Google Books API
      String series = '';
      String seriesPosition = '';
      
      // Check for seriesInfo field (this is the proper Google Books API field for series)
      if (volumeInfo['seriesInfo'] != null) {
        final seriesInfo = volumeInfo['seriesInfo'];
        
        // Extract volumeSeries array
        if (seriesInfo['volumeSeries'] != null && seriesInfo['volumeSeries'] is List) {
          final volumeSeries = seriesInfo['volumeSeries'] as List;
          if (volumeSeries.isNotEmpty) {
            final firstSeries = volumeSeries[0];
            
            // Get series name (often stored in a 'series' field)
            if (firstSeries['series'] != null) {
              series = firstSeries['series']['title'] ?? '';
            }
            
            // Get order number
            if (firstSeries['orderNumber'] != null) {
              seriesPosition = firstSeries['orderNumber'].toString();
            }
          }
        }
        
        // Also check bookDisplayNumber
        if (seriesPosition.isEmpty && seriesInfo['bookDisplayNumber'] != null) {
          seriesPosition = seriesInfo['bookDisplayNumber'].toString();
        }
      }
      
      // If no series info found in seriesInfo, try to extract from title/subtitle
      if (series.isEmpty) {
        final title = volumeInfo['title'] as String? ?? '';
        final subtitle = volumeInfo['subtitle'] as String? ?? '';
        
        // Try to extract from title
        final titleMatch = RegExp(r'(.*?)\s*(?:#|Book\s+)(\d+)', caseSensitive: false).firstMatch(title);
        if (titleMatch != null) {
          series = titleMatch.group(1)?.trim() ?? '';
          seriesPosition = titleMatch.group(2) ?? '';
        } else if (subtitle.isNotEmpty) {
          // Try subtitle
          final subtitleMatch = RegExp(r'(.*?)\s*(?:#|Book\s+)(\d+)', caseSensitive: false).firstMatch(subtitle);
          if (subtitleMatch != null) {
            series = subtitleMatch.group(1)?.trim() ?? '';
            seriesPosition = subtitleMatch.group(2) ?? '';
          }
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

  // Optimize Google Books image URLs for better quality
  String _optimizeImageUrl(String originalUrl) {
    try {
      if (!originalUrl.contains('books.google.com')) {
        return originalUrl;
      }
      
      Uri uri = Uri.parse(originalUrl);
      Map<String, String> queryParams = Map<String, String>.from(uri.queryParameters);
      
      // If the URL contains a book ID, construct a high-quality URL
      if (queryParams.containsKey('id')) {
        String bookId = queryParams['id']!;
        // This format provides high quality images (800x1200)
        return 'https://books.google.com/books/publisher/content/images/frontcover/$bookId?fife=w800-h1200';
      }
      
      // Fallback: modify existing parameters for better quality
      queryParams['zoom'] = '0'; // Request original size
      queryParams.remove('w'); // Remove width restriction
      queryParams.remove('h'); // Remove height restriction
      queryParams.remove('edge'); // Remove edge effects
      
      return uri.replace(queryParameters: queryParams).toString();
    } catch (e) {
      // Return original URL if optimization fails
      return originalUrl;
    }
  }
}