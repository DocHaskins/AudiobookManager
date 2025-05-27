// lib/ui/widgets/detail/audiobook_cover_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/services/cover_art_manager.dart';
import 'package:audiobook_organizer/ui/widgets/cover_image_dialog.dart';
import 'package:audiobook_organizer/ui/widgets/detail/audiobook_actions_section.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class AudiobookCoverSection extends StatefulWidget {
  final AudiobookFile book;
  final LibraryManager libraryManager;
  final VoidCallback onRefreshBook;
  final ValueChanged<bool> onUpdateMetadataStatus;
  final Function(AudiobookFile)? onBookUpdated;
  final bool isUpdatingMetadata;

  const AudiobookCoverSection({
    Key? key,
    required this.book,
    required this.libraryManager,
    required this.onRefreshBook,
    required this.onUpdateMetadataStatus,
    this.onBookUpdated,
    this.isUpdatingMetadata = false,
  }) : super(key: key);

  @override
  State<AudiobookCoverSection> createState() => _AudiobookCoverSectionState();
}

class _AudiobookCoverSectionState extends State<AudiobookCoverSection> {
  final CoverArtManager _coverArtManager = CoverArtManager();
  String? _currentCoverPath;
  bool _isLoadingCover = false;

  @override
  void initState() {
    super.initState();
    _loadCoverPath();
  }

  @override
  void didUpdateWidget(AudiobookCoverSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload cover if the book changed or metadata was updated
    if (oldWidget.book.path != widget.book.path || 
        oldWidget.book.metadata?.thumbnailUrl != widget.book.metadata?.thumbnailUrl) {
      _loadCoverPath();
    }
  }

  Future<void> _loadCoverPath() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingCover = true;
    });

    try {
      // Use CoverArtManager to get the actual cover path
      final coverPath = await _coverArtManager.getCoverPath(widget.book.path);
      
      // If we found a cover but metadata doesn't have the correct path, update it
      if (coverPath != null && widget.book.metadata != null) {
        final currentThumbnailUrl = widget.book.metadata!.thumbnailUrl;
        
        // If metadata has wrong path (URL instead of local file), fix it
        if (currentThumbnailUrl != coverPath && 
            (currentThumbnailUrl.startsWith('http') || !File(currentThumbnailUrl).existsSync())) {
          
          Logger.log('Fixing metadata thumbnail path from "$currentThumbnailUrl" to "$coverPath"');
          
          // Update metadata with correct local path
          final updatedMetadata = widget.book.metadata!.copyWith(thumbnailUrl: coverPath);
          final success = await widget.libraryManager.updateMetadata(widget.book, updatedMetadata);
          
          if (success) {
            Logger.log('Successfully updated metadata with correct cover path');
          } else {
            Logger.warning('Failed to update metadata with correct cover path');
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _currentCoverPath = coverPath;
          _isLoadingCover = false;
        });
      }
      
      Logger.debug('Cover path for ${widget.book.filename}: ${coverPath ?? "None"}');
    } catch (e) {
      Logger.error('Error loading cover path: $e');
      if (mounted) {
        setState(() {
          _currentCoverPath = null;
          _isLoadingCover = false;
        });
      }
    }
  }

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
          
          // Action buttons
          AudiobookActionsSection(
            book: widget.book,
            libraryManager: widget.libraryManager,
            onRefreshBook: widget.onRefreshBook,
            onUpdateMetadataStatus: widget.onUpdateMetadataStatus,
            onBookUpdated: widget.onBookUpdated,
            isUpdatingMetadata: widget.isUpdatingMetadata,
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    // First try to get cover from metadata (which should be the local path)
    final metadataCoverPath = widget.book.metadata?.thumbnailUrl;
    final shouldUseMetadataPath = metadataCoverPath != null && 
                                  metadataCoverPath.isNotEmpty && 
                                  !metadataCoverPath.startsWith('http') &&
                                  File(metadataCoverPath).existsSync();
    
    final displayPath = shouldUseMetadataPath ? metadataCoverPath : _currentCoverPath;
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        key: ValueKey(displayPath ?? 'no-cover-${DateTime.now().millisecondsSinceEpoch}'),
        width: double.infinity,
        height: double.infinity,
        child: _isLoadingCover
            ? _buildLoadingPlaceholder()
            : displayPath != null && displayPath.isNotEmpty
                ? _buildCoverWithImage(context, displayPath)
                : _buildClickablePlaceholder(context),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildCoverWithImage(BuildContext context, String coverPath) {
    return Stack(
      children: [
        Image.file(
          File(coverPath),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            Logger.debug('Error loading cover image from: $coverPath - $error');
            return _buildClickablePlaceholder(context);
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
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _changeCoverImage(context),
          ),
        ),
      ],
    );
  }

  Widget _buildClickablePlaceholder(BuildContext context) {
    return Material(
      color: Colors.grey[800],
      child: InkWell(
        onTap: () => _changeCoverImage(context),
        child: Container(
          width: double.infinity,
          height: double.infinity,
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
        ),
      ),
    );
  }

  Future<void> _changeCoverImage(BuildContext context) async {
    try {
      final metadataMatcher = Provider.of<MetadataMatcher>(context, listen: false);
      
      final coverSource = await CoverImageDialog.show(
        context: context,
        currentMetadata: widget.book.metadata,
        metadataMatcher: metadataMatcher,
      );
      
      if (coverSource != null && mounted) {
        _showLoadingDialog(context);
        
        try {
          Logger.log('Updating cover from dialog selection: $coverSource');
          
          final success = await widget.libraryManager.updateCoverImage(widget.book, coverSource);
          
          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            
            if (success) {
              // Refresh the cover path from CoverArtManager
              await _loadCoverPath();
              
              // Call the refresh callback to update the book object
              widget.onRefreshBook();
              
              _showSnackBar(context, 'Cover image updated successfully', Colors.green);
            } else {
              _showSnackBar(context, 'Failed to update cover image', Colors.red);
            }
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            Logger.error('Error updating cover: $e');
            _showSnackBar(context, 'Error updating cover: ${e.toString()}', Colors.red);
          }
        }
      }
    } catch (e) {
      Logger.error('Error in _changeCoverImage: $e');
      if (mounted) {
        _showSnackBar(context, 'Error opening cover dialog: ${e.toString()}', Colors.red);
      }
    }
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Updating cover...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}