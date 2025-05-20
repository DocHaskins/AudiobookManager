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
      appBar: AppBar(
        title: const Text('Now Playing'),
        actions: [
          // Sleep timer button
          StreamBuilder<Duration?>(
            stream: playerService.sleepTimerStream,
            builder: (context, snapshot) {
              final hasTimer = snapshot.data != null;
              
              return IconButton(
                icon: Icon(
                  hasTimer ? Icons.nightlight : Icons.nightlight_outlined,
                  color: hasTimer ? Colors.amber : null,
                ),
                tooltip: 'Sleep Timer',
                onPressed: () => _showSleepTimerDialog(context, playerService),
              );
            },
          ),
          
          // Favorite button
          if (metadata != null)
            IconButton(
              icon: Icon(
                metadata.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: metadata.isFavorite ? Colors.red : null,
              ),
              onPressed: () => _toggleFavorite(context, libraryManager),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Player'),
            Tab(text: 'Bookmarks'),
            Tab(text: 'Notes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Player tab
          _buildPlayerTab(playerService),
          
          // Bookmarks tab
          _buildBookmarksTab(playerService, libraryManager),
          
          // Notes tab
          _buildNotesTab(playerService, libraryManager),
        ],
      ),
    );
  }
  
  // Build the main player tab
  Widget _buildPlayerTab(AudioPlayerService playerService) {
    final metadata = widget.file.metadata;
    
    return Column(
      children: [
        // Cover image and title area
        Expanded(
          flex: 3,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cover image
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: metadata?.thumbnailUrl.isNotEmpty == true
                          ? Image.file(
                              File(metadata!.thumbnailUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.book, size: 80);
                              },
                            )
                          : const Icon(Icons.book, size: 80),
                    ),
                  ),
                  
                  // Title and author
                  const SizedBox(height: 24),
                  Text(
                    metadata?.title ?? widget.file.filename,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metadata?.authorsFormatted ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  if (metadata?.series.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${metadata!.series} ${metadata.seriesPosition.isNotEmpty ? "#${metadata.seriesPosition}" : ""}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        
        // Playback controls and progress
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: SliderTheme(
                  data: const SliderThemeData(
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble(),
                    max: _duration.inMilliseconds > 0 
                        ? _duration.inMilliseconds.toDouble() 
                        : 1.0,
                    min: 0.0,
                    onChanged: (value) {
                      playerService.seekTo(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ),
              
              // Time display
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_positionString),
                    Text('-$_remainingString'),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Playback controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Add bookmark button
                  IconButton(
                    icon: const Icon(Icons.bookmark_add),
                    onPressed: () => _addBookmark(context, playerService),
                    tooltip: 'Add Bookmark',
                  ),
                  
                  // Skip back button
                  IconButton(
                    icon: const Icon(Icons.replay_30),
                    iconSize: 36,
                    onPressed: () => playerService.skipBackward(duration: const Duration(seconds: 30)),
                  ),
                  
                  // Play/pause button
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      iconSize: 48,
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
                    icon: const Icon(Icons.forward_30),
                    iconSize: 36,
                    onPressed: () => playerService.skipForward(duration: const Duration(seconds: 30)),
                  ),
                  
                  // Playback speed button
                  TextButton(
                    onPressed: () => _showPlaybackSpeedDialog(context, playerService),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      '${_playbackSpeed.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Sleep timer indicator
              StreamBuilder<Duration?>(
                stream: playerService.sleepTimerStream,
                builder: (context, snapshot) {
                  final timerDuration = snapshot.data;
                  
                  if (timerDuration == null) {
                    return const SizedBox(height: 8);
                  }
                  
                  final remaining = playerService.getRemainingTimerDuration();
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:  [
                        const Icon(Icons.nightlight, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          'Sleep timer: ${remaining?.inMinutes ?? 0}:${(remaining?.inSeconds.remainder(60) ?? 0).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            playerService.cancelSleepTimer();
                          },
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.bookmark_add),
            label: const Text('Add Bookmark'),
            onPressed: () => _addBookmark(context, playerService),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ),
        
        // Bookmarks list
        Expanded(
          child: sortedBookmarks.isEmpty
              ? const Center(
                  child: Text(
                    'No bookmarks yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: sortedBookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = sortedBookmarks[index];
                    
                    return ListTile(
                      leading: const Icon(Icons.bookmark),
                      title: Text(bookmark.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDuration(bookmark.position)),
                          if (bookmark.note != null && bookmark.note!.isNotEmpty)
                            Text(
                              bookmark.note!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteBookmark(context, playerService, bookmark.id),
                      ),
                      onTap: () => playerService.jumpToBookmark(bookmark),
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.note_add),
            label: const Text('Add Note'),
            onPressed: () => _addNote(context, playerService, libraryManager),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ),
        
        // Notes list
        Expanded(
          child: sortedNotes.isEmpty
              ? const Center(
                  child: Text(
                    'No notes yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: sortedNotes.length,
                  itemBuilder: (context, index) {
                    final note = sortedNotes[index];
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Note header
                            Row(
                              children:  [
                                const Icon(Icons.note, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    note.createdAt.toString().split('.')[0],
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
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
                                    child: Text(_formatDuration(note.position!)),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _deleteNote(context, libraryManager, note.id),
                                ),
                              ],
                            ),
                            
                            // Note content
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(note.content),
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
  
  // Show sleep timer dialog
  void _showSleepTimerDialog(BuildContext context, AudioPlayerService playerService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sleep Timer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final duration in _sleepTimerOptions)
              ListTile(
                title: Text('${duration.inMinutes} minutes'),
                onTap: () {
                  Navigator.pop(context);
                  playerService.setSleepTimer(duration);
                },
              ),
            const Divider(),
            ListTile(
              title: const Text('Cancel Timer'),
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
            child: const Text('Close'),
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
        title: const Text('Playback Speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final speed in speeds)
              ListTile(
                title: Text('${speed.toStringAsFixed(2)}x'),
                selected: (speed - _playbackSpeed).abs() < 0.01,
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
            child: const Text('Close'),
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
        title: const Text('Add Bookmark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
        title: const Text('Delete Bookmark'),
        content: const Text('Are you sure you want to delete this bookmark?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
          title: const Text('Add Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                autofocus: true,
              ),
              
              // Option to attach position
              CheckboxListTile(
                title: const Text('Attach current position'),
                subtitle: Text(_formatDuration(_position)),
                value: attachPosition,
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
              child: const Text('Cancel'),
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
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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