// lib/ui/screens/library_screen.dart - Updated with proper responsive grid for new cards
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/ui/widgets/audiobook_grid_item.dart';
import 'package:audiobook_organizer/ui/widgets/audiobook_list_item.dart';
import 'package:audiobook_organizer/ui/widgets/collection_grid_item.dart';
import 'package:audiobook_organizer/ui/widgets/collection_detail_view.dart';
import 'package:audiobook_organizer/ui/widgets/audiobook_detail_view.dart';
import 'package:audiobook_organizer/ui/screens/settings_screen.dart';

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
  bool _showSettings = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  
  // Navigation stack
  final List<Widget> _navigationStack = [];
  
  // Filtered data
  List<AudiobookFile> _filteredBooks = [];
  List<Collection> _filteredCollections = [];
  
  // Dynamic genres
  List<String> _availableGenres = [];

  @override
  void initState() {
    super.initState();
    _updateGenres();
    _updateFilteredData();
    
    // Listen to library changes
    widget.libraryManager.libraryChanged.listen((_) {
      if (mounted) {
        setState(() {
          _updateGenres();
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

  void _updateGenres() {
    final Set<String> genres = <String>{};
    
    // Extract genres from all books
    for (final book in widget.libraryManager.files) {
      if (book.metadata != null) {
        // Check categories field
        if (book.metadata!.categories.isNotEmpty) {
          for (final category in book.metadata!.categories) {
            final cleanGenre = category.trim();
            if (cleanGenre.isNotEmpty) {
              genres.add(cleanGenre);
            }
          }
        }
        
        // Also check if there are user tags that could be genres
        if (book.metadata!.userTags.isNotEmpty) {
          for (final tag in book.metadata!.userTags) {
            final cleanTag = tag.trim();
            if (cleanTag.isNotEmpty) {
              genres.add(cleanTag);
            }
          }
        }
      }
    }

    // Convert to sorted list
    _availableGenres = genres.toList()..sort();
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
                (_selectedCategory == 'Recently Added' && _isRecentlyAdded(book)) ||
                (_selectedCategory == 'In Progress' && _isInProgress(book)) ||
                metadata.categories.any((cat) => cat.trim() == _selectedCategory);
            
            return matchesSearch && matchesCategory;
          })
          .toList();
    }
  }

  bool _isRecentlyAdded(AudiobookFile book) {
    // Check if book was added in the last 30 days
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    // You might need to adjust this based on how you track when books were added
    // For now, we'll use file modification time as a proxy
    try {
      final file = File(book.path);
      final lastModified = file.lastModifiedSync();
      return lastModified.isAfter(thirtyDaysAgo);
    } catch (e) {
      return false;
    }
  }

  bool _isInProgress(AudiobookFile book) {
    // Check if the book has been started but not finished
    final metadata = book.metadata;
    if (metadata?.playbackPosition != null && metadata!.audioDuration != null) {
      final progress = metadata.playbackPosition!.inMilliseconds / metadata.audioDuration!.inMilliseconds;
      return progress > 0.01 && progress < 0.95; // Started but not nearly finished
    }
    return false;
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

  // NEW: Toggle settings mode
  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
      if (_showSettings) {
        // Reset other states when entering settings
        _searchQuery = '';
        _selectedCategory = 'All';
      }
    });
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
            child: _showSettings ? _buildSettingsSidebar() : _buildSidebar(),
          ),
          
          // Main Content Area
          Expanded(
            child: Container(
              color: const Color(0xFF121212),
              child: _showSettings 
                  ? _buildSettingsContent()
                  : (_navigationStack.isEmpty
                      ? _buildMainContent()
                      : _buildDetailContent()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        // Logo/App Name with Settings Icon
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
              const Expanded(
                child: Text(
                  'Audiobooks',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // NEW: Settings Icon
              IconButton(
                icon: const Icon(
                  Icons.settings,
                  color: Colors.white70,
                  size: 24,
                ),
                onPressed: _toggleSettings,
                tooltip: 'Settings',
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryItem('All', Icons.library_books),
                if (!_showCollections) ...[
                  _buildCategoryItem('Favorites', Icons.favorite),
                  _buildCategoryItem('Recently Added', Icons.new_releases),
                  _buildCategoryItem('In Progress', Icons.play_circle_outline),
                  if (_availableGenres.isNotEmpty) ...[
                    const Divider(color: Color(0xFF2A2A2A), height: 32),
                    _buildSectionTitle('GENRES'),
                    // Scrollable genre list
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4, // Max 40% of screen height
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _availableGenres.length,
                        itemBuilder: (context, index) {
                          final genre = _availableGenres[index];
                          return _buildCategoryItem(
                            genre,
                            _getGenreIcon(genre),
                          );
                        },
                      ),
                    ),
                  ],
                ] else ...[
                  _buildCategoryItem('Series', Icons.collections_bookmark),
                  _buildCategoryItem('Custom', Icons.folder_special),
                  _buildCategoryItem('Author', Icons.person),
                ],
                // Add some bottom padding to ensure last item is visible
                const SizedBox(height: 16),
              ],
            ),
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
                  _calculateTotalDuration(),
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

  // NEW: Settings Sidebar
  Widget _buildSettingsSidebar() {
    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white70,
                  size: 24,
                ),
                onPressed: _toggleSettings,
              ),
              const SizedBox(width: 8),
              const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Settings Categories
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingsCategoryItem('Library', Icons.library_books, 'Library'),
                _buildSettingsCategoryItem('Theme', Icons.palette, 'Theme'),
                _buildSettingsCategoryItem('Collections', Icons.collections_bookmark, 'Collections'),
                _buildSettingsCategoryItem('Playback', Icons.play_circle, 'Playback'),
                _buildSettingsCategoryItem('Storage', Icons.storage, 'Storage'),
                _buildSettingsCategoryItem('About', Icons.info_outline, 'About'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // NEW: Settings category item
  Widget _buildSettingsCategoryItem(String title, IconData icon, String category) {
    final isSelected = _selectedCategory == category;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A2A2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400],
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Settings Content
  Widget _buildSettingsContent() {
    return SettingsPanel(
      selectedCategory: _selectedCategory,
      libraryManager: widget.libraryManager,
      collectionManager: widget.collectionManager,
    );
  }

  IconData _getGenreIcon(String genre) {
    // Map common genres to appropriate icons
    final genreMap = {
      'fiction': Icons.auto_stories,
      'non-fiction': Icons.menu_book,
      'mystery': Icons.search,
      'sci-fi': Icons.rocket_launch,
      'science fiction': Icons.rocket_launch,
      'fantasy': Icons.castle,
      'romance': Icons.favorite,
      'thriller': Icons.flash_on,
      'horror': Icons.warning,
      'biography': Icons.person,
      'autobiography': Icons.person,
      'history': Icons.history_edu,
      'business': Icons.business,
      'self-help': Icons.psychology,
      'health': Icons.health_and_safety,
      'cooking': Icons.restaurant,
      'travel': Icons.flight,
      'technology': Icons.computer,
      'science': Icons.science,
      'philosophy': Icons.psychology_alt,
      'religion': Icons.church,
      'spirituality': Icons.spa,
      'true crime': Icons.gavel,
      'comedy': Icons.sentiment_very_satisfied,
      'drama': Icons.theater_comedy,
      'adventure': Icons.explore,
      'children': Icons.child_care,
      'young adult': Icons.school,
      'classic': Icons.library_books,
      'poetry': Icons.format_quote,
    };

    final lowerGenre = genre.toLowerCase();
    return genreMap[lowerGenre] ?? Icons.category;
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

    // Check _isGridView to determine which view to show
    if (_isGridView) {
      return _buildGridView();
    } else {
      return _buildListView();
    }
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // TRULY FIXED: Static card dimensions - absolutely no resizing!
        const double cardWidth = 200.0;   // LOCKED width
        const double cardHeight = 400.0;  // LOCKED height  
        const double spacing = 24.0;      // LOCKED spacing
        
        // Calculate how many FIXED-SIZE cards fit across the available width
        final availableWidth = constraints.maxWidth - (spacing * 2); // Account for padding
        final int crossAxisCount = (availableWidth / (cardWidth + spacing))
            .floor()
            .clamp(1, 10);
        
        // Calculate the actual width used by the grid
        final double gridWidth = (crossAxisCount * cardWidth) + ((crossAxisCount - 1) * spacing);
        
        return Center(
          child: Container(
            width: gridWidth + (spacing * 2), // Add padding
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GridView.builder(
                // FIXED: Custom delegate with absolutely fixed dimensions
                gridDelegate: _FixedSizeGridDelegate(
                  crossAxisCount: crossAxisCount,
                  itemWidth: cardWidth,
                  itemHeight: cardHeight,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                ),
                itemCount: _filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = _filteredBooks[index];
                  return SizedBox(
                    width: cardWidth,  // Force exact width
                    height: cardHeight, // Force exact height
                    child: AudiobookGridItem(
                      book: book,
                      onTap: () => _navigateToDetail(
                        AudiobookDetailView(
                          book: book,
                          libraryManager: widget.libraryManager,
                        ),
                      ),
                      onFavoriteTap: () => _toggleFavorite(book),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
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
          //onFavoriteTap: () => _toggleFavorite(book),
        );
      },
    );
  }

  Future<void> _toggleFavorite(AudiobookFile book) async {
    if (book.metadata != null) {
      final success = await widget.libraryManager.updateUserData(
        book,
        isFavorite: !book.metadata!.isFavorite,
      );
      
      if (success) {
        setState(() {
          _updateFilteredData();
        });
      }
    }
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Simple calculation for collection grid: fixed item width
        const double itemWidth = 200;  // Fixed width for each collection
        const double spacing = 20;
        
        // Calculate how many items fit across the width
        final int crossAxisCount = ((constraints.maxWidth + spacing) / (itemWidth + spacing)).floor().clamp(1, 20);
        
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100), // Keep bottom padding for mini-player
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount, // Now responsive!
            childAspectRatio: 0.8, // Slightly taller for collections
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
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

// Custom grid delegate that enforces absolutely fixed item sizes
class _FixedSizeGridDelegate extends SliverGridDelegate {
  final int crossAxisCount;
  final double itemWidth;
  final double itemHeight;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const _FixedSizeGridDelegate({
    required this.crossAxisCount,
    required this.itemWidth,
    required this.itemHeight,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: itemHeight + mainAxisSpacing,
      crossAxisStride: itemWidth + crossAxisSpacing,
      childMainAxisExtent: itemHeight,
      childCrossAxisExtent: itemWidth,
      reverseCrossAxis: false,
    );
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegate oldDelegate) {
    if (oldDelegate is! _FixedSizeGridDelegate) return true;
    return crossAxisCount != oldDelegate.crossAxisCount ||
           itemWidth != oldDelegate.itemWidth ||
           itemHeight != oldDelegate.itemHeight ||
           crossAxisSpacing != oldDelegate.crossAxisSpacing ||
           mainAxisSpacing != oldDelegate.mainAxisSpacing;
  }
}