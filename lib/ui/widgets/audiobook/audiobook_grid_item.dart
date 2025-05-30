// lib/widgets/audiobook_grid_item.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'dart:io';
import 'dart:ui';

class AudiobookGridItem extends StatefulWidget {
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
  State<AudiobookGridItem> createState() => _AudiobookGridItemState();
}

class _AudiobookGridItemState extends State<AudiobookGridItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _elevationAnimation = Tween<double>(
      begin: 2.0,
      end: 12.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverChange(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.book.metadata;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) => _onHoverChange(true),
            onExit: (_) => _onHoverChange(false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(128),
                      blurRadius: _elevationAnimation.value,
                      offset: Offset(0, _elevationAnimation.value / 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Large Cover Section
                    Container(
                      height: 260,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Stack(
                        children: [
                          // Cover Image
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.grey[900],
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
                          
                          // Rating Badge
                          if (metadata?.averageRating != null && metadata!.averageRating > 0)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: ClipRect(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(160),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Color(0xFFFBBF24),
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          metadata.averageRating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),     
                            ),
                          
                          // Hover Controls - Positioned at Bottom
                          AnimatedOpacity(
                            opacity: _isHovered ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(90),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withAlpha(160),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Favorite Button
                                      _buildHoverButton(
                                        icon: metadata?.isFavorite == true 
                                            ? Icons.favorite 
                                            : Icons.favorite_border,
                                        color: metadata?.isFavorite == true 
                                            ? Colors.red 
                                            : Colors.white,
                                        backgroundColor: Colors.black.withAlpha(140),
                                        onPressed: () => _handleFavoritePress(context),
                                      ),
                                      
                                      const SizedBox(width: 12),
                                      
                                      // Play Button
                                      Consumer<AudioPlayerService>(
                                        builder: (context, playerService, child) {
                                          final isCurrentBook = playerService.currentFile?.path == widget.book.path;
                                          final isPlaying = playerService.isPlaying && isCurrentBook;
                                          
                                          return _buildHoverButton(
                                            icon: isPlaying ? Icons.pause : Icons.play_arrow,
                                            color: Colors.white,
                                            backgroundColor: const Color(0xFF3B82F6),
                                            size: 50,
                                            iconSize: 24,
                                            onPressed: () => _handlePlayPress(context, playerService),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Info Section
                    Container(
                      height: 140,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title - Reduced space
                          SizedBox(
                            height: 36, // Reduced from 44 to 36
                            child: Text(
                              metadata?.title ?? widget.book.filename,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15, // Reduced from 16 to 15
                                fontWeight: FontWeight.w700,
                                height: 1.2, // Reduced line height
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          const SizedBox(height: 6), // Reduced from 8
                          
                          // Author
                          SizedBox(
                            height: 15, // Reduced from 16
                            child: Text(
                              metadata?.authorsFormatted ?? 'Unknown Author',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12, // Reduced from 13
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          const SizedBox(height: 6), // Reduced from 12
                          
                          // Series and Duration Row
                          SizedBox(
                            height: 14,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Series Info
                                Expanded(
                                  child: Text(
                                    metadata?.series.isNotEmpty == true
                                        ? '${metadata!.series}${metadata.seriesPosition.isNotEmpty ? " #${metadata.seriesPosition}" : ""}'
                                        : 'Standalone',
                                    style: const TextStyle(
                                      color: Color(0xFF6366F1),
                                      fontSize: 10, // Reduced from 11
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                
                                // Duration
                                if (metadata?.audioDuration != null)
                                  Text(
                                    metadata!.durationFormatted,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 10, // Reduced from 11
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Genre Tag at Bottom
                          if (_getGenreText(metadata).isNotEmpty)
                            Container(
                              height: 20,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withAlpha(60),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  _getGenreText(metadata),
                                  style: const TextStyle(
                                    color: Color(0xFFA5B4FC),
                                    fontSize: 9, // Reduced from 10
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHoverButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
    double size = 44,
    double iconSize = 18,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(90),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: iconSize,
        ),
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
    
    if (uniqueGenres.isEmpty) {
      return '';
    } else if (uniqueGenres.length == 1) {
      return uniqueGenres.first;
    } else if (uniqueGenres.length >= 2) {
      return '${uniqueGenres.first}, ${uniqueGenres[1]}';
    } else {
      return uniqueGenres.first;
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Icon(
          Icons.headphones,
          size: 64,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Future<void> _handlePlayPress(BuildContext context, AudioPlayerService playerService) async {
    try {
      final isCurrentBook = playerService.currentFile?.path == widget.book.path;
      
      if (isCurrentBook) {
        // If this is the current book, toggle play/pause
        if (playerService.isPlaying) {
          await playerService.pause();
        } else {
          await playerService.resume();
        }
      } else {
        // If this is a different book, start playing it
        final success = await playerService.play(widget.book);
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
    if (widget.onFavoriteTap != null) {
      widget.onFavoriteTap!();
      return;
    }
    
    // Default implementation
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.book.metadata?.isFavorite == true 
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