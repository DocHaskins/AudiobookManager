// lib/ui/widgets/library/library_content_view.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/ui/widgets/library/library_books_view.dart';
import 'package:audiobook_organizer/ui/widgets/library/library_collections_view.dart';
import 'package:audiobook_organizer/utils/library_filter_utils.dart';

class LibraryContentView extends StatefulWidget {
  final LibraryManager libraryManager;
  final CollectionManager collectionManager;
  final AudioPlayerService playerService;
  final String currentSubsection;
  
  // Add parameters for sidebar state
  final String searchQuery;
  final SortOption sortOption;
  final bool showCollections;
  final bool isReversed;

  const LibraryContentView({
    Key? key,
    required this.libraryManager,
    required this.collectionManager,
    required this.playerService,
    required this.currentSubsection,
    this.searchQuery = '',
    this.sortOption = SortOption.title,
    this.showCollections = false,
    this.isReversed = false,
  }) : super(key: key);

  @override
  State<LibraryContentView> createState() => _LibraryContentViewState();
}

class _LibraryContentViewState extends State<LibraryContentView> {
  // View states - now driven by sidebar
  bool _isGridView = true;
  
  // Navigation stack for detail views
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

  @override
  void didUpdateWidget(LibraryContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update filtered data when any sidebar-controlled parameter changes
    if (oldWidget.currentSubsection != widget.currentSubsection ||
        oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.sortOption != widget.sortOption ||
        oldWidget.showCollections != widget.showCollections ||
        oldWidget.isReversed != widget.isReversed) {
      setState(() {
        _updateFilteredData();
      });
    }
  }

  void _updateFilteredData() {
    if (widget.showCollections) {
      _filteredCollections = LibraryFilterUtils.filterCollections(
        widget.collectionManager.collections,
        searchQuery: widget.searchQuery,
        selectedCategory: widget.currentSubsection,
      );
    } else {
      _filteredBooks = LibraryFilterUtils.filterBooks(
        widget.libraryManager.files,
        searchQuery: widget.searchQuery,
        selectedCategory: widget.currentSubsection,
        sortOption: widget.sortOption,
        isReversed: widget.isReversed,
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

  void _onViewToggle(bool isGridView) {
    setState(() {
      _isGridView = isGridView;
    });
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main library content - always present to preserve scroll position
        _buildMainContent(context),
        
        // Detail view overlay - only visible when navigation stack is not empty
        if (_navigationStack.isNotEmpty) _buildDetailOverlay(),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: widget.showCollections
              ? LibraryCollectionsView(
                  collections: _filteredCollections,
                  libraryManager: widget.libraryManager,
                  collectionManager: widget.collectionManager,
                  onNavigateToDetail: _navigateToDetail,
                )
              : LibraryBooksView(
                  books: _filteredBooks,
                  isGridView: _isGridView,
                  libraryManager: widget.libraryManager,
                  onNavigateToDetail: _navigateToDetail,
                  onToggleFavorite: _toggleFavorite,
                ),
        ),
      ],
    );
  }

  Widget _buildDetailOverlay() {
    return Container(
      color: const Color(0xFF121212), // Same background as main content
      child: Column(
        children: [
          // Back button header
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
          // Detail content
          Expanded(
            child: _navigationStack.last,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Text(
            _getHeaderTitle(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // View toggle buttons
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const VerticalDivider(color: Color(0xFF404040), width: 1),
                if (!widget.showCollections) ...[
                  IconButton(
                    icon: Icon(
                      Icons.grid_view,
                      color: _isGridView ? Theme.of(context).primaryColor : Colors.grey[600],
                    ),
                    onPressed: () => _onViewToggle(true),
                    tooltip: 'Grid View',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.view_list,
                      color: !_isGridView ? Theme.of(context).primaryColor : Colors.grey[600],
                    ),
                    onPressed: () => _onViewToggle(false),
                    tooltip: 'List View',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getHeaderTitle() {
    if (widget.showCollections) {
      switch (widget.currentSubsection) {
        case 'Series':
          return 'Series Collections';
        case 'Custom':
          return 'Custom Collections';
        case 'Author':
          return 'Author Collections';
        default:
          return 'All Collections';
      }
    } else {
      switch (widget.currentSubsection) {
        case 'Favorites':
          return 'Favorite Books';
        case 'Recently Added':
          return 'Recently Added';
        case 'In Progress':
          return 'In Progress';
        case 'All':
          return 'All Books';
        default:
          // Check if it's a genre or author
          final genres = LibraryFilterUtils.extractGenresWithCounts(widget.libraryManager.files);
          final authors = LibraryFilterUtils.extractAuthorsWithCounts(widget.libraryManager.files);
          
          if (genres.containsKey(widget.currentSubsection)) {
            return '${widget.currentSubsection} Books';
          } else if (authors.containsKey(widget.currentSubsection)) {
            return 'Books by ${widget.currentSubsection}';
          }
          return widget.currentSubsection;
      }
    }
  }
}