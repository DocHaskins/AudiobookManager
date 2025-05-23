// lib/widgets/audiobook_list_item.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'dart:io';

class AudiobookListItem extends StatelessWidget {
  final AudiobookFile book;
  final VoidCallback onTap;

  const AudiobookListItem({
    Key? key,
    required this.book,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final metadata = book.metadata;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Cover Image
              Container(
                width: 60,
                height: 60,
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
                      metadata?.title ?? book.filename,
                      style: const TextStyle(
                        color: Colors.white,
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
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Additional Info and Play Button
              Row(
                children: [
                  if (metadata != null) ...[
                    if (metadata.series.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${metadata.series} #${metadata.seriesPosition}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    Text(
                      metadata.durationFormatted,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (metadata.isFavorite)
                      Icon(
                        Icons.favorite,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    const SizedBox(width: 16),
                  ],
                  
                  // Play Button
                  Consumer<AudioPlayerService>(
                    builder: (context, playerService, child) {
                      final isCurrentBook = playerService.currentFile?.path == book.path;
                      final isPlaying = playerService.isPlaying && isCurrentBook;
                      
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => _handlePlayPress(context, playerService),
                        ),
                      );
                    },
                  ),
                ],
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
        await playerService.play(book);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing audiobook: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}