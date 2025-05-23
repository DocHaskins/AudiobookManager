// lib/widgets/audiobook_detail_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/ui/screens/player_screen.dart';
import '../widgets/add_to_collection_dialog.dart';
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
  
  // Edit controllers
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _seriesController;
  late TextEditingController _seriesPositionController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _initializeControllers();
    
    // Listen to library changes
    widget.libraryManager.libraryChanged.listen((books) {
      final updatedBook = books.firstWhere(
        (b) => b.path == _book.path,
        orElse: () => _book,
      );
      if (mounted && updatedBook != _book) {
        setState(() {
          _book = updatedBook;
          _initializeControllers();
        });
      }
    });
  }

  void _initializeControllers() {
    final metadata = _book.metadata;
    _titleController = TextEditingController(text: metadata?.title ?? _book.filename);
    _authorController = TextEditingController(text: metadata?.authorsFormatted ?? '');
    _seriesController = TextEditingController(text: metadata?.series ?? '');
    _seriesPositionController = TextEditingController(text: metadata?.seriesPosition ?? '');
    _descriptionController = TextEditingController(text: metadata?.description ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _book.metadata;
    
    return Container(
      color: const Color(0xFF121212),
      child: Row(
        children: [
          // Left side - Cover and actions
          Container(
            width: 350,
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // Cover Image
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
                    child: metadata?.thumbnailUrl != null && metadata!.thumbnailUrl.isNotEmpty
                        ? Stack(
                            children: [
                              Image.file(
                                File(metadata.thumbnailUrl),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
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
                ),
                
                const SizedBox(height: 24),
                
                // Action buttons
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
                
                // Favorite button
                OutlinedButton.icon(
                  onPressed: _toggleFavorite,
                  icon: Icon(
                    metadata?.isFavorite ?? false ? Icons.favorite : Icons.favorite_border,
                    color: metadata?.isFavorite ?? false ? Colors.red : null,
                  ),
                  label: Text(metadata?.isFavorite ?? false ? 'Favorited' : 'Add to Favorites'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                ),
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
                    
                    const SizedBox(height: 32),
                    
                    // Additional info
                    Container(
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    ));
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
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
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
    final metadata = _book.metadata ?? AudiobookMetadata(
      id: _book.path,
      title: _titleController.text,
      authors: [],
    );
    
    final updatedMetadata = metadata.copyWith(
      title: _titleController.text,
      authors: _authorController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      series: _seriesController.text,
      seriesPosition: _seriesPositionController.text,
      description: _descriptionController.text,
    );
    
    await widget.libraryManager.updateMetadata(_book, updatedMetadata);
    
    setState(() {
      _isEditingMetadata = false;
    });
  }

  Future<void> _toggleFavorite() async {
    await widget.libraryManager.updateUserData(
      _book,
      isFavorite: !(_book.metadata?.isFavorite ?? false),
    );
  }

  Future<void> _changeCoverImage() async {
    // Show dialog to choose between URL or local file
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Change Cover Image', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link, color: Colors.white),
              title: const Text('From URL', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(context).pop('url'),
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: Colors.white),
              title: const Text('From File', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(context).pop('file'),
            ),
            ListTile(
              leading: const Icon(Icons.search, color: Colors.white),
              title: const Text('Search Online', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(context).pop('search'),
            ),
          ],
        ),
      ),
    );
    
    if (choice == null) return;
    
    switch (choice) {
      case 'url':
        _changeCoverFromUrl();
        break;
      case 'file':
        // Implement file picker
        break;
      case 'search':
        // Implement online search
        break;
    }
  }

  Future<void> _changeCoverFromUrl() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Enter Image URL', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'https://...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    
    if (url != null && url.isNotEmpty) {
      await widget.libraryManager.updateCoverImage(_book, url);
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

  // FIXED: Implement play functionality with proper navigation
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
    _titleController.dispose();
    _authorController.dispose();
    _seriesController.dispose();
    _seriesPositionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}