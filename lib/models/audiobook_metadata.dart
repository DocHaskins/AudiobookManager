import 'package:audiobook_organizer/utils/logger.dart';

class AudiobookMetadata {
  final String id;
  final String title;
  final List<String> authors;
  final String description;
  final String publisher;
  final String publishedDate;
  final List<String> categories;
  final double averageRating;
  final int ratingsCount;
  final String thumbnailUrl;
  final String language;
  final String series;
  final String seriesPosition;
  final String provider; // Which API provided this metadata
  
  AudiobookMetadata({
    required this.id,
    required this.title,
    required this.authors,
    this.description = '',
    this.publisher = '',
    this.publishedDate = '',
    this.categories = const [],
    this.averageRating = 0.0,
    this.ratingsCount = 0,
    this.thumbnailUrl = '',
    this.language = '',
    this.series = '',
    this.seriesPosition = '',
    required this.provider,
  });
  
  // Factory to create from Google Books API response
  factory AudiobookMetadata.fromGoogleBooks(Map<String, dynamic> data) {
    var volumeInfo = data['volumeInfo'] ?? {};
    var imageLinks = volumeInfo['imageLinks'] ?? {};
    
    return AudiobookMetadata(
      id: data['id'] ?? '',
      title: volumeInfo['title'] ?? 'Unknown Title',
      authors: List<String>.from(volumeInfo['authors'] ?? []),
      description: volumeInfo['description'] ?? '',
      publisher: volumeInfo['publisher'] ?? '',
      publishedDate: volumeInfo['publishedDate'] ?? '',
      categories: List<String>.from(volumeInfo['categories'] ?? []),
      averageRating: (volumeInfo['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingsCount: volumeInfo['ratingsCount'] ?? 0,
      thumbnailUrl: imageLinks['thumbnail'] ?? '',
      language: volumeInfo['language'] ?? '',
      series: '', // Not directly provided by Google Books
      seriesPosition: '', // Not directly provided by Google Books
      provider: 'Google Books',
    );
  }
  
  // Factory to create from Open Library API response
  factory AudiobookMetadata.fromOpenLibrary(Map<String, dynamic> data) {
    return AudiobookMetadata(
      id: data['key'] ?? '',
      title: data['title'] ?? 'Unknown Title',
      authors: List<String>.from(
        (data['author_name'] ?? []).map((name) => name.toString())
      ),
      description: data['description'] ?? '',
      publisher: (data['publisher'] as List<dynamic>?)?.isNotEmpty ?? false 
        ? data['publisher'][0] 
        : '',
      publishedDate: data['publish_date'] != null && (data['publish_date'] as List).isNotEmpty
        ? data['publish_date'][0]
        : '',
      categories: List<String>.from(data['subject'] ?? []),
      averageRating: 0.0, // Not provided by Open Library
      ratingsCount: 0, // Not provided by Open Library
      thumbnailUrl: data['cover_i'] != null 
        ? 'https://covers.openlibrary.org/b/id/${data['cover_i']}-M.jpg' 
        : '',
      language: '', // May need additional parsing
      series: '', // May need additional parsing
      seriesPosition: '', // May need additional parsing
      provider: 'Open Library',
    );
  }
  
  // Convert to a Map for storage
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'id': id,
      'title': title,
      'authors': authors.join('|'),
      'description': description,
      'publisher': publisher,
      'publishedDate': publishedDate,
      'categories': categories.join('|'),
      'averageRating': averageRating,
      'ratingsCount': ratingsCount,
      'thumbnailUrl': thumbnailUrl,
      'language': language,
      'series': series,
      'seriesPosition': seriesPosition,
      'provider': provider,
    };
    
    // Log the metadata being saved
    Logger.debug('Converting metadata to map: Title: $title, Thumbnail: $thumbnailUrl');
    
    return map;
  }
  
  factory AudiobookMetadata.fromMap(Map<String, dynamic> map) {
    // Helper function to safely handle string lists
    List<String> parseStringList(dynamic value) {
      if (value == null || value is! String || value.isEmpty) {
        return [];
      }
      
      // Use explicit String type for the function passed to where()
      return value.split('|').where((String s) => s.isNotEmpty).toList();
    }
    
    return AudiobookMetadata(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Unknown Title',
      authors: parseStringList(map['authors']),
      description: map['description'] as String? ?? '',
      publisher: map['publisher'] as String? ?? '',
      publishedDate: map['publishedDate'] as String? ?? '',
      categories: parseStringList(map['categories']),
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingsCount: (map['ratingsCount'] as num?)?.toInt() ?? 0,
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      language: map['language'] as String? ?? '',
      series: map['series'] as String? ?? '',
      seriesPosition: map['seriesPosition'] as String? ?? '',
      provider: map['provider'] as String? ?? 'Unknown',
    );
  }
  
  // Helper method to get year from published date
  String get year {
    // Try to extract year from publishedDate
    final RegExp yearRegex = RegExp(r'\b\d{4}\b');
    final match = yearRegex.firstMatch(publishedDate);
    return match?.group(0) ?? '';
  }
  
  // Helper method to get primary author
  String get primaryAuthor {
    return authors.isNotEmpty ? authors.first : 'Unknown Author';
  }
  
  // Helper method to get all authors as formatted string
  String get authorsFormatted {
    return authors.isEmpty ? 'Unknown Author' : authors.join(', ');
  }
}