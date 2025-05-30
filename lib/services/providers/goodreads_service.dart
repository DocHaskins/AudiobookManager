// lib/services/providers/goodreads_service.dart
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class GoodreadsMetadata {
  final String title;
  final String subtitle;
  final List<String> authors;
  final String description;
  final List<String> genres;
  final double rating;
  final int ratingsCount;
  final String coverImageUrl;
  final String authorImageUrl;
  final String publishedDate;
  final String publisher;
  final int pageCount;
  final String isbn;
  final String series;
  final String seriesPosition;
  final String goodreadsUrl;

  GoodreadsMetadata({
    this.title = '',
    this.subtitle = '',
    this.authors = const [],
    this.description = '',
    this.genres = const [],
    this.rating = 0.0,
    this.ratingsCount = 0,
    this.coverImageUrl = '',
    this.authorImageUrl = '',
    this.publishedDate = '',
    this.publisher = '',
    this.pageCount = 0,
    this.isbn = '',
    this.series = '',
    this.seriesPosition = '',
    this.goodreadsUrl = '',
  });

  // Convert to AudiobookMetadata
  AudiobookMetadata toAudiobookMetadata(String id) {
    return AudiobookMetadata(
      id: id,
      title: title,
      subtitle: subtitle,
      authors: authors,
      description: description,
      categories: genres,
      averageRating: rating,
      ratingsCount: ratingsCount,
      thumbnailUrl: coverImageUrl,
      publishedDate: publishedDate,
      publisher: publisher,
      pageCount: pageCount,
      series: series,
      seriesPosition: seriesPosition,
      provider: 'goodreads',
      identifiers: isbn.isNotEmpty 
          ? [AudiobookIdentifier(type: 'ISBN', identifier: isbn)]
          : [],
    );
  }

  @override
  String toString() {
    return 'GoodreadsMetadata{title: $title, authors: $authors, rating: $rating, genres: $genres}';
  }
}

class GoodreadsSearchResult {
  final String title;
  final List<String> authors;
  final String bookUrl;
  final String coverUrl;
  final double rating;
  final String series;
  final String publishedYear;

  GoodreadsSearchResult({
    required this.title,
    required this.authors,
    required this.bookUrl,
    this.coverUrl = '',
    this.rating = 0.0,
    this.series = '',
    this.publishedYear = '',
  });

  @override
  String toString() {
    return 'GoodreadsSearchResult{title: $title, authors: $authors, rating: $rating}';
  }
}

class GoodreadsService {
  static const String _baseUrl = 'https://www.goodreads.com';
  static final http.Client _httpClient = http.Client();
  
  // Headers to mimic a real browser
  static final Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
  };

  /// Search for books on Goodreads and return results
  static Future<List<GoodreadsSearchResult>> searchBooks(String title, String author) async {
    try {
      final query = Uri.encodeComponent('$title $author'.trim());
      final searchUrl = '$_baseUrl/search?q=$query';
      
      Logger.log('Searching Goodreads: $searchUrl');
      
      final response = await _httpClient.get(
        Uri.parse(searchUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        Logger.error('Goodreads search failed with status: ${response.statusCode}');
        return [];
      }
      
      return _parseSearchResults(response.body);
      
    } catch (e) {
      Logger.error('Error searching Goodreads: $e');
      return [];
    }
  }

  /// Parse search results from Goodreads search page
  static List<GoodreadsSearchResult> _parseSearchResults(String html) {
    try {
      final document = html_parser.parse(html);
      final results = <GoodreadsSearchResult>[];
      
      // Look for book results in the search page
      final bookElements = document.querySelectorAll('tr[itemtype="http://schema.org/Book"]');
      
      Logger.log('Found ${bookElements.length} potential book elements');
      
      for (final element in bookElements.take(10)) { // Limit to top 10 results
        try {
          // Extract title
          final titleElement = element.querySelector('.bookTitle') ??
                              element.querySelector('[data-testid="title"]') ??
                              element.querySelector('a[class*="title"]');
          
          String title = '';
          String bookUrl = '';
          if (titleElement != null) {
            title = titleElement.text.trim();
            bookUrl = titleElement.attributes['href'] ?? '';
            if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
              bookUrl = _baseUrl + bookUrl;
            }
          }
          
          if (title.isEmpty || bookUrl.isEmpty) continue;
          
          // Extract authors
          final authors = <String>[];
          final authorElements = element.querySelectorAll('.authorName');
          
          for (final authorElement in authorElements) {
            final authorName = authorElement.text.trim();
            if (authorName.isNotEmpty && !authors.contains(authorName)) {
              authors.add(authorName);
            }
          }
          
          // Extract cover image
          String coverUrl = '';
          final coverElement = element.querySelector('img');
          if (coverElement != null) {
            coverUrl = coverElement.attributes['src'] ?? '';
            // Get high-resolution version
            if (coverUrl.contains('._')) {
              coverUrl = coverUrl.replaceAll(RegExp(r'\._[^.]*\.'), '.');
            }
          }
          
          // Extract rating
          double rating = 0.0;
          final ratingElement = element.querySelector('.minirating') ??
                               element.querySelector('[class*="rating"]');
          if (ratingElement != null) {
            final ratingText = ratingElement.text;
            final ratingMatch = RegExp(r'(\d+\.?\d*)').firstMatch(ratingText);
            if (ratingMatch != null) {
              rating = double.tryParse(ratingMatch.group(1)!) ?? 0.0;
            }
          }
          
          // Extract series info if present
          String series = '';
          final seriesElement = element.querySelector('.greyText');
          if (seriesElement != null) {
            final seriesText = seriesElement.text;
            final seriesMatch = RegExp(r'\(([^#]+)').firstMatch(seriesText);
            if (seriesMatch != null) {
              series = seriesMatch.group(1)!.trim();
            }
          }
          
          // Extract publication year
          String publishedYear = '';
          final pubElement = element.querySelector('.greyText');
          if (pubElement != null) {
            final pubText = pubElement.text;
            final yearMatch = RegExp(r'(\d{4})').firstMatch(pubText);
            if (yearMatch != null) {
              publishedYear = yearMatch.group(1)!;
            }
          }
          
          final result = GoodreadsSearchResult(
            title: title,
            authors: authors,
            bookUrl: bookUrl,
            coverUrl: coverUrl,
            rating: rating,
            series: series,
            publishedYear: publishedYear,
          );
          
          results.add(result);
          Logger.debug('Parsed search result: $title by ${authors.join(", ")}');
          
        } catch (e) {
          Logger.warning('Error parsing individual search result: $e');
          continue;
        }
      }
      
      Logger.log('Successfully parsed ${results.length} search results');
      return results;
      
    } catch (e) {
      Logger.error('Error parsing search results: $e');
      return [];
    }
  }

  /// Get detailed metadata from a specific Goodreads book URL
  static Future<GoodreadsMetadata?> getBookMetadata(String bookUrl) async {
    try {
      Logger.log('Fetching book metadata from: $bookUrl');
      
      final response = await _httpClient.get(
        Uri.parse(bookUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) {
        Logger.error('Failed to fetch book page: ${response.statusCode}');
        return null;
      }
      
      return _parseBookPage(response.body, bookUrl);
      
    } catch (e) {
      Logger.error('Error fetching book metadata: $e');
      return null;
    }
  }

  /// Parse Goodreads book page HTML and extract metadata
  static GoodreadsMetadata? _parseBookPage(String html, String url) {
    try {
      Logger.log('Parsing Goodreads book page');
      
      final document = html_parser.parse(html);
      
      // Extract title and subtitle
      final titleElement = document.querySelector('h1[data-testid="bookTitle"]') ??
                          document.querySelector('.BookPageTitleSection__title h1') ??
                          document.querySelector('h1#bookTitle') ??
                          document.querySelector('h1');
      
      String title = '';
      String subtitle = '';
      
      if (titleElement != null) {
        final fullTitle = titleElement.text.trim();
        // Check if there's a subtitle (usually separated by : or —)
        if (fullTitle.contains(':')) {
          final parts = fullTitle.split(':');
          title = parts[0].trim();
          subtitle = parts.sublist(1).join(':').trim();
        } else if (fullTitle.contains('—')) {
          final parts = fullTitle.split('—');
          title = parts[0].trim();
          subtitle = parts.sublist(1).join('—').trim();
        } else {
          title = fullTitle;
        }
      }

      // Extract authors
      final authors = <String>[];
      final authorElements = document.querySelectorAll('[data-testid="name"]');
      
      for (final element in authorElements) {
        final authorName = element.text.trim();
        if (authorName.isNotEmpty && !authors.contains(authorName)) {
          authors.add(authorName);
        }
      }

      // Extract description
      String description = '';
      final descriptionElement = document.querySelector('[data-testid="description"]') ??
                                document.querySelector('.BookPageMetadataSection__description') ??
                                document.querySelector('#description') ??
                                document.querySelector('.readable');
      
      if (descriptionElement != null) {
        description = _cleanDescription(descriptionElement.text);
      }

      // Extract rating
      double rating = 0.0;
      final ratingElement = document.querySelector('[data-testid="RatingStatistics__rating"]') ??
                           document.querySelector('.BookPageMetadataSection__ratingStats') ??
                           document.querySelector('#bookMeta .average');
      
      if (ratingElement != null) {
        final ratingText = ratingElement.text;
        final ratingMatch = RegExp(r'(\d+\.?\d*)').firstMatch(ratingText);
        if (ratingMatch != null) {
          rating = double.tryParse(ratingMatch.group(1)!) ?? 0.0;
        }
      }

      // Extract ratings count
      int ratingsCount = 0;
      final ratingsCountElement = document.querySelector('[data-testid="RatingStatistics__ratingCount"]') ??
                                 document.querySelector('.votes');
      if (ratingsCountElement != null) {
        final ratingsText = ratingsCountElement.text;
        final ratingsMatch = RegExp(r'([\d,]+)').firstMatch(ratingsText);
        if (ratingsMatch != null) {
          final ratingsStr = ratingsMatch.group(1)!.replaceAll(',', '');
          ratingsCount = int.tryParse(ratingsStr) ?? 0;
        }
      }

      // Extract cover image
      String coverImageUrl = '';
      final coverElement = document.querySelector('[data-testid="coverImage"]') ??
                          document.querySelector('.BookCover__image img') ??
                          document.querySelector('#coverImage') ??
                          document.querySelector('img[id*="cover"]');
      
      if (coverElement != null) {
        coverImageUrl = coverElement.attributes['src'] ?? '';
        // Get high-resolution version if possible
        if (coverImageUrl.contains('._')) {
          coverImageUrl = coverImageUrl.replaceAll(RegExp(r'\._[^.]*\.'), '.');
        }
      }

      // Extract genres/categories
      final genres = <String>[];
      final genreElements = document.querySelectorAll('[data-testid="genresList"] a');
      
      for (final element in genreElements.take(5)) { // Limit to top 5 genres
        final genre = element.text.trim();
        if (genre.isNotEmpty && !genres.contains(genre)) {
          genres.add(genre);
        }
      }

      // Extract publication info
      String publishedDate = '';
      String publisher = '';
      int pageCount = 0;
      String isbn = '';

      final detailsElements = document.querySelectorAll('[data-testid="publicationInfo"]');
      
      for (final element in detailsElements) {
        final text = element.text.toLowerCase();
        
        // Extract published date
        final dateMatch = RegExp(r'published.*?(\w+\s+\d{1,2},?\s+\d{4})').firstMatch(text);
        if (dateMatch != null && publishedDate.isEmpty) {
          publishedDate = dateMatch.group(1)!;
        }
        
        // Extract publisher
        final publisherMatch = RegExp(r'by\s+([^(]+)').firstMatch(text);
        if (publisherMatch != null && publisher.isEmpty) {
          publisher = publisherMatch.group(1)!.trim();
        }
        
        // Extract page count
        final pageMatch = RegExp(r'(\d+)\s+pages').firstMatch(text);
        if (pageMatch != null && pageCount == 0) {
          pageCount = int.tryParse(pageMatch.group(1)!) ?? 0;
        }
        
        // Extract ISBN
        final isbnMatch = RegExp(r'isbn[:\s]*(\d{10,13})').firstMatch(text);
        if (isbnMatch != null && isbn.isEmpty) {
          isbn = isbnMatch.group(1)!;
        }
      }

      // Extract series information
      String series = '';
      String seriesPosition = '';
      final seriesElement = document.querySelector('[data-testid="bookSeries"]') ??
                           document.querySelector('.BookPageTitleSection__title a') ??
                           document.querySelector('#bookSeries');
      
      if (seriesElement != null) {
        final seriesText = seriesElement.text;
        final seriesMatch = RegExp(r'(.+?)\s*#(\d+)').firstMatch(seriesText);
        if (seriesMatch != null) {
          series = seriesMatch.group(1)!.trim();
          seriesPosition = seriesMatch.group(2)!;
        } else {
          series = seriesText.trim();
        }
      }

      final goodreadsMetadata = GoodreadsMetadata(
        title: title,
        subtitle: subtitle,
        authors: authors,
        description: description,
        genres: genres,
        rating: rating,
        ratingsCount: ratingsCount,
        coverImageUrl: coverImageUrl,
        publishedDate: publishedDate,
        publisher: publisher,
        pageCount: pageCount,
        isbn: isbn,
        series: series,
        seriesPosition: seriesPosition,
        goodreadsUrl: url,
      );

      Logger.log('Successfully parsed Goodreads metadata: $goodreadsMetadata');
      return goodreadsMetadata;

    } catch (e, stackTrace) {
      Logger.error('Error parsing Goodreads page', e, stackTrace);
      return null;
    }
  }

  /// Clean up description text
  static String _cleanDescription(String description) {
    return description
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('...more', '')
        .replaceAll('(less)', '')
        .trim();
  }

  /// Validate if URL is a Goodreads book page
  static bool isGoodreadsBookUrl(String url) {
    return url.contains('goodreads.com/book/show/') || 
           url.contains('goodreads.com/en/book/show/');
  }

  /// Extract book ID from Goodreads URL
  static String? extractBookIdFromUrl(String url) {
    final match = RegExp(r'/book/show/(\d+)').firstMatch(url);
    return match?.group(1);
  }

  /// Clean up HTTP client resources
  static void dispose() {
    _httpClient.close();
  }
}