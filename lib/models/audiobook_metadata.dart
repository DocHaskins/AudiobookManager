// File: lib/models/audiobook_metadata.dart
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
  
  // Audio quality information
  final String? audioDuration;   // e.g. "08:27:59"
  final String? bitrate;         // e.g. "192kbps"
  final int? channels;           // e.g. 2 for stereo
  final String? sampleRate;      // e.g. "44.1kHz"
  final String? fileFormat;      // e.g. "MP3", "M4B"
  
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
    this.audioDuration,
    this.bitrate,
    this.channels,
    this.sampleRate,
    this.fileFormat,
    required this.provider,
  });
  
  // Factory to create from Google Books API response
  factory AudiobookMetadata.fromGoogleBooks(Map<String, dynamic> data) {
    var volumeInfo = data['volumeInfo'] ?? {};
    var imageLinks = volumeInfo['imageLinks'] ?? {};
    
    // Prioritize larger images when available 
    String thumbnailUrl = '';
    if (imageLinks.isNotEmpty) {
      thumbnailUrl = imageLinks['extraLarge'] ?? 
                   imageLinks['large'] ?? 
                   imageLinks['medium'] ?? 
                   imageLinks['small'] ?? 
                   imageLinks['thumbnail'] ?? 
                   imageLinks['smallThumbnail'] ?? '';
      
      // Ensure URL uses HTTPS
      if (thumbnailUrl.isNotEmpty && thumbnailUrl.startsWith('http:')) {
        thumbnailUrl = thumbnailUrl.replaceFirst('http:', 'https:');
      }
    }
    
    // Try to extract series information from title or subtitle
    String series = '';
    String seriesPosition = '';
    
    final title = volumeInfo['title'] as String? ?? '';
    final seriesMatch = RegExp(r'(.*?)\s*(?:\(|\[)?(Book|#)?\s*(\d+)(?:\)|\])?\s*$').firstMatch(title);
    if (seriesMatch != null) {
      series = seriesMatch.group(1)?.trim() ?? '';
      seriesPosition = seriesMatch.group(3) ?? '';
    }
    
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
      thumbnailUrl: thumbnailUrl,
      language: volumeInfo['language'] ?? '',
      series: series,
      seriesPosition: seriesPosition,
      audioDuration: null,
      bitrate: null,
      channels: null,
      sampleRate: null,
      fileFormat: null,
      provider: 'Google Books',
    );
  }
  
  // Factory to create from Open Library API response
  factory AudiobookMetadata.fromOpenLibrary(Map<String, dynamic> data) {
    // Extract cover image
    String thumbnailUrl = '';
    if (data.containsKey('cover_i')) {
      final coverId = data['cover_i'];
      if (coverId != null) {
        // Use large cover when available
        thumbnailUrl = 'https://covers.openlibrary.org/b/id/$coverId-L.jpg';
      }
    } else if (data.containsKey('cover_edition_key')) {
      final editionKey = data['cover_edition_key'];
      if (editionKey != null) {
        thumbnailUrl = 'https://covers.openlibrary.org/b/olid/$editionKey-L.jpg';
      }
    }
    
    // Extract series info from title
    final title = data['title'] as String? ?? 'Unknown Title';
    final seriesInfo = _extractSeriesInfo(title);
    
    return AudiobookMetadata(
      id: data['key'] as String? ?? '',
      title: title,
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
      thumbnailUrl: thumbnailUrl,
      language: '', // May need additional parsing
      series: seriesInfo['series'] ?? '',
      seriesPosition: seriesInfo['position'] ?? '',
      // Online sources don't provide audio quality info
      audioDuration: null,
      bitrate: null,
      channels: null,
      sampleRate: null,
      fileFormat: null,
      provider: 'Open Library',
    );
  }
  
  // Helper method to extract series information from title
  static Map<String, String?> _extractSeriesInfo(String title) {
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
      // Add audio quality fields
      'audioDuration': audioDuration,
      'bitrate': bitrate,
      'channels': channels,
      'sampleRate': sampleRate,
      'fileFormat': fileFormat,
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
      // Add audio quality fields
      audioDuration: map['audioDuration'] as String?,
      bitrate: map['bitrate'] as String?,
      channels: map['channels'] as int?,
      sampleRate: map['sampleRate'] as String?,
      fileFormat: map['fileFormat'] as String?,
      provider: map['provider'] as String? ?? 'Unknown',
    );
  }
  
  // Create a copy with updated fields
  AudiobookMetadata copyWith({
    String? id,
    String? title,
    List<String>? authors,
    String? description,
    String? publisher,
    String? publishedDate,
    List<String>? categories,
    double? averageRating,
    int? ratingsCount,
    String? thumbnailUrl,
    String? language,
    String? series,
    String? seriesPosition,
    String? audioDuration,
    String? bitrate,
    int? channels,
    String? sampleRate,
    String? fileFormat,
    String? provider,
  }) {
    return AudiobookMetadata(
      id: id ?? this.id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      description: description ?? this.description,
      publisher: publisher ?? this.publisher,
      publishedDate: publishedDate ?? this.publishedDate,
      categories: categories ?? this.categories,
      averageRating: averageRating ?? this.averageRating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      language: language ?? this.language,
      series: series ?? this.series,
      seriesPosition: seriesPosition ?? this.seriesPosition,
      audioDuration: audioDuration ?? this.audioDuration,
      bitrate: bitrate ?? this.bitrate,
      channels: channels ?? this.channels,
      sampleRate: sampleRate ?? this.sampleRate,
      fileFormat: fileFormat ?? this.fileFormat,
      provider: provider ?? this.provider,
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
  
  // Helper method to get formatted audio quality
  String get audioQualityFormatted {
    List<String> qualities = [];
    
    if (bitrate != null && bitrate!.isNotEmpty) {
      qualities.add(bitrate!);
    }
    
    if (channels != null) {
      qualities.add(channels == 2 ? 'Stereo' : 'Mono');
    }
    
    if (sampleRate != null && sampleRate!.isNotEmpty) {
      qualities.add(sampleRate!);
    }
    
    return qualities.isEmpty ? 'Unknown quality' : qualities.join(', ');
  }
}