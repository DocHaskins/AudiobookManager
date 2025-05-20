// lib/ui/screens/library_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/ui/screens/audiobook_details_screen.dart';
import 'package:audiobook_organizer/ui/screens/player_screen.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/ui/widgets/book_grid_item.dart';
import 'package:audiobook_organizer/ui/widgets/book_list_item.dart';

// View types
enum ViewType { grid, list, series, authors }

class LibraryScreen extends StatefulWidget {
  // Add navigation callback
  final Function(Widget)? onNavigate;
  
  const LibraryScreen({
    Key? key, 
    this.onNavigate,
  }) : super(key: key);

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  // Current view type
  ViewType _viewType = ViewType.grid;
  
  // Current filter
  String _currentFilter = '';
  
  // Tab controller for different sections
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize tab controller
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        // Update view type based on selected tab
        _viewType = ViewType.values[_tabController.index];
      });
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final library = Provider.of<List<AudiobookFile>>(context);
    final libraryManager = Provider.of<LibraryManager>(context);
    final playerService = Provider.of<AudioPlayerService>(context);
    
    return Column(
      children: [
        // Tab bar
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Grid'),
            Tab(text: 'List'),
            Tab(text: 'Series'),
            Tab(text: 'Authors'),
          ],
        ),
        
        // Filter chip section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              const Text('Filter: '),
              _currentFilter.isEmpty
                  ? const Text('None', style: TextStyle(color: Colors.grey))
                  : Chip(
                      label: Text(_currentFilter),
                      onDeleted: () {
                        setState(() {
                          _currentFilter = '';
                        });
                      },
                    ),
              const Spacer(),
              if (libraryManager.isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Library',
                onPressed: () => _refreshLibrary(libraryManager),
              ),
            ],
          ),
        ),
        
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Grid view
              _buildGridView(context, library, playerService),
              
              // List view
              _buildListView(context, library, playerService),
              
              // Series view
              _buildSeriesView(context, library, libraryManager, playerService),
              
              // Authors view
              _buildAuthorsView(context, library, libraryManager, playerService),
            ],
          ),
        ),
      ],
    );
  }
  
  // Build grid view of audiobooks
  Widget _buildGridView(BuildContext context, List<AudiobookFile> library, AudioPlayerService playerService) {
    final filteredLibrary = _filterLibrary(library);
    
    if (filteredLibrary.isEmpty) {
      return _buildEmptyView();
    }
    
    // Calculate how many columns to display based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = (screenWidth / 160).floor();
    crossAxisCount = crossAxisCount < 2 ? 2 : crossAxisCount;
    
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.6, // Book cover aspect ratio (slightly wider than 2:3 to account for text)
        crossAxisSpacing: 8,
        mainAxisSpacing: 12, // Increased for better vertical separation
      ),
      itemCount: filteredLibrary.length,
      itemBuilder: (context, index) {
        final file = filteredLibrary[index];
        return BookGridItem(
          book: file,
          onTap: () => _openAudiobookDetails(context, file),
          onLongPress: () => _showOptionsMenu(context, file, playerService),
          onPlayTap: () => _playAudiobook(context, file, playerService),
        );
      },
    );
  }
  
  // Build list view of audiobooks
  Widget _buildListView(BuildContext context, List<AudiobookFile> library, AudioPlayerService playerService) {
    final filteredLibrary = _filterLibrary(library);
    
    if (filteredLibrary.isEmpty) {
      return _buildEmptyView();
    }
    
    return ListView.builder(
      itemCount: filteredLibrary.length,
      itemBuilder: (context, index) {
        final file = filteredLibrary[index];
        return BookListItem(
          book: file,
          onTap: () => _openAudiobookDetails(context, file),
          onLongPress: () => _showOptionsMenu(context, file, playerService),
          onPlayTap: () => _playAudiobook(context, file, playerService),
        );
      },
    );
  }
  
  // Build series view
  Widget _buildSeriesView(BuildContext context, List<AudiobookFile> library, 
                          LibraryManager libraryManager, AudioPlayerService playerService) {
    final series = libraryManager.getAllSeries();
    
    if (series.isEmpty) {
      return _buildEmptyView(message: 'No series found');
    }
    
    return ListView.builder(
      itemCount: series.length,
      itemBuilder: (context, index) {
        final seriesName = series[index];
        final seriesBooks = libraryManager.getFilesBySeries(seriesName);
        final sortedBooks = _sortBooksBySeries(seriesBooks);
        
        // Skip if filtered and no match
        if (_currentFilter.isNotEmpty && 
            !seriesName.toLowerCase().contains(_currentFilter.toLowerCase())) {
          return const SizedBox.shrink();
        }
        
        return ExpansionTile(
          title: Text(seriesName),
          subtitle: Text('${seriesBooks.length} books'),
          children: [
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sortedBooks.length,
                itemBuilder: (context, bookIndex) {
                  final file = sortedBooks[bookIndex];
                  final metadata = file.metadata;
                  
                  return InkWell(
                    onTap: () => _openAudiobookDetails(context, file),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.all(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cover image
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
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
                                              return Center(child: Text('#${metadata.seriesPosition}'));
                                            },
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            '#${metadata?.seriesPosition ?? '?'}',
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                        ),
                                ),
                                
                                // Play icon overlay
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: InkWell(
                                      onTap: () => _playAudiobook(context, file, playerService),
                                      child: const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Book number and title
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '#${metadata?.seriesPosition ?? '?'} - ${metadata?.title ?? file.filename}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
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
      },
    );
  }
  
  // Build authors view
  Widget _buildAuthorsView(BuildContext context, List<AudiobookFile> library, 
                           LibraryManager libraryManager, AudioPlayerService playerService) {
    final authors = libraryManager.getAllAuthors();
    
    if (authors.isEmpty) {
      return _buildEmptyView(message: 'No authors found');
    }
    
    return ListView.builder(
      itemCount: authors.length,
      itemBuilder: (context, index) {
        final authorName = authors[index];
        final authorBooks = libraryManager.getFilesByAuthor(authorName);
        
        // Skip if filtered and no match
        if (_currentFilter.isNotEmpty && 
            !authorName.toLowerCase().contains(_currentFilter.toLowerCase())) {
          return const SizedBox.shrink();
        }
        
        return ExpansionTile(
          title: Text(authorName),
          subtitle: Text('${authorBooks.length} books'),
          children: [
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: authorBooks.length,
                itemBuilder: (context, bookIndex) {
                  final file = authorBooks[bookIndex];
                  final metadata = file.metadata;
                  
                  return InkWell(
                    onTap: () => _openAudiobookDetails(context, file),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.all(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cover image
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
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
                                
                                // Play icon overlay
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: InkWell(
                                      onTap: () => _playAudiobook(context, file, playerService),
                                      child: const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Title
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              metadata?.title ?? file.filename,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          
                          // Series info
                          if (metadata?.series.isNotEmpty == true)
                            Text(
                              '${metadata!.series} ${metadata.seriesPosition.isNotEmpty ? "#${metadata.seriesPosition}" : ""}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[400],
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
      },
    );
  }
  
  // Build empty view for when no books are found
  Widget _buildEmptyView({String message = 'No audiobooks found'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.library_music, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Add folders to your library using the + button',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
  
  // Filter library based on the current filter
  List<AudiobookFile> _filterLibrary(List<AudiobookFile> library) {
    if (_currentFilter.isEmpty) {
      return library;
    }
    
    final filterLower = _currentFilter.toLowerCase();
    return library.where((file) {
      final metadata = file.metadata;
      if (metadata == null) {
        return file.filename.toLowerCase().contains(filterLower);
      }
      
      return metadata.title.toLowerCase().contains(filterLower) ||
             metadata.authors.any((a) => a.toLowerCase().contains(filterLower)) ||
             metadata.series.toLowerCase().contains(filterLower) ||
             metadata.userTags.any((t) => t.toLowerCase().contains(filterLower));
    }).toList();
  }
  
  // Sort books by series position
  List<AudiobookFile> _sortBooksBySeries(List<AudiobookFile> books) {
    final sortedBooks = List<AudiobookFile>.from(books);
    
    sortedBooks.sort((a, b) {
      final aPosition = int.tryParse(a.metadata?.seriesPosition ?? '') ?? 999;
      final bPosition = int.tryParse(b.metadata?.seriesPosition ?? '') ?? 999;
      return aPosition.compareTo(bPosition);
    });
    
    return sortedBooks;
  }
  
  // Open audiobook details screen
  void _openAudiobookDetails(BuildContext context, AudiobookFile file) {
    if (widget.onNavigate != null) {
      // Use the navigation callback
      widget.onNavigate!(AudiobookDetailsScreen(
        file: file,
      ));
    } else {
      // Fallback to traditional navigation
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AudiobookDetailsScreen(file: file),
        ),
      ).then((_) {
        // Force a refresh when returning
        setState(() {
          imageCache.clear();
          imageCache.clearLiveImages();
        });
      });
    }
  }
  
  // Play an audiobook
  Future<void> _playAudiobook(BuildContext context, AudiobookFile file, AudioPlayerService playerService) async {
    try {
      final success = await playerService.play(file);
      
      if (success) {
        // Navigate to player screen using callback if available
        if (widget.onNavigate != null) {
          widget.onNavigate!(PlayerScreen(
            file: file,
          ));
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlayerScreen(file: file),
            ),
          );
        }
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to play audiobook'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error playing audiobook', e);
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing audiobook: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Show options menu for an audiobook
  void _showOptionsMenu(BuildContext context, AudiobookFile file, AudioPlayerService playerService) {
    final metadata = file.metadata;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('View Details'),
            onTap: () {
              Navigator.pop(context);
              _openAudiobookDetails(context, file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Play'),
            onTap: () {
              Navigator.pop(context);
              _playAudiobook(context, file, playerService);
            },
          ),
          if (metadata != null)
            ListTile(
              leading: Icon(metadata.isFavorite ? Icons.favorite : Icons.favorite_border),
              title: Text(metadata.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
              onTap: () {
                Navigator.pop(context);
                _toggleFavorite(context, file);
              },
            ),
          ListTile(
            leading: const Icon(Icons.filter_alt),
            title: const Text('Filter By This'),
            onTap: () {
              Navigator.pop(context);
              _filterBy(file);
            },
          ),
        ],
      ),
    );
  }
  
  // Toggle favorite status
  void _toggleFavorite(BuildContext context, AudiobookFile file) {
    final libraryManager = Provider.of<LibraryManager>(context, listen: false);
    final metadata = file.metadata;
    
    if (metadata != null) {
      libraryManager.updateUserData(
        file,
        isFavorite: !metadata.isFavorite,
      );
    }
  }
  
  // Filter by a specific attribute
  void _filterBy(AudiobookFile file) {
    final metadata = file.metadata;
    
    if (metadata != null) {
      // Show filter options
      showDialog(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Filter By'),
          children: [
            if (metadata.series.isNotEmpty)
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentFilter = metadata.series;
                    _tabController.animateTo(2); // Switch to Series tab
                  });
                },
                child: Text('Series: ${metadata.series}'),
              ),
            if (metadata.authors.isNotEmpty)
              ...metadata.authors.map((author) => SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentFilter = author;
                    _tabController.animateTo(3); // Switch to Authors tab
                  });
                },
                child: Text('Author: $author'),
              )),
            if (metadata.userTags.isNotEmpty)
              ...metadata.userTags.map((tag) => SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentFilter = tag;
                  });
                },
                child: Text('Tag: $tag'),
              )),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }
  
  // Refresh library
  Future<void> _refreshLibrary(LibraryManager libraryManager) async {
    // Show refresh options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refresh Library'),
        content: const Text('How would you like to refresh your library?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performRefresh(libraryManager, forceMetadataUpdate: false);
            },
            child: const Text('Scan for New Files'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performRefresh(libraryManager, forceMetadataUpdate: true);
            },
            child: const Text('Full Refresh (Update All Metadata)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  // Perform the refresh
  Future<void> _performRefresh(LibraryManager libraryManager, {required bool forceMetadataUpdate}) async {
    try {
      // Show loading indicator in snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Text(forceMetadataUpdate 
                   ? 'Updating all metadata...' 
                   : 'Scanning for new files...'),
            ],
          ),
          duration: const Duration(seconds: 30),
        ),
      );
      
      // Perform the refresh
      await libraryManager.rescanLibrary(forceMetadataUpdate: forceMetadataUpdate);
      
      // Hide the snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Library refresh complete'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Hide the loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing library: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      
      Logger.error('Error refreshing library', e);
    }
  }
}