// lib/ui/widgets/detail/utils/detail_actions.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_controllers_mixin.dart';
import 'package:audiobook_organizer/ui/widgets/dialogs/metadata_search_dialog.dart';
import 'package:audiobook_organizer/ui/widgets/dialogs/conversion_progress_dialog.dart';
import 'package:audiobook_organizer/ui/widgets/dialogs/goodreads_search_dialog.dart';
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
        
        if (success) {
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

  // UPDATED: Browse Goodreads using HTTP-based search (Windows compatible)
  Future<void> browseGoodreads(
    BuildContext context,
    AudiobookFile book,
  ) async {
    Logger.log('=== Starting Goodreads browsing for: ${book.filename} ===');
    onUpdateMetadataStatus(true);

    try {
      if (!context.mounted) {
        Logger.error('Context not mounted, cannot browse Goodreads');
        return;
      }

      // Extract title and author for search
      String title = book.metadata?.title ?? book.filename.replaceAll(RegExp(r'\.[^.]+'), '');
      String author = book.metadata?.authorsFormatted ?? '';

      Logger.log('Opening Goodreads search with title: "$title", author: "$author"');

      // Show the Goodreads search dialog (works on all platforms including Windows)
      final result = await GoodreadsSearchDialog.show(
        context: context,
        title: title,
        author: author,
        currentMetadata: book.metadata,
      );

      if (result != null) {
        Logger.log('Goodreads result received: ${result.metadata.title}');
        Logger.log('Selected options: Title=${result.options.updateTitle}, Authors=${result.options.updateAuthors}, etc.');

        // Convert GoodreadsMetadata to AudiobookMetadata
        final goodreadsAudioMetadata = result.metadata.toAudiobookMetadata(book.path);
        
        // Apply selective updates based on user choices
        AudiobookMetadata updatedMetadata = book.metadata ?? AudiobookMetadata(
          id: book.path,
          title: title,
          authors: [],
        );

        // Selectively update fields based on options
        updatedMetadata = updatedMetadata.copyWith(
          title: result.options.updateTitle ? result.metadata.title : updatedMetadata.title,
          subtitle: result.options.updateTitle ? result.metadata.subtitle : updatedMetadata.subtitle,
          authors: result.options.updateAuthors ? result.metadata.authors : updatedMetadata.authors,
          description: result.options.updateDescription ? result.metadata.description : updatedMetadata.description,
          categories: result.options.updateGenres ? result.metadata.genres : updatedMetadata.categories,
          averageRating: result.options.updateRating ? result.metadata.rating : updatedMetadata.averageRating,
          ratingsCount: result.options.updateRating ? result.metadata.ratingsCount : updatedMetadata.ratingsCount,
          publisher: result.options.updatePublisher ? result.metadata.publisher : updatedMetadata.publisher,
          publishedDate: result.options.updatePublishedDate ? result.metadata.publishedDate : updatedMetadata.publishedDate,
          series: result.options.updateSeries ? result.metadata.series : updatedMetadata.series,
          seriesPosition: result.options.updateSeries ? result.metadata.seriesPosition : updatedMetadata.seriesPosition,
          pageCount: result.metadata.pageCount > 0 ? result.metadata.pageCount : updatedMetadata.pageCount,
          provider: 'goodreads',
        );

        // Handle cover update separately if requested
        if (result.options.updateCover && result.metadata.coverImageUrl.isNotEmpty) {
          Logger.log('Updating cover from Goodreads: ${result.metadata.coverImageUrl}');
          final coverSuccess = await libraryManager.updateCoverImage(book, result.metadata.coverImageUrl);
          Logger.log('Goodreads cover update success: $coverSuccess');
        }

        // Add ISBN identifier if available and selected
        if (result.options.updateISBN && result.metadata.isbn.isNotEmpty) {
          final existingIdentifiers = List<AudiobookIdentifier>.from(updatedMetadata.identifiers);
          // Remove existing ISBN entries
          existingIdentifiers.removeWhere((id) => id.type.contains('ISBN'));
          // Add new ISBN
          existingIdentifiers.add(AudiobookIdentifier(type: 'ISBN', identifier: result.metadata.isbn));
          updatedMetadata = updatedMetadata.copyWith(identifiers: existingIdentifiers);
        }

        // Update the metadata
        final success = await libraryManager.updateMetadata(book, updatedMetadata);

        if (success) {
          Logger.log('Goodreads metadata update successful');
          
          // Update the local book object
          book.metadata = updatedMetadata;
          
          // Refresh the book data
          onRefreshBook();
          
          // Call the update callback
          onBookUpdated?.call(book);
          
          // Show success message
          if (context.mounted) {
            final updatedFields = _getUpdatedFieldsList(result.options);
            _showSnackBar(
              context, 
              'Successfully updated from Goodreads: ${updatedFields.join(", ")}', 
              Colors.green,
              duration: const Duration(seconds: 4),
            );
          }
          
          Logger.log('Successfully updated metadata from Goodreads for: ${book.filename}');
        } else {
          Logger.error('Failed to update metadata from Goodreads');
          if (context.mounted) {
            _showSnackBar(context, 'Failed to update metadata from Goodreads', Colors.red);
          }
        }
      } else {
        Logger.log('User cancelled Goodreads browsing');
      }
    } catch (e) {
      Logger.error('Error browsing Goodreads: $e');
      Logger.error('Stack trace: ${StackTrace.current}');
      if (context.mounted) {
        _showSnackBar(context, 'Error browsing Goodreads: ${e.toString()}', Colors.red);
      }
    } finally {
      Logger.log('=== Goodreads browsing completed ===');
      onUpdateMetadataStatus(false);
    }
  }

  // Helper method to get list of updated fields
  List<String> _getUpdatedFieldsList(GoodreadsSelectionOptions options) {
    final updatedFields = <String>[];
    
    if (options.updateTitle) updatedFields.add('Title');
    if (options.updateAuthors) updatedFields.add('Authors');
    if (options.updateDescription) updatedFields.add('Description');
    if (options.updateGenres) updatedFields.add('Genres');
    if (options.updateRating) updatedFields.add('Rating');
    if (options.updateCover) updatedFields.add('Cover');
    if (options.updatePublisher) updatedFields.add('Publisher');
    if (options.updatePublishedDate) updatedFields.add('Published Date');
    if (options.updateSeries) updatedFields.add('Series');
    if (options.updateISBN) updatedFields.add('ISBN');
    
    return updatedFields;
  }

  Future<void> saveMetadataToFile(
    BuildContext context,
    AudiobookFile book, {
    DetailControllersMixin? controllers,
  }) async {
    onUpdateMetadataStatus(true);

    try {
      AudiobookMetadata? metadataToSave = book.metadata;
      
      if (controllers != null && controllers.isEditingMetadata && controllers.titleController != null) {
        Logger.log('Syncing controller changes before saving to file');
        
        final currentMetadata = book.metadata ?? AudiobookMetadata(
          id: book.path,
          title: controllers.titleController!.text,
          authors: [],
        );

        // Parse the genres/categories from the controller
        final categories = controllers.parseCommaSeparatedValues(
          controllers.categoriesController!.text
        );
        final userTags = controllers.parseCommaSeparatedValues(
          controllers.userTagsController!.text
        );
        final genres = controllers.parseCommaSeparatedValues(
          controllers.genresController!.text
        );
        
        // Create updated metadata with controller values
        metadataToSave = currentMetadata.copyWith(
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
          publisher: controllers.publisherController?.text ?? currentMetadata.publisher,
          publishedDate: controllers.publishedDateController?.text ?? currentMetadata.publishedDate,
        );

        // Update the book object with synced metadata
        final updateSuccess = await libraryManager.updateMetadata(book, metadataToSave);
        if (!updateSuccess) {
          Logger.error('Failed to update book metadata before file save');
          if (context.mounted) {
            _showSnackBar(context, 'Failed to update metadata before file save', Colors.red);
          }
          return;
        }
        
        Logger.log('Successfully synced controller changes to book metadata');
      }

      if (metadataToSave == null) {
        if (context.mounted) {
          _showSnackBar(context, 'No metadata to save', Colors.orange);
        }
        return;
      }

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

  // Convert MP3 to M4B method with progress dialog
  Future<void> convertToM4B(
    BuildContext context,
    AudiobookFile book,
  ) async {
    if (book.extension.toLowerCase() != '.mp3') {
      if (context.mounted) {
        _showSnackBar(context, 'Can only convert MP3 files to M4B', Colors.orange);
      }
      return;
    }

    if (book.metadata == null) {
      if (context.mounted) {
        _showSnackBar(context, 'Cannot convert file without metadata', Colors.orange);
      }
      return;
    }

    // Show confirmation dialog
    if (context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.transform, color: Colors.purple),
              SizedBox(width: 8),
              Text('Convert to M4B'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Convert "${book.filename}" to M4B format?'),
              const SizedBox(height: 16),
              const Text(
                'This will:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('• Convert MP3 to M4B using FFmpeg'),
              const Text('• Transfer all metadata to new file'),
              const Text('• Delete original MP3 file'),
              const Text('• Update library with new M4B file'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(24),
                  border: Border.all(color: Colors.orange.withAlpha(90)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone. Make sure you have backups if needed.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Convert'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }
    }

    try {
      Logger.log('Starting MP3 to M4B conversion for: ${book.filename}');
      
      // Check if FFmpeg is available using MetadataService
      final metadataService = MetadataService();
      final ffmpegAvailable = await metadataService.isFFmpegAvailableForConversion();
      
      if (!ffmpegAvailable) {
        Logger.error('FFmpeg not available for conversion');
        if (context.mounted) {
          _showSnackBar(
            context,
            'FFmpeg is required for conversion.\nPlease install FFmpeg and add it to your system PATH.\nDownload from: https://ffmpeg.org/download.html',
            Colors.red,
            duration: const Duration(seconds: 8),
          );
        }
        return;
      }

      Logger.log('FFmpeg is available for conversion');

      // Create M4B file path
      final originalPath = book.path;
      final directory = path_util.dirname(originalPath);
      final baseName = path_util.basenameWithoutExtension(originalPath);
      final m4bPath = path_util.join(directory, '$baseName.m4b');

      // Check if M4B file already exists
      if (await File(m4bPath).exists()) {
        Logger.error('M4B file already exists: $m4bPath');
        if (context.mounted) {
          _showSnackBar(
            context,
            'M4B file already exists at target location',
            Colors.red,
          );
        }
        return;
      }

      Logger.log('Converting $originalPath to $m4bPath');
      
      // Create progress controller
      final progressController = StreamController<ConversionProgress>.broadcast();
      bool isCancelled = false;
      
      // Show progress dialog
      if (context.mounted) {
        ConversionProgressDialog.show(
          context: context,
          fileName: book.filename,
          totalDuration: book.metadata?.audioDuration,
          onCancel: () {
            isCancelled = true;
            progressController.add(ConversionProgress.cancelled());
            Navigator.of(context).pop();
            Logger.log('Conversion cancelled by user');
          },
          progressStream: progressController.stream,
        );
      }
      
      // Perform the conversion using MetadataService with progress tracking
      final success = await metadataService.convertMP3ToM4B(
        originalPath,
        m4bPath,
        book.metadata!,
        progressController: progressController,
        totalDuration: book.metadata?.audioDuration,
      );

      // Close progress controller
      await progressController.close();

      if (isCancelled) {
        // Clean up partial file if conversion was cancelled
        try {
          final m4bFile = File(m4bPath);
          if (await m4bFile.exists()) {
            await m4bFile.delete();
            Logger.log('Cleaned up partial conversion file');
          }
        } catch (e) {
          Logger.warning('Failed to cleanup partial file: $e');
        }
        return;
      }

      if (success) {
        Logger.log('Conversion successful, updating library...');
        
        // Update the library manager to replace the old file with the new one
        final updateSuccess = await libraryManager.replaceFileInLibrary(
          originalPath,
          m4bPath,
          book.metadata!,
        );

        if (updateSuccess) {
          // Delete the original MP3 file
          try {
            await File(originalPath).delete();
            Logger.log('Deleted original MP3 file: $originalPath');
          } catch (e) {
            Logger.warning('Failed to delete original file: $e');
            // Continue anyway, conversion was successful
          }

          // Update the book object with new path
          final updatedBook = AudiobookFile(
            path: m4bPath,
            lastModified: await File(m4bPath).lastModified(),
            fileSize: await File(m4bPath).length(),
            metadata: book.metadata,
          );

          // Refresh the UI
          onRefreshBook();
          onBookUpdated?.call(updatedBook);

          // Close progress dialog if still open
          if (context.mounted) {
            Navigator.of(context).pop();
            _showSnackBar(
              context,
              'Successfully converted "${book.metadata!.title}" to M4B format',
              Colors.green,
              duration: const Duration(seconds: 4),
            );
          }

          Logger.log('MP3 to M4B conversion completed successfully');
        } else {
          Logger.error('Failed to update library after conversion');
          if (context.mounted) {
            Navigator.of(context).pop();
            _showSnackBar(
              context,
              'Conversion succeeded but failed to update library',
              Colors.orange,
            );
          }
        }
      } else {
        Logger.error('Failed to convert MP3 to M4B');
        if (context.mounted) {
          Navigator.of(context).pop();
          _showSnackBar(
            context,
            'Failed to convert file to M4B format',
            Colors.red,
          );
        }
      }
    } catch (e) {
      Logger.error('Error during MP3 to M4B conversion: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        _showSnackBar(
          context,
          'Error during conversion: ${e.toString()}',
          Colors.red,
          duration: const Duration(seconds: 6),
        );
      }
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