// lib/ui/widgets/book_list_item.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'dart:io';

class BookListItem extends StatelessWidget {
  final AudiobookFile book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPlayTap;
  
  const BookListItem({
    super.key,
    required this.book,
    required this.onTap,
    this.onLongPress,
    this.onPlayTap,
  });
  
  // Helper getters to simplify access to metadata
  String get displayName => book.metadata?.title ?? book.filename;
  String get author => book.metadata?.authorsFormatted ?? 'Unknown';
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: _buildCoverImage(theme),
      title: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (book.metadata?.series.isNotEmpty == true)
            Text(
              '${book.metadata!.series} ${book.metadata!.seriesPosition.isNotEmpty ? "#${book.metadata!.seriesPosition}" : ""}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (book.metadata?.isFavorite == true)
            const Icon(Icons.favorite, color: Colors.red, size: 16),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: onPlayTap,
          ),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
  
  // Build cover image widget
  Widget _buildCoverImage(ThemeData theme) {
    final metadata = book.metadata;
    
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: metadata?.thumbnailUrl.isNotEmpty == true
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                File(metadata!.thumbnailUrl),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.book);
                },
              ),
            )
          : const Icon(Icons.book),
    );
  }
}