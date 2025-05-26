// lib/widgets/mini_player.dart - Three-section Spotify layout with centered progress
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/ui/screens/player_screen.dart';
import 'dart:io';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  AudiobookFile? _currentFile;
  AudiobookFile? _lastPlayedFile;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration? _totalDuration;
  bool _initialized = false;
  
  // Animation controllers for smooth transitions
  late AnimationController _playPauseController;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _playPauseController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    // Load last played file on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLastPlayedFile();
      _setupPlayerListeners();
    });
  }

  @override
  void dispose() {
    _playPauseController.dispose();
    super.dispose();
  }

  void _setupPlayerListeners() {
    final playerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    // Listen to file changes
    playerService.fileChangeStream.listen((file) {
      if (mounted) {
        setState(() {
          _currentFile = file;
          if (file != null) {
            _lastPlayedFile = file;
          }
        });
      }
    });
    
    // Listen to player state changes
    playerService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.playing) {
            _playPauseController.forward();
          } else {
            _playPauseController.reverse();
          }
        });
      }
    });
    
    // Listen to position changes
    playerService.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
    
    // Listen to duration changes
    playerService.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    // Initialize current state
    setState(() {
      _currentFile = playerService.currentFile;
      _isPlaying = playerService.isPlaying;
      _currentPosition = playerService.currentPosition;
      _totalDuration = playerService.totalDuration;
      
      if (_currentFile != null) {
        _lastPlayedFile = _currentFile;
      }
      
      if (_isPlaying) {
        _playPauseController.forward();
      }
    });
  }

  void _loadLastPlayedFile() {
    if (_initialized) return;
    
    final libraryManager = Provider.of<LibraryManager>(context, listen: false);
    
    // Find the most recently played book
    AudiobookFile? mostRecentBook;
    DateTime? mostRecentDate;
    
    for (final book in libraryManager.files) {
      final lastPlayed = book.metadata?.lastPlayedPosition;
      if (lastPlayed != null) {
        if (mostRecentDate == null || lastPlayed.isAfter(mostRecentDate)) {
          mostRecentDate = lastPlayed;
          mostRecentBook = book;
        }
      }
    }
    
    if (mostRecentBook != null && _currentFile == null) {
      setState(() {
        _lastPlayedFile = mostRecentBook;
      });
    }
    
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final displayFile = _currentFile ?? _lastPlayedFile;
    final hasActiveAudio = _currentFile != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: displayFile != null ? 100 : 0,
      child: displayFile != null
          ? Container(
              decoration: BoxDecoration(
                color: const Color(0xFF181818), // Spotify's mini player color
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[800]!.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // TOP: Full-width progress bar with times
                  _buildTopProgressBar(hasActiveAudio),
                  
                  // BOTTOM: Main content row
                  Expanded(
                    child: Row(
                      children: [
                        // LEFT SECTION: Track info (Album art + Title/Author)
                        Expanded(
                          flex: 1,
                          child: _buildLeftSection(displayFile, hasActiveAudio),
                        ),
                        
                        // CENTER SECTION: Player controls
                        Expanded(
                          flex: 1,
                          child: _buildCenterControlsSection(hasActiveAudio),
                        ),
                        
                        // RIGHT SECTION: Tools
                        Expanded(
                          flex: 1,
                          child: _buildRightSection(displayFile, hasActiveAudio),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  // LEFT SECTION: Album art + Track info
  Widget _buildLeftSection(AudiobookFile file, bool hasActiveAudio) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToFullPlayer(file),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Album Art
              _buildAlbumArt(file, hasActiveAudio),
              const SizedBox(width: 16),
              
              // Track Info
              Expanded(child: _buildTrackInfo(file, hasActiveAudio)),
            ],
          ),
        ),
      ),
    );
  }

  // TOP: Full-width progress bar with draggable thumb and times
  Widget _buildTopProgressBar(bool hasActiveAudio) {
    return Consumer<AudioPlayerService>(
      builder: (context, playerService, child) {
        double progress = 0.0;
        String currentTime = '0:00';
        String totalTime = '0:00';
        
        if (hasActiveAudio && _totalDuration != null && _totalDuration!.inSeconds > 0) {
          progress = _currentPosition.inSeconds / _totalDuration!.inSeconds;
          currentTime = _formatDuration(_currentPosition);
          totalTime = _formatDuration(_totalDuration!);
        } else if (_currentFile == null && _lastPlayedFile != null) {
          final savedPosition = _lastPlayedFile!.metadata?.playbackPosition;
          final totalDuration = _lastPlayedFile!.metadata?.audioDuration;
          if (savedPosition != null && totalDuration != null && totalDuration.inSeconds > 0) {
            progress = savedPosition.inSeconds / totalDuration.inSeconds;
            currentTime = _formatDuration(savedPosition);
            totalTime = _formatDuration(totalDuration);
          }
        }
        
        return Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              // Current time
              SizedBox(
                width: 50, // Increased width to accommodate hours
                child: Text(
                  currentTime,
                  style: TextStyle(
                    color: hasActiveAudio ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Draggable progress bar
              Expanded(
                child: GestureDetector(
                  onTapDown: hasActiveAudio ? (details) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final localPosition = box.globalToLocal(details.globalPosition);
                    final progressStart = 70.0; // Updated for larger time width
                    final progressWidth = box.size.width - 140; // Updated for larger time widths
                    final tapPosition = (localPosition.dx - progressStart) / progressWidth;
                    
                    if (tapPosition >= 0 && tapPosition <= 1 && _totalDuration != null) {
                      final newPosition = Duration(
                        milliseconds: (tapPosition * _totalDuration!.inMilliseconds).round(),
                      );
                      playerService.seekTo(newPosition);
                    }
                  } : null,
                  onPanUpdate: hasActiveAudio ? (details) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final localPosition = box.globalToLocal(details.globalPosition);
                    final progressStart = 70.0; // Updated for larger time width
                    final progressWidth = box.size.width - 140; // Updated for larger time widths
                    final panPosition = (localPosition.dx - progressStart) / progressWidth;
                    
                    if (panPosition >= 0 && panPosition <= 1 && _totalDuration != null) {
                      final newPosition = Duration(
                        milliseconds: (panPosition * _totalDuration!.inMilliseconds).round(),
                      );
                      playerService.seekTo(newPosition);
                    }
                  } : null,
                  child: Container(
                    height: 16,
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                        // Background track
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        
                        // Progress track
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: hasActiveAudio 
                                  ? const Color(0xFF1DB954) 
                                  : Colors.grey[500],
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                        
                        // Draggable thumb
                        if (hasActiveAudio)
                          Positioned(
                            left: (progress.clamp(0.0, 1.0) * 
                                   (MediaQuery.of(context).size.width - 140)) - 6, // Updated for larger time widths
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Total time
              SizedBox(
                width: 50, // Increased width to accommodate hours
                child: Text(
                  totalTime,
                  style: TextStyle(
                    color: hasActiveAudio ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // CENTER SECTION: Just player controls now
  Widget _buildCenterControlsSection(bool hasActiveAudio) {
    return Consumer<AudioPlayerService>(
      builder: (context, playerService, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Skip Backward
            IconButton(
              icon: Icon(
                Icons.replay_10,
                size: 20,
                color: hasActiveAudio ? Colors.white : Colors.grey[500],
              ),
              onPressed: hasActiveAudio ? () async {
                try {
                  await playerService.skipBackward();
                } catch (e) {
                  debugPrint('Skip backward error: $e');
                }
              } : null,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              splashRadius: 16,
            ),
            
            const SizedBox(width: 12),
            
            // Play/Pause button
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _handlePlayPause(playerService, _currentFile ?? _lastPlayedFile!, hasActiveAudio),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                    size: 18,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Skip Forward
            IconButton(
              icon: Icon(
                Icons.forward_30,
                size: 20,
                color: hasActiveAudio ? Colors.white : Colors.grey[500],
              ),
              onPressed: hasActiveAudio ? () async {
                try {
                  await playerService.skipForward();
                } catch (e) {
                  debugPrint('Skip forward error: $e');
                }
              } : null,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              splashRadius: 16,
            ),
          ],
        );
      },
    );
  }

  // RIGHT SECTION: Tools and actions
  Widget _buildRightSection(AudiobookFile displayFile, bool hasActiveAudio) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Heart/Favorite button
          IconButton(
            icon: Icon(
              displayFile.metadata?.isFavorite == true
                  ? Icons.favorite
                  : Icons.favorite_border,
              size: 16,
              color: displayFile.metadata?.isFavorite == true
                  ? const Color(0xFF1DB954) // Spotify green
                  : Colors.grey[400],
            ),
            onPressed: () => _toggleFavorite(displayFile),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            splashRadius: 16,
          ),
          
          const SizedBox(width: 8),
          
          // Full screen player button
          IconButton(
            icon: Icon(
              Icons.launch,
              size: 16,
              color: Colors.grey[400],
            ),
            onPressed: () => _navigateToFullPlayer(displayFile),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            splashRadius: 16,
            tooltip: 'Open full player',
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(AudiobookFile file, bool hasActiveAudio) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey[900],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: file.metadata?.thumbnailUrl != null && file.metadata!.thumbnailUrl.isNotEmpty
            ? Image.file(
                File(file.metadata!.thumbnailUrl),
                fit: BoxFit.cover,
                width: 56,
                height: 56,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: Icon(
        Icons.headphones,
        color: Colors.grey[500],
        size: 24,
      ),
    );
  }

  Widget _buildTrackInfo(AudiobookFile file, bool hasActiveAudio) {
    final metadata = file.metadata;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: hasActiveAudio ? Colors.white : Colors.grey[400],
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          child: Text(
            metadata?.title.isNotEmpty == true ? metadata!.title : file.filename,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        const SizedBox(height: 2),
        
        // Author
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 11,
          ),
          child: Text(
            metadata?.authorsFormatted.isNotEmpty == true
                ? metadata!.authorsFormatted
                : 'Unknown Author',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _handlePlayPause(AudioPlayerService playerService, AudiobookFile displayFile, bool hasActiveAudio) async {
    try {
      if (hasActiveAudio) {
        if (_isPlaying) {
          await playerService.pause();
        } else {
          await playerService.resume();
        }
      } else {
        final success = await playerService.play(displayFile);
        if (success) {
          setState(() {
            _currentFile = displayFile;
            _lastPlayedFile = displayFile;
          });
        }
      }
    } catch (e) {
      debugPrint('Play/pause error: $e');
    }
  }

  Future<void> _toggleFavorite(AudiobookFile file) async {
    try {
      final libraryManager = Provider.of<LibraryManager>(context, listen: false);
      await libraryManager.updateUserData(
        file,
        isFavorite: !(file.metadata?.isFavorite ?? false),
      );
    } catch (e) {
      debugPrint('Toggle favorite error: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    // Show hours if duration is 1 hour or more
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  void _navigateToFullPlayer(AudiobookFile file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(file: file),
      ),
    );
  }
}