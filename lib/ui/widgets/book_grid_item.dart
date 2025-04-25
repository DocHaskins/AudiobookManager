// File: lib/ui/widgets/book_grid_item.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';

class BookGridItem extends StatelessWidget {
  final AudiobookFile book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  
  const BookGridItem({
    Key? key,
    required this.book,
    required this.onTap,
    this.onLongPress,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Expanded(
              child: book.metadata?.thumbnailUrl.isNotEmpty ?? false
                ? Hero(
                    tag: 'book-cover-${book.path}',
                    child: CachedNetworkImage(
                      imageUrl: book.metadata!.thumbnailUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.audiotrack, size: 48),
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Icon(
                        Icons.audiotrack,
                        size: 48,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
            ),
            
            // Book info
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    book.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Author
                  Text(
                    book.author,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Build status/info badges
                  _buildInfoBadges(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoBadges(BuildContext context) {
    final badges = <Widget>[];
    
    // Pending badge
    if (!book.hasMetadata) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Pending Match',
            style: TextStyle(fontSize: 10),
          ),
        ),
      );
    }
    
    // File metadata badge
    if (book.hasFileMetadata) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'File Tags',
            style: TextStyle(fontSize: 10),
          ),
        ),
      );
    }
    
    // Series badge
    if (book.metadata?.series.isNotEmpty ?? false) {
      final seriesText = book.metadata!.seriesPosition.isNotEmpty
          ? '${book.metadata!.series} #${book.metadata!.seriesPosition}'
          : book.metadata!.series;
      
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
}