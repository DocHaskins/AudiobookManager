// lib/ui/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/ui/screens/library_screen.dart';
import 'package:audiobook_organizer/ui/screens/player_screen.dart';
import 'package:audiobook_organizer/ui/screens/settings_screen.dart';
import 'package:audiobook_organizer/ui/widgets/mini_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  // Tab screens
  late List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize tab screens
    _screens = [
      const LibraryScreen(),
      const SettingsScreen(),
    ];
  }
  
  @override
  Widget build(BuildContext context) {
    final libraryManager = Provider.of<LibraryManager>(context);
    final playerService = Provider.of<AudioPlayerService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audiobook Organizer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Folder',
            onPressed: () => _addFolder(context, libraryManager),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main content area
          Expanded(
            child: _screens[_currentIndex],
          ),
          
          // Mini player at bottom
          StreamBuilder<bool>(
            stream: playerService.playerStateStream.map(
              (state) => state.playing,
            ),
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              
              // Only show mini player when an audiobook is loaded
              if (playerService.currentFile != null) {
                return MiniPlayer(
                  playerService: playerService,
                  onTap: () => _navigateToPlayer(context, playerService),
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
  
  // Add a folder to the library
  Future<void> _addFolder(BuildContext context, LibraryManager libraryManager) async {
    try {
      // Show directory picker
      String? selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Audiobooks Folder',
      );
      
      if (selectedDir != null) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            title: Text('Scanning Folder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Scanning for audiobooks...'),
              ],
            ),
          ),
        );
        
        // Add the directory to library manager
        await libraryManager.addDirectory(selectedDir);
        
        // Close loading dialog
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Folder added to library'),
        ));
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error adding folder: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
      
      Logger.error('Error adding folder', e);
    }
  }
  
  // Show search dialog
  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: AudiobookSearchDelegate(),
    );
  }
  
  // Navigate to player screen
  void _navigateToPlayer(BuildContext context, AudioPlayerService playerService) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          file: playerService.currentFile!,
        ),
      ),
    );
  }
}

// Search delegate for audiobooks
class AudiobookSearchDelegate extends SearchDelegate<AudiobookFile?> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }
  
  Widget _buildSearchResults(BuildContext context) {
    final library = Provider.of<List<AudiobookFile>>(context);
    
    if (query.isEmpty) {
      return const Center(
        child: Text('Enter a search term'),
      );
    }
    
    final queryLower = query.toLowerCase();
    final results = library.where((file) {
      final metadata = file.metadata;
      if (metadata == null) {
        return file.filename.toLowerCase().contains(queryLower);
      }
      
      // Search in title, author, series, etc.
      return metadata.title.toLowerCase().contains(queryLower) ||
             metadata.authors.any((a) => a.toLowerCase().contains(queryLower)) ||
             metadata.series.toLowerCase().contains(queryLower) ||
             metadata.userTags.any((t) => t.toLowerCase().contains(queryLower));
    }).toList();
    
    if (results.isEmpty) {
      return const Center(
        child: Text('No results found'),
      );
    }
    
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final file = results[index];
        final metadata = file.metadata;
        
        return ListTile(
          leading: metadata?.thumbnailUrl.isNotEmpty == true
              ? Image.file(File(metadata!.thumbnailUrl), width: 40, height: 40, fit: BoxFit.cover)
              : const Icon(Icons.audiotrack),
          title: Text(metadata?.title ?? file.filename),
          subtitle: Text(metadata?.authorsFormatted ?? ''),
          onTap: () {
            close(context, file);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PlayerScreen(file: file),
              ),
            );
          },
        );
      },
    );
  }
}