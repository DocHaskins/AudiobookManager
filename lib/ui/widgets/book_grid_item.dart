// File: lib/ui/widgets/book_grid_item.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

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
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: 2,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with rating overlay - fixed height
            SizedBox(
              height: 160, // Fixed height for cover
              child: _buildCoverWithOverlays(theme),
            ),
            
            // Book info - takes remaining space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      book.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1, // Reduced to 1 line
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 2), // Reduced spacing
                    
                    // Author
                    Text(
                      book.author,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4), // Reduced spacing
                    
                    // Build info badges with limited height
                    Expanded(
                      child: _buildInfoBadges(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

  // Fixed method to build cover with overlays
  Widget _buildCoverWithOverlays(ThemeData theme) {
    final coverUrl = _getCoverUrl();
    
    return Stack(
      fit: StackFit.expand, // Make stack fill the available space
      children: [
        // Base image or placeholder
        coverUrl != null && coverUrl.isNotEmpty
            ? _buildActualCoverImage(coverUrl, theme)
            : Container(
                color: theme.colorScheme.surfaceVariant,
                child: Center(
                  child: Icon(
                    Icons.audiotrack,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              
        // Rating badge - top right corner
        if (book.metadata?.averageRating != null && book.metadata!.averageRating > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.metadata!.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.star,
                    size: 14,
                    color: Colors.amber,
                  ),
                ],
              ),
            ),
          ),
          
        // Duration badge - bottom left corner
        if (book.metadata?.audioDuration != null || book.fileMetadata?.audioDuration != null)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    book.metadata?.audioDuration ?? 
                    book.fileMetadata?.audioDuration ?? 
                    '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildActualCoverImage(String coverUrl, ThemeData theme) {
    // Fix the detection of local file paths - remove the contains('/') check
    if (coverUrl.startsWith('/') || coverUrl.contains(':\\')) {
      final normalizedPath = Platform.isWindows 
        ? coverUrl.replaceAll('/', '\\') 
        : coverUrl.replaceAll('\\', '/');
      
      return Hero(
        tag: 'book-cover-${book.path}',
        child: Image.file(
          File(normalizedPath),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackImage(theme);
          },
        ),
      );
    }
    
    return Hero(
      tag: 'book-cover-${book.path}',
      child: CachedNetworkImage(
        imageUrl: coverUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: theme.colorScheme.surfaceVariant,
          child: Center(
            child: CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(theme),
      ),
    );
  }

  Widget _buildFallbackImage(ThemeData theme) {
    try {
      final bookDir = path.dirname(book.path);
      final coverDir = path.join(bookDir, 'covers');
      final bookName = path.basenameWithoutExtension(book.path);
      final coverPath = path.join(coverDir, '$bookName.jpg');
      
      return Image.file(
        File(coverPath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(theme);
        },
      );
    } catch (e) {
      return _buildPlaceholder(theme);
    }
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.audiotrack,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
  
  Widget _buildInfoBadges(BuildContext context) {
    final theme = Theme.of(context);
    
    final List<Widget> allBadges = [];
    
    final categories = book.metadata?.categories ?? book.fileMetadata?.categories ?? [];
    if (categories.isNotEmpty) {
      allBadges.add(
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
    
    // Series badge - priority 2
    final seriesInfo = book.metadata?.series ?? book.fileMetadata?.series ?? '';
    final seriesPosition = book.metadata?.seriesPosition ?? book.fileMetadata?.seriesPosition ?? '';
    
    if (seriesInfo.isNotEmpty) {
      final seriesText = seriesPosition.isNotEmpty
          ? '$seriesInfo #$seriesPosition'
          : seriesInfo;
      
      allBadges.add(
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
    
    // Audio quality badge (bitrate) - priority 3
    final bitrate = book.metadata?.bitrate ?? book.fileMetadata?.bitrate;
    if (bitrate != null && bitrate.isNotEmpty) {
      allBadges.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            bitrate,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.secondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    
    if (allBadges.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Only show at most 2 badges to save space
    final displayBadges = allBadges.length > 2 ? allBadges.sublist(0, 2) : allBadges;
    
    return SingleChildScrollView(
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: displayBadges,
      ),
    );
  }
}