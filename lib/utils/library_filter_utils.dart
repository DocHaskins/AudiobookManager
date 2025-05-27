// lib/utils/library_filter_utils.dart
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/collection.dart';

enum SortOption {
  title('A-Z'),
  titleDesc('Z-A'),
  author('Author'),
  rating('Rating'),
  duration('Duration'),
  dateAdded('Date Added'),
  series('Series'),
  genre('Genre');

  const SortOption(this.displayName);
  final String displayName;
}

class LibraryFilterUtils {
  // Extract genres from books with counts
  static Map<String, int> extractGenresWithCounts(List<AudiobookFile> books) {
    final Map<String, int> genreCounts = {};
    
    for (final book in books) {
      if (book.metadata?.categories.isNotEmpty ?? false) {
        for (final genre in book.metadata!.categories) {
          if (genre.isNotEmpty) {
            genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
          }
        }
      }
    }
    
    return Map.fromEntries(
      genreCounts.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))
    );
  }

  // Extract authors from books with counts
  static Map<String, int> extractAuthorsWithCounts(List<AudiobookFile> books) {
    final Map<String, int> authorCounts = {};
    
    for (final book in books) {
      if (book.metadata?.authors.isNotEmpty ?? false) {
        for (final author in book.metadata!.authors) {
          if (author.isNotEmpty) {
            authorCounts[author] = (authorCounts[author] ?? 0) + 1;
          }
        }
      }
    }
    
    return Map.fromEntries(
      authorCounts.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))
    );
  }

  // Legacy method for backwards compatibility
  static List<String> extractGenresFromBooks(List<AudiobookFile> books) {
    return extractGenresWithCounts(books).keys.toList();
  }

  // Filter books based on search query, category, and sort option
  static List<AudiobookFile> filterBooks(
    List<AudiobookFile> books, {
    String searchQuery = '',
    String selectedCategory = 'All',
    SortOption sortOption = SortOption.title,
  }) {
    List<AudiobookFile> filtered = books;

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((book) {
        final title = book.metadata?.title.toLowerCase() ?? '';
        final authors = book.metadata?.authors.join(' ').toLowerCase() ?? '';
        final series = book.metadata?.series.toLowerCase() ?? '';
        final categories = book.metadata?.categories.join(' ').toLowerCase() ?? '';
        
        return title.contains(query) || 
               authors.contains(query) || 
               series.contains(query) ||
               categories.contains(query);
      }).toList();
    }

    // Apply category filter
    if (selectedCategory != 'All') {
      switch (selectedCategory) {
        case 'Favorites':
          filtered = filtered.where((book) => book.metadata?.isFavorite ?? false).toList();
          break;
        case 'Recently Added':
          // Sort by last modified and take recent ones
          filtered.sort((a, b) => b.lastModified.compareTo(a.lastModified));
          // You can adjust this threshold as needed
          final recentThreshold = DateTime.now().subtract(const Duration(days: 30));
          filtered = filtered.where((book) => book.lastModified.isAfter(recentThreshold)).toList();
          break;
        case 'In Progress':
          filtered = filtered.where((book) => book.metadata?.playbackPosition != null).toList();
          break;
        default:
          // Check if it's a genre
          filtered = filtered.where((book) {
            return book.metadata?.categories.contains(selectedCategory) ?? false;
          }).toList();
          
          // If no results, check if it's an author
          if (filtered.isEmpty) {
            filtered = books.where((book) {
              return book.metadata?.authors.contains(selectedCategory) ?? false;
            }).toList();
          }
          break;
      }
    }

    // Apply sorting
    return _sortBooks(filtered, sortOption);
  }

  // Sort books based on the selected sort option
  static List<AudiobookFile> _sortBooks(List<AudiobookFile> books, SortOption sortOption) {
    final sortedBooks = List<AudiobookFile>.from(books);
    
    switch (sortOption) {
      case SortOption.title:
        sortedBooks.sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
        break;
      case SortOption.titleDesc:
        sortedBooks.sort((a, b) => b.displayTitle.compareTo(a.displayTitle));
        break;
      case SortOption.author:
        sortedBooks.sort((a, b) => a.displayAuthors.compareTo(b.displayAuthors));
        break;
      case SortOption.rating:
        sortedBooks.sort((a, b) {
          final aRating = a.metadata?.userRating ?? a.metadata?.averageRating ?? 0;
          final bRating = b.metadata?.userRating ?? b.metadata?.averageRating ?? 0;
          return bRating.compareTo(aRating); // Highest rating first
        });
        break;
      case SortOption.duration:
        sortedBooks.sort((a, b) {
          final aDuration = a.metadata?.audioDuration?.inSeconds ?? 0;
          final bDuration = b.metadata?.audioDuration?.inSeconds ?? 0;
          return bDuration.compareTo(aDuration); // Longest first
        });
        break;
      case SortOption.dateAdded:
        sortedBooks.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
      case SortOption.series:
        sortedBooks.sort((a, b) {
          final aSeries = a.metadata?.series ?? '';
          final bSeries = b.metadata?.series ?? '';
          if (aSeries != bSeries) {
            return aSeries.compareTo(bSeries);
          }
          // If same series, sort by position
          final aPos = int.tryParse(a.metadata?.seriesPosition ?? '0') ?? 0;
          final bPos = int.tryParse(b.metadata?.seriesPosition ?? '0') ?? 0;
          return aPos.compareTo(bPos);
        });
        break;
      case SortOption.genre:
        sortedBooks.sort((a, b) {
          final aGenre = a.metadata?.categories.isNotEmpty == true 
              ? a.metadata!.categories.first 
              : '';
          final bGenre = b.metadata?.categories.isNotEmpty == true 
              ? b.metadata!.categories.first 
              : '';
          return aGenre.compareTo(bGenre);
        });
        break;
    }
    
    return sortedBooks;
  }

  // Filter collections (existing functionality)
  static List<Collection> filterCollections(
    List<Collection> collections, {
    String searchQuery = '',
    String selectedCategory = 'All',
  }) {
    List<Collection> filtered = collections;

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((collection) {
        final name = collection.name.toLowerCase();
        final description = collection.description?.toLowerCase() ?? '';
        
        return name.contains(query) || description.contains(query);
      }).toList();
    }

    // Apply category filter
    if (selectedCategory != 'All') {
      switch (selectedCategory) {
        case 'Series':
          filtered = filtered.where((collection) => collection.type == CollectionType.series).toList();
          break;
        case 'Custom':
          filtered = filtered.where((collection) => collection.type == CollectionType.custom).toList();
          break;
        case 'Author':
          filtered = filtered.where((collection) => collection.type == CollectionType.author).toList();
          break;
      }
    }

    return filtered;
  }
}