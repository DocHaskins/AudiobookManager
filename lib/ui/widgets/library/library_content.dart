// lib/ui/widgets/library_content.dart - Main content area
// =============================================================================

import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/ui/widgets/library/library_books_view.dart';
import 'package:audiobook_organizer/ui/widgets/library/library_collections_view.dart';

class LibraryContent extends StatelessWidget {
  final List<Widget> navigationStack;
  final bool showCollections;
  final bool isGridView;
  final List<AudiobookFile> filteredBooks;
  final List<Collection> filteredCollections;
  final LibraryManager libraryManager;
  final CollectionManager collectionManager;
  final Function(Widget) onNavigateToDetail;
  final VoidCallback onNavigateBack;
  final ValueChanged<bool> onViewToggle;
  final Function(AudiobookFile) onToggleFavorite;

  const LibraryContent({
    Key? key,
    required this.navigationStack,
    required this.showCollections,
    required this.isGridView,
    required this.filteredBooks,
    required this.filteredCollections,
    required this.libraryManager,
    required this.collectionManager,
    required this.onNavigateToDetail,
    required this.onNavigateBack,
    required this.onViewToggle,
    required this.onToggleFavorite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (navigationStack.isNotEmpty) {
      return _buildDetailContent();
    }
    return _buildMainContent(context);
  }

  Widget _buildMainContent(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: showCollections
              ? LibraryCollectionsView(
                  collections: filteredCollections,
                  libraryManager: libraryManager,
                  collectionManager: collectionManager,
                  onNavigateToDetail: onNavigateToDetail,
                )
              : LibraryBooksView(
                  books: filteredBooks,
                  isGridView: isGridView,
                  libraryManager: libraryManager,
                  onNavigateToDetail: onNavigateToDetail,
                  onToggleFavorite: onToggleFavorite,
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Text(
            showCollections ? 'Collections' : 'Library',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
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
                    color: isGridView ? Theme.of(context).primaryColor : Colors.grey[600],
                  ),
                  onPressed: () => onViewToggle(true),
                ),
                IconButton(
                  icon: Icon(
                    Icons.view_list,
                    color: !isGridView ? Theme.of(context).primaryColor : Colors.grey[600],
                  ),
                  onPressed: () => onViewToggle(false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onNavigateBack,
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
        Expanded(
          child: navigationStack.last,
        ),
      ],
    );
  }
}