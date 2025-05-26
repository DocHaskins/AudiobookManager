// lib/widgets/audiobook_grid_item.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'dart:io';

class AudiobookGridItem extends StatelessWidget {
  final AudiobookFile book;
  final VoidCallback onTap;
  final VoidCallback? onPlayTap;
  final VoidCallback? onFavoriteTap;

  const AudiobookGridItem({
    Key? key,
    required this.book,
    required this.onTap,
    this.onPlayTap,
    this.onFavoriteTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final metadata = book.metadata;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Image with Rating - Flexible to fill remaining space
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      color: Colors.grey[900],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      child: metadata?.thumbnailUrl != null && metadata!.thumbnailUrl.isNotEmpty
                          ? Image.file(
                              File(metadata.thumbnailUrl),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),
                  
                  // Rating in upper right
                  if (metadata?.averageRating != null && metadata!.averageRating > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              metadata.averageRating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          Container(
            height: 130, // Increased height to accommodate genre
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left panel - Book info
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        // Title - Fixed height
                        SizedBox(
                          height: 32, // Fixed height for 2 lines
                          child: Text(
                            metadata?.title ?? book.filename,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Author - Fixed height
                        SizedBox(
                          height: 16, // Fixed height for 1 line
                          child: Text(
                            metadata?.authorsFormatted ?? 'Unknown Author',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        const SizedBox(height: 6),
                        
                        // Genre - New addition
                        SizedBox(
                          height: 14,
                          child: Text(
                            _getGenreText(metadata),
                            style: TextStyle(
                              color: Theme.of(context).primaryColor.withOpacity(0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Series info if available
                        if (metadata?.series.isNotEmpty == true)
                          SizedBox(
                            height: 14, // Fixed height for series
                            child: Text(
                              '${metadata!.series}${metadata.seriesPosition.isNotEmpty ? " #${metadata.seriesPosition}" : ""}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Right panel - Controls with fixed width
                SizedBox(
                  width: 48, // Fixed width for controls
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Favorite button
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          icon: Icon(
                            metadata?.isFavorite == true 
                                ? Icons.favorite 
                                : Icons.favorite_border,
                            color: metadata?.isFavorite == true 
                                ? Colors.red 
                                : Colors.grey[400],
                          ),
                          onPressed: onFavoriteTap ?? () => _handleFavoritePress(context),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Play button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Consumer<AudioPlayerService>(
                          builder: (context, playerService, child) {
                            final isCurrentBook = playerService.currentFile?.path == book.path;
                            final isPlaying = playerService.isPlaying && isCurrentBook;
                            
                            return IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              onPressed: onPlayTap ?? () => _handlePlayPress(context, playerService),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGenreText(dynamic metadata) {
    if (metadata == null) return '';
    
    // Combine categories and user tags for genre display
    final List<String> allGenres = [];
    
    // Add categories - safely handle different types
    if (metadata.categories != null) {
      try {
        if (metadata.categories is List) {
          for (var cat in metadata.categories) {
            final genreStr = cat.toString().trim();
            if (genreStr.isNotEmpty) {
              allGenres.add(genreStr);
            }
          }
        }
      } catch (e) {
        print('Error processing categories: $e');
      }
    }
    
    // Add user tags - safely handle different types
    if (metadata.userTags != null) {
      try {
        if (metadata.userTags is List) {
          for (var tag in metadata.userTags) {
            final tagStr = tag.toString().trim();
            if (tagStr.isNotEmpty) {
              allGenres.add(tagStr);
            }
          }
        }
      } catch (e) {
        print('Error processing userTags: $e');
      }
    }
    
    final uniqueGenres = allGenres.toSet().where((genre) => genre.isNotEmpty).toList();
    
    if (uniqueGenres.length == 1) {
      return uniqueGenres.first;
    } else {
      return '${uniqueGenres.first}, ${uniqueGenres[1]}';
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Icon(
          Icons.headphones,
          size: 48,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Future<void> _handlePlayPress(BuildContext context, AudioPlayerService playerService) async {
    try {
      final isCurrentBook = playerService.currentFile?.path == book.path;
      
      if (isCurrentBook) {
        // If this is the current book, toggle play/pause
        if (playerService.isPlaying) {
          await playerService.pause();
        } else {
          await playerService.resume();
        }
      } else {
        // If this is a different book, start playing it
        final success = await playerService.play(book);
        if (!success) {
          // Show error if play failed
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to play audiobook'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audiobook: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleFavoritePress(BuildContext context) async {
    // This is a default implementation - you might want to pass a callback
    // or use Provider to access the LibraryManager
    try {
      // You would typically call something like:
      // await libraryManager.updateUserData(book, isFavorite: !book.metadata!.isFavorite);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            book.metadata?.isFavorite == true 
                ? 'Removed from favorites' 
                : 'Added to favorites'
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating favorites: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}