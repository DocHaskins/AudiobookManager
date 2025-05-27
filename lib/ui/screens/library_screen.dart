import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/ui/widgets/library/library_sidebar.dart';
import 'package:audiobook_organizer/ui/widgets/library/library_content.dart';
import 'package:audiobook_organizer/ui/widgets/settings_content.dart';
import 'package:audiobook_organizer/utils/library_filter_utils.dart';

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
  SortOption _selectedSortOption = SortOption.title;
  
  // Navigation stack
  final List<Widget> _navigationStack = [];
  
  // Filtered data
  List<AudiobookFile> _filteredBooks = [];
  List<Collection> _filteredCollections = [];
  
  // Dynamic categories with counts
  Map<String, int> _availableGenres = {};
  Map<String, int> _availableAuthors = {};

  @override
  void initState() {
    super.initState();
    _updateCategories();
    _updateFilteredData();
    
    // Listen to library changes
    widget.libraryManager.libraryChanged.listen((_) {
      if (mounted) {
        setState(() {
          _updateCategories();
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

  void _updateCategories() {
    _availableGenres = LibraryFilterUtils.extractGenresWithCounts(
      widget.libraryManager.files
    );
    _availableAuthors = LibraryFilterUtils.extractAuthorsWithCounts(
      widget.libraryManager.files
    );
  }

  void _updateFilteredData() {
    if (_showCollections) {
      _filteredCollections = LibraryFilterUtils.filterCollections(
        widget.collectionManager.collections,
        searchQuery: _searchQuery,
        selectedCategory: _selectedCategory,
      );
    } else {
      _filteredBooks = LibraryFilterUtils.filterBooks(
        widget.libraryManager.files,
        searchQuery: _searchQuery,
        selectedCategory: _selectedCategory,
        sortOption: _selectedSortOption,
      );
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

  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
      if (_showSettings) {
        _searchQuery = '';
        _selectedCategory = 'All';
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _updateFilteredData();
    });
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
      _updateFilteredData();
    });
  }

  void _onSortOptionChanged(SortOption sortOption) {
    setState(() {
      _selectedSortOption = sortOption;
      _updateFilteredData();
    });
  }

  void _onViewToggle(bool isGridView) {
    setState(() {
      _isGridView = isGridView;
    });
  }

  void _onShowCollectionsToggle(bool showCollections) {
    setState(() {
      _showCollections = showCollections;
      _updateFilteredData();
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
            child: LibrarySidebar(
              showSettings: _showSettings,
              showCollections: _showCollections,
              searchQuery: _searchQuery,
              selectedCategory: _selectedCategory,
              selectedSortOption: _selectedSortOption,
              availableGenres: _availableGenres,
              availableAuthors: _availableAuthors,
              filteredBooks: _filteredBooks,
              filteredCollections: _filteredCollections,
              onToggleSettings: _toggleSettings,
              onSearchChanged: _onSearchChanged,
              onCategoryChanged: _onCategoryChanged,
              onSortOptionChanged: _onSortOptionChanged,
              onShowCollectionsToggle: _onShowCollectionsToggle,
            ),
          ),
          
          // Main Content Area
          Expanded(
            child: Container(
              color: const Color(0xFF121212),
              child: _showSettings 
                  ? SettingsContent(
                      selectedCategory: _selectedCategory,
                      libraryManager: widget.libraryManager,
                      collectionManager: widget.collectionManager,
                    )
                  : LibraryContent(
                      navigationStack: _navigationStack,
                      showCollections: _showCollections,
                      isGridView: _isGridView,
                      filteredBooks: _filteredBooks,
                      filteredCollections: _filteredCollections,
                      libraryManager: widget.libraryManager,
                      collectionManager: widget.collectionManager,
                      onNavigateToDetail: _navigateToDetail,
                      onNavigateBack: _navigateBack,
                      onViewToggle: _onViewToggle,
                      onToggleFavorite: _toggleFavorite,
                    ),
            ),
          ),
        ],
      ),
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
}