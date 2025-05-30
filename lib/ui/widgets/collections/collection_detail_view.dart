// lib/widgets/collection_detail_view.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import '../audiobook/audiobook_list_item.dart';
import 'dart:io';

class CollectionDetailView extends StatefulWidget {
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
  State<CollectionDetailView> createState() => _CollectionDetailViewState();
}

class _CollectionDetailViewState extends State<CollectionDetailView> {
  late List<AudiobookFile> _currentBooks;
  late Collection _currentCollection;
  bool _isCollectionBeingDeleted = false;

  @override
  void initState() {
    super.initState();
    _currentBooks = widget.books;
    _currentCollection = widget.collection;
    
    // Listen for collection changes to handle auto-cleanup
    widget.collectionManager.collectionsChanged.listen((_) {
      if (mounted && !_isCollectionBeingDeleted) {
        _checkAndUpdateCollection();
      }
    });
  }

  void _checkAndUpdateCollection() {
    // Get updated collection and books
    final updatedCollection = widget.collectionManager.getCollection(_currentCollection.id);
    if (updatedCollection == null) {
      // Collection was deleted, we should navigate back
      return;
    }
    
    final updatedBooks = widget.libraryManager.getBooksForCollection(updatedCollection);
    
    setState(() {
      _currentCollection = updatedCollection;
      _currentBooks = updatedBooks;
    });
    
    // Auto-remove empty collections (except favorites and custom user collections)
    if (updatedBooks.isEmpty && _shouldAutoRemoveWhenEmpty()) {
      _autoRemoveEmptyCollection();
    }
  }

  bool _shouldAutoRemoveWhenEmpty() {
    // Don't auto-remove custom collections or favorite collections
    return _currentCollection.type != CollectionType.custom && 
           _currentCollection.type != CollectionType.favorite;
  }

  Future<void> _autoRemoveEmptyCollection() async {
    if (_isCollectionBeingDeleted) return;
    
    try {
      _isCollectionBeingDeleted = true;
      Logger.log('Auto-removing empty collection: ${_currentCollection.name}');
      
      await widget.collectionManager.deleteCollection(_currentCollection.id);
      
      if (mounted) {
        // Show a brief message and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Collection "${_currentCollection.name}" was automatically removed (no books remaining)'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.orange[700],
          ),
        );
        
        // Navigate back after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      Logger.error('Error auto-removing empty collection: ${_currentCollection.name}', e);
      _isCollectionBeingDeleted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedBooks = _currentCollection.getSortedBooks(_currentBooks);
    final totalDuration = _currentCollection.getTotalDuration(_currentBooks);
    final averageRating = _currentCollection.calculateAverageRating(_currentBooks);

    // Show empty state if no books
    if (sortedBooks.isEmpty) {
      return _buildEmptyCollectionView();
    }

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
                            _currentCollection.type.toString().split('.').last.toUpperCase(),
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
                        _currentCollection.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_currentCollection.description != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _currentCollection.description!,
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
                      if (_currentCollection.type == CollectionType.custom)
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
                    direction: _currentCollection.type == CollectionType.custom 
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
                      libraryManager: widget.libraryManager, // Pass LibraryManager
                      onTap: () => widget.onBookTap(book),
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

  Widget _buildEmptyCollectionView() {
    return Container(
      color: const Color(0xFF121212),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 24),
            Text(
              'Collection "${_currentCollection.name}" is empty',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _shouldAutoRemoveWhenEmpty()
                  ? 'This collection will be automatically removed since it has no books.'
                  : 'Add books to this collection to see them here.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (_currentCollection.type == CollectionType.custom) ...[
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _deleteCollection(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Collection'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[400],
                      side: BorderSide(color: Colors.red[400]!),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
    switch (_currentCollection.type) {
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
    if (_isCollectionBeingDeleted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Delete Collection?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${_currentCollection.name}"? The books will remain in your library.',
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
      _isCollectionBeingDeleted = true;
      try {
        await widget.collectionManager.deleteCollection(_currentCollection.id);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        Logger.error('Error deleting collection: ${_currentCollection.name}', e);
        _isCollectionBeingDeleted = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting collection: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeFromCollection(AudiobookFile book) async {
    try {
      await widget.collectionManager.removeBookFromCollection(_currentCollection.id, book.path);
      
      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${book.displayTitle}" from collection'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error removing book from collection', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing book: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}