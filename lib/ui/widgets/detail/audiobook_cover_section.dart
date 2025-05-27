// lib/ui/widgets/detail/audiobook_cover_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/ui/widgets/cover_image_dialog.dart';
import 'package:audiobook_organizer/ui/widgets/detail/audiobook_actions_section.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class AudiobookCoverSection extends StatelessWidget {
  final AudiobookFile book;
  final LibraryManager libraryManager;
  final VoidCallback onRefreshBook;
  final ValueChanged<bool> onUpdateMetadataStatus; // Added missing parameter
  final bool isUpdatingMetadata; // Added missing parameter

  const AudiobookCoverSection({
    Key? key,
    required this.book,
    required this.libraryManager,
    required this.onRefreshBook,
    required this.onUpdateMetadataStatus, // Added
    this.isUpdatingMetadata = false, // Added with default value
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Cover Image
          Container(
            width: 320,
            height: 520,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[900],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 25,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildCoverImage(context),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Action buttons - now using dedicated component
          AudiobookActionsSection(
            book: book,
            libraryManager: libraryManager,
            onRefreshBook: onRefreshBook,
            onUpdateMetadataStatus: onUpdateMetadataStatus,
            isUpdatingMetadata: isUpdatingMetadata,
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    final metadata = book.metadata;
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        key: ValueKey(metadata?.thumbnailUrl ?? 'no-cover'),
        width: double.infinity,
        height: double.infinity,
        child: metadata?.thumbnailUrl != null && metadata!.thumbnailUrl.isNotEmpty
            ? Stack(
                children: [
                  Image.file(
                    File(metadata.thumbnailUrl),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      Logger.debug('Error loading cover image: ${metadata.thumbnailUrl}');
                      return _buildPlaceholder();
                    },
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) return child;
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: child,
                      );
                    },
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: () => _changeCoverImage(context),
                    ),
                  ),
                ],
              )
            : InkWell(
                onTap: () => _changeCoverImage(context),
                child: _buildPlaceholder(),
              ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.headphones, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Click to add cover',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _changeCoverImage(BuildContext context) async {
    final metadataMatcher = Provider.of<MetadataMatcher>(context, listen: false);
    
    final coverSource = await CoverImageDialog.show(
      context: context,
      currentMetadata: book.metadata,
      metadataMatcher: metadataMatcher,
    );
    
    if (coverSource != null) {
      _showLoadingDialog(context);
      
      try {
        final success = await libraryManager.updateCoverImage(book, coverSource);
        Navigator.of(context).pop(); // Close loading dialog
        
        if (success) {
          onRefreshBook();
          _showSnackBar(context, 'Cover image updated successfully', Colors.green);
        } else {
          _showSnackBar(context, 'Failed to update cover image', Colors.red);
        }
      } catch (e) {
        Navigator.of(context).pop(); // Close loading dialog
        Logger.error('Error updating cover: $e');
        _showSnackBar(context, 'Error updating cover: ${e.toString()}', Colors.red);
      }
    }
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }
}