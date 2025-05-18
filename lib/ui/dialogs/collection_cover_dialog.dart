// lib/ui/dialogs/collection_cover_dialog.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class CollectionCoverDialog extends StatefulWidget {
  final AudiobookCollection collection;
  
  const CollectionCoverDialog({
    Key? key,
    required this.collection,
  }) : super(key: key);
  
  static Future<AudiobookMetadata?> show({
    required BuildContext context,
    required AudiobookCollection collection,
  }) async {
    return showDialog<AudiobookMetadata>(
      context: context,
      builder: (context) => CollectionCoverDialog(
        collection: collection,
      ),
    );
  }

  @override
  State<CollectionCoverDialog> createState() => _CollectionCoverDialogState();
}

class _CollectionCoverDialogState extends State<CollectionCoverDialog> {
  int _selectedCoverIndex = -1;
  bool _useTiledCover = false;
  
  @override
  void initState() {
    super.initState();
    // If collection already has metadata, select it
    if (widget.collection.hasMetadata && widget.collection.metadata!.thumbnailUrl.isNotEmpty) {
      // Try to find which book's cover is currently used
      for (int i = 0; i < widget.collection.files.length; i++) {
        final book = widget.collection.files[i];
        final bookCover = book.metadata?.thumbnailUrl ?? book.fileMetadata?.thumbnailUrl ?? '';
        if (bookCover == widget.collection.metadata!.thumbnailUrl) {
          _selectedCoverIndex = i;
          break;
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Collection Cover',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Use Tiled Cover Display'),
              subtitle: const Text('Show multiple covers in a grid pattern'),
              value: _useTiledCover,
              onChanged: (value) {
                setState(() {
                  _useTiledCover = value;
                });
              },
            ),
            
            if (!_useTiledCover)
              const Text(
                'Select a book cover to use for the collection:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            
            const SizedBox(height: 8),
            
            Expanded(
              child: _useTiledCover
                  ? _buildTiledCoverPreview()
                  : _buildCoverSelectionGrid(),
            ),
            
            const Divider(),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _createCollectionMetadata,
                  child: const Text('APPLY'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCoverSelectionGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.collection.files.length,
      itemBuilder: (context, index) {
        final book = widget.collection.files[index];
        final isSelected = _selectedCoverIndex == index;
        
        return InkWell(
          onTap: () {
            setState(() {
              _selectedCoverIndex = index;
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Book cover
              Card(
                elevation: isSelected ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: isSelected
                      ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                      : BorderSide.none,
                ),
                child: _buildBookCover(book),
              ),
              
              // Selection indicator
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildTiledCoverPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tiled Cover Preview:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildTiledCoverLayout(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTiledCoverLayout() {
    // Get up to 4 books with covers
    final booksWithCovers = widget.collection.files
        .where((book) => (book.metadata?.thumbnailUrl.isNotEmpty ?? false) || 
                         (book.fileMetadata?.thumbnailUrl.isNotEmpty ?? false))
        .take(4)
        .toList();
    
    // If no books have covers, show default
    if (booksWithCovers.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Center(
          child: Icon(
            Icons.library_books,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    
    // Decide layout based on number of books
    if (booksWithCovers.length == 1) {
      return _buildBookCover(booksWithCovers[0]);
    } else if (booksWithCovers.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildBookCover(booksWithCovers[0])),
          Expanded(child: _buildBookCover(booksWithCovers[1])),
        ],
      );
    } else if (booksWithCovers.length == 3) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildBookCover(booksWithCovers[0])),
                Expanded(child: _buildBookCover(booksWithCovers[1])),
              ],
            ),
          ),
          Expanded(
            child: _buildBookCover(booksWithCovers[2]),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildBookCover(booksWithCovers[0])),
                Expanded(child: _buildBookCover(booksWithCovers[1])),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildBookCover(booksWithCovers[2])),
                Expanded(child: _buildBookCover(booksWithCovers[3])),
              ],
            ),
          ),
        ],
      );
    }
  }
  
  Widget _buildBookCover(AudiobookFile book) {
    final coverUrl = book.metadata?.thumbnailUrl ?? book.fileMetadata?.thumbnailUrl;
    
    if (coverUrl == null || coverUrl.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Center(
          child: Icon(
            Icons.book_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    
    if (coverUrl.startsWith('/') || coverUrl.contains(':\\')) {
      return Image.file(
        File(coverUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Center(
            child: Icon(
              Icons.book_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    
    return CachedNetworkImage(
      imageUrl: coverUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Center(
          child: Icon(
            Icons.book_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
  
  void _createCollectionMetadata() {
    // If using a single book's cover
    if (!_useTiledCover && _selectedCoverIndex >= 0 && _selectedCoverIndex < widget.collection.files.length) {
      final selectedBook = widget.collection.files[_selectedCoverIndex];
      final bookMetadata = selectedBook.metadata ?? selectedBook.fileMetadata;
      
      if (bookMetadata != null) {
        // Create collection metadata from the selected book
        final collectionMetadata = AudiobookMetadata(
          id: widget.collection.title.hashCode.toString(),
          title: widget.collection.title,
          authors: [bookMetadata.primaryAuthor],
          thumbnailUrl: bookMetadata.thumbnailUrl,
          categories: bookMetadata.categories,
          series: bookMetadata.series,
          seriesPosition: bookMetadata.seriesPosition,
          provider: 'Collection Manager',
        );
        
        Navigator.pop(context, collectionMetadata);
        return;
      }
    }
    
    // If using tiled cover, we just need to set a flag in the collection
    // and the collection will handle rendering the tiled layout
    if (_useTiledCover) {
      // Create a special metadata for tiled display
      final collectionMetadata = AudiobookMetadata(
        id: widget.collection.title.hashCode.toString(),
        title: widget.collection.title,
        authors: _getCollectionAuthors(),
        thumbnailUrl: 'tiled', // Special value to indicate tiled view
        categories: _getCollectionCategories(),
        series: _getCollectionSeries(),
        seriesPosition: '',
        provider: 'Collection Manager',
      );
      
      Navigator.pop(context, collectionMetadata);
      return;
    }
    
    // If no valid selection, show an error
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select a cover or enable tiled display'),
      ),
    );
  }
  
  List<String> _getCollectionAuthors() {
    final authors = <String>{};
    
    for (final book in widget.collection.files) {
      final bookAuthors = book.metadata?.authors ?? book.fileMetadata?.authors ?? [];
      authors.addAll(bookAuthors);
    }
    
    return authors.toList();
  }
  
  List<String> _getCollectionCategories() {
    final categories = <String>{};
    
    for (final book in widget.collection.files) {
      final bookCategories = book.metadata?.categories ?? book.fileMetadata?.categories ?? [];
      categories.addAll(bookCategories);
    }
    
    return categories.toList();
  }
  
  String _getCollectionSeries() {
    // Try to get a common series name
    final seriesNames = <String>{};
    
    for (final book in widget.collection.files) {
      final series = book.metadata?.series ?? book.fileMetadata?.series ?? '';
      if (series.isNotEmpty) {
        seriesNames.add(series);
      }
    }
    
    return seriesNames.length == 1 ? seriesNames.first : '';
  }
}