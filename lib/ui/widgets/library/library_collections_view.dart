// lib/ui/widgets/library_collections_view.dart - Collections display component
// =============================================================================

import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/ui/widgets/collections/collection_grid_item.dart';
import 'package:audiobook_organizer/ui/widgets/collections/collection_detail_view.dart';
import 'package:audiobook_organizer/ui/widgets/audiobook/audiobook_detail_view.dart';

class LibraryCollectionsView extends StatelessWidget {
  final List<Collection> collections;
  final LibraryManager libraryManager;
  final CollectionManager collectionManager;
  final Function(Widget) onNavigateToDetail;

  const LibraryCollectionsView({
    Key? key,
    required this.collections,
    required this.libraryManager,
    required this.collectionManager,
    required this.onNavigateToDetail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return _buildEmptyState();
    }

    return _buildCollectionsGrid();
  }

  Widget _buildEmptyState() {
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

  Widget _buildCollectionsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double itemWidth = 200;
        const double spacing = 20;
        
        final int crossAxisCount = ((constraints.maxWidth + spacing) / 
            (itemWidth + spacing)).floor().clamp(1, 20);
        
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.8,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: collections.length,
          itemBuilder: (context, index) {
            final collection = collections[index];
            final books = libraryManager.getBooksForCollection(collection);
            return CollectionGridItem(
              collection: collection,
              books: books,
              onTap: () => onNavigateToDetail(
                CollectionDetailView(
                  collection: collection,
                  books: books,
                  libraryManager: libraryManager,
                  collectionManager: collectionManager,
                  onBookTap: (book) => onNavigateToDetail(
                    AudiobookDetailView(
                      book: book,
                      libraryManager: libraryManager,
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
}