// lib/ui/widgets/library_books_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/ui/widgets/audiobook/audiobook_grid_item.dart';
import 'package:audiobook_organizer/ui/widgets/audiobook/audiobook_list_item.dart';
import 'package:audiobook_organizer/ui/widgets/audiobook/audiobook_detail_view.dart';

class LibraryBooksView extends StatefulWidget {
  final List<AudiobookFile> books;
  final bool isGridView;
  final LibraryManager libraryManager;
  final Function(Widget) onNavigateToDetail;
  final Function(AudiobookFile) onToggleFavorite;

  const LibraryBooksView({
    Key? key,
    required this.books,
    required this.isGridView,
    required this.libraryManager,
    required this.onNavigateToDetail,
    required this.onToggleFavorite,
  }) : super(key: key);

  @override
  State<LibraryBooksView> createState() => _LibraryBooksViewState();
}

class _LibraryBooksViewState extends State<LibraryBooksView> {
  late ScrollController _gridScrollController;
  late ScrollController _listScrollController;

  @override
  void initState() {
    super.initState();
    _gridScrollController = ScrollController();
    _listScrollController = ScrollController();
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.books.isEmpty) {
      return _buildEmptyState();
    }

    return widget.isGridView ? _buildGridView() : _buildListView();
  }

  Widget _buildEmptyState() {
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

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double cardWidth = 200.0;
        const double cardHeight = 400.0;
        const double spacing = 24.0;
        const double scrollbarSpace = 16.0; // Space reserved for scrollbar
        
        // Calculate how many fixed-size cards fit across the available width
        // Subtract scrollbar space from available width
        final availableWidth = constraints.maxWidth - (spacing * 2) - scrollbarSpace;
        final int crossAxisCount = (availableWidth / (cardWidth + spacing))
            .floor()
            .clamp(1, 10);
        
        // Calculate the actual width used by the grid
        final double gridWidth = (crossAxisCount * cardWidth) + 
            ((crossAxisCount - 1) * spacing);
        
        return Scrollbar(
          controller: _gridScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          thickness: 8.0,
          radius: const Radius.circular(4.0),
          child: SingleChildScrollView(
            controller: _gridScrollController,
            child: Center(
              child: Container(
                width: gridWidth + (spacing * 2),
                margin: const EdgeInsets.only(right: scrollbarSpace), // Reserve space for scrollbar
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    alignment: WrapAlignment.start,
                    children: widget.books.map((book) {
                      return SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: AudiobookGridItem(
                          book: book,
                          libraryManager: widget.libraryManager, // Pass library manager
                          onTap: () => widget.onNavigateToDetail(
                            AudiobookDetailView(
                              book: book,
                              libraryManager: widget.libraryManager,
                            ),
                          ),
                          onFavoriteTap: () => widget.onToggleFavorite(book),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    const double scrollbarSpace = 16.0; // Space reserved for scrollbar
    
    return Scrollbar(
      controller: _listScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      thickness: 8.0,
      radius: const Radius.circular(4.0),
      child: ListView.builder(
        controller: _listScrollController,
        padding: const EdgeInsets.fromLTRB(24, 24, 24 + scrollbarSpace, 24), // Add right padding for scrollbar
        itemCount: widget.books.length,
        itemBuilder: (context, index) {
          final book = widget.books[index];
          return AudiobookListItem(
            book: book,
            libraryManager: widget.libraryManager, // Pass library manager
            onTap: () => widget.onNavigateToDetail(
              AudiobookDetailView(
                book: book,
                libraryManager: widget.libraryManager,
              ),
            ),
            // Note: List view doesn't have favorite tap - handled in detail view
          );
        },
      ),
    );
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