// lib/ui/screens/main_container.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/ui/widgets/mini_player.dart';
import 'package:audiobook_organizer/ui/screens/player_screen.dart';
import 'package:audiobook_organizer/ui/screens/library_screen.dart';
import 'package:audiobook_organizer/ui/screens/settings_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({Key? key}) : super(key: key);

  @override
  _MainContainerState createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;
  
  // Navigation history stack for back button support
  final List<Widget> _navigationStack = [];
  
  // Tab screens
  late List<Widget> _screens;
  
  // Currently displayed content
  late Widget _currentContent;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize tab screens with navigation callback
    _screens = [
      LibraryScreen(onNavigate: _navigateToScreen),
      const SettingsScreen(),
    ];
    
    _currentContent = _screens[0];
    _navigationStack.add(_currentContent);
  }
  
  @override
  Widget build(BuildContext context) {
    final libraryManager = Provider.of<LibraryManager>(context);
    final playerService = Provider.of<AudioPlayerService>(context);
    
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        // Custom app bar that shows back button when navigation stack has items
        appBar: AppBar(
          title: const Text('Audiobook Organizer'),
          leading: _navigationStack.length > 1 
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBack,
                ) 
              : null,
          actions: [
            if (_navigationStack.length <= 1) 
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
              child: _currentContent,
            ),
            
            // Mini player at bottom - always visible when a file is playing
            StreamBuilder<AudiobookFile?>(
              stream: playerService.fileChangeStream,
              builder: (context, snapshot) {
                // Only show mini player when an audiobook is loaded
                if (playerService.currentFile != null) {
                  return MiniPlayer(
                    playerService: playerService,
                    onTap: () => _navigateToPlayer(playerService),
                    onStop: () => playerService.stop(),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ],
        ),
        bottomNavigationBar: _navigationStack.length <= 1
            ? BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                    _currentContent = _screens[index];
                    // Reset navigation stack when switching tabs
                    _navigationStack.clear();
                    _navigationStack.add(_currentContent);
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
              )
            : null, // Hide bottom navigation when in detail screens
      ),
    );
  }
  
  // Navigate to a detail screen
  void _navigateToScreen(Widget screen) {
    setState(() {
      _currentContent = screen;
      _navigationStack.add(screen);
    });
  }
  
  // Handle back button
  void _handleBack() {
    if (_navigationStack.length > 1) {
      setState(() {
        _navigationStack.removeLast();
        _currentContent = _navigationStack.last;
      });
    }
  }
  
  // Handle system back button
  Future<bool> _handleWillPop() async {
    if (_navigationStack.length > 1) {
      _handleBack();
      return false;
    }
    return true;
  }
  
  // Navigate to player screen
  void _navigateToPlayer(AudioPlayerService playerService) {
    if (playerService.currentFile != null) {
      _navigateToScreen(PlayerScreen(
        file: playerService.currentFile!,
      ));
    }
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
    // Implement search functionality within the container
    // You could either navigate to a search screen or show a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Search for audiobooks...',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (query) {
            Navigator.pop(context);
            // Implement search functionality
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}