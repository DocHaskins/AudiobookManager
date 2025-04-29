// File: lib/ui/widgets/book_list_item.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';

class BookListItem extends StatelessWidget {
  final AudiobookFile book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  
  const BookListItem({
    Key? key,
    required this.book,
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
            // Cover thumbnail
            leading: SizedBox(
              width: 56,
              height: 56,
              child: book.metadata?.thumbnailUrl.isNotEmpty ?? false
                ? Hero(
                    tag: 'book-cover-${book.path}',
                    child: CachedNetworkImage(
                      imageUrl: book.metadata!.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade200,
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
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.audiotrack, size: 32),
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(
                        Icons.audiotrack,
                        size: 32,
                      ),
                    ),
                  ),
            ),
            
            // Title and author
            title: Text(
              book.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _buildInfoBadges(context),
              ],
            ),
            
            // Status indicator
            trailing: _buildStatusIndicator(context),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoBadges(BuildContext context) {
    final badges = <Widget>[];
    
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
  
  Widget _buildStatusIndicator(BuildContext context) {
    // Pending status
    if (!book.hasMetadata) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Pending',
          style: TextStyle(fontSize: 12),
        ),
      );
    }
    
    // File metadata indicator
    if (book.hasFileMetadata) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'File Tags',
          style: TextStyle(fontSize: 12),
        ),
      );
    }
    
    // If there's rating data, show stars
    if ((book.metadata?.averageRating ?? 0) > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            book.metadata!.averageRating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.star,
            size: 16,
            color: Colors.amber.shade600,
          ),
        ],
      );
    }
    
    return const SizedBox(width: 24);
  }
}