// lib/widgets/collection_grid_item.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'dart:io';

class CollectionGridItem extends StatelessWidget {
  final Collection collection;
  final List<AudiobookFile> books;
  final VoidCallback onTap;

  const CollectionGridItem({
    Key? key,
    required this.collection,
    required this.books,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Grid
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  color: Colors.grey[900],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: _buildCoverGrid(),
                ),
              ),
            ),
            
            // Collection Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getCollectionIcon(),
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${books.length} books',
                        style: TextStyle(
                          color: Colors.grey[400],
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
    );
  }

  Widget _buildCoverGrid() {
    final booksWithCovers = books.where((book) => 
      book.metadata?.thumbnailUrl != null && 
      book.metadata!.thumbnailUrl.isNotEmpty
    ).toList();
    
    if (booksWithCovers.isEmpty) {
      return Container(
        color: Colors.grey[800],
        child: Center(
          child: Icon(
            Icons.collections_bookmark,
            size: 48,
            color: Colors.grey[600],
          ),
        ),
      );
    }
    
    // Create 2x2 grid
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: booksWithCovers.length.clamp(0, 4),
      itemBuilder: (context, index) {
        return Image.file(
          File(booksWithCovers[index].metadata!.thumbnailUrl),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[800],
            child: Icon(
              Icons.headphones,
              size: 24,
              color: Colors.grey[600],
            ),
          ),
        );
      },
    );
  }

  IconData _getCollectionIcon() {
    switch (collection.type) {
      case CollectionType.series:
        return Icons.collections_bookmark;
      case CollectionType.author:
        return Icons.person;
      case CollectionType.custom:
        return Icons.folder_special;
      case CollectionType.genre:
        return Icons.category;
      case CollectionType.year:
        return Icons.calendar_today;
      case CollectionType.favorite:
        return Icons.favorite;
    }
  }
}