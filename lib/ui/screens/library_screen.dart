// File: lib/ui/screens/library_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/services/audiobook_scanner.dart';
import 'package:audiobook_organizer/storage/library_storage.dart';
import 'package:audiobook_organizer/ui/widgets/library_sidebar.dart';
import 'package:audiobook_organizer/ui/widgets/book_grid_item.dart';
import 'package:audiobook_organizer/ui/widgets/book_list_item.dart';
import 'package:audiobook_organizer/ui/widgets/collection_grid_item.dart';
import 'package:audiobook_organizer/ui/widgets/collection_list_item.dart';
import 'package:audiobook_organizer/ui/dialogs/library_dialogs.dart';
import 'package:audiobook_organizer/ui/widgets/book_detail_panel.dart'; // Import the new widget
import 'package:audiobook_organizer/utils/logger.dart';

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
      final libraryStorage = Provider.of<LibraryStorage>(context, listen: false);
      final libraryData = await libraryStorage.loadLibrary();
      
      final allBooks = libraryData['audiobooks'] as List<AudiobookFile>;
      final collections = libraryData['collections'] as List<AudiobookCollection>;
      
      // Separate books with complete metadata from those needing review
      final completeBooks = <AudiobookFile>[];
      final incompleteBooks = <AudiobookFile>[];
      
      for (final book in allBooks) {
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
    final String? directory = await getDirectoryPath();
    if (directory == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      
      final libraryResults = await scanner.scanForLibraryView(directory, matchOnline: true);
      final filesResults = await scanner.scanForFilesView(directory);
      
      if (!mounted) return;
      
      // Update state
      setState(() {
        for (final entry in libraryResults.entries) {
          if (entry.value.length > 1) {
            // Multiple files - create a collection
            final collection = AudiobookCollection.fromFiles(entry.value, entry.key);
            _collections.add(collection);
          } else if (entry.value.length == 1) {
            // Single file - add to individual books
            _individualBooks.add(entry.value.first);
          }
        }
        
        _filesNeedingReview.addAll(filesResults);
        _isLoading = false;
      });
      
      // Extract updated genres
      _extractGenres();
      
      // Save the library
      await _saveLibrary();
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned directory: $directory\nFound ${libraryResults.length} complete items and ${filesResults.length} files needing metadata'),
          duration: const Duration(seconds: 4),
        ),
      );
      
      if (filesResults.isNotEmpty) {
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
      final libraryStorage = Provider.of<LibraryStorage>(context, listen: false);
      await libraryStorage.saveLibrary(
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
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BookDetailPanel(
        book: book,
        onClose: () => Navigator.pop(context, false),
        onUpdateMetadata: (metadata) async {
          // Create updated book with new metadata
          final updatedBook = AudiobookFile(
            path: book.path,
            filename: book.filename,
            extension: book.extension,
            size: book.size,
            lastModified: book.lastModified,
            metadata: metadata,
            fileMetadata: book.fileMetadata,
          );
          
          // IMPORTANT: Update the book in the appropriate list
          setState(() {
            // Update in _individualBooks list
            final bookIndex = _individualBooks.indexWhere((b) => b.path == book.path);
            if (bookIndex >= 0) {
              _individualBooks[bookIndex] = updatedBook;
            }
            
            // Update in _filesNeedingReview list if it exists there
            final fileIndex = _filesNeedingReview.indexWhere((f) => f.path == book.path);
            if (fileIndex >= 0) {
              _filesNeedingReview[fileIndex] = updatedBook;
            }
          });
          
          // Save to file if in files tab
          if (_tabController.index == 1) {
            try {
              await updatedBook.writeMetadataToFile(metadata);
              
              // If in Files tab and now has complete metadata, potentially move to Library
              if (updatedBook.hasCompleteMetadata) {
                // Show a notification
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('File now has complete metadata and will be moved to the Library'),
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            } catch (e) {
              Logger.error('Failed to save metadata to file', e);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error saving metadata to file: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          
          // Save the updated library to storage
          await _saveLibrary();
          
          // Close dialog with true result to indicate changes were made
          Navigator.pop(context, true);
        },
      ),
    );
    
    if (result == true && mounted) {
      // DON'T reload library here - we've already updated it in memory
      // and saved it to storage with _saveLibrary()
      // await _loadLibrary();
      
      // Instead, just refresh UI if needed
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
      final processedCount = await scanner.processFilesWithOnlineMetadata(_filesNeedingReview);
      
      if (!mounted) return;
      
      // Force reload library to update UI state
      await _loadLibrary();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processed $processedCount files with online metadata.'),
        ),
      );
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
    ? FloatingActionButton.extended(
        onPressed: _scanDirectory,
        icon: const Icon(Icons.add),
        label: const Text('Scan Directory'),
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