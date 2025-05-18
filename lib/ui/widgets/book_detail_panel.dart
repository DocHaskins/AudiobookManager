// File: lib/ui/widgets/book_detail_panel.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class BookDetailPanel extends StatelessWidget {
  final dynamic item; // Can be AudiobookFile or AudiobookCollection
  final VoidCallback onClose;
  final Function(AudiobookMetadata)? onUpdateMetadata;
  
  const BookDetailPanel({
    Key? key,
    required this.item,
    required this.onClose,
    this.onUpdateMetadata,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (item is AudiobookFile) {
      return _buildBookDetail(context, item as AudiobookFile);
    } else if (item is AudiobookCollection) {
      return _buildCollectionDetail(context, item as AudiobookCollection);
    }
    
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Text('Unsupported item type: ${item.runtimeType}'),
      ),
    );
  }
  
  Widget _buildBookDetail(BuildContext context, AudiobookFile book) {
    // Existing book detail implementation
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    book.displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Book details implementation here
                    // This would depend on your existing implementation
                    const Text("Book details would go here"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCollectionDetail(BuildContext context, AudiobookCollection collection) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and close button
            Row(
              children: [
                Expanded(
                  child: Text(
                    collection.displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            const Divider(),
            
            // Collection info section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image (with special handling for 'tiled')
                SizedBox(
                  width: 160,
                  height: 240,
                  child: _buildCollectionCover(context, collection),
                ),
                const SizedBox(width: 16),
                
                // Collection metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Author: ${collection.author}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Books: ${collection.fileCount}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (collection.metadata?.series.isNotEmpty ?? false)
                        Text(
                          'Series: ${collection.metadata!.series}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Path: ${collection.directoryPath ?? "Multiple locations"}',
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Books list header
            const Text(
              'Books in this Collection:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // List of books in the collection
            Expanded(
              child: ListView.builder(
                itemCount: collection.files.length,
                itemBuilder: (context, index) {
                  final book = collection.files[index];
                  return ListTile(
                    leading: SizedBox(
                      width: 40,
                      height: 40,
                      child: _buildBookCoverThumbnail(book),
                    ),
                    title: Text(
                      book.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      book.fileMetadata?.audioDuration ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    // You could add onTap to open individual book details
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCollectionCover(BuildContext context, AudiobookCollection collection) {
    // Special handling for tiled display
    if (collection.metadata?.thumbnailUrl == 'tiled') {
      return _buildTiledCoverDisplay(context, collection);
    }
    
    // Regular cover display
    if (collection.metadata?.thumbnailUrl.isNotEmpty ?? false) {
      final thumbnailUrl = collection.metadata!.thumbnailUrl;
      
      if (thumbnailUrl.startsWith('/') || thumbnailUrl.contains(':\\')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(thumbnailUrl),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultCover(context),
          ),
        );
      }
      
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.indigo.shade100,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => _buildDefaultCover(context),
        ),
      );
    }
    
    // Default cover if no metadata/thumbnail
    return _buildDefaultCover(context);
  }
  
  Widget _buildDefaultCover(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.library_books,
          size: 64,
          color: Colors.indigo.shade800,
        ),
      ),
    );
  }
  
  Widget _buildTiledCoverDisplay(BuildContext context, AudiobookCollection collection) {
    // Get up to 4 books with covers
    final booksWithCovers = collection.files
        .where((book) => 
            (book.metadata?.thumbnailUrl.isNotEmpty ?? false) || 
            (book.fileMetadata?.thumbnailUrl.isNotEmpty ?? false))
        .take(4)
        .toList();
    
    if (booksWithCovers.isEmpty) {
      return _buildDefaultCover(context);
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: booksWithCovers.length == 1
          ? _buildBookCoverThumbnail(booksWithCovers[0])
          : booksWithCovers.length == 2
              ? Row(
                  children: [
                    Expanded(child: _buildBookCoverThumbnail(booksWithCovers[0])),
                    Expanded(child: _buildBookCoverThumbnail(booksWithCovers[1])),
                  ],
                )
              : booksWithCovers.length == 3
                  ? Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _buildBookCoverThumbnail(booksWithCovers[0])),
                              Expanded(child: _buildBookCoverThumbnail(booksWithCovers[1])),
                            ],
                          ),
                        ),
                        Expanded(child: _buildBookCoverThumbnail(booksWithCovers[2])),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _buildBookCoverThumbnail(booksWithCovers[0])),
                              Expanded(child: _buildBookCoverThumbnail(booksWithCovers[1])),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _buildBookCoverThumbnail(booksWithCovers[2])),
                              Expanded(child: _buildBookCoverThumbnail(booksWithCovers[3])),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
  
  Widget _buildBookCoverThumbnail(AudiobookFile book) {
    final coverUrl = book.metadata?.thumbnailUrl ?? book.fileMetadata?.thumbnailUrl;
    
    if (coverUrl == null || coverUrl.isEmpty) {
      return Container(
        color: Colors.indigo.shade100,
        child: const Center(
          child: Icon(
            Icons.book_rounded,
            size: 32,
            color: Colors.indigo,
          ),
        ),
      );
    }
    
    if (coverUrl.startsWith('/') || coverUrl.contains(':\\')) {
      return Image.file(
        File(coverUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.indigo.shade100,
          child: const Center(
            child: Icon(
              Icons.book_rounded,
              size: 32,
              color: Colors.indigo,
            ),
          ),
        ),
      );
    }
    
    return CachedNetworkImage(
      imageUrl: coverUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.indigo.shade100,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.indigo.shade100,
        child: const Center(
          child: Icon(
            Icons.book_rounded,
            size: 32,
            color: Colors.indigo,
          ),
        ),
      ),
    );
  }
}