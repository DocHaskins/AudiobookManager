// =============================================================================
// lib/ui/widgets/detail/utils/detail_actions.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_controllers_mixin.dart';
import 'package:audiobook_organizer/ui/widgets/metadata_search_dialog.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class DetailActions {
  final LibraryManager libraryManager;
  final VoidCallback onRefreshBook;
  final ValueChanged<bool> onUpdateMetadataStatus;

  DetailActions({
    required this.libraryManager,
    required this.onRefreshBook,
    required this.onUpdateMetadataStatus,
  });

  Future<void> saveMetadata(
    BuildContext context,
    AudiobookFile book,
    DetailControllersMixin controllers,
  ) async {
    try {
      if (controllers.titleController == null) return;
      
      final metadata = book.metadata ?? AudiobookMetadata(
        id: book.path,
        title: controllers.titleController!.text,
        authors: [],
      );

      final categories = controllers.parseCommaSeparatedValues(
        controllers.categoriesController!.text
      );
      final userTags = controllers.parseCommaSeparatedValues(
        controllers.userTagsController!.text
      );
      final genres = controllers.parseCommaSeparatedValues(
        controllers.genresController!.text
      );
      
      final updatedMetadata = metadata.copyWith(
        title: controllers.titleController!.text,
        authors: controllers.authorController!.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        series: controllers.seriesController!.text,
        seriesPosition: controllers.seriesPositionController!.text,
        description: controllers.descriptionController!.text,
        categories: genres.isNotEmpty ? genres : categories,
        userTags: userTags,
        publisher: controllers.publisherController?.text ?? metadata.publisher,
        publishedDate: controllers.publishedDateController?.text ?? metadata.publishedDate,
      );
      
      final success = await libraryManager.updateMetadata(book, updatedMetadata);
      
      if (success) {
        onRefreshBook();
        controllers.setEditingMetadata(false);
        
        _showSnackBar(context, 'Metadata saved successfully', Colors.green);
      } else {
        _showSnackBar(context, 'Failed to save metadata', Colors.red);
      }
    } catch (e) {
      Logger.error('Error saving metadata: $e');
      _showSnackBar(context, 'Error saving metadata: ${e.toString()}', Colors.red);
    }
  }

  Future<void> searchOnlineMetadata(
    BuildContext context,
    AudiobookFile book,
  ) async {
    onUpdateMetadataStatus(true);

    try {
      final metadataMatcher = Provider.of<MetadataMatcher>(context, listen: false);
      
      String searchQuery = '';
      if (book.metadata != null) {
        searchQuery = '${book.metadata!.title} ${book.metadata!.authorsFormatted}';
      } else {
        searchQuery = book.filename.replaceAll(RegExp(r'\.[^.]+'), '');
      }
      
      final providers = metadataMatcher.providers;
      
      final result = await MetadataSearchDialog.show(
        context: context,
        initialQuery: searchQuery,
        providers: providers,
        currentMetadata: book.metadata,
      );
      
      if (result != null) {
        AudiobookMetadata? finalMetadata;
        
        switch (result.updateType) {
          case MetadataUpdateType.enhance:
            finalMetadata = await metadataMatcher.enhanceMetadata(book, result.metadata);
            if (result.updateCover && result.metadata.thumbnailUrl.isNotEmpty) {
              await _handleCoverUpdate(book, result.metadata.thumbnailUrl);
              onRefreshBook();
            }
            break;
          case MetadataUpdateType.update:
            finalMetadata = await metadataMatcher.updateToNewVersion(
              book, 
              result.metadata, 
              updateCover: result.updateCover
            );
            break;
          case MetadataUpdateType.replace:
            finalMetadata = await metadataMatcher.replaceWithDifferentBook(
              book, 
              result.metadata, 
              updateCover: result.updateCover
            );
            break;
        }
        
        if (finalMetadata != null) {
          onRefreshBook();
          _showSnackBar(context, _getSuccessMessage(result.updateType), Colors.green);
        }
      }
    } catch (e) {
      Logger.error('Error updating metadata: $e');
      _showSnackBar(context, 'Error updating metadata: ${e.toString()}', Colors.red);
    } finally {
      onUpdateMetadataStatus(false);
    }
  }

  Future<void> saveMetadataToFile(
    BuildContext context,
    AudiobookFile book,
  ) async {
    if (book.metadata == null) {
      _showSnackBar(context, 'No metadata to save', Colors.orange);
      return;
    }

    onUpdateMetadataStatus(true);

    try {
      Logger.log('Saving metadata to file for: ${book.filename}');
      
      final success = await libraryManager.writeMetadataToFile(book);
      
      if (success) {
        onRefreshBook();
        
        final durationText = book.metadata?.audioDuration != null 
            ? " (Duration: ${book.metadata!.durationFormatted})" 
            : "";
            
        _showSnackBar(
          context, 
          'Metadata saved to file successfully$durationText', 
          Colors.green,
          duration: const Duration(seconds: 4),
        );
      } else {
        Logger.error('Failed to save metadata to file: ${book.filename}');
        _showSnackBar(context, 'Failed to save metadata to file', Colors.red);
      }
    } catch (e) {
      Logger.error('Error saving metadata to file: $e');
      _showSnackBar(
        context, 
        'Error saving metadata to file: ${e.toString()}', 
        Colors.red,
        duration: const Duration(seconds: 6),
      );
    } finally {
      onUpdateMetadataStatus(false);
    }
  }

  Future<bool> _handleCoverUpdate(AudiobookFile book, String coverSource) async {
    try {
      final success = await libraryManager.updateCoverImage(book, coverSource);
      if (success) {
        Logger.log('Successfully updated cover art for: ${book.filename}');
        return true;
      }
      return false;
    } catch (e) {
      Logger.error('Error updating cover art for: ${book.filename}', e);
      return false;
    }
  }

  String _getSuccessMessage(MetadataUpdateType updateType) {
    switch (updateType) {
      case MetadataUpdateType.enhance:
        return 'Metadata enhanced successfully';
      case MetadataUpdateType.update:
        return 'Updated to new version successfully';
      case MetadataUpdateType.replace:
        return 'Replaced with new book successfully';
    }
  }

  void _showSnackBar(
    BuildContext context, 
    String message, 
    Color color, {
    Duration? duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
}