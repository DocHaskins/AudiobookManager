import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/ui/screens/player_screen.dart';
import 'package:audiobook_organizer/ui/widgets/metadata_search_dialog.dart';
import 'package:audiobook_organizer/ui/widgets/cover_image_dialog.dart';
import '../widgets/add_to_collection_dialog.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'dart:io';

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

class _AudiobookDetailViewState extends State<AudiobookDetailView> {
  late AudiobookFile _book;
  bool _isEditingMetadata = false;
  bool _isUpdatingMetadata = false;
  
  // Edit controllers
  // Change the controller declarations to nullable
  TextEditingController? _titleController;
  TextEditingController? _authorController;
  TextEditingController? _seriesController;
  TextEditingController? _seriesPositionController;
  TextEditingController? _descriptionController;
  TextEditingController? _categoriesController;
  TextEditingController? _userTagsController;

  // Stream subscription for library changes
  late StreamSubscription<List<AudiobookFile>> _librarySubscription;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _initializeControllers();
    
    // Listen to library changes with proper error handling
    _librarySubscription = widget.libraryManager.libraryChanged.listen(
      _onLibraryChanged,
      onError: (error) {
        Logger.error('Error listening to library changes: $error');
      },
    );
  }

  void _onLibraryChanged(List<AudiobookFile> books) {
    if (!mounted) return;
    
    try {
      final updatedBook = books.firstWhere(
        (b) => b.path == _book.path,
        orElse: () => _book,
      );
      
      // ENHANCED: Always update if the book object changed
      if (updatedBook != _book) {
        Logger.debug('Book object changed, updating UI for: ${_book.filename}');
        setState(() {
          _book = updatedBook;
          if (!_isEditingMetadata) {
            _initializeControllers();
          }
        });
      }
    } catch (e) {
      Logger.error('Error handling library change: $e');
    }
  }

  void _initializeControllers() {
    _disposeControllers();
    
    final metadata = _book.metadata;
    _titleController = TextEditingController(text: metadata?.title ?? _book.filename);
    _authorController = TextEditingController(text: metadata?.authorsFormatted ?? '');
    _seriesController = TextEditingController(text: metadata?.series ?? '');
    _seriesPositionController = TextEditingController(text: metadata?.seriesPosition ?? '');
    _descriptionController = TextEditingController(text: metadata?.description ?? '');
    _categoriesController = TextEditingController(
      text: metadata?.categories.isEmpty ?? true ? '' : metadata!.categories.join(', ')
    );
    _userTagsController = TextEditingController(
      text: metadata?.userTags.isEmpty ?? true ? '' : metadata!.userTags.join(', ')
    );
  }

  void _disposeControllers() {
    try {
      _titleController?.dispose();
      _authorController?.dispose();
      _seriesController?.dispose();
      _seriesPositionController?.dispose();
      _descriptionController?.dispose();
      _categoriesController?.dispose();
      _userTagsController?.dispose();
    } catch (e) {
      Logger.debug('Error disposing controllers (expected during init): $e');
    }
  }

  Future<void> _refreshBookData() async {
    try {
      final refreshedBook = widget.libraryManager.getFileByPath(_book.path);
      if (refreshedBook != null && refreshedBook != _book) {
        setState(() {
          _book = refreshedBook;
          if (!_isEditingMetadata) {
            _initializeControllers();
          }
        });
        Logger.log('Force refreshed book data for: ${_book.filename}');
      }
    } catch (e) {
      Logger.error('Error force refreshing book data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if file exists before showing the detail view
    return FutureBuilder<bool>(
      future: _fileExists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: const Color(0xFF121212),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final fileExists = snapshot.data ?? false;
        
        if (!fileExists) {
          return _buildMissingFileWidget();
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

  Widget _buildMissingFileWidget() {
    return Container(
      color: const Color(0xFF121212),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              Text(
                'FILE NOT FOUND',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The audiobook file could not be found at its expected location.',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expected Path:',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      _book.path,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'File Name:',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _book.filename,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'The file may have been moved, renamed, or deleted.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNormalDetailView() {
    final metadata = _book.metadata;
    
    return Container(
      color: const Color(0xFF121212),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Cover and actions
                Container(
                  width: 380,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Cover Image
                      Container(
                        width: 320,
                        height: 320,
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
                          child: _buildCoverImage(metadata),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Action buttons - Goodreads style
                      _buildActionButtons(context),
                    ],
                  ),
                ),
                
                // Right side - Metadata in Goodreads style
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Edit button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _isEditingMetadata
                                  ? TextField(
                                      controller: _titleController!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                      decoration: const InputDecoration(
                                        border: UnderlineInputBorder(),
                                      ),
                                    )
                                  : Text(
                                      metadata?.title ?? _book.filename,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: _isEditingMetadata ? _saveMetadata : _editMetadata,
                              icon: Icon(_isEditingMetadata ? Icons.save : Icons.edit),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF2A2A2A),
                                foregroundColor: Colors.white,
                              ),
                            ),
                            if (_isEditingMetadata)
                              IconButton(
                                onPressed: _cancelEdit,
                                icon: const Icon(Icons.close),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF2A2A2A),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Author
                        _buildAuthorField(metadata?.authorsFormatted ?? 'Unknown'),
                        
                        const SizedBox(height: 12),
                        
                        // Series info - Now editable when in edit mode
                        _buildSeriesSection(metadata),
                        
                        // Collections and Series Section
                        _buildCollectionsDisplay(),

                        const SizedBox(height: 16),

                        _buildDescriptionSection(metadata),

                        const SizedBox(height: 24),
                        // Rating and genres section - Goodreads style
                        _buildRatingAndGenresSection(metadata),
                        
                        const SizedBox(height: 24),

                        // File Information
                        _buildFileInformation(),
                      ],
                    ),
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

  Widget _buildSeriesSection(AudiobookMetadata? metadata) {
    if (_isEditingMetadata) {
      // Show editable series fields when in edit mode
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SERIES INFORMATION',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _seriesController!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Series Name',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _seriesPositionController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Position #',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      );
    } else {
      // Show display version when not editing
      if (metadata?.series.isNotEmpty ?? false) {
        return Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.library_books,
                  color: Theme.of(context).primaryColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '${metadata!.series}${metadata.seriesPosition.isNotEmpty ? " #${metadata.seriesPosition}" : ""}',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _viewSeries(metadata.series),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('View Series', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        );
      } else {
        return const SizedBox(height: 0);
      }
    }
  }

  Widget _buildCoverImage(AudiobookMetadata? metadata) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
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
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      onPressed: _changeCoverImage,
                    ),
                  ),
                ],
              )
            : InkWell(
                onTap: _changeCoverImage,
                child: _buildPlaceholder(),
              ),
      ),
    );
  }

  Widget _buildAuthorField(String author) {
    return _isEditingMetadata
        ? TextField(
            controller: _authorController,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              border: UnderlineInputBorder(),
              hintText: 'Author name',
            ),
          )
        : InkWell(
            onTap: () {
              // TODO: Navigate to author page or search
            },
            child: Text(
              author,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          );
  }

  Widget _buildRatingAndGenresSection(AudiobookMetadata? metadata) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Online rating
          if (metadata?.averageRating != null && metadata!.averageRating > 0) ...[
            Row(
              children: [
                _buildStarRating(metadata.averageRating),
                const SizedBox(width: 12),
                Text(
                  '${metadata.averageRating.toStringAsFixed(2)} avg rating',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                if (metadata.ratingsCount > 0) ...[
                  Text(
                    ' • ${_formatRatingCount(metadata.ratingsCount)} ratings',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          // User rating
          Row(
            children: [
              Text(
                'Your rating: ',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              _buildUserRating(metadata?.userRating ?? 0),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Genres - Debug and display
          Builder(builder: (context) {
            final categories = metadata?.categories ?? [];
            final hasCategories = categories.isNotEmpty;
            
            if (hasCategories || _isEditingMetadata) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Genres',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isEditingMetadata)
                    TextField(
                      controller: _categoriesController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Enter genres separated by commas',
                        border: UnderlineInputBorder(),
                      ),
                    )
                  else if (hasCategories)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((genre) => 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).primaryColor.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            genre.trim(), // Ensure no whitespace issues
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ).toList(),
                    )
                  else
                    Text(
                      'No genres available',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              );
            } else {
              return const SizedBox.shrink(); // Don't show anything if no categories
            }
          }),
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 18);
        } else if (index < rating) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 18);
        } else {
          return Icon(Icons.star_border, color: Colors.grey[400], size: 18);
        }
      }),
    );
  }

  Widget _buildUserRating(int userRating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return InkWell(
          onTap: () => _updateUserRating(starIndex),
          child: Icon(
            starIndex <= userRating ? Icons.star : Icons.star_border,
            color: starIndex <= userRating ? Colors.amber : Colors.grey[400],
            size: 20,
          ),
        );
      }),
    );
  }

  Widget _buildDescriptionSection(AudiobookMetadata? metadata) {
    final description = metadata?.description ?? '';
    final hasDescription = description.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DESCRIPTION',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (_isEditingMetadata)
          TextField(
            controller: _descriptionController!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
            maxLines: 6,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              hintText: 'Enter book description...',
            ),
          )
        else if (hasDescription)
          Text(
            description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.6,
            ),
          )
        else
          Text(
            'No description available',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildUserTagsSection(AudiobookMetadata? metadata) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PERSONAL TAGS',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (_isEditingMetadata)
          TextField(
            controller: _userTagsController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Enter tags separated by commas',
              border: UnderlineInputBorder(),
            ),
          )
        else if (metadata?.userTags.isNotEmpty ?? false)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metadata!.userTags.map((tag) => 
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.5)),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ).toList(),
          )
        else
          Text(
            'No personal tags',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildCollectionsDisplay() {
    final collectionManager = widget.libraryManager.collectionManager;
    if (collectionManager == null) {
      return Text(
        'Collections not available',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final currentCollections = collectionManager.getCollectionsForBook(_book.path);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collections:',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (currentCollections.isEmpty)
          Text(
            'Not in any collections',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: currentCollections.map((collection) => 
              Material(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _removeFromCollection(collection),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_special,
                          color: Colors.blue,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          collection.name,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.close,
                          color: Colors.blue.withOpacity(0.7),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).toList(),
          ),
      ],
    );
  }

  Widget _buildSeriesEditingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Series Information:',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _seriesController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Series Name',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _seriesPositionController!,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Position #',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddSeriesHint() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Series Information:',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Not part of a series',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditingMetadata = true;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Add to Series', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _viewSeries(String seriesName) async {
    try {
      final seriesBooks = widget.libraryManager.getFilesBySeries(seriesName);
      
      if (seriesBooks.isNotEmpty) {
        // Sort books by series position
        seriesBooks.sort((a, b) {
          final aPos = int.tryParse(a.metadata?.seriesPosition ?? '') ?? 0;
          final bPos = int.tryParse(b.metadata?.seriesPosition ?? '') ?? 0;
          return aPos.compareTo(bPos);
        });
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$seriesName Series'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${seriesBooks.length} books in this series:'),
                  const SizedBox(height: 16),
                  ...seriesBooks.map((book) => ListTile(
                    leading: Icon(
                      book.path == _book.path ? Icons.play_arrow : Icons.book,
                      color: book.path == _book.path ? Theme.of(context).primaryColor : null,
                    ),
                    title: Text(
                      book.metadata?.title ?? book.filename,
                      style: TextStyle(
                        fontWeight: book.path == _book.path ? FontWeight.bold : FontWeight.normal,
                        color: book.path == _book.path ? Theme.of(context).primaryColor : null,
                      ),
                    ),
                    subtitle: Text('Position: ${book.metadata?.seriesPosition ?? "Unknown"}'),
                    dense: true,
                  )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Logger.error('Error viewing series: $e');
    }
  }

  Future<void> _removeFromCollection(dynamic collection) async {
    try {
      final collectionManager = widget.libraryManager.collectionManager;
      if (collectionManager == null) return;
      
      final success = await collectionManager.removeBookFromCollection(collection.id, _book.path);
      
      if (success) {
        setState(() {}); // Refresh the collections display
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed from ${collection.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error removing from collection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove from collection: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Primary action - Play button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _playAudiobook(context),
            icon: const Icon(Icons.play_arrow, size: 24),
            label: const Text(
              'Play',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Secondary actions in a grid
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                onPressed: _addToCollections,
                icon: Icons.add,
                label: 'Add to\nCollection',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryButton(
                onPressed: _toggleFavorite,
                icon: _book.metadata?.isFavorite ?? false 
                    ? Icons.favorite 
                    : Icons.favorite_border,
                label: _book.metadata?.isFavorite ?? false 
                    ? 'Favorited' 
                    : 'Favorite',
                iconColor: _book.metadata?.isFavorite ?? false 
                    ? Colors.red 
                    : null,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Full width secondary actions
        SizedBox(
          width: double.infinity,
          child: _buildSecondaryButton(
            onPressed: _isUpdatingMetadata ? null : _searchOnlineMetadata,
            icon: Icons.search,
            label: 'Search Online Metadata',
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Save to File button
        SizedBox(
          width: double.infinity,
          child: _buildSecondaryButton(
            onPressed: _isUpdatingMetadata ? null : _saveMetadataToFile,
            icon: Icons.save_alt,
            label: 'Save Metadata to File',
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Debug button (only show in debug mode)
        if (kDebugMode)
          SizedBox(
            width: double.infinity,
            child: _buildSecondaryButton(
              onPressed: _showDebugInfo,
              icon: Icons.bug_report,
              label: 'Debug File Info',
            ),
          ),
      ],
    );
  }

  Widget _buildSecondaryButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: iconColor),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.grey[700]!),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildFileInformation() {
    final metadata = _book.metadata;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FILE INFORMATION',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          
          // Critical file information that should always be available
          _buildInfoRow('File Name', _book.filename),
          _buildInfoRow('File Path', _book.path),
          _buildInfoRow('File Size', _formatFileSize(_book.fileSize)),
          _buildInfoRow('Date Added', _formatDate(_book.lastModified)),
          _buildInfoRow('Format', _book.extension.replaceFirst('.', '').toUpperCase()),
          
          // Metadata-dependent information
          if (metadata?.audioDuration != null)
            _buildInfoRow('Duration', metadata!.durationFormatted)
          else
            _buildInfoRow('Duration', 'Not available'),
            
          if (metadata?.fileFormat.isNotEmpty ?? false)
            _buildInfoRow('Audio Format', metadata!.fileFormat),

        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.headphones,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Click to add cover',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatRatingCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  bool _hasUserData(AudiobookMetadata metadata) {
    return metadata.userRating > 0 ||
           metadata.playbackPosition != null ||
           metadata.userTags.isNotEmpty ||
           metadata.isFavorite ||
           metadata.bookmarks.isNotEmpty ||
           metadata.notes.isNotEmpty;
  }

  String _getProgressInfo(AudiobookMetadata metadata) {
    if (metadata.playbackPosition != null && metadata.audioDuration != null) {
      final progress = (metadata.playbackPosition!.inMilliseconds / 
                       metadata.audioDuration!.inMilliseconds * 100);
      return '${progress.toStringAsFixed(1)}% complete';
    } else if (metadata.playbackPosition != null) {
      return 'Position: ${_formatDuration(metadata.playbackPosition!)}';
    } else if (metadata.lastPlayedPosition != null) {
      return 'Last played: ${_formatDate(metadata.lastPlayedPosition!)}';
    }
    return 'Not started';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // Action methods
  Future<void> _updateUserRating(int rating) async {
    try {
      final success = await widget.libraryManager.updateUserData(
        _book,
        userRating: rating,
      );
      
      if (success) {
        await _refreshBookData();
      }
    } catch (e) {
      Logger.error('Error updating user rating: $e');
    }
  }

  void _editMetadata() {
    setState(() {
      _isEditingMetadata = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditingMetadata = false;
      _initializeControllers();
    });
  }

  Future<void> _saveMetadata() async {
    try {
      // Ensure controllers are initialized
      if (_titleController == null) return;
      
      final metadata = _book.metadata ?? AudiobookMetadata(
        id: _book.path,
        title: _titleController!.text,
        authors: [],
      );

      final categories = _parseCommaSeparatedValues(_categoriesController!.text);
      final userTags = _parseCommaSeparatedValues(_userTagsController!.text);
      
      final updatedMetadata = metadata.copyWith(
        title: _titleController!.text,
        authors: _authorController!.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        series: _seriesController!.text,
        seriesPosition: _seriesPositionController!.text,
        description: _descriptionController!.text,
        categories: categories,
        userTags: userTags,
      );
      
      final success = await widget.libraryManager.updateMetadata(_book, updatedMetadata);
      
      if (success) {
        await _refreshBookData();
        setState(() {
          _isEditingMetadata = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metadata saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save metadata'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error saving metadata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving metadata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final success = await widget.libraryManager.updateUserData(
        _book,
        isFavorite: !(_book.metadata?.isFavorite ?? false),
      );
      
      if (success) {
        await _refreshBookData();
      }
    } catch (e) {
      Logger.error('Error toggling favorite: $e');
    }
  }

  Future<void> _searchOnlineMetadata() async {
    if (_isUpdatingMetadata) return;
    
    setState(() {
      _isUpdatingMetadata = true;
    });

    try {
      final metadataMatcher = Provider.of<MetadataMatcher>(context, listen: false);
      
      String searchQuery = '';
      if (_book.metadata != null) {
        searchQuery = '${_book.metadata!.title} ${_book.metadata!.authorsFormatted}';
      } else {
        searchQuery = _book.filename.replaceAll(RegExp(r'\.[^.]+'), '');
      }
      
      final providers = metadataMatcher.providers;
      
      final result = await MetadataSearchDialog.show(
        context: context,
        initialQuery: searchQuery,
        providers: providers,
        currentMetadata: _book.metadata,
      );
      
      if (result != null) {
        AudiobookMetadata? finalMetadata;
        
        switch (result.updateType) {
          case MetadataUpdateType.enhance:
            finalMetadata = await metadataMatcher.enhanceMetadata(_book, result.metadata);
            if (result.updateCover && result.metadata.thumbnailUrl.isNotEmpty) {
              await _handleCoverUpdate(result.metadata.thumbnailUrl);
              await _refreshBookData();
            }
            break;
          case MetadataUpdateType.update:
            finalMetadata = await metadataMatcher.updateToNewVersion(
              _book, 
              result.metadata, 
              updateCover: result.updateCover
            );
            break;
          case MetadataUpdateType.replace:
            finalMetadata = await metadataMatcher.replaceWithDifferentBook(
              _book, 
              result.metadata, 
              updateCover: result.updateCover
            );
            break;
        }
        
        if (finalMetadata != null) {
          await _refreshBookData();
          setState(() {
            _book.metadata = finalMetadata;
            if (!_isEditingMetadata) {
              _initializeControllers();
            }
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_getSuccessMessage(result.updateType)),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      Logger.error('Error updating metadata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating metadata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingMetadata = false;
        });
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

  Future<bool> _handleCoverUpdate(String coverSource) async {
    try {
      final success = await widget.libraryManager.updateCoverImage(_book, coverSource);
      if (success) {
        Logger.log('Successfully updated cover art for: ${_book.filename}');
        return true;
      }
      return false;
    } catch (e) {
      Logger.error('Error updating cover art for: ${_book.filename}', e);
      return false;
    }
  }

  Future<void> _changeCoverImage() async {
    final metadataMatcher = Provider.of<MetadataMatcher>(context, listen: false);
    
    final coverSource = await CoverImageDialog.show(
      context: context,
      currentMetadata: _book.metadata,
      metadataMatcher: metadataMatcher,
    );
    
    if (coverSource != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      try {
        final success = await widget.libraryManager.updateCoverImage(_book, coverSource);
        Navigator.of(context).pop();
        
        if (success) {
          await _refreshBookData();
          setState(() {});
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cover image updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update cover image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        Navigator.of(context).pop();
        Logger.error('Error updating cover: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating cover: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addToCollections() async {
    final collectionManager = widget.libraryManager.collectionManager;
    if (collectionManager == null) return;
    
    final currentCollections = collectionManager.getCollectionsForBook(_book.path);
    
    await showDialog(
      context: context,
      builder: (context) => AddToCollectionDialog(
        collectionManager: collectionManager,
        bookPath: _book.path,
        currentCollections: currentCollections,
      ),
    );
  }

  List<String> _parseCommaSeparatedValues(String input) {
    return input
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _saveMetadataToFile() async {
    if (_book.metadata == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No metadata to save'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUpdatingMetadata = true;
    });

    try {
      Logger.log('Saving metadata to file for: ${_book.filename}');
      
      // Show what we're about to save
      final metadataInfo = {
        'title': _book.metadata!.title,
        'authors': _book.metadata!.authors,
        'series': _book.metadata!.series,
        'duration': _book.metadata!.audioDuration?.inSeconds,
        'completeness': _book.metadata!.completionPercentage.toStringAsFixed(1) + '%',
      };
      Logger.debug('Metadata to save: $metadataInfo');
      
      // Use the LibraryManager to write metadata directly to the file
      final success = await widget.libraryManager.writeMetadataToFile(_book);
      
      if (success) {
        // Force refresh book data to ensure we see any changes
        await _refreshBookData();
        
        // Log successful save with verification
        if (_book.metadata?.audioDuration != null) {
          Logger.log('Successfully saved metadata with duration: ${_book.metadata!.durationFormatted}');
        } else {
          Logger.warning('Metadata saved but no duration found after save');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Metadata saved to file successfully${_book.metadata?.audioDuration != null ? " (Duration: ${_book.metadata!.durationFormatted})" : ""}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        Logger.error('Failed to save metadata to file: ${_book.filename}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save metadata to file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error saving metadata to file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving metadata to file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingMetadata = false;
        });
      }
    }
  }

  Future<void> _showDebugInfo() async {
    try {
      // Get detailed information about this file
      final detailedInfo = await _book.extractDetailedInfoFromFile();
      
      // Get library statistics
      final stats = await widget.libraryManager.getMetadataStatistics();
      
      // Create debug information string
      final debugInfo = '''
📁 FILE INFORMATION:
${_formatMapForDisplay(detailedInfo['file_info'] as Map<String, dynamic>)}

🔍 RAW METADATA_GOD INFO:
${_formatMapForDisplay(detailedInfo['raw_metadata_god_info'] as Map<String, dynamic>)}

📊 LIBRARY STATISTICS:
${_formatMapForDisplay(stats)}

🏥 NEEDS REPAIR: ${_book.needsMetadataRepair ? 'YES' : 'NO'}
📈 COMPLETION: ${_book.metadata?.completionPercentage.toStringAsFixed(1) ?? '0'}%
      ''';
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Debug Info: ${_book.filename}'),
            content: SingleChildScrollView(
              child: SelectableText(
                debugInfo,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  // Copy to clipboard would be nice but requires additional dependencies
                  Logger.log('Debug Info for ${_book.filename}:\n$debugInfo');
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Debug info logged to console'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                child: const Text('Log to Console'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Logger.error('Error getting debug info: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting debug info: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatMapForDisplay(Map<String, dynamic> map) {
    return map.entries
        .map((entry) => '  ${entry.key}: ${entry.value}')
        .join('\n');
  }

  Future<void> _playAudiobook(BuildContext context) async {
    try {
      final playerService = Provider.of<AudioPlayerService>(context, listen: false);
      final success = await playerService.play(_book);
      
      if (success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlayerScreen(file: _book),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to play audiobook'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing audiobook: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _librarySubscription.cancel();
    _disposeControllers();
    super.dispose();
  }
}