// lib/ui/widgets/detail/utils/detail_actions.dart
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
  final Function(AudiobookFile)? onBookUpdated;

  DetailActions({
    required this.libraryManager,
    required this.onRefreshBook,
    required this.onUpdateMetadataStatus,
    this.onBookUpdated,
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
        
        // Check if context is still mounted before showing snackbar
        if (context.mounted) {
          _showSnackBar(context, 'Metadata saved successfully', Colors.green);
        }
      } else {
        if (context.mounted) {
          _showSnackBar(context, 'Failed to save metadata', Colors.red);
        }
      }
    } catch (e) {
      Logger.error('Error saving metadata: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Error saving metadata: ${e.toString()}', Colors.red);
      }
    }
  }

  Future<void> searchOnlineMetadata(
    BuildContext context,
    AudiobookFile book,
  ) async {
    Logger.log('=== Starting metadata search for: ${book.filename} ===');
    onUpdateMetadataStatus(true);

    try {
      // Ensure context is available and get the MetadataMatcher
      if (!context.mounted) {
        Logger.error('Context not mounted, cannot search metadata');
        return;
      }

      final metadataMatcher = Provider.of<MetadataMatcher>(context, listen: false);
      
      String searchQuery = '';
      if (book.metadata != null) {
        searchQuery = '${book.metadata!.title} ${book.metadata!.authorsFormatted}';
      } else {
        searchQuery = book.filename.replaceAll(RegExp(r'\.[^.]+'), '');
      }
      
      Logger.log('Search query: "$searchQuery"');
      Logger.log('Available providers: ${metadataMatcher.providers.length}');
      
      final providers = metadataMatcher.providers;
      
      Logger.log('Showing metadata search dialog...');
      
      // Show dialog and wait for result
      final result = await MetadataSearchDialog.show(
        context: context,
        initialQuery: searchQuery,
        providers: providers,
        currentMetadata: book.metadata,
      );
      
      Logger.log('Dialog completed. Result: ${result != null ? 'Found result' : 'No result'}');
      
      // Process the result if we have one
      if (result != null) {
        Logger.log('Processing metadata update: ${result.updateType.name} operation for ${book.filename}');
        Logger.log('Selected metadata title: "${result.metadata.title}"');
        Logger.log('Update cover: ${result.updateCover}');
        
        bool success = false;
        AudiobookMetadata? finalMetadata;
        
        // Handle cover update first if requested
        if (result.updateCover && result.metadata.thumbnailUrl.isNotEmpty) {
          Logger.log('Updating cover image from: ${result.metadata.thumbnailUrl}');
          final coverSuccess = await libraryManager.updateCoverImage(book, result.metadata.thumbnailUrl);
          Logger.log('Cover update success: $coverSuccess');
        }
        
        // Apply the correct operation directly using the metadata merge methods
        Logger.log('Applying ${result.updateType.name} operation...');
        switch (result.updateType) {
          case MetadataUpdateType.enhance:
            Logger.log('Enhancing metadata for: ${book.filename}');
            if (book.metadata != null) {
              finalMetadata = book.metadata!.enhance(result.metadata);
              Logger.log('Enhanced existing metadata');
            } else {
              finalMetadata = result.metadata;
              Logger.log('No existing metadata, using new metadata directly');
            }
            success = await libraryManager.updateMetadata(book, finalMetadata);
            Logger.log('Enhance operation success: $success');
            break;
            
          case MetadataUpdateType.update:
            Logger.log('Updating version for: ${book.filename}');
            if (book.metadata != null) {
              finalMetadata = book.metadata!.updateVersion(result.metadata);
              Logger.log('Updated version keeping user data');
            } else {
              finalMetadata = result.metadata;
              Logger.log('No existing metadata, using new metadata directly');
            }
            success = await libraryManager.updateMetadata(book, finalMetadata);
            Logger.log('Update operation success: $success');
            break;
            
          case MetadataUpdateType.replace:
            Logger.log('Replacing book metadata for: ${book.filename}');
            if (book.metadata != null) {
              finalMetadata = book.metadata!.replaceBook(result.metadata);
              Logger.log('Replaced book, reset user data');
            } else {
              finalMetadata = result.metadata;
              Logger.log('No existing metadata, using new metadata directly');
            }
            success = await libraryManager.updateMetadata(book, finalMetadata);
            Logger.log('Replace operation success: $success');
            break;
        }
        
        if (success && finalMetadata != null) {
          Logger.log('Metadata update successful, updating UI...');
          
          // Update the local book object
          book.metadata = finalMetadata; 
          
          // Refresh the book data to ensure consistency
          onRefreshBook();
          
          // Call the update callback with the updated book
          onBookUpdated?.call(book);
          
          // Show success message if context is still mounted
          if (context.mounted) {
            _showSnackBar(context, _getSuccessMessage(result.updateType), Colors.green);
          } else {
            Logger.log('Context unmounted, success message not shown but operation completed successfully');
          }
          
          Logger.log('Successfully updated metadata for: ${book.filename}');
        } else {
          Logger.error('Failed to update metadata for: ${book.filename} - Success: $success, FinalMetadata: ${finalMetadata != null}');
          if (context.mounted) {
            _showSnackBar(context, 'Failed to update metadata', Colors.red);
          } else {
            Logger.log('Context unmounted, error message not shown');
          }
        }
      } else {
        Logger.log('No result from dialog - user cancelled or no selection made');
      }
    } catch (e) {
      Logger.error('Error updating metadata: $e');
      Logger.error('Stack trace: ${StackTrace.current}');
      if (context.mounted) {
        _showSnackBar(context, 'Error updating metadata: ${e.toString()}', Colors.red);
      }
    } finally {
      Logger.log('=== Metadata search completed ===');
      onUpdateMetadataStatus(false);
    }
  }

  Future<void> saveMetadataToFile(
    BuildContext context,
    AudiobookFile book,
  ) async {
    if (book.metadata == null) {
      if (context.mounted) {
        _showSnackBar(context, 'No metadata to save', Colors.orange);
      }
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
            
        if (context.mounted) {
          _showSnackBar(
            context, 
            'Metadata saved to file successfully$durationText', 
            Colors.green,
            duration: const Duration(seconds: 4),
          );
        }
      } else {
        Logger.error('Failed to save metadata to file: ${book.filename}');
        if (context.mounted) {
          _showSnackBar(context, 'Failed to save metadata to file', Colors.red);
        }
      }
    } catch (e) {
      Logger.error('Error saving metadata to file: $e');
      if (context.mounted) {
        _showSnackBar(
          context, 
          'Error saving metadata to file: ${e.toString()}', 
          Colors.red,
          duration: const Duration(seconds: 6),
        );
      }
    } finally {
      onUpdateMetadataStatus(false);
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
    // Additional safety check - only show snackbar if context is still mounted
    if (!context.mounted) {
      Logger.debug('Context not mounted, skipping snackbar: $message');
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: duration ?? const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Fallback logging if snackbar fails
      Logger.error('Failed to show snackbar: $message', e);
    }
  }
}