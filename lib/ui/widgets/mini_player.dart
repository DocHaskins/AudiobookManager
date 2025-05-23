// lib/widgets/mini_player.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/ui/screens/player_screen.dart';
import 'dart:io';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  AudiobookFile? _currentFile;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updatePlayerState(AudioPlayerService playerService) {
    final newFile = playerService.currentFile;
    final newPlayingState = playerService.isPlaying;
    
    // Only update if something actually changed
    if (_currentFile != newFile || _isPlaying != newPlayingState) {
      setState(() {
        _currentFile = newFile;
        _isPlaying = newPlayingState;
      });
      
      // Show/hide based on whether we have a current file
      if (newFile != null && !_animationController.isCompleted) {
        _animationController.forward();
      } else if (newFile == null && !_animationController.isDismissed) {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, playerService, child) {
        // Update state when consumer rebuilds
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updatePlayerState(playerService);
        });

        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              border: Border(
                top: BorderSide(color: Colors.grey[800]!, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToFullPlayer(_currentFile),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Album Art
                      _buildAlbumArt(_currentFile),
                      const SizedBox(width: 16),
                      
                      // Track Info
                      Expanded(child: _buildTrackInfo(_currentFile)),
                      
                      // Controls
                      _buildControls(playerService),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumArt(AudiobookFile? file) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: file?.metadata?.thumbnailUrl != null &&
                file!.metadata!.thumbnailUrl.isNotEmpty
            ? Image.file(
                File(file.metadata!.thumbnailUrl),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Icon(
        Icons.headphones,
        color: Colors.grey[600],
        size: 32,
      ),
    );
  }

  Widget _buildTrackInfo(AudiobookFile? file) {
    if (file == null) return const SizedBox.shrink();

    final metadata = file.metadata;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metadata?.title.isNotEmpty == true
              ? metadata!.title
              : file.filename,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          metadata?.authorsFormatted.isNotEmpty == true
              ? metadata!.authorsFormatted
              : 'Unknown Author',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildControls(AudioPlayerService playerService) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Skip Backward
        IconButton(
          icon: const Icon(Icons.replay_10, color: Colors.white),
          onPressed: () async {
            try {
              await playerService.skipBackward();
            } catch (e) {
              // Handle error silently or show a snackbar if needed
            }
          },
          iconSize: 24,
          tooltip: 'Skip back 10s',
        ),
        
        // Play/Pause
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () async {
              try {
                if (_isPlaying) {
                  await playerService.pause();
                } else {
                  await playerService.resume();
                }
              } catch (e) {
                // Handle error silently or show a snackbar if needed
              }
            },
          ),
        ),
        
        // Skip Forward
        IconButton(
          icon: const Icon(Icons.forward_30, color: Colors.white),
          onPressed: () async {
            try {
              await playerService.skipForward();
            } catch (e) {
              // Handle error silently or show a snackbar if needed
            }
          },
          iconSize: 24,
          tooltip: 'Skip forward 30s',
        ),
        
        // Progress indicator
        const SizedBox(width: 8),
        StreamBuilder<Duration>(
          stream: playerService.positionStream,
          builder: (context, positionSnapshot) {
            return StreamBuilder<Duration?>(
              stream: playerService.durationStream,
              builder: (context, durationSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;
                final duration = durationSnapshot.data;
                
                if (duration == null || duration.inSeconds == 0) {
                  return const SizedBox.shrink();
                }
                
                final progress = position.inSeconds / duration.inSeconds;
                
                return SizedBox(
                  width: 60,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[700],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                        minHeight: 3,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(position),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _navigateToFullPlayer(AudiobookFile? file) {
    if (file == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(file: file),
      ),
    );
  }
}