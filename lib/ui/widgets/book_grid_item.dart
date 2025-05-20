// lib/ui/widgets/book_grid_item.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'dart:io';

class BookGridItem extends StatelessWidget {
  final AudiobookFile book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPlayTap;
  
  const BookGridItem({
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
    
    // Wrap with ConstrainedBox to enforce maximum width
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover image with overlays
            Expanded(
              child: AspectRatio(
                aspectRatio: 0.67, // Standard book cover ratio (2:3)
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Base container with cover image or placeholder
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildCoverImage(context),
                    ),
                    
                    // Rating overlay if available
                    if (book.metadata?.averageRating != null && book.metadata!.averageRating > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                book.metadata!.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
                    
                    // Favorite indicator
                    if (book.metadata?.isFavorite == true)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                      ),
                    
                    // Play button overlay
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: onPlayTap,
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    
                    // Progress indicator if available
                    if (book.metadata?.playbackPosition != null && book.metadata!.audioDuration != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: book.metadata!.playbackPosition!.inSeconds / 
                                book.metadata!.audioDuration!.inSeconds,
                          backgroundColor: Colors.transparent,
                          minHeight: 2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            
            // Author
            Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
            
            // Series info if available
            if (book.metadata?.series.isNotEmpty == true)
              Text(
                '${book.metadata!.series} ${book.metadata!.seriesPosition.isNotEmpty ? "#${book.metadata!.seriesPosition}" : ""}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[400],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Build cover image that handles file paths
  Widget _buildCoverImage(BuildContext context) {
    final metadata = book.metadata;
    
    if (metadata?.thumbnailUrl.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(metadata!.thumbnailUrl),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.book, size: 40);
          },
        ),
      );
    }
    
    // Fallback to generic icon
    return const Icon(Icons.book, size: 40);
  }
}