// File: lib/ui/screens/library_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/audiobook_scanner.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/ui/screens/detail_view.dart';
import 'package:audiobook_organizer/ui/screens/batch_organize_view.dart';
import 'package:audiobook_organizer/ui/debug/debug_tools_menu.dart';
import 'package:audiobook_organizer/storage/library_storage.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/ui/widgets/library_sidebar.dart';
import 'package:audiobook_organizer/ui/widgets/book_grid_item.dart';
import 'package:audiobook_organizer/ui/widgets/book_list_item.dart';
import 'package:audiobook_organizer/ui/widgets/collection_grid_item.dart';
import 'package:audiobook_organizer/ui/widgets/collection_list_item.dart';
import 'package:audiobook_organizer/ui/dialogs/library_dialogs.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({Key? key}) : super(key: key);

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  // Library data
  List<AudiobookFile> _individualAudiobooks = [];
  List<AudiobookCollection> _audiobookCollections = [];
  
  // UI state
  bool _isLoading = true;
  bool _isGridView = true;
  double _gridItemSize = 180; // Default grid item size
  
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
    _loadSavedLibrary();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLibrary() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final libraryStorage = Provider.of<LibraryStorage>(context, listen: false);
      final libraryData = await libraryStorage.loadLibrary();
      
      setState(() {
        _individualAudiobooks = libraryData['audiobooks'];
        _audiobookCollections = libraryData['collections'];
        _isLoading = false;
        
        // Extract available genres from metadata
        _extractGenres();
      });
      
      print('LOG: Loaded ${_individualAudiobooks.length} audiobooks and ${_audiobookCollections.length} collections from storage');
    } catch (e) {
      print('ERROR: Failed to load library: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading saved library: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Extract all available genres from book metadata
  void _extractGenres() {
    Set<String> genres = {'All'};
    
    // Add genres from individual books
    for (var book in _individualAudiobooks) {
      if (book.metadata?.categories.isNotEmpty ?? false) {
        genres.addAll(book.metadata!.categories);
      }
    }
    
    // Add genres from collections
    for (var collection in _audiobookCollections) {
      if (collection.metadata?.categories.isNotEmpty ?? false) {
        genres.addAll(collection.metadata!.categories);
      }
    }
    
    _availableGenres = genres.toList()..sort();
  }
  
  // Filter items based on selected genre, collection filter, and search query
  List<dynamic> _getFilteredItems() {
    List<dynamic> items = [];
    
    // Start with collections if not filtered out
    if (!_showCollectionsOnly) {
      items.addAll(_audiobookCollections);
    }
    
    // Add individual books
    items.addAll(_individualAudiobooks);
    
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
    
    // Apply collection filter
    if (_showCollectionsOnly) {
      items = items.where((item) => item is AudiobookCollection).toList();
    }
    
    // Apply search query if not empty
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        if (item is AudiobookFile) {
          return _matchesSearch(item.displayName) || 
                 _matchesSearch(item.author);
        } else if (item is AudiobookCollection) {
          return _matchesSearch(item.displayName) || 
                 _matchesSearch(item.author);
        }
        return false;
      }).toList();
    }
    
    return items;
  }
  
  bool _matchesSearch(String text) {
    return text.toLowerCase().contains(_searchQuery.toLowerCase());
  }
  
  // Save library changes
  Future<void> _saveLibrary() async {
    try {
      final libraryStorage = Provider.of<LibraryStorage>(context, listen: false);
      await libraryStorage.saveLibrary(_individualAudiobooks, _audiobookCollections);
      print('LOG: Library saved successfully');
    } catch (e) {
      print('ERROR: Failed to save library: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving library: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Open scan directory dialog
  Future<void> _scanDirectory() async {
    final String? directory = await getDirectoryPath();
    if (directory == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final scanner = Provider.of<AudiobookScanner>(context, listen: false);
      
      // Use the scanAndGroupFiles method
      final bookGroups = await scanner.scanAndGroupFiles(directory);
      
      // Process each group
      bookGroups.forEach((title, files) {
        if (files.length > 1) {
          // Create a collection for multi-file books
          final collection = AudiobookCollection.fromFiles(files, title);
          collection.sortFiles(); // Sort by chapter number
          _audiobookCollections.add(collection);
        } else if (files.length == 1) {
          // Add single files to the individual list
          _individualAudiobooks.add(files.first);
        }
      });
      
      // Extract genres from new books
      _extractGenres();
      
      // Save the library
      await _saveLibrary();
      
      setState(() {
        _isLoading = false;
      });
      
      // Show result message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added audiobooks from: $directory'),
          ),
        );
      }
    } catch (e) {
      print('ERROR: Error scanning directory: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning directory: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Open book details view
  void _openBookDetails(AudiobookFile book) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetailView(audiobook: book),
      ),
    );
    
    if (result == true) {
      // Refresh library if changes were made
      setState(() {});
      await _saveLibrary();
    }
  }
  
  // Open collection details dialog
  void _openCollectionDetails(AudiobookCollection collection) async {
    // Implemented in LibraryDialogs
    final result = await LibraryDialogs.showCollectionDetailsDialog(
      context: context, 
      collection: collection,
    );
    
    if (result != null) {
      // Handle collection action results
      setState(() {
        // Process result and update UI
      });
      await _saveLibrary();
    }
  }
  
  // Find metadata for books without metadata
  Future<void> _matchPendingMetadata() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final matcher = Provider.of<MetadataMatcher>(context, listen: false);
      int matchedCount = 0;
      
      // Match individual books
      for (final book in _individualAudiobooks.where((b) => !b.hasMetadata).toList()) {
        final metadata = await matcher.matchFile(book);
        if (metadata != null) {
          final index = _individualAudiobooks.indexWhere((b) => b.path == book.path);
          if (index >= 0) {
            setState(() {
              _individualAudiobooks[index] = AudiobookFile(
                path: book.path,
                filename: book.filename,
                extension: book.extension,
                size: book.size,
                lastModified: book.lastModified,
                metadata: metadata,
              );
            });
            matchedCount++;
          }
        }
      }
      
      // Match collections
      for (final collection in _audiobookCollections.where((c) => !c.hasMetadata).toList()) {
        if (collection.files.isNotEmpty) {
          final metadata = await matcher.matchFile(collection.files.first);
          if (metadata != null) {
            final index = _audiobookCollections.indexWhere(
              (c) => c.files.isNotEmpty && c.files.first.path == collection.files.first.path);
            if (index >= 0) {
              setState(() {
                _audiobookCollections[index].updateMetadata(metadata);
              });
              matchedCount++;
            }
          }
        }
      }
      
      // Extract updated genres
      _extractGenres();
      
      // Save the library
      await _saveLibrary();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found metadata for $matchedCount items'),
          ),
        );
      }
    } catch (e) {
      print('ERROR: Error matching metadata: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding metadata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final items = _getFilteredItems();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AudioBook Organizer'),
        actions: [
          // Search widget
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
                fillColor: Colors.white.withOpacity(0.2),
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
          
          // Grid/List view toggle
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: 'Toggle view',
          ),
          
          // Menu button with more options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.pushNamed(context, '/settings');
                  break;
                case 'match':
                  _matchPendingMetadata();
                  break;
                case 'organize':
                  _openBatchOrganize();
                  break;
                case 'stats':
                  _showLibraryStats();
                  break;
                case 'clear':
                  _confirmClearLibrary();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'match',
                child: ListTile(
                  leading: Icon(Icons.search),
                  title: Text('Match Pending Metadata'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'organize',
                child: ListTile(
                  leading: Icon(Icons.folder),
                  title: Text('Batch Organize'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'stats',
                child: ListTile(
                  leading: Icon(Icons.bar_chart),
                  title: Text('Library Statistics'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('Clear Library'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildLibraryLayout(items),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanDirectory,
        icon: const Icon(Icons.add),
        label: const Text('Scan Directory'),
      ),
    );
  }
  
  Widget _buildLibraryLayout(List<dynamic> items) {
    // If library is empty, show empty state
    if (_individualAudiobooks.isEmpty && _audiobookCollections.isEmpty) {
      return _buildEmptyState();
    }
    
    return Row(
      children: [
        // Left sidebar
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
        
        // Main content area
        Expanded(
          child: _isGridView
              ? _buildGridView(items)
              : _buildListView(items),
        ),
      ],
    );
  }
  
  Widget _buildGridView(List<dynamic> items) {
    // Calculate grid dimensions based on item size
    final crossAxisCount = (MediaQuery.of(context).size.width - 260) ~/ _gridItemSize;
    
    return items.isEmpty
        ? const Center(child: Text('No items match the selected filters'))
        : GridView.builder(
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
                  onLongPress: () => _showBookContextMenu(item),
                );
              } else if (item is AudiobookCollection) {
                return CollectionGridItem(
                  collection: item,
                  onTap: () => _openCollectionDetails(item),
                  onLongPress: () => _showCollectionContextMenu(item),
                );
              }
              return const SizedBox();
            },
          );
  }
  
  Widget _buildListView(List<dynamic> items) {
    return items.isEmpty
        ? const Center(child: Text('No items match the selected filters'))
        : ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is AudiobookFile) {
                return BookListItem(
                  book: item,
                  onTap: () => _openBookDetails(item),
                  onLongPress: () => _showBookContextMenu(item),
                );
              } else if (item is AudiobookCollection) {
                return CollectionListItem(
                  collection: item,
                  onTap: () => _openCollectionDetails(item),
                  onLongPress: () => _showCollectionContextMenu(item),
                );
              }
              return const SizedBox();
            },
          );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.audiotrack, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No audiobooks found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add audiobooks by scanning a directory',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _scanDirectory,
            icon: const Icon(Icons.folder_open),
            label: const Text('Select Directory'),
          ),
        ],
      ),
    );
  }
  
  // Show context menu for a book
  void _showBookContextMenu(AudiobookFile book) {
    // Implementation moved to LibraryDialogs class
    LibraryDialogs.showBookContextMenu(
      context: context,
      book: book,
      collections: _audiobookCollections,
      onAddToCollection: (collection) {
        _addBookToCollection(book, collection);
      },
      onCreateCollection: (name) {
        _createCollectionWithBook(name, book);
      },
      onFindMetadata: () {
        _findMetadataForBook(book);
      },
      onRemove: () {
        _removeBookFromLibrary(book);
      },
    );
  }
  
  // Show context menu for a collection
  void _showCollectionContextMenu(AudiobookCollection collection) {
    // Implementation moved to LibraryDialogs class
    LibraryDialogs.showCollectionContextMenu(
      context: context,
      collection: collection,
      onFindMetadata: () {
        _findMetadataForCollection(collection);
      },
      onApplyMetadata: () {
        if (collection.metadata != null) {
          _applyMetadataToCollection(collection, collection.metadata!);
        }
      },
      onRename: (newName) {
        _renameCollection(collection, newName);
      },
      onRemove: (keepFiles) {
        _removeCollectionFromLibrary(collection, keepFiles);
      },
    );
  }
  
  // Add book to collection
  Future<void> _addBookToCollection(AudiobookFile book, AudiobookCollection collection) async {
    setState(() {
      _individualAudiobooks.removeWhere((b) => b.path == book.path);
      collection.files.add(book);
    });
    
    await _saveLibrary();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "${book.displayName}" to collection "${collection.displayName}"')),
    );
  }
  
  // Create new collection with a book
  Future<void> _createCollectionWithBook(String name, AudiobookFile book) async {
    final collection = AudiobookCollection(
      title: name,
      files: [book],
      metadata: book.metadata,
    );
    
    setState(() {
      _individualAudiobooks.removeWhere((b) => b.path == book.path);
      _audiobookCollections.add(collection);
    });
    
    await _saveLibrary();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created collection "$name" with "${book.displayName}"')),
    );
  }
  
  // Find metadata for a book
  Future<void> _findMetadataForBook(AudiobookFile book) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final matcher = Provider.of<MetadataMatcher>(context, listen: false);
      final metadata = await matcher.matchFile(book);
      
      if (metadata != null) {
        setState(() {
          final index = _individualAudiobooks.indexWhere((b) => b.path == book.path);
          if (index >= 0) {
            _individualAudiobooks[index] = AudiobookFile(
              path: book.path,
              filename: book.filename,
              extension: book.extension,
              size: book.size,
              lastModified: book.lastModified,
              metadata: metadata,
            );
          }
        });
        
        await _saveLibrary();
        _extractGenres();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found metadata for "${metadata.title}"')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching metadata found')),
        );
      }
    } catch (e) {
      print('ERROR: Failed to find metadata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding metadata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Remove book from library
  Future<void> _removeBookFromLibrary(AudiobookFile book) async {
    setState(() {
      _individualAudiobooks.removeWhere((b) => b.path == book.path);
    });
    
    await _saveLibrary();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed "${book.displayName}" from library')),
    );
  }
  
  // Find metadata for a collection
  Future<void> _findMetadataForCollection(AudiobookCollection collection) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final matcher = Provider.of<MetadataMatcher>(context, listen: false);
      
      if (collection.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collection has no files')),
        );
        return;
      }
      
      final metadata = await matcher.matchFile(collection.files.first);
      
      if (metadata != null) {
        setState(() {
          final index = _audiobookCollections.indexWhere((c) => c == collection);
          if (index >= 0) {
            _audiobookCollections[index].updateMetadata(metadata);
          }
        });
        
        await _saveLibrary();
        _extractGenres();
        
        // Ask if we should apply metadata to all files
        LibraryDialogs.showApplyMetadataDialog(
          context: context,
          metadata: metadata,
          fileCount: collection.fileCount,
          onApply: () {
            _applyMetadataToCollection(collection, metadata);
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching metadata found')),
        );
      }
    } catch (e) {
      print('ERROR: Failed to find metadata for collection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding metadata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Apply metadata to all files in a collection
  Future<void> _applyMetadataToCollection(AudiobookCollection collection, AudiobookMetadata metadata) async {
    setState(() {
      collection.updateMetadata(metadata);
      
      for (int i = 0; i < collection.files.length; i++) {
        final file = collection.files[i];
        collection.files[i] = AudiobookFile(
          path: file.path,
          filename: file.filename,
          extension: file.extension,
          size: file.size,
          lastModified: file.lastModified,
          metadata: metadata,
        );
      }
    });
    
    await _saveLibrary();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied metadata to all ${collection.files.length} files in collection')),
    );
  }
  
  // Rename a collection
  Future<void> _renameCollection(AudiobookCollection collection, String newName) async {
    setState(() {
      final index = _audiobookCollections.indexWhere((c) => c == collection);
      if (index >= 0) {
        _audiobookCollections[index] = AudiobookCollection(
          title: newName,
          files: collection.files,
          directoryPath: collection.directoryPath,
          metadata: collection.metadata,
        );
      }
    });
    
    await _saveLibrary();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Renamed collection to "$newName"')),
    );
  }
  
  // Remove collection from library
  Future<void> _removeCollectionFromLibrary(AudiobookCollection collection, bool keepFiles) async {
    final files = List<AudiobookFile>.from(collection.files);
    
    setState(() {
      _audiobookCollections.removeWhere((c) => c == collection);
      
      if (keepFiles) {
        _individualAudiobooks.addAll(files);
      }
    });
    
    await _saveLibrary();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted collection "${collection.displayName}"')),
    );
  }
  
  // Show library statistics
  void _showLibraryStats() {
    LibraryDialogs.showLibraryStats(
      context: context,
      individualBooks: _individualAudiobooks,
      collections: _audiobookCollections,
      genres: _availableGenres,
    );
  }
  
  // Batch organize books
  void _openBatchOrganize() async {
    List<AudiobookFile> allFiles = [..._individualAudiobooks];
    for (var collection in _audiobookCollections) {
      allFiles.addAll(collection.files);
    }
    
    if (allFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files to organize')),
      );
      return;
    }
    
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BatchOrganizeView(audiobooks: allFiles),
      ),
    );
    
    if (result == true) {
      // Refresh the library
      await _loadSavedLibrary();
    }
  }
  
  // Clear library data
  void _confirmClearLibrary() {
    LibraryDialogs.showConfirmClearLibraryDialog(
      context: context,
      onConfirm: () async {
        setState(() {
          _isLoading = true;
        });
        
        try {
          final libraryStorage = Provider.of<LibraryStorage>(context, listen: false);
          await libraryStorage.clearLibrary();
          
          final metadataCache = Provider.of<MetadataCache>(context, listen: false);
          await metadataCache.clearCache();
          
          setState(() {
            _individualAudiobooks = [];
            _audiobookCollections = [];
            _availableGenres = ['All'];
            _selectedGenre = 'All';
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Library data cleared successfully')),
          );
        } catch (e) {
          print('ERROR: Failed to clear library data: $e');
          
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing library data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }
}