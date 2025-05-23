// lib/main_container.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/ui/screens/library_screen.dart';
import 'package:audiobook_organizer/ui/screens/player_screen.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({Key? key}) : super(key: key);

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  AudiobookFile? _currentlyPlaying;
  bool _showMiniPlayer = false;

  @override
  void initState() {
    super.initState();
    
    // Listen to player changes to show/hide mini player
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playerService = Provider.of<AudioPlayerService>(context, listen: false);
      playerService.fileChangeStream.listen((file) {
        setState(() {
          _currentlyPlaying = file;
          _showMiniPlayer = file != null;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryManager = Provider.of<LibraryManager>(context);
    final collectionManager = Provider.of<CollectionManager>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          // Main content area
          Expanded(
            child: LibraryScreen(
              libraryManager: libraryManager,
              collectionManager: collectionManager,
            ),
          ),
          
          // Mini player (shown when something is playing)
          if (_showMiniPlayer && _currentlyPlaying != null)
            _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return Consumer<AudioPlayerService>(
      builder: (context, playerService, _) {
        return Container(
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            border: Border(
              top: BorderSide(color: Colors.grey[800]!),
            ),
          ),
          child: Row(
            children: [
              // Album art
              Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[900],
                ),
                child: _currentlyPlaying?.metadata?.thumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(_currentlyPlaying!.metadata!.thumbnailUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.headphones, color: Colors.white54),
                        ),
                      )
                    : const Icon(Icons.headphones, color: Colors.white54),
              ),
              
              // Track info
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentlyPlaying?.metadata?.title ?? _currentlyPlaying?.filename ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _currentlyPlaying?.metadata?.authorsFormatted ?? '',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Controls
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      playerService.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (playerService.isPlaying) {
                        playerService.pause();
                      } else {
                        playerService.resume();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: () {
                      // Navigate to full player
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PlayerScreen(file: _currentlyPlaying!),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}