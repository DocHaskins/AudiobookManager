// lib/screens/library_screen.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import '../widgets/audiobook_grid_item.dart';
import '../widgets/audiobook_list_item.dart';
import '../widgets/collection_grid_item.dart';
import '../widgets/collection_detail_view.dart';
import '../widgets/audiobook_detail_view.dart';

class LibraryScreen extends StatefulWidget {
  final LibraryManager libraryManager;
  final CollectionManager collectionManager;

  const LibraryScreen({
    Key? key,
    required this.libraryManager,
    required this.collectionManager,
  }) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // View states
  bool _showCollections = false;
  bool _isGridView = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  
  // Navigation stack
  final List<Widget> _navigationStack = [];
  
  // Filtered data
  List<AudiobookFile> _filteredBooks = [];
  List<Collection> _filteredCollections = [];

  @override
  void initState() {
    super.initState();
    _updateFilteredData();
    
    // Listen to library changes
    widget.libraryManager.libraryChanged.listen((_) {
      if (mounted) {
        setState(() {
          _updateFilteredData();
        });
      }
    });
    
    // Listen to collection changes
    widget.collectionManager.collectionsChanged.listen((_) {
      if (mounted) {
        setState(() {
          _updateFilteredData();
        });
      }
    });
  }

  void _updateFilteredData() {
    if (_showCollections) {
      _filteredCollections = widget.collectionManager.collections
          .where((collection) {
            final matchesSearch = collection.name.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesCategory = _selectedCategory == 'All' || 
                collection.type.toString().contains(_selectedCategory.toLowerCase());
            return matchesSearch && matchesCategory;
          })
          .toList();
    } else {
      _filteredBooks = widget.libraryManager.files
          .where((book) {
            final metadata = book.metadata;
            if (metadata == null) return false;
            
            final matchesSearch = metadata.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                metadata.authorsFormatted.toLowerCase().contains(_searchQuery.toLowerCase());
            
            final matchesCategory = _selectedCategory == 'All' ||
                (_selectedCategory == 'Favorites' && metadata.isFavorite) ||
                metadata.categories.any((cat) => cat.contains(_selectedCategory));
            
            return matchesSearch && matchesCategory;
          })
          .toList();
    }
  }

  void _navigateToDetail(Widget detailView) {
    setState(() {
      _navigationStack.add(detailView);
    });
  }

  void _navigateBack() {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _navigationStack.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 280,
            color: const Color(0xFF000000),
            child: _buildSidebar(),
          ),
          
          // Main Content Area
          Expanded(
            child: Container(
              color: const Color(0xFF121212),
              child: _navigationStack.isEmpty
                  ? _buildMainContent()
                  : _buildDetailContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        // Logo/App Name
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(
                Icons.headphones,
                color: Theme.of(context).primaryColor,
                size: 32,
              ),
              const SizedBox(width: 12),
              const Text(
                'Audiobooks',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search ${_showCollections ? "collections" : "books"}...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _updateFilteredData();
                });
              },
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // View Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleButton(
                    'Books',
                    !_showCollections,
                    () => setState(() {
                      _showCollections = false;
                      _updateFilteredData();
                    }),
                  ),
                ),
                Expanded(
                  child: _buildToggleButton(
                    'Collections',
                    _showCollections,
                    () => setState(() {
                      _showCollections = true;
                      _updateFilteredData();
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Categories/Filters
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCategoryItem('All', Icons.library_books),
              if (!_showCollections) ...[
                _buildCategoryItem('Favorites', Icons.favorite),
                _buildCategoryItem('Recently Added', Icons.new_releases),
                _buildCategoryItem('In Progress', Icons.play_circle_outline),
                const Divider(color: Color(0xFF2A2A2A), height: 32),
                _buildSectionTitle('GENRES'),
                _buildCategoryItem('Fiction', Icons.auto_stories),
                _buildCategoryItem('Non-Fiction', Icons.menu_book),
                _buildCategoryItem('Mystery', Icons.search),
                _buildCategoryItem('Sci-Fi', Icons.rocket_launch),
              ] else ...[
                _buildCategoryItem('Series', Icons.collections_bookmark),
                _buildCategoryItem('Custom', Icons.folder_special),
                _buildCategoryItem('Author', Icons.person),
              ],
            ],
          ),
        ),
        
        // Bottom Stats
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey[800]!),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _showCollections
                    ? '${_filteredCollections.length} Collections'
                    : '${_filteredBooks.length} Books',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              if (!_showCollections)
                Text(
                  '${_calculateTotalDuration()}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String title, IconData icon) {
    final isSelected = _selectedCategory == title;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = title;
          _updateFilteredData();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A2A2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Header with view toggle
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Text(
                _showCollections ? 'Collections' : 'Library',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // View Toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.grid_view,
                        color: _isGridView ? Theme.of(context).primaryColor : Colors.grey[600],
                      ),
                      onPressed: () => setState(() => _isGridView = true),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.view_list,
                        color: !_isGridView ? Theme.of(context).primaryColor : Colors.grey[600],
                      ),
                      onPressed: () => setState(() => _isGridView = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: _showCollections
              ? _buildCollectionsView()
              : _buildBooksView(),
        ),
      ],
    );
  }

  Widget _buildDetailContent() {
    return Column(
      children: [
        // Navigation Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _navigateBack,
              ),
              const SizedBox(width: 16),
              const Text(
                'Back',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        
        // Detail Content
        Expanded(
          child: _navigationStack.last,
        ),
      ],
    );
  }

  Widget _buildBooksView() {
    if (_filteredBooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'No books found',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return _isGridView
        ? GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 0.7,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: _filteredBooks.length,
            itemBuilder: (context, index) {
              final book = _filteredBooks[index];
              return AudiobookGridItem(
                book: book,
                onTap: () => _navigateToDetail(
                  AudiobookDetailView(
                    book: book,
                    libraryManager: widget.libraryManager,
                  ),
                ),
              );
            },
          )
        : ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _filteredBooks.length,
            itemBuilder: (context, index) {
              final book = _filteredBooks[index];
              return AudiobookListItem(
                book: book,
                onTap: () => _navigateToDetail(
                  AudiobookDetailView(
                    book: book,
                    libraryManager: widget.libraryManager,
                  ),
                ),
              );
            },
          );
  }

  Widget _buildCollectionsView() {
    if (_filteredCollections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.collections_bookmark,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'No collections found',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _filteredCollections.length,
      itemBuilder: (context, index) {
        final collection = _filteredCollections[index];
        final books = widget.libraryManager.getBooksForCollection(collection);
        return CollectionGridItem(
          collection: collection,
          books: books,
          onTap: () => _navigateToDetail(
            CollectionDetailView(
              collection: collection,
              books: books,
              libraryManager: widget.libraryManager,
              collectionManager: widget.collectionManager,
              onBookTap: (book) => _navigateToDetail(
                AudiobookDetailView(
                  book: book,
                  libraryManager: widget.libraryManager,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _calculateTotalDuration() {
    Duration total = Duration.zero;
    for (final book in _filteredBooks) {
      if (book.metadata?.audioDuration != null) {
        total += book.metadata!.audioDuration!;
      }
    }
    
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '$hours hours, $minutes minutes';
    } else {
      return '$minutes minutes';
    }
  }
}