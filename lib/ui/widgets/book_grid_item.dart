// File: lib/ui/widgets/book_grid_item.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'dart:io';

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
            // Cover image - FIXED to handle both metadata and fileMetadata
            Expanded(
              child: _buildCoverImage(),
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
        child: Center(
          child: Icon(
            Icons.audiotrack,
            size: 48,
            color: Colors.grey.shade700,
          ),
        ),
      );
    }
    
    // Check if it's a local file path
    if (coverUrl.startsWith('/') || coverUrl.contains(':\\')) {
      return Hero(
        tag: 'book-cover-${book.path}',
        child: Image.file(
          File(coverUrl),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(
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
      );
    }
    
    // Otherwise handle as network image
    return Hero(
      tag: 'book-cover-${book.path}',
      child: CachedNetworkImage(
        imageUrl: coverUrl,
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
          child: Center(
            child: Icon(
              Icons.audiotrack,
              size: 48,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoBadges(BuildContext context) {
    final badges = <Widget>[];
    
    // Pending badge
    if (!book.hasMetadata && !book.hasFileMetadata) {
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
    if (book.hasFileMetadata && !book.hasMetadata) {
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
}