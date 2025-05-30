// lib/widgets/audiobook_list_item.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'dart:async';
import 'dart:io';

class AudiobookListItem extends StatefulWidget {
  final AudiobookFile book;
  final VoidCallback onTap;
  final LibraryManager libraryManager; // Add LibraryManager dependency

  const AudiobookListItem({
    Key? key,
    required this.book,
    required this.onTap,
    required this.libraryManager, // Make it required
  }) : super(key: key);

  @override
  State<AudiobookListItem> createState() => _AudiobookListItemState();
}

class _AudiobookListItemState extends State<AudiobookListItem> {
  bool _isUpdating = false; // Track updating status
  StreamSubscription<Set<String>>? _updatingFilesSubscription; // Listen to updates

  @override
  void initState() {
    super.initState();
    
    // Initialize updating status
    _checkUpdateStatus();
    
    // Listen to updating files changes
    _updatingFilesSubscription = widget.libraryManager.updatingFilesChanged.listen((_) {
      if (mounted) {
        _checkUpdateStatus();
      }
    });
  }

  @override
  void dispose() {
    _updatingFilesSubscription?.cancel();
    super.dispose();
  }

  void _checkUpdateStatus() {
    final newUpdateStatus = widget.libraryManager.isFileUpdating(widget.book.path);
    if (newUpdateStatus != _isUpdating) {
      setState(() {
        _isUpdating = newUpdateStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.book.metadata;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _isUpdating ? null : widget.onTap, // Disable tap when updating
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
            border: _isUpdating ? Border.all(
              color: Theme.of(context).primaryColor.withAlpha(100),
              width: 1,
            ) : null,
          ),
          child: Stack(
            children: [
              // Main content
              Row(
                children: [
                  // Cover Image
                  Container(
                    width: 60,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.grey[900],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: metadata?.thumbnailUrl != null && metadata!.thumbnailUrl.isNotEmpty
                          ? Image.file(
                              File(metadata.thumbnailUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Book Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metadata?.title ?? widget.book.filename,
                          style: TextStyle(
                            color: _isUpdating ? Colors.grey[500] : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metadata?.authorsFormatted ?? 'Unknown Author',
                          style: TextStyle(
                            color: _isUpdating ? Colors.grey[600] : Colors.grey[400],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Series info moved here - under the author
                        if (metadata != null && metadata.series.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${metadata.series} #${metadata.seriesPosition}',
                              style: TextStyle(
                                color: _isUpdating ? Colors.grey[600] : Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Additional Info and Play Button
                  Row(
                    children: [
                      if (metadata != null) ...[
                        Text(
                          metadata.durationFormatted,
                          style: TextStyle(
                            color: _isUpdating ? Colors.grey[600] : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (metadata.isFavorite)
                          Icon(
                            Icons.favorite,
                            size: 16,
                            color: _isUpdating 
                                ? Colors.grey[600] 
                                : Theme.of(context).primaryColor,
                          ),
                        const SizedBox(width: 16),
                      ],
                      
                      // Play Button
                      Consumer<AudioPlayerService>(
                        builder: (context, playerService, child) {
                          final isCurrentBook = playerService.currentFile?.path == widget.book.path;
                          final isPlaying = playerService.isPlaying && isCurrentBook;
                          
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _isUpdating 
                                  ? Colors.grey[700]
                                  : Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: _isUpdating ? null : () => _handlePlayPress(context, playerService),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              
              // Updating indicator overlay
              if (_isUpdating)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withAlpha(100),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Updating...',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
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
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Icon(
          Icons.headphones,
          size: 24,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Future<void> _handlePlayPress(BuildContext context, AudioPlayerService playerService) async {
    if (_isUpdating) return; // Don't allow play when updating
    
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
}