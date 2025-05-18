// File: lib/ui/screens/library_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/services/audiobook_scanner.dart';
import 'package:audiobook_organizer/storage/audiobook_storage_manager.dart';
import 'package:audiobook_organizer/ui/widgets/library_sidebar.dart';
import 'package:audiobook_organizer/ui/widgets/book_grid_item.dart';
import 'package:audiobook_organizer/ui/widgets/book_list_item.dart';
import 'package:audiobook_organizer/ui/widgets/collection_grid_item.dart';
import 'package:audiobook_organizer/ui/widgets/collection_list_item.dart';
import 'package:audiobook_organizer/ui/dialogs/library_dialogs.dart';
import 'package:audiobook_organizer/ui/widgets/book_detail_panel.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/ui/dialogs/manage_collections_dialog.dart';
import 'package:audiobook_organizer/ui/dialogs/collection_cover_dialog.dart';
import 'package:audiobook_organizer/ui/screens/detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Library data
  List<AudiobookFile> _individualBooks = [];
  List<AudiobookCollection> _collections = [];
  List<AudiobookFile> _filesNeedingReview = [];
  
  // UI state
  bool _isLoading = true;
  bool _isGridView = true;
  double _gridItemSize = 180;
  
  // Filter state
  String _selectedGenre = 'All';
  bool _showCollectionsOnly = false;
  List<String> _availableGenres = ['All'];
  
  // Search state
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadLibrary();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      // Clear search when changing tabs
      setState(() {
        _searchQuery = '';
        _searchController.clear();
      });
    }
  }
  
  Future<void> _loadLibrary() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final storageManager = Provider.of<AudiobookStorageManager>(context, listen: false);
      
      // First load the library
      final libraryData = await storageManager.loadLibrary();
      final allBooks = libraryData['audiobooks'] as List<AudiobookFile>;
      final collections = libraryData['collections'] as List<AudiobookCollection>;
      
      // Separate books with complete metadata from those needing review
      final completeBooks = <AudiobookFile>[];
      final incompleteBooks = <AudiobookFile>[];
      
      // Track unique books by path to avoid duplicates
      final Set<String> processedPaths = {};
      
      for (final book in allBooks) {
        // Skip if we've already processed this book
        if (processedPaths.contains(book.path)) {
          continue;
        }
        
        processedPaths.add(book.path);
        
        if (book.hasCompleteMetadata) {
          completeBooks.add(book);
        } else {
          incompleteBooks.add(book);
        }
      }
      
      if (!mounted) return;
      
      setState(() {
        _individualBooks = completeBooks;
        _filesNeedingReview = incompleteBooks;
        _collections = collections;
        _isLoading = false;
        
        // Extract available genres
        _extractGenres();
      });
      
      Logger.log('Loaded ${_individualBooks.length} books, ${_collections.length} collections, and ${_filesNeedingReview.length} files needing review');
    } catch (e) {
      Logger.error('Failed to load library', e);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading library: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _extractGenres() {
    final Set<String> genres = {'All'};
    
    // Add genres from individual books
    for (final book in _individualBooks) {
      if (book.metadata?.categories.isNotEmpty ?? false) {
        genres.addAll(book.metadata!.categories);
      }
    }
    
    // Add genres from collections
    for (final collection in _collections) {
      if (collection.metadata?.categories.isNotEmpty ?? false) {
        genres.addAll(collection.metadata!.categories);
      }
    }
    
    _availableGenres = genres.toList()..sort();
  }
  
  // Scan a directory for audiobooks
  Future<void> _scanDirectory() async {
    final scanner = Provider.of<AudiobookScanner>(context, listen: false);
    final storageManager = Provider.of<AudiobookStorageManager>(context, listen: false);
    final String? directory = await getDirectoryPath();
    if (directory == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get books and files from scanner without saving them to storage
      final libraryResults = await scanner.scanForLibraryView(directory, matchOnline: true);
      final filesResults = await scanner.scanForFilesView(directory);
      
      if (!mounted) return;
      
      // Create a set of paths to check for duplicates
      final Set<String> existingBookPaths = _individualBooks.map((book) => book.path).toSet();
      final Set<String> existingCollectionTitles = _collections.map((coll) => coll.title).toSet();
      final Set<String> existingFilePaths = _filesNeedingReview.map((file) => file.path).toSet();
      
      int newBooks = 0;
      int newCollections = 0;
      int newFilesNeedingReview = 0;
      
      // Since we need to await inside the loop, we need to handle this outside setState
      final collectionsToAdd = <AudiobookCollection>[];
      final booksToAdd = <AudiobookFile>[];
      final filesToAdd = <AudiobookFile>[];
      
      // Check collections first
      for (final entry in libraryResults.entries) {
        if (entry.value.length > 1) {
          // Multiple files - create a collection
          final collection = AudiobookCollection.fromFiles(entry.value, entry.key);
          
          // Only add if not a duplicate
          if (!existingCollectionTitles.contains(collection.title) && 
              !(await storageManager.hasCollection(collection.title))) {
            collectionsToAdd.add(collection);
            existingCollectionTitles.add(collection.title);
            newCollections++;
          }
        } else if (entry.value.length == 1) {
          // Single file - add to individual books
          final book = entry.value.first;
          
          // Only add if not a duplicate and not currently being processed
          if (!existingBookPaths.contains(book.path) && 
              !(await storageManager.hasAudiobook(book.path)) &&
              !storageManager.isFileBeingProcessed(book.path)) {
            booksToAdd.add(book);
            existingBookPaths.add(book.path);
            newBooks++;
          }
        }
      }
      
      // Check files needing review
      for (final file in filesResults) {
        // Only add if not a duplicate and not currently being processed
        if (!existingFilePaths.contains(file.path) && 
            !(await storageManager.hasAudiobook(file.path)) &&
            !storageManager.isFileBeingProcessed(file.path)) {
          filesToAdd.add(file);
          existingFilePaths.add(file.path);
          newFilesNeedingReview++;
        }
      }
      
      // Now update state with all the items we've collected
      if (!mounted) return;
      
      setState(() {
        _collections.addAll(collectionsToAdd);
        _individualBooks.addAll(booksToAdd);
        _filesNeedingReview.addAll(filesToAdd);
        _isLoading = false;
      });
      
      // Extract updated genres
      _extractGenres();
      
      // First save new collections
      if (collectionsToAdd.isNotEmpty) {
        await storageManager.saveCollections(collectionsToAdd);
      }
      
      // Then save books and files in one batch to avoid duplicate processing
      final allNewFiles = [...booksToAdd, ...filesToAdd];
      if (allNewFiles.isNotEmpty) {
        await storageManager.saveAudiobooks(allNewFiles);
      }
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned directory: $directory\nAdded $newBooks new books, $newCollections new collections, and $newFilesNeedingReview new files needing metadata'),
          duration: const Duration(seconds: 4),
        ),
      );
      
      if (newFilesNeedingReview > 0) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Files needing complete metadata were found. Switch to the Files tab to find online metadata.'),
              action: SnackBarAction(
                label: 'SWITCH',
                onPressed: () {
                  _tabController.animateTo(1); // Switch to Files tab
                },
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        });
      }
    } catch (e) {
      Logger.error('Error scanning directory', e);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning directory: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Save library to storage
  Future<void> _saveLibrary() async {
    try {
      final storageManager = Provider.of<AudiobookStorageManager>(context, listen: false);
      await storageManager.saveLibrary(
        [..._individualBooks, ..._filesNeedingReview], 
        _collections
      );
    } catch (e) {
      Logger.error('Failed to save library', e);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving library: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Filter library items based on tab, genre, collections, and search
  List<dynamic> _getFilteredItems() {
    List<dynamic> items = [];
    
    if (_tabController.index == 0) {
      // Library tab - show books with metadata and collections
      if (!_showCollectionsOnly) {
        items.addAll(_individualBooks);
      }
      items.addAll(_collections);
    } else {
      // Files tab - show files needing metadata
      items.addAll(_filesNeedingReview);
    }
    
    // Apply genre filter if not 'All'
    if (_selectedGenre != 'All') {
      items = items.where((item) {
        if (item is AudiobookFile) {
          return item.metadata?.categories.contains(_selectedGenre) ?? false;
        } else if (item is AudiobookCollection) {
          return item.metadata?.categories.contains(_selectedGenre) ?? false;
        }
        return false;
      }).toList();
    }
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      items = items.where((item) {
        if (item is AudiobookFile) {
          return item.displayName.toLowerCase().contains(query) ||
                 item.author.toLowerCase().contains(query);
        } else if (item is AudiobookCollection) {
          return item.displayName.toLowerCase().contains(query) ||
                 item.author.toLowerCase().contains(query);
        }
        return false;
      }).toList();
    }
    
    return items;
  }
  
  void _openBookDetails(AudiobookFile book) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(audiobook: book),
      ),
    );
    
    if (result == true && mounted) {
      setState(() {});
    }
  }

  void _openCollectionDetails(AudiobookCollection collection) async {
    final result = await LibraryDialogs.showCollectionDetailsDialog(
      context: context,
      collection: collection,
    );
    
    if (result != null && mounted) {
      // Handle different actions based on result
      switch (result['action']) {
        case 'open_file':
          _openBookDetails(result['file']);
          break;
        case 'remove_file':
          // Implement remove file logic
          break;
        case 'find_metadata':
          // Implement find metadata logic
          break;
        case 'apply_metadata':
          // Implement apply metadata logic
          break;
      }
      
      await _loadLibrary();
    }
  }
  

  Future<void> _manageCollections() async {
    final result = await ManageCollectionsDialog.show(
      context: context,
      collections: _collections,
      allBooks: _individualBooks,
    );
    
    if (result != null && mounted) {
      final action = result['action'] as String;
      
      if (action == 'create') {
        final newCollection = result['collection'] as AudiobookCollection;
        
        // Show dialog to select cover
        final metadata = await CollectionCoverDialog.show(
          context: context,
          collection: newCollection,
        );
        
        if (metadata != null && mounted) {
          newCollection.updateMetadata(metadata);
          
          setState(() {
            _collections.add(newCollection);
          });
          
          // Save to storage
          final storageManager = Provider.of<AudiobookStorageManager>(context, listen: false);
          await storageManager.saveCollections([newCollection]);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Collection "${newCollection.title}" created successfully'),
            ),
          );
        }
      } else if (action == 'update') {
        final updatedCollection = result['collection'] as AudiobookCollection;
        
        // Show dialog to modify cover if needed
        final metadata = await CollectionCoverDialog.show(
          context: context,
          collection: updatedCollection,
        );
        
        if (metadata != null && mounted) {
          updatedCollection.updateMetadata(metadata);
          
          // Save to storage
          final storageManager = Provider.of<AudiobookStorageManager>(context, listen: false);
          await storageManager.saveCollections([updatedCollection]);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Collection "${updatedCollection.title}" updated successfully'),
            ),
          );
        }
        
        // Reload library to reflect changes
        await _loadLibrary();
      }
    }
  }

  Future<void> _processPendingFiles() async {
    if (_filesNeedingReview.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files need processing')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final scanner = Provider.of<AudiobookScanner>(context, listen: false);
      final storageManager = Provider.of<AudiobookStorageManager>(context, listen: false);
      
      // First, filter for files that are not currently being processed
      final filesToProcess = _filesNeedingReview
          .where((file) => !storageManager.isFileBeingProcessed(file.path))
          .toList();
      
      if (filesToProcess.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All files are currently being processed, please wait')),
        );
        return;
      }
      
      // Process the files
      final processedCount = await scanner.processFilesWithOnlineMetadata(filesToProcess);
      
      if (!mounted) return;
      
      // Rather than reloading the entire library, let's update our in-memory lists
      final completedFiles = <AudiobookFile>[];
      final remainingIncompleteFiles = <AudiobookFile>[];
      
      // Check each file to see if it now has complete metadata
      for (final file in _filesNeedingReview) {
        if (file.hasCompleteMetadata) {
          completedFiles.add(file);
        } else {
          remainingIncompleteFiles.add(file);
        }
      }
      
      // Save processed files to storage ONCE
      if (filesToProcess.isNotEmpty) {
        await storageManager.saveAudiobooks(filesToProcess);
      }
      
      // Update state without reloading from disk
      if (mounted) {
        setState(() {
          // Move completed files to individual books
          _individualBooks.addAll(completedFiles);
          
          // Update the files needing review list
          _filesNeedingReview = remainingIncompleteFiles;
          
          _isLoading = false;
        });
        
        // Extract updated genres with the new books
        _extractGenres();
      }
      
      if (!mounted) return;
      
      // Show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            completedFiles.isEmpty
                ? 'Processed $processedCount files, but no files were completed'
                : 'Processed $processedCount files. ${completedFiles.length} files now have complete metadata and were moved to the Library.',
          ),
        ),
      );
      
      // If all files are now complete, offer to switch to the Library tab
      if (completedFiles.isNotEmpty && remainingIncompleteFiles.isEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('All files now have complete metadata. Switch to the Library tab to view them.'),
              action: SnackBarAction(
                label: 'SWITCH',
                onPressed: () {
                  _tabController.animateTo(0); // Switch to Library tab
                },
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        });
      }
    } catch (e) {
      Logger.error('Failed to process pending files', e);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final items = _getFilteredItems();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AudioBook Organizer'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Library', icon: Icon(Icons.library_books)),
            Tab(text: 'Files', icon: Icon(Icons.audio_file)),
          ],
        ),
        actions: [
          // Search field
          Container(
            width: 250,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Colors.white.withAlpha(51), // 0.2 opacity = 51/255
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // View toggle
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: 'Toggle view',
          ),
          
          // Settings
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/settings');
              if (result == true && mounted) {
                // Settings changed, reload library
                _loadLibrary();
              }
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Sidebar
                LibrarySidebar(
                  genres: _availableGenres,
                  selectedGenre: _selectedGenre,
                  showCollectionsOnly: _showCollectionsOnly,
                  onGenreSelected: (genre) {
                    setState(() {
                      _selectedGenre = genre;
                    });
                  },
                  onShowCollectionsChanged: (value) {
                    setState(() {
                      _showCollectionsOnly = value;
                    });
                  },
                  gridItemSize: _gridItemSize,
                  onGridSizeChanged: (value) {
                    setState(() {
                      _gridItemSize = value;
                    });
                  },
                ),
                
                // Main content
                Expanded(
                  child: items.isEmpty
                      ? _buildEmptyState()
                      : _isGridView
                          ? _buildGridView(items)
                          : _buildListView(items),
                ),
              ],
            ),
    floatingActionButton: _tabController.index == 0 
    ? Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _manageCollections,
            icon: const Icon(Icons.collections_bookmark),
            label: const Text('Manage Collections'),
            heroTag: 'manage_collections',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            onPressed: _scanDirectory,
            icon: const Icon(Icons.add),
            label: const Text('Scan Directory'),
            heroTag: 'scan_directory',
          ),
        ],
      )
    : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _processPendingFiles,
            icon: const Icon(Icons.cloud_download),
            label: const Text('Match Online Metadata'),
            heroTag: 'match_online',
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            onPressed: _scanDirectory,
            icon: const Icon(Icons.add),
            label: const Text('Scan Directory'),
            heroTag: 'scan_directory',
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    String message;
    IconData icon;
    
    if (_tabController.index == 0) {
      if (_individualBooks.isEmpty && _collections.isEmpty) {
        message = 'Your library is empty. Scan a directory to add audiobooks.';
        icon = Icons.library_books;
      } else {
        message = 'No items match the current filters or search query.';
        icon = Icons.search_off;
      }
    } else {
      if (_filesNeedingReview.isEmpty) {
        message = 'No files need metadata review. Great job!';
        icon = Icons.check_circle;
      } else {
        message = 'No files match the current search query.';
        icon = Icons.search_off;
      }
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          if (_individualBooks.isEmpty && _collections.isEmpty && _filesNeedingReview.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _scanDirectory,
              icon: const Icon(Icons.folder_open),
              label: const Text('Scan Directory'),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildGridView(List<dynamic> items) {
    // Calculate grid dimensions based on item size
    final crossAxisCount = (MediaQuery.of(context).size.width - 260) ~/ _gridItemSize;
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount > 0 ? crossAxisCount : 1,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is AudiobookFile) {
          return BookGridItem(
            book: item,
            onTap: () => _openBookDetails(item),
            onLongPress: () => _showItemContextMenu(item),
          );
        } else if (item is AudiobookCollection) {
          return CollectionGridItem(
            collection: item,
            onTap: () => _openCollectionDetails(item),
            onLongPress: () => _showItemContextMenu(item),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
  
  Widget _buildListView(List<dynamic> items) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is AudiobookFile) {
          return BookListItem(
            book: item,
            onTap: () => _openBookDetails(item),
            onLongPress: () => _showItemContextMenu(item),
          );
        } else if (item is AudiobookCollection) {
          return CollectionListItem(
            collection: item,
            onTap: () => _openCollectionDetails(item),
            onLongPress: () => _showItemContextMenu(item),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
  
  void _showItemContextMenu(dynamic item) {
    if (item is AudiobookFile) {
      // Show book context menu
      if (_tabController.index == 0) {
        // Library tab
        LibraryDialogs.showBookContextMenu(
          context: context,
          book: item,
          collections: _collections, 
          onAddToCollection: (collection) {
            // Implement add to collection
          },
          onCreateCollection: (name) {
            // Implement create collection
          },
          onFindMetadata: () {
            // Implement find metadata
          },
          onRemove: () {
            // Implement remove book
          },
        );
      } else {
        // Files tab
        // Show file-specific context menu
      }
    } else if (item is AudiobookCollection) {
      // Show collection context menu
      LibraryDialogs.showCollectionContextMenu(
        context: context,
        collection: item,
        onFindMetadata: () {
          // Implement find metadata
        },
        onApplyMetadata: () {
          // Implement apply metadata
        },
        onRename: (newName) {
          // Implement rename
        },
        onRemove: (keepFiles) {
          // Implement remove collection
        },
      );
    }
  }
}