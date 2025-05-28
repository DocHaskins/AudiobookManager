// lib/widgets/collection_detail_view.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import '../audiobook/audiobook_list_item.dart';
import 'dart:io';

class CollectionDetailView extends StatelessWidget {
  final Collection collection;
  final List<AudiobookFile> books;
  final LibraryManager libraryManager;
  final CollectionManager collectionManager;
  final Function(AudiobookFile) onBookTap;

  const CollectionDetailView({
    Key? key,
    required this.collection,
    required this.books,
    required this.libraryManager,
    required this.collectionManager,
    required this.onBookTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sortedBooks = collection.getSortedBooks(books);
    final totalDuration = collection.getTotalDuration(books);
    final averageRating = collection.calculateAverageRating(books);

    return Container(
      color: const Color(0xFF121212),
      child: Column(
        children: [
          // Collection Header
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey[900]!,
                  const Color(0xFF121212),
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Grid
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[800],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildCoverGrid(sortedBooks),
                  ),
                ),
                
                const SizedBox(width: 32),
                
                // Collection Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getCollectionIcon(),
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            collection.type.toString().split('.').last.toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        collection.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (collection.description != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          collection.description!,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      
                      // Stats
                      Row(
                        children: [
                          _buildStat('Books', sortedBooks.length.toString()),
                          const SizedBox(width: 24),
                          _buildStat('Duration', _formatDuration(totalDuration)),
                          if (averageRating > 0) ...[
                            const SizedBox(width: 24),
                            _buildStat('Avg Rating', averageRating.toStringAsFixed(1)),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Actions
                      if (collection.type == CollectionType.custom)
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _editCollection(context),
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A2A2A),
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => _deleteCollection(context),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red[400],
                                side: BorderSide(color: Colors.red[400]!),
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
          
          // Books List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: sortedBooks.length,
              itemBuilder: (context, index) {
                final book = sortedBooks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: Key(book.path),
                    direction: collection.type == CollectionType.custom 
                        ? DismissDirection.endToStart 
                        : DismissDirection.none,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red[900],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (_) => _removeFromCollection(book),
                    child: AudiobookListItem(
                      book: book,
                      onTap: () => onBookTap(book),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverGrid(List<AudiobookFile> books) {
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
            size: 64,
            color: Colors.grey[600],
          ),
        ),
      );
    }
    
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
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
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

  Future<void> _editCollection(BuildContext context) async {
    // Show edit dialog
  }

  Future<void> _deleteCollection(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Delete Collection?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${collection.name}"? The books will remain in your library.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );
    
    if (confirmed ?? false) {
      await collectionManager.deleteCollection(collection.id);
    }
  }

  Future<void> _removeFromCollection(AudiobookFile book) async {
    await collectionManager.removeBookFromCollection(collection.id, book.path);
  }
}