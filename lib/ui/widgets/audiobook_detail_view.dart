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
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _seriesController;
  late TextEditingController _seriesPositionController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoriesController;
  late TextEditingController _userTagsController;

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
    // Dispose existing controllers first to prevent memory leaks
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
    
    Logger.debug('Controllers initialized for: ${metadata?.title ?? _book.filename}');
  }

  void _disposeControllers() {
    try {
      _titleController.dispose();
      _authorController.dispose();
      _seriesController.dispose();
      _seriesPositionController.dispose();
      _descriptionController.dispose();
      _categoriesController.dispose();
      _userTagsController.dispose();
    } catch (e) {
      // Controllers might not be initialized yet
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

  Future<void> _clearImageCache(String imagePath) async {
    try {
      final file = File(imagePath);
      
      // Clear from Flutter's image cache
      await FileImage(file).evict();
      
      // Also clear from the network image cache (if applicable)
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      
      Logger.debug('Cleared image cache for: $imagePath');
    } catch (e) {
      Logger.debug('Error clearing image cache: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _book.metadata;
    
    return Container(
      color: const Color(0xFF121212),
      child: Stack(
        children: [
          Row(
            children: [
              // Left side - Cover and actions
              Container(
                width: 350,
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // Cover Image with enhanced refresh handling
                    Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[900],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildCoverImage(metadata),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    _buildActionButtons(context),
                  ],
                ),
              ),
              
              // Right side - Metadata
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  child: SingleChildScrollView(
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
                                      controller: _titleController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: const InputDecoration(
                                        border: UnderlineInputBorder(),
                                      ),
                                    )
                                  : Text(
                                      metadata?.title ?? _book.filename,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
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
                        
                        const SizedBox(height: 16),
                        
                        // Author
                        _buildMetadataField(
                          'Author',
                          metadata?.authorsFormatted ?? 'Unknown',
                          _authorController,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Series info
                        if (metadata?.series.isNotEmpty ?? false || _isEditingMetadata) ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildMetadataField(
                                  'Series',
                                  metadata?.series ?? '',
                                  _seriesController,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildMetadataField(
                                  'Position',
                                  metadata?.seriesPosition ?? '',
                                  _seriesPositionController,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                        
                        // Description
                        _buildMetadataField(
                          'Description',
                          metadata?.description.isEmpty ?? true
                              ? 'No description available'
                              : metadata!.description,
                          _descriptionController,
                          multiline: true,
                        ),

                        const SizedBox(height: 24),
                        
                        // Categories/Genres
                        _buildMetadataField(
                          'Genres/Categories',
                          (_book.metadata?.categories.isEmpty ?? true)
                              ? 'No genres specified'
                              : _book.metadata!.categories.join(', '),
                          _categoriesController,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // User Tags
                        _buildMetadataField(
                          'Personal Tags',
                          (_book.metadata?.userTags.isEmpty ?? true)
                              ? 'No tags specified'
                              : _book.metadata!.userTags.join(', '),
                          _userTagsController,
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Additional info
                        _buildFileInformation(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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

  Widget _buildCoverImage(AudiobookMetadata? metadata) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        // Simple key based on metadata - CoverArtManager handles cache busting via unique paths
        key: ValueKey(metadata?.thumbnailUrl ?? 'no-cover'),
        width: double.infinity,
        height: double.infinity,
        child: metadata?.thumbnailUrl != null && metadata!.thumbnailUrl.isNotEmpty
            ? Stack(
                children: [
                  // Simple image display - no cache management needed here
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

  Future<void> _changeCoverImage() async {
    final metadataMatcher = Provider.of<MetadataMatcher>(context, listen: false);
    
    final coverSource = await CoverImageDialog.show(
      context: context,
      currentMetadata: _book.metadata,
      metadataMatcher: metadataMatcher,
    );
    
    if (coverSource != null) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      try {
        // Use the enhanced updateCoverImage method which handles CoverArtManager properly
        final success = await widget.libraryManager.updateCoverImage(_book, coverSource);
        
        // Hide loading indicator
        Navigator.of(context).pop();
        
        if (success) {
          // Force refresh book data to get the updated cover path
          await _refreshBookData();
          
          // Update the UI state
          setState(() {
            // The book object should now have the updated metadata with new cover path
          });
          
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
        // Hide loading indicator
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

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _playAudiobook(context),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        OutlinedButton.icon(
          onPressed: _addToCollections,
          icon: const Icon(Icons.add),
          label: const Text('Add to Collection'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white38),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Search online metadata button
        OutlinedButton.icon(
          onPressed: _isUpdatingMetadata ? null : _searchOnlineMetadata,
          icon: const Icon(Icons.search),
          label: const Text('Search Online Metadata'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white38),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Favorite button
        OutlinedButton.icon(
          onPressed: _toggleFavorite,
          icon: Icon(
            _book.metadata?.isFavorite ?? false ? Icons.favorite : Icons.favorite_border,
            color: _book.metadata?.isFavorite ?? false ? Colors.red : null,
          ),
          label: Text(_book.metadata?.isFavorite ?? false ? 'Favorited' : 'Add to Favorites'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white38),
          ),
        ),
        
        // ENHANCED: Debug refresh button (only in debug mode)
        if (kDebugMode) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _refreshBookData,
            icon: const Icon(Icons.refresh),
            label: const Text('Force Refresh'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Colors.grey[400],
              side: BorderSide(color: Colors.grey[600]!),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileInformation() {
    final metadata = _book.metadata;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'File Information',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Duration', metadata?.durationFormatted ?? 'Unknown'),
          _buildInfoRow('Format', metadata?.fileFormat ?? _book.extension.toUpperCase()),
          _buildInfoRow('File Size', _formatFileSize(_book.fileSize)),
          _buildInfoRow('Added', _formatDate(_book.lastModified)),
          if (metadata?.averageRating != null && metadata!.averageRating > 0)
            _buildInfoRow('Rating', '${metadata.averageRating}/5'),
          
          if (metadata?.categories.isNotEmpty ?? false)
            _buildInfoRow('Genres', metadata!.categories.join(', ')),
          if (metadata?.userTags.isNotEmpty ?? false)
            _buildInfoRow('Tags', metadata!.userTags.join(', ')),
          
          // Show user data status
          if (metadata != null && _hasUserData(metadata)) ...[
            const SizedBox(height: 8),
            _buildInfoRow('User Data', _getUserDataSummary(metadata)),
          ],
        ],
      ),
    );
  }

  // TEMPORARY: Simple check for user data (until extension is added)
  bool _hasUserData(AudiobookMetadata metadata) {
    return metadata.userRating > 0 ||
           metadata.playbackPosition != null ||
           metadata.userTags.isNotEmpty ||
           metadata.isFavorite ||
           metadata.bookmarks.isNotEmpty ||
           metadata.notes.isNotEmpty;
  }

  String _getUserDataSummary(AudiobookMetadata metadata) {
    final List<String> userDataItems = [];
    
    if (metadata.userRating > 0) userDataItems.add('Rating: ${metadata.userRating}/5');
    if (metadata.isFavorite) userDataItems.add('Favorite');
    if (metadata.bookmarks.isNotEmpty) userDataItems.add('${metadata.bookmarks.length} bookmarks');
    if (metadata.notes.isNotEmpty) userDataItems.add('${metadata.notes.length} notes');
    if (metadata.playbackPosition != null) userDataItems.add('Progress saved');
    if (metadata.userTags.isNotEmpty) userDataItems.add('${metadata.userTags.length} tags');
    
    return userDataItems.isEmpty ? 'None' : userDataItems.join(', ');
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

  Widget _buildMetadataField(String label, String value, TextEditingController controller, {bool multiline = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        if (_isEditingMetadata)
          TextField(
            controller: controller,
            style: TextStyle(
              color: Colors.white,
              fontSize: multiline ? 14 : 16,
            ),
            maxLines: multiline ? 4 : 1,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              color: value == 'No description available' ? Colors.grey[600] : Colors.white,
              fontSize: multiline ? 14 : 16,
              height: multiline ? 1.5 : null,
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
      final metadata = _book.metadata ?? AudiobookMetadata(
        id: _book.path,
        title: _titleController.text,
        authors: [],
      );

      final categories = _parseCommaSeparatedValues(_categoriesController.text);
      final userTags = _parseCommaSeparatedValues(_userTagsController.text);
      
      final updatedMetadata = metadata.copyWith(
        title: _titleController.text,
        authors: _authorController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        series: _seriesController.text,
        seriesPosition: _seriesPositionController.text,
        description: _descriptionController.text,
        categories: categories,
        userTags: userTags,
      );
      
      final success = await widget.libraryManager.updateMetadata(_book, updatedMetadata);
      
      if (success) {
        // Force refresh book data
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
      
      // Build search query from current metadata or filename
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
            Logger.log('Enhancing metadata for: ${_book.filename}');
            finalMetadata = await metadataMatcher.enhanceMetadata(_book, result.metadata);
            
            // Handle cover enhancement separately if requested
            if (result.updateCover && result.metadata.thumbnailUrl.isNotEmpty) {
              final coverSuccess = await _handleCoverUpdate(result.metadata.thumbnailUrl);
              if (coverSuccess && finalMetadata != null) {
                // Reload metadata to get updated cover path
                await _refreshBookData();
                final updatedBook = widget.libraryManager.getFileByPath(_book.path);
                if (updatedBook?.metadata != null) {
                  finalMetadata = updatedBook!.metadata;
                }
              }
            }
            break;
            
          case MetadataUpdateType.update:
            Logger.log('Updating to new version for: ${_book.filename}');
            finalMetadata = await metadataMatcher.updateToNewVersion(
              _book, 
              result.metadata, 
              updateCover: result.updateCover
            );
            break;
            
          case MetadataUpdateType.replace:
            Logger.log('Replacing with different book for: ${_book.filename}');
            finalMetadata = await metadataMatcher.replaceWithDifferentBook(
              _book, 
              result.metadata, 
              updateCover: result.updateCover
            );
            break;
        }
        
        if (finalMetadata != null) {
          // CRITICAL: Force refresh the book data from library manager
          await _refreshBookData();
          
          // Also manually update the book object to ensure UI updates immediately
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
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update metadata'),
                backgroundColor: Colors.red,
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

  // Helper method to handle cover updates using CoverArtManager
  Future<bool> _handleCoverUpdate(String coverSource) async {
    try {
      Logger.log('Updating cover art for: ${_book.filename}');
      
      // Simple call - LibraryManager + CoverArtManager handle everything
      final success = await widget.libraryManager.updateCoverImage(_book, coverSource);
      
      if (success) {
        Logger.log('Successfully updated cover art for: ${_book.filename}');
        return true;
      } else {
        Logger.error('Failed to update cover art for: ${_book.filename}');
        return false;
      }
    } catch (e) {
      Logger.error('Error updating cover art for: ${_book.filename}', e);
      return false;
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

  Future<void> _playAudiobook(BuildContext context) async {
    try {
      final playerService = Provider.of<AudioPlayerService>(context, listen: false);
      
      // Start playing the audiobook
      final success = await playerService.play(_book);
      
      if (success) {
        // Navigate to the player screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
              file: _book,
            ),
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to play audiobook'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Show error message
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