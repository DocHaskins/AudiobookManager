// lib/ui/widgets/detail/audiobook_detail_view.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/ui/widgets/detail/audiobook_cover_section.dart';
import 'package:audiobook_organizer/ui/widgets/detail/audiobook_metadata_section.dart';
import 'package:audiobook_organizer/ui/widgets/detail/missing_file_widget.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_controllers_mixin.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class AudiobookDetailView extends StatefulWidget {
  final AudiobookFile book;
  final LibraryManager libraryManager;

  const AudiobookDetailView({
    Key? key,
    required this.book,
    required this.libraryManager,
  }) : super(key: key);

  @override
  State<AudiobookDetailView> createState() => _AudiobookDetailViewState();
}

class _AudiobookDetailViewState extends State<AudiobookDetailView> 
    with DetailControllersMixin {
  late AudiobookFile _book;
  bool _isUpdatingMetadata = false;
  late StreamSubscription<List<AudiobookFile>> _librarySubscription;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    initializeControllers(_book.metadata, _book.filename);
    
    _librarySubscription = widget.libraryManager.libraryChanged.listen(
      _onLibraryChanged,
      onError: (error) => Logger.error('Error listening to library changes: $error'),
    );
  }

  void _onLibraryChanged(List<AudiobookFile> books) {
    if (!mounted) return;
    
    try {
      final updatedBook = books.firstWhere(
        (b) => b.path == _book.path,
        orElse: () => _book,
      );

      if (updatedBook != _book) {
        Logger.debug('Book object changed, updating UI for: ${_book.filename}');
        setState(() {
          _book = updatedBook;
          if (!isEditingMetadata) {
            initializeControllers(_book.metadata, _book.filename);
          }
        });
      }
    } catch (e) {
      Logger.error('Error handling library change: $e');
    }
  }

  Future<void> refreshBookData() async {
    try {
      final refreshedBook = widget.libraryManager.getFileByPath(_book.path);
      if (refreshedBook != null && refreshedBook != _book) {
        setState(() {
          _book = refreshedBook;
          if (!isEditingMetadata) {
            initializeControllers(_book.metadata, _book.filename);
          }
        });
        Logger.log('Force refreshed book data for: ${_book.filename}');
      }
    } catch (e) {
      Logger.error('Error force refreshing book data: $e');
    }
  }

  void _onBookUpdated(AudiobookFile updatedBook) {
    Logger.log('Book updated via metadata search: ${updatedBook.filename}');
    setState(() {
      _book = updatedBook;
      if (!isEditingMetadata) {
        initializeControllers(_book.metadata, _book.filename);
      }
    });
  }

  // Add method to handle editing state changes
  void _onEditingStateChanged(bool isEditing) {
    setState(() {
      setEditingMetadata(isEditing);
      if (!isEditing) {
        // Reset controllers when canceling edit
        initializeControllers(_book.metadata, _book.filename);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _fileExists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: const Color(0xFF121212),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        
        final fileExists = snapshot.data ?? false;
        
        if (!fileExists) {
          return MissingFileWidget(book: _book);
        }
        
        return _buildNormalDetailView();
      },
    );
  }

  Future<bool> _fileExists() async {
    try {
      final file = File(_book.path);
      return await file.exists();
    } catch (e) {
      Logger.error('Error checking file existence: $e');
      return false;
    }
  }

  Widget _buildNormalDetailView() {
    return Container(
      color: const Color(0xFF121212),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Cover and actions
                AudiobookCoverSection(
                  book: _book,
                  libraryManager: widget.libraryManager,
                  onRefreshBook: refreshBookData,
                  onUpdateMetadataStatus: (bool isUpdating) {
                    setState(() {
                      _isUpdatingMetadata = isUpdating;
                    });
                  },
                  onBookUpdated: _onBookUpdated,
                  isUpdatingMetadata: _isUpdatingMetadata,
                ),
                
                // Right side - Metadata
                Expanded(
                  child: AudiobookMetadataSection(
                    book: _book,
                    libraryManager: widget.libraryManager,
                    controllers: this, // Pass the mixin
                    onRefreshBook: refreshBookData,
                    onUpdateMetadataStatus: (bool isUpdating) {
                      setState(() {
                        _isUpdatingMetadata = isUpdating;
                      });
                    },
                    onEditingStateChanged: _onEditingStateChanged, // Add this callback
                    isUpdatingMetadata: _isUpdatingMetadata,
                  ),
                ),
              ],
            ),
          ),
          
          // Loading overlay
          if (_isUpdatingMetadata)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Updating metadata...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _librarySubscription.cancel();
    disposeControllers();
    super.dispose();
  }
}