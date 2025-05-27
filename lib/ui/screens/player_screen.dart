// lib/ui/screens/player_screen.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/services/library_manager.dart';

class PlayerScreen extends StatefulWidget {
  final AudiobookFile file;
  
  const PlayerScreen({Key? key, required this.file}) : super(key: key);
  
  @override
  PlayerScreenState createState() => PlayerScreenState();
}

class PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  // Tab controller for different sections (Player, Bookmarks, Notes)
  late TabController _tabController;
  
  // Playback position and state
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  
  // Initial page index
  int _currentTabIndex = 0;
  
  // Timer update and display formatting
  late Timer _positionTimer;
  String get _positionString => _formatDuration(_position);
  String get _durationString => _formatDuration(_duration);
  String get _remainingString => _formatDuration(_duration - _position);
  
  // Sleep timer options
  final List<Duration> _sleepTimerOptions = const [
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(minutes: 60),
    Duration(minutes: 90),
  ];
  
  @override
  void initState() {
    super.initState();
    
    // Initialize tab controller
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    
    // Start timer to update position display
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updatePosition();
    });
    
    // Initial position update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePosition();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _positionTimer.cancel();
    super.dispose();
  }
  
  // Format a duration as HH:MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }
  
  // Update position from player
  void _updatePosition() {
    final playerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    setState(() {
      _position = playerService.currentPosition;
      _duration = playerService.totalDuration ?? Duration.zero;
      _isPlaying = playerService.isPlaying;
      _playbackSpeed = playerService.currentSpeed;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final playerService = Provider.of<AudioPlayerService>(context);
    final libraryManager = Provider.of<LibraryManager>(context);
    final metadata = widget.file.metadata;
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark background like Spotify
      body: Column(
        children: [
          // TOP SECTION: AppBar with tabs
          _buildTopSection(playerService, metadata),
          
          // MIDDLE SECTION: Expandable content area
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Player tab - Cover and info
                _buildPlayerContent(),
                
                // Bookmarks tab
                _buildBookmarksTab(playerService, libraryManager),
                
                // Notes tab
                _buildNotesTab(playerService, libraryManager),
              ],
            ),
          ),
          
          // BOTTOM SECTION: Fixed player controls (only show on player tab)
          if (_currentTabIndex == 0)
            _buildBottomControls(playerService),
        ],
      ),
    );
  }
  
  // TOP SECTION: AppBar and Tabs
  Widget _buildTopSection(AudioPlayerService playerService, AudiobookMetadata? metadata) {
    return Container(
      color: const Color(0xFF181818),
      child: SafeArea(
        child: Column(
          children: [
            // AppBar content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 28, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back to Library',
                  ),
                  
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Now Playing',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          metadata?.title ?? widget.file.filename,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Sleep timer button
                  StreamBuilder<Duration?>(
                    stream: playerService.sleepTimerStream,
                    builder: (context, snapshot) {
                      final hasTimer = snapshot.data != null;
                      
                      return IconButton(
                        icon: Icon(
                          hasTimer ? Icons.nightlight : Icons.nightlight_outlined,
                          color: hasTimer ? Colors.amber : Colors.grey[400],
                          size: 24,
                        ),
                        tooltip: 'Sleep Timer',
                        onPressed: () => _showSleepTimerDialog(context, playerService),
                      );
                    },
                  ),
                  
                  // More options menu
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 24),
                    color: const Color(0xFF2A2A2A),
                    onSelected: (value) {
                      switch (value) {
                        case 'favorite':
                          _toggleFavorite(context, Provider.of<LibraryManager>(context, listen: false));
                          break;
                        case 'speed':
                          _showPlaybackSpeedDialog(context, playerService);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'favorite',
                        child: Row(
                          children: [
                            Icon(
                              metadata?.isFavorite == true ? Icons.favorite : Icons.favorite_border,
                              color: metadata?.isFavorite == true ? const Color(0xFF1DB954) : Colors.grey[400],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              metadata?.isFavorite == true ? 'Remove from favorites' : 'Add to favorites',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'speed',
                        child: Row(
                          children: [
                            Icon(Icons.speed, color: Colors.grey[400], size: 20),
                            const SizedBox(width: 12),
                            const Text('Playback speed', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Tab bar
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF1DB954),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[400],
              tabs: const [
                Tab(text: 'Player'),
                Tab(text: 'Bookmarks'),
                Tab(text: 'Notes'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // MIDDLE SECTION: Player content (cover and info)
  Widget _buildPlayerContent() {
    final metadata = widget.file.metadata;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 16),
          
          // Cover image
          LayoutBuilder(
            builder: (context, constraints) {
              // Responsive cover size
              final size = (constraints.maxWidth * 0.8).clamp(200.0, 400.0);
              
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: metadata?.thumbnailUrl.isNotEmpty == true
                    ? Image.file(
                        File(metadata!.thumbnailUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.headphones, size: size * 0.2, color: Colors.grey[600]);
                        },
                      )
                    : Icon(Icons.headphones, size: size * 0.2, color: Colors.grey[600]),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Title and author
          Text(
            metadata?.title ?? widget.file.filename,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 12),
          
          Text(
            metadata?.authorsFormatted ?? 'Unknown Author',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          if (metadata?.series.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              '${metadata!.series} ${metadata.seriesPosition.isNotEmpty ? "#${metadata.seriesPosition}" : ""}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          const SizedBox(height: 120), // Space for bottom controls
        ],
      ),
    );
  }
  
  // BOTTOM SECTION: Fixed player controls
  Widget _buildBottomControls(AudioPlayerService playerService) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        border: Border(
          top: BorderSide(color: Colors.grey[800]!.withOpacity(0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress slider and time
              _buildProgressSection(),
              
              const SizedBox(height: 20),
              
              // Player controls
              _buildPlayerControls(playerService),
              
              // Sleep timer indicator
              _buildSleepTimerIndicator(playerService),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProgressSection() {
    return Column(
      children: [
        // Progress slider
        SliderTheme(
          data: SliderThemeData(
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 3,
            activeTrackColor: const Color(0xFF1DB954),
            inactiveTrackColor: Colors.grey[800],
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF1DB954).withOpacity(0.1),
          ),
          child: Slider(
            value: _position.inMilliseconds.toDouble(),
            max: _duration.inMilliseconds > 0 
                ? _duration.inMilliseconds.toDouble() 
                : 1.0,
            min: 0.0,
            onChanged: (value) {
              final playerService = Provider.of<AudioPlayerService>(context, listen: false);
              playerService.seekTo(Duration(milliseconds: value.toInt()));
            },
          ),
        ),
        
        // Time display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _positionString,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _durationString,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPlayerControls(AudioPlayerService playerService) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive control sizes
        final isCompact = constraints.maxWidth < 400;
        final iconSize = isCompact ? 24.0 : 32.0;
        final playButtonSize = isCompact ? 56.0 : 64.0;
        final playIconSize = isCompact ? 28.0 : 32.0;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Add bookmark button
            IconButton(
              icon: Icon(Icons.bookmark_add, color: Colors.grey[400]),
              onPressed: () => _addBookmark(context, playerService),
              tooltip: 'Add Bookmark',
              iconSize: iconSize * 0.8,
            ),
            
            // Skip back button
            IconButton(
              icon: const Icon(Icons.replay_30, color: Colors.white),
              iconSize: iconSize,
              onPressed: () => playerService.skipBackward(duration: const Duration(seconds: 30)),
            ),
            
            // Play/pause button
            Container(
              width: playButtonSize,
              height: playButtonSize,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.black,
                ),
                iconSize: playIconSize,
                onPressed: () {
                  if (_isPlaying) {
                    playerService.pause();
                  } else {
                    playerService.resume();
                  }
                },
              ),
            ),
            
            // Skip forward button
            IconButton(
              icon: const Icon(Icons.forward_30, color: Colors.white),
              iconSize: iconSize,
              onPressed: () => playerService.skipForward(duration: const Duration(seconds: 30)),
            ),
            
            // Playback speed button
            GestureDetector(
              onTap: () => _showPlaybackSpeedDialog(context, playerService),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 12, 
                  vertical: isCompact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_playbackSpeed.toStringAsFixed(1)}x',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontWeight: FontWeight.w600,
                    fontSize: isCompact ? 11 : 12,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildSleepTimerIndicator(AudioPlayerService playerService) {
    return StreamBuilder<Duration?>(
      stream: playerService.sleepTimerStream,
      builder: (context, snapshot) {
        final timerDuration = snapshot.data;
        
        if (timerDuration == null) {
          return const SizedBox(height: 8);
        }
        
        final remaining = playerService.getRemainingTimerDuration();
        
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.nightlight, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Sleep timer: ${remaining?.inMinutes ?? 0}:${(remaining?.inSeconds.remainder(60) ?? 0).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => playerService.cancelSleepTimer(),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.amber.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Build the bookmarks tab
  Widget _buildBookmarksTab(AudioPlayerService playerService, LibraryManager libraryManager) {
    final metadata = widget.file.metadata;
    final bookmarks = metadata?.bookmarks ?? [];
    
    // Sort bookmarks by position
    final sortedBookmarks = List<AudiobookBookmark>.from(bookmarks);
    sortedBookmarks.sort((a, b) => a.position.compareTo(b.position));
    
    return Column(
      children: [
        // Add bookmark button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.bookmark_add),
            label: const Text('Add Bookmark'),
            onPressed: () => _addBookmark(context, playerService),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),
        
        // Bookmarks list
        Expanded(
          child: sortedBookmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'No bookmarks yet',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add bookmarks to mark important moments',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedBookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = sortedBookmarks[index];
                    
                    return Card(
                      color: const Color(0xFF1A1A1A),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.bookmark,
                            color: Color(0xFF1DB954),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          bookmark.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(bookmark.position),
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            if (bookmark.note != null && bookmark.note!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  bookmark.note!,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.grey[500]),
                          onPressed: () => _deleteBookmark(context, playerService, bookmark.id),
                        ),
                        onTap: () => playerService.jumpToBookmark(bookmark),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
  
  // Build the notes tab
  Widget _buildNotesTab(AudioPlayerService playerService, LibraryManager libraryManager) {
    final metadata = widget.file.metadata;
    final notes = metadata?.notes ?? [];
    
    // Sort notes by creation date (most recent first)
    final sortedNotes = List<AudiobookNote>.from(notes);
    sortedNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return Column(
      children: [
        // Add note button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.note_add),
            label: const Text('Add Note'),
            onPressed: () => _addNote(context, playerService, libraryManager),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),
        
        // Notes list
        Expanded(
          child: sortedNotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_outlined, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'No notes yet',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add notes to remember key insights',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedNotes.length,
                  itemBuilder: (context, index) {
                    final note = sortedNotes[index];
                    
                    return Card(
                      color: const Color(0xFF1A1A1A),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Note header
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1DB954).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.note,
                                    color: Color(0xFF1DB954),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatDate(note.createdAt),
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (note.position != null)
                                        Text(
                                          'At ${_formatDuration(note.position!)}',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (note.position != null)
                                  TextButton(
                                    onPressed: () {
                                      playerService.seekTo(note.position!);
                                      _tabController.animateTo(0); // Switch to player tab
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'GO TO',
                                      style: TextStyle(
                                        color: Color(0xFF1DB954),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[500]),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () => _deleteNote(context, libraryManager, note.id),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Note content
                            Text(
                              note.content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
  
  // Show sleep timer dialog
  void _showSleepTimerDialog(BuildContext context, AudioPlayerService playerService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Sleep Timer', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final duration in _sleepTimerOptions)
              ListTile(
                title: Text('${duration.inMinutes} minutes', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  playerService.setSleepTimer(duration);
                },
              ),
            const Divider(color: Colors.grey),
            ListTile(
              title: const Text('Cancel Timer', style: TextStyle(color: Colors.white)),
              leading: const Icon(Icons.cancel, color: Colors.red),
              onTap: () {
                Navigator.pop(context);
                playerService.cancelSleepTimer();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }
  
  // Show playback speed dialog
  void _showPlaybackSpeedDialog(BuildContext context, AudioPlayerService playerService) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Playback Speed', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final speed in speeds)
              ListTile(
                title: Text('${speed.toStringAsFixed(2)}x', style: const TextStyle(color: Colors.white)),
                selected: (speed - _playbackSpeed).abs() < 0.01,
                selectedTileColor: const Color(0xFF1DB954).withOpacity(0.1),
                onTap: () {
                  Navigator.pop(context);
                  playerService.setSpeed(speed);
                  setState(() {
                    _playbackSpeed = speed;
                  });
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }
  
  // Toggle favorite status
  void _toggleFavorite(BuildContext context, LibraryManager libraryManager) {
    final metadata = widget.file.metadata;
    
    if (metadata != null) {
      libraryManager.updateUserData(
        widget.file,
        isFavorite: !metadata.isFavorite,
      );
    }
  }
  
  // Add a bookmark at current position
  void _addBookmark(BuildContext context, AudioPlayerService playerService) {
    TextEditingController titleController = TextEditingController();
    TextEditingController noteController = TextEditingController();
    
    // Format current position for the default title
    final position = _formatDuration(_position);
    titleController.text = 'Bookmark at $position';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Add Bookmark', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1DB954)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1DB954)),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final title = titleController.text.trim();
              final note = noteController.text.trim();
              
              if (title.isNotEmpty) {
                final bookmark = await playerService.addBookmark(
                  title,
                  note: note.isNotEmpty ? note : null,
                );
                
                if (bookmark != null) {
                  // Switch to bookmarks tab
                  _tabController.animateTo(1);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  // Delete a bookmark
  void _deleteBookmark(BuildContext context, AudioPlayerService playerService, String bookmarkId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Delete Bookmark', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this bookmark?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await playerService.removeBookmark(bookmarkId);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  // Add a note
  void _addNote(BuildContext context, AudioPlayerService playerService, LibraryManager libraryManager) {
    TextEditingController contentController = TextEditingController();
    bool attachPosition = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text('Add Note', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Note',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1DB954)),
                  ),
                ),
                maxLines: 5,
                autofocus: true,
              ),
              
              // Option to attach position
              CheckboxListTile(
                title: const Text('Attach current position', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  _formatDuration(_position),
                  style: TextStyle(color: Colors.grey[400]),
                ),
                value: attachPosition,
                activeColor: const Color(0xFF1DB954),
                onChanged: (value) {
                  setState(() {
                    attachPosition = value ?? false;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                final content = contentController.text.trim();
                
                if (content.isNotEmpty) {
                  final note = AudiobookNote(
                    id: const Uuid().v4(),
                    content: content,
                    createdAt: DateTime.now(),
                    position: attachPosition ? _position : null,
                    chapter: null, // Could be added in future
                  );
                  
                  final success = await libraryManager.addNote(widget.file, note);
                  
                  if (success) {
                    // Switch to notes tab
                    _tabController.animateTo(2);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Delete a note
  void _deleteNote(BuildContext context, LibraryManager libraryManager, String noteId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Delete Note', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this note?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await libraryManager.removeNote(widget.file, noteId);
            },  
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}