// File: lib/ui/widgets/book_list_item.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'dart:io';

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
            // Cover thumbnail - FIXED to handle both metadata and fileMetadata
            leading: SizedBox(
              width: 56,
              height: 56,
              child: _buildCoverImage(),
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
  
  // New method to get the best available cover URL from either metadata or fileMetadata
  String? _getCoverUrl() {
    // First try online metadata
    if (book.metadata?.thumbnailUrl.isNotEmpty ?? false) {
      return book.metadata!.thumbnailUrl;
    }
    
    // Then try file metadata
    if (book.fileMetadata?.thumbnailUrl.isNotEmpty ?? false) {
      return book.fileMetadata!.thumbnailUrl;
    }
    
    return null;
  }
  
  // New method to build cover image that handles both local and network images
  Widget _buildCoverImage() {
    final coverUrl = _getCoverUrl();
    
    if (coverUrl == null || coverUrl.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(
            Icons.audiotrack,
            size: 32,
          ),
        ),
      );
    }
    
    // Check if it's a local file path
    if (coverUrl.startsWith('/') || coverUrl.contains(':\\')) {
      return Hero(
        tag: 'book-cover-${book.path}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(
            File(coverUrl),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Icon(Icons.audiotrack, size: 32),
              ),
            ),
          ),
        ),
      );
    }
    
    // Otherwise handle as network image
    return Hero(
      tag: 'book-cover-${book.path}',
      child: CachedNetworkImage(
        imageUrl: coverUrl,
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
    );
  }
  
  Widget _buildInfoBadges(BuildContext context) {
    final badges = <Widget>[];
    
    // Get series from best available metadata
    final seriesInfo = book.metadata?.series ?? book.fileMetadata?.series ?? '';
    final seriesPosition = book.metadata?.seriesPosition ?? book.fileMetadata?.seriesPosition ?? '';
    
    // Series badge
    if (seriesInfo.isNotEmpty) {
      final seriesText = seriesPosition.isNotEmpty
          ? '$seriesInfo #$seriesPosition'
          : seriesInfo;
      
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
    if (!book.hasMetadata && !book.hasFileMetadata) {
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
    if (book.hasFileMetadata && !book.hasMetadata) {
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
    final rating = book.metadata?.averageRating ?? 0;
    if (rating > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
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