import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'dart:io';

class CollectionListItem extends StatelessWidget {
  final AudiobookCollection collection;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  
  const CollectionListItem({
    Key? key,
    required this.collection,
    required this.onTap,
    this.onLongPress,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            // Collection thumbnail
            leading: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                children: [
                  // Cover image or placeholder
                  collection.metadata?.thumbnailUrl.isNotEmpty ?? false
                    ? collection.metadata!.thumbnailUrl == 'tiled'
                        ? _buildTiledThumbnail()
                        : Hero(
                            tag: 'collection-${collection.title}',
                            child: CachedNetworkImage(
                              imageUrl: collection.metadata!.thumbnailUrl,
                              fit: BoxFit.cover,
                              width: 56,
                              height: 56,
                              placeholder: (context, url) => Container(
                                color: Colors.indigo.shade100,
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.indigo.shade100,
                                child: const Center(
                                  child: Icon(Icons.library_books, size: 32),
                                ),
                              ),
                            ),
                          )
                    : Container(
                        color: Colors.indigo.shade100,
                        child: Center(
                          child: Icon(
                            Icons.library_books,
                            size: 32,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                      ),
                    
                  // Collection indicator
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.indigo,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${collection.fileCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Title and author
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    collection.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!collection.hasMetadata)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collection.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _buildInfoBadges(context),
              ],
            ),
            
            // Controls or additional info
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: onLongPress,
              tooltip: 'Collection Options',
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoBadges(BuildContext context) {
    final badges = <Widget>[];
    
    // Series badge
    if (collection.metadata?.series.isNotEmpty ?? false) {
      final seriesText = collection.metadata!.seriesPosition.isNotEmpty
          ? '${collection.metadata!.series} #${collection.metadata!.seriesPosition}'
          : collection.metadata!.series;
      
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            seriesText,
            style: const TextStyle(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: badges,
    );
  }
  
  Widget _buildTiledThumbnail() {
    // Get up to 4 books with covers
    final booksWithCovers = collection.files
        .where((book) => 
            (book.metadata?.thumbnailUrl.isNotEmpty ?? false) || 
            (book.fileMetadata?.thumbnailUrl.isNotEmpty ?? false))
        .take(4)
        .toList();
    
    if (booksWithCovers.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        color: Colors.indigo.shade100,
        child: Center(
          child: Icon(
            Icons.library_books,
            size: 32,
            color: Colors.indigo.shade800,
          ),
        ),
      );
    }
    
    if (booksWithCovers.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 56,
          height: 56,
          child: _buildBookCoverThumbnail(booksWithCovers[0]),
        ),
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 56,
        height: 56,
        child: booksWithCovers.length == 2
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
            size: 16,
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
              size: 16,
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
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.indigo.shade100,
        child: const Center(
          child: Icon(
            Icons.book_rounded,
            size: 16,
            color: Colors.indigo,
          ),
        ),
      ),
    );
  }
}