// lib/ui/widgets/library_books_view.dart - Books display component
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/ui/widgets/audiobook/audiobook_grid_item.dart';
import 'package:audiobook_organizer/ui/widgets/audiobook/audiobook_list_item.dart';
import 'package:audiobook_organizer/ui/widgets/audiobook/audiobook_detail_view.dart';

class LibraryBooksView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return _buildEmptyState();
    }

    return isGridView ? _buildGridView() : _buildListView();
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
        // Fixed card dimensions - no resizing
        const double cardWidth = 200.0;
        const double cardHeight = 400.0;
        const double spacing = 24.0;
        
        // Calculate how many fixed-size cards fit across the available width
        final availableWidth = constraints.maxWidth - (spacing * 2);
        final int crossAxisCount = (availableWidth / (cardWidth + spacing))
            .floor()
            .clamp(1, 10);
        
        // Calculate the actual width used by the grid
        final double gridWidth = (crossAxisCount * cardWidth) + 
            ((crossAxisCount - 1) * spacing);
        
        return Center(
          child: Container(
            width: gridWidth + (spacing * 2),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GridView.builder(
                // Use custom delegate with absolutely fixed dimensions
                gridDelegate: _FixedSizeGridDelegate(
                  crossAxisCount: crossAxisCount,
                  itemWidth: cardWidth,
                  itemHeight: cardHeight,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                ),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return SizedBox(
                    width: cardWidth,  // Force exact width
                    height: cardHeight, // Force exact height
                    child: AudiobookGridItem(
                      book: book,
                      onTap: () => onNavigateToDetail(
                        AudiobookDetailView(
                          book: book,
                          libraryManager: libraryManager,
                        ),
                      ),
                      onFavoriteTap: () => onToggleFavorite(book),
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
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return AudiobookListItem(
          book: book,
          onTap: () => onNavigateToDetail(
            AudiobookDetailView(
              book: book,
              libraryManager: libraryManager,
            ),
          ),
          // Note: List view doesn't have favorite tap - handled in detail view
        );
      },
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