// lib/ui/widgets/mini_player.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';

class MiniPlayer extends StatelessWidget {
  final AudioPlayerService playerService;
  final VoidCallback onTap;
  final VoidCallback? onStop;  // New callback for stop button
  
  const MiniPlayer({
    Key? key,
    required this.playerService,
    required this.onTap,
    this.onStop,  // Add optional stop callback
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final file = playerService.currentFile;
    if (file == null) return const SizedBox.shrink();
    
    final metadata = file.metadata;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, -1),
            ),
          ],
        ),
        child: Column(
          children: [
            // Progress bar
            StreamBuilder<Duration>(
              stream: playerService.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = playerService.totalDuration ?? const Duration(seconds: 1);
                
                return LinearProgressIndicator(
                  value: position.inMilliseconds / duration.inMilliseconds,
                  minHeight: 2,
                  backgroundColor: Colors.grey[800],
                );
              },
            ),
            
            // Player controls and info
            Expanded(
              child: Row(
                children: [
                  // Cover image
                  Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.all(8),
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
                  ),
                  
                  // Title and author
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          metadata?.title ?? file.filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          metadata?.authorsFormatted ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Playback controls
                  Row(
                    children: [
                      // Rewind button
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        onPressed: () => playerService.skipBackward(),
                        iconSize: 24,
                      ),
                      
                      // Play/pause button
                      StreamBuilder<bool>(
                        stream: playerService.playerStateStream.map(
                          (state) => state.playing,
                        ),
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? false;
                          
                          return IconButton(
                            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: () {
                              if (isPlaying) {
                                playerService.pause();
                              } else {
                                playerService.resume();
                              }
                            },
                            iconSize: 32,
                          );
                        },
                      ),
                      
                      // Forward button
                      IconButton(
                        icon: const Icon(Icons.forward_30),
                        onPressed: () => playerService.skipForward(),
                        iconSize: 24,
                      ),
                      
                      // Stop button - New!
                      IconButton(
                        icon: const Icon(Icons.stop),
                        onPressed: onStop,
                        iconSize: 24,
                        color: Colors.red[300],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}