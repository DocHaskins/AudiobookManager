// lib/ui/widgets/detail/audiobook_metadata_section.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_controllers_mixin.dart';
import 'package:audiobook_organizer/ui/widgets/detail/title_author_section.dart';
import 'package:audiobook_organizer/ui/widgets/detail/series_section.dart';
import 'package:audiobook_organizer/ui/widgets/detail/collections_section.dart';
import 'package:audiobook_organizer/ui/widgets/detail/genres_section.dart';
import 'package:audiobook_organizer/ui/widgets/detail/publisher_section.dart';
import 'package:audiobook_organizer/ui/widgets/detail/description_section.dart';
import 'package:audiobook_organizer/ui/widgets/detail/rating_section.dart';
import 'package:audiobook_organizer/ui/widgets/detail/file_info_section.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_actions.dart';

class AudiobookMetadataSection extends StatelessWidget {
  final AudiobookFile book;
  final LibraryManager libraryManager;
  final DetailControllersMixin controllers;
  final VoidCallback onRefreshBook;
  final ValueChanged<bool> onUpdateMetadataStatus;
  final ValueChanged<bool> onEditingStateChanged; // Add this callback
  final bool isUpdatingMetadata;

  const AudiobookMetadataSection({
    Key? key,
    required this.book,
    required this.libraryManager,
    required this.controllers,
    required this.onRefreshBook,
    required this.onUpdateMetadataStatus,
    required this.onEditingStateChanged, // Add this parameter
    this.isUpdatingMetadata = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final metadata = book.metadata;
    
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Edit Controls
          TitleAuthorSection(
            book: book,
            controllers: controllers,
            onSave: () => _saveMetadata(context),
            onEdit: () => onEditingStateChanged(true), // Use the callback
            onCancel: () => onEditingStateChanged(false), // Use the callback
          ),
          
          const SizedBox(height: 12),
          
          // Series Information
          SeriesSection(
            metadata: metadata,
            controllers: controllers,
          ),
          
          // Collections Display
          CollectionsSection(
            book: book,
            libraryManager: libraryManager,
          ),

          const SizedBox(height: 16),

          // Genres Section
          GenresSection(
            metadata: metadata,
            controllers: controllers,
          ),

          const SizedBox(height: 16),

          // Publisher Information
          PublisherSection(
            metadata: metadata,
            controllers: controllers,
          ),

          const SizedBox(height: 16),

          // Description Section
          DescriptionSection(
            metadata: metadata,
            controllers: controllers,
          ),

          const SizedBox(height: 24),
          
          // Rating Section
          RatingSection(
            book: book,
            libraryManager: libraryManager,
            onRefreshBook: onRefreshBook,
          ),
          
          const SizedBox(height: 24),

          // File Information
          FileInfoSection(book: book),
        ],
      ),
    );
  }

  Future<void> _saveMetadata(BuildContext context) async {
    final actions = DetailActions(
      libraryManager: libraryManager,
      onRefreshBook: onRefreshBook,
      onUpdateMetadataStatus: onUpdateMetadataStatus,
    );
    
    await actions.saveMetadata(context, book, controllers);
    onEditingStateChanged(false);
  }
}