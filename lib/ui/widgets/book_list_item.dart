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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      color: colorScheme.surface,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
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
              child: _buildCoverImage(theme),
            ),
            
            // Title and author
            title: Text(
              book.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                
                // Info badges (genre, duration, etc)
                _buildInfoBadges(context),
              ],
            ),
            
            // Rating on the right
            trailing: _buildRatingInfo(context),
          ),
        ),
      ),
    );
  }
  
  // Get the best available cover URL from either metadata or fileMetadata
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
  
  // Build cover image that handles both local and network images
  Widget _buildCoverImage(ThemeData theme) {
    final coverUrl = _getCoverUrl();
    
    if (coverUrl == null || coverUrl.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Icon(
            Icons.audiotrack,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
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
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Icon(
                  Icons.audiotrack, 
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    // Otherwise handle as network image
    return Hero(
      tag: 'book-cover-${book.path}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: coverUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          errorWidget: (context, error, stackTrace) => Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(
                Icons.audiotrack, 
                size: 32,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoBadges(BuildContext context) {
    final theme = Theme.of(context);
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
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            seriesText,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    
    // Add genre if available (from categories)
    final categories = book.metadata?.categories ?? book.fileMetadata?.categories ?? [];
    if (categories.isNotEmpty) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            categories.first,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.tertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    
    // Duration badge
    final duration = book.metadata?.audioDuration ?? book.fileMetadata?.audioDuration;
    if (duration != null && duration.isNotEmpty) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time,
                size: 10,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 2),
              Text(
                duration,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.secondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
  
  Widget _buildRatingInfo(BuildContext context) {
    final theme = Theme.of(context);
    final rating = book.metadata?.averageRating ?? 0;
    
    if (rating > 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.star,
                size: 16,
                color: Colors.amber.shade600,
              ),
            ],
          ),
          if (book.metadata?.ratingsCount != null && book.metadata!.ratingsCount > 0)
            Text(
              '(${book.metadata!.ratingsCount})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
        ],
      );
    }
    
    // Show file format if no rating
    final fileFormat = book.metadata?.fileFormat ?? book.fileMetadata?.fileFormat;
    if (fileFormat != null && fileFormat.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          fileFormat,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    
    return const SizedBox(width: 24);
  }
}