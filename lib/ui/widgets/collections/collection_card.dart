// lib/widgets/collection_card.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';

class CollectionCard extends StatelessWidget {
  final Collection collection;
  final List<AudiobookFile> books;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  
  const CollectionCard({
    Key? key,
    required this.collection,
    required this.books,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final collectionBooks = collection.getSortedBooks(books);
    final averageRating = collection.calculateAverageRating(books);
    final totalDuration = collection.getTotalDuration(books);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover images stack - Flexible to fill remaining space
              Expanded(
                child: Stack(
                  children: [
                    // Background covers (fanned out effect)
                    if (collectionBooks.length > 2)
                      Positioned(
                        top: 8,
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: _buildCoverImage(
                          collectionBooks[2].metadata?.thumbnailUrl,
                          opacity: 0.3,
                        ),
                      ),
                    if (collectionBooks.length > 1)
                      Positioned(
                        top: 4,
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: _buildCoverImage(
                          collectionBooks[1].metadata?.thumbnailUrl,
                          opacity: 0.5,
                        ),
                      ),
                    // Main cover
                    if (collectionBooks.isNotEmpty)
                      _buildCoverImage(
                        collection.coverImagePath ?? 
                        collectionBooks.first.metadata?.thumbnailUrl,
                      ),
                    if (collectionBooks.isEmpty)
                      _buildEmptyPlaceholder(),
                    // Collection type badge
                    if (collection.type == CollectionType.series)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'SERIES',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Bottom section
              Container(
                height: 80,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Collection name
                    Text(
                      collection.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Book count and duration
                    Text(
                      '${collection.bookCount} books • ${_formatDuration(totalDuration)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Rating - always show, even if 0
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          final filled = index < averageRating.floor();
                          final half = index == averageRating.floor() && 
                                       averageRating % 1 >= 0.5;
                          return Icon(
                            half ? Icons.star_half : Icons.star,
                            size: 14,
                            color: filled || half ? Colors.amber : Colors.grey[300],
                          );
                        }),
                        const SizedBox(width: 4),
                        Text(
                          averageRating > 0 ? averageRating.toStringAsFixed(1) : 'No rating',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCoverImage(String? imagePath, {double opacity = 1.0}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2 * opacity),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: opacity,
          child: imagePath != null && File(imagePath).existsSync()
              ? Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }
  
  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.library_books,
          size: 48,
          color: Colors.grey[500],
        ),
      ),
    );
  }
  
  Widget _buildEmptyPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.collections_bookmark,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Empty Collection',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

// Grid view for collections with responsive layout
class CollectionGridView extends StatelessWidget {
  final List<Collection> collections;
  final List<AudiobookFile> allBooks;
  final Function(Collection)? onCollectionTap;
  final Function(Collection)? onCollectionLongPress;
  
  const CollectionGridView({
    Key? key,
    required this.collections,
    required this.allBooks,
    this.onCollectionTap,
    this.onCollectionLongPress,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No collections yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Collections will appear here when you add books with series',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Simple calculation for collection grid: fixed item width
        const double itemWidth = 220;
        const double spacing = 16;
        
        // Calculate how many items fit across the width
        final int crossAxisCount = ((constraints.maxWidth + spacing) / (itemWidth + spacing)).floor().clamp(1, 10);
        
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.75, // 220 width / 293 height (220*1.33)
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: collections.length,
          itemBuilder: (context, index) {
            final collection = collections[index];
            return CollectionCard(
              collection: collection,
              books: allBooks,
              onTap: () => onCollectionTap?.call(collection),
              onLongPress: () => onCollectionLongPress?.call(collection),
            );
          },
        );
      },
    );
  }
}