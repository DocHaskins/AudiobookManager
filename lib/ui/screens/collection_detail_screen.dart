// lib/screens/collection_detail_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import '../widgets/audiobook_card.dart';

class CollectionDetailScreen extends StatelessWidget {
  final Collection collection;
  final CollectionManager collectionManager;
  final LibraryManager libraryManager;
  final Function(AudiobookFile)? onBookTap;
  
  const CollectionDetailScreen({
    Key? key,
    required this.collection,
    required this.collectionManager,
    required this.libraryManager,
    this.onBookTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AudiobookFile>>(
      stream: libraryManager.libraryChanged,
      builder: (context, snapshot) {
        final allBooks = snapshot.data ?? libraryManager.files;
        final collectionBooks = collection.getSortedBooks(allBooks);
        final averageRating = collection.calculateAverageRating(allBooks);
        final totalDuration = collection.getTotalDuration(allBooks);
        
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // App bar with collection info
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    collection.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background image
                      if (collectionBooks.isNotEmpty && 
                          collectionBooks.first.metadata?.thumbnailUrl != null)
                        Image.file(
                          File(collectionBooks.first.metadata!.thumbnailUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      else
                        Container(
                          color: Theme.of(context).primaryColor,
                        ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black87,
                            ],
                          ),
                        ),
                      ),
                      // Collection stats
                      Positioned(
                        bottom: 60,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Book count
                            _buildStatChip(
                              context,
                              Icons.book,
                              '${collection.bookCount} books',
                            ),
                            // Duration
                            _buildStatChip(
                              context,
                              Icons.schedule,
                              _formatDuration(totalDuration),
                            ),
                            // Rating
                            if (averageRating > 0)
                              _buildStatChip(
                                context,
                                Icons.star,
                                averageRating.toStringAsFixed(1),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  // Edit collection
                  if (collection.type == CollectionType.custom)
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _editCollection(context),
                    ),
                  // More options
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(context, value),
                    itemBuilder: (context) => [
                      if (collection.type == CollectionType.custom)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete Collection'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Text('Export List'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Description
              if (collection.description?.isNotEmpty ?? false)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          collection.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              
              // Books grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: collectionBooks.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.library_books_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No books in this collection',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (collection.type == CollectionType.custom) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _addBooksToCollection(context),
                                  icon: Icon(Icons.add),
                                  label: Text('Add Books'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _calculateCrossAxisCount(context),
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final book = collectionBooks[index];
                            final position = book.metadata?.seriesPosition ?? '';
                            
                            return Stack(
                              children: [
                                AudiobookCard(
                                  file: book,
                                  onTap: () => onBookTap?.call(book),
                                ),
                                // Series position badge
                                if (position.isNotEmpty)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '#$position',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                          childCount: collectionBooks.length,
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: collection.type == CollectionType.custom
              ? FloatingActionButton(
                  onPressed: () => _addBooksToCollection(context),
                  child: Icon(Icons.add),
                  tooltip: 'Add Books',
                )
              : null,
        );
      },
    );
  }
  
  Widget _buildStatChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
  
  int _calculateCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 5;
    if (width > 900) return 4;
    if (width > 600) return 3;
    if (width > 400) return 2;
    return 1;
  }
  
  void _editCollection(BuildContext context) {
    // TODO: Navigate to edit collection screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit collection functionality coming soon')),
    );
  }
  
  void _addBooksToCollection(BuildContext context) {
    // TODO: Show book selection dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Add books functionality coming soon')),
    );
  }
  
  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'delete':
        _deleteCollection(context);
        break;
      case 'export':
        _exportCollection(context);
        break;
    }
  }
  
  void _deleteCollection(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Collection'),
        content: Text('Are you sure you want to delete "${collection.name}"? The books will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await collectionManager.deleteCollection(collection.id);
              if (success) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Collection deleted')),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  void _exportCollection(BuildContext context) {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export functionality coming soon')),
    );
  }
}