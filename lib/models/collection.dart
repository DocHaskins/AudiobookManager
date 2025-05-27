// lib/models/collection.dart
import 'package:audiobook_organizer/models/audiobook_file.dart';

class Collection {
  final String id;
  final String name;
  final String? description;
  final List<String> bookPaths; // File paths of books in this collection
  final CollectionType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? coverImagePath; // Custom collection cover
  final Map<String, dynamic> metadata; // Additional metadata
  
  Collection({
    required this.id,
    required this.name,
    this.description,
    required this.bookPaths,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.coverImagePath,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};
  
  // Create a new collection
  factory Collection.create({
    required String name,
    String? description,
    List<String>? bookPaths,
    required CollectionType type,
    String? coverImagePath,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return Collection(
      id: '${name.toLowerCase().replaceAll(' ', '_')}_${now.millisecondsSinceEpoch}',
      name: name,
      description: description,
      bookPaths: bookPaths ?? [],
      type: type,
      createdAt: now,
      updatedAt: now,
      coverImagePath: coverImagePath,
      metadata: metadata,
    );
  }
  
  // Create from series
  factory Collection.fromSeries(String seriesName, List<AudiobookFile> books) {
    return Collection.create(
      name: seriesName,
      bookPaths: books.map((b) => b.path).toList(),
      type: CollectionType.series,
      metadata: {
        'autoCreated': true,
        'seriesName': seriesName,
      },
    );
  }
  
  // Calculate average rating from books
  double calculateAverageRating(List<AudiobookFile> allBooks) {
    final collectionBooks = allBooks.where((book) => bookPaths.contains(book.path)).toList();
    
    if (collectionBooks.isEmpty) return 0.0;
    
    double totalRating = 0;
    int ratedBooks = 0;
    
    for (final book in collectionBooks) {
      if (book.metadata != null) {
        // Use user rating if available, otherwise use average rating
        final rating = book.metadata!.userRating > 0 
            ? book.metadata!.userRating.toDouble()
            : book.metadata!.averageRating;
            
        if (rating > 0) {
          totalRating += rating;
          ratedBooks++;
        }
      }
    }
    
    return ratedBooks > 0 ? totalRating / ratedBooks : 0.0;
  }
  
  // Get total duration
  Duration getTotalDuration(List<AudiobookFile> allBooks) {
    final collectionBooks = allBooks.where((book) => bookPaths.contains(book.path)).toList();
    
    Duration total = Duration.zero;
    for (final book in collectionBooks) {
      if (book.metadata?.audioDuration != null) {
        total += book.metadata!.audioDuration!;
      }
    }
    
    return total;
  }
  
  // Get sorted books in collection
  List<AudiobookFile> getSortedBooks(List<AudiobookFile> allBooks) {
    final collectionBooks = allBooks
        .where((book) => bookPaths.contains(book.path))
        .toList();
    
    // Sort by series position if available
    collectionBooks.sort((a, b) {
      final aPos = int.tryParse(a.metadata?.seriesPosition ?? '') ?? 999;
      final bPos = int.tryParse(b.metadata?.seriesPosition ?? '') ?? 999;
      return aPos.compareTo(bPos);
    });
    
    return collectionBooks;
  }
  
  // Add book to collection
  Collection addBook(String bookPath) {
    if (bookPaths.contains(bookPath)) return this;
    
    return copyWith(
      bookPaths: [...bookPaths, bookPath],
      updatedAt: DateTime.now(),
    );
  }
  
  // Remove book from collection
  Collection removeBook(String bookPath) {
    return copyWith(
      bookPaths: bookPaths.where((path) => path != bookPath).toList(),
      updatedAt: DateTime.now(),
    );
  }
  
  // Check if collection contains book
  bool containsBook(String bookPath) {
    return bookPaths.contains(bookPath);
  }
  
  // Get book count
  int get bookCount => bookPaths.length;
  
  // Copy with
  Collection copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? bookPaths,
    CollectionType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? coverImagePath,
    Map<String, dynamic>? metadata,
  }) {
    return Collection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      bookPaths: bookPaths ?? this.bookPaths,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      metadata: metadata ?? this.metadata,
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'bookPaths': bookPaths,
      'type': type.toString(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'coverImagePath': coverImagePath,
      'metadata': metadata,
    };
  }
  
  // Create from JSON
  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      bookPaths: List<String>.from(json['bookPaths'] ?? []),
      type: CollectionType.values.firstWhere(
        (type) => type.toString() == json['type'],
        orElse: () => CollectionType.custom,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      coverImagePath: json['coverImagePath'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

enum CollectionType {
  series,    // Auto-created from series
  author,    // Books by same author
  custom,    // User-created
  genre,     // Books by genre
  year,      // Books by year
  favorite,  // Favorite books
}