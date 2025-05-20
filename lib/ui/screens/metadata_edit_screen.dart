// lib/ui/screens/metadata_edit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audiobook_organizer/ui/widgets/manual_metadata_search_dialog.dart';
import 'package:audiobook_organizer/services/providers/google_books_provider.dart';
import 'package:audiobook_organizer/services/providers/open_library_provider.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class MetadataEditScreen extends StatefulWidget {
  final AudiobookFile file;
  
  const MetadataEditScreen({Key? key, required this.file}) : super(key: key);
  
  @override
  _MetadataEditScreenState createState() => _MetadataEditScreenState();
}

class _MetadataEditScreenState extends State<MetadataEditScreen> {
  // Form key
  final _formKey = GlobalKey<FormState>();
  
  // Text controllers
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _descriptionController;
  late TextEditingController _publisherController;
  late TextEditingController _publishDateController;
  late TextEditingController _seriesController;
  late TextEditingController _seriesPositionController;
  late TextEditingController _tagsController;
  
  // Rating
  int _userRating = 0;
  
  // Loading state
  bool _isLoading = false;
  bool _isSearching = false;
  
  // Online search results
  List<AudiobookMetadata> _searchResults = [];
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with current metadata
    final metadata = widget.file.metadata;
    
    _titleController = TextEditingController(text: metadata?.title ?? widget.file.filename);
    _authorController = TextEditingController(text: metadata?.authors.join(', ') ?? '');
    _descriptionController = TextEditingController(text: metadata?.description ?? '');
    _publisherController = TextEditingController(text: metadata?.publisher ?? '');
    _publishDateController = TextEditingController(text: metadata?.publishedDate ?? '');
    _seriesController = TextEditingController(text: metadata?.series ?? '');
    _seriesPositionController = TextEditingController(text: metadata?.seriesPosition ?? '');
    _tagsController = TextEditingController(text: metadata?.userTags.join(', ') ?? '');
    
    _userRating = metadata?.userRating ?? 0;
  }
  
  @override
  void dispose() {
    // Dispose controllers
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _publisherController.dispose();
    _publishDateController.dispose();
    _seriesController.dispose();
    _seriesPositionController.dispose();
    _tagsController.dispose();
    
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Metadata'),
        actions: [
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Online',
            onPressed: () => _showSearchDialog(context),
          ),
          
          // Save button
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: _saveMetadata,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: _buildForm(),
            ),
    );
  }
  
  // Build the form
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          _buildCoverImageSection(),
          
          const SizedBox(height: 24),
          
          // Title field
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Author field
          TextFormField(
            controller: _authorController,
            decoration: const InputDecoration(
              labelText: 'Author(s)',
              border: OutlineInputBorder(),
              hintText: 'Separate multiple authors with commas',
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Series section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Series name
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _seriesController,
                  decoration: const InputDecoration(
                    labelText: 'Series',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Series position
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _seriesPositionController,
                  decoration: const InputDecoration(
                    labelText: 'Book #',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Description field
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
          
          const SizedBox(height: 16),
          
          // Publisher info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Publisher
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _publisherController,
                  decoration: const InputDecoration(
                    labelText: 'Publisher',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Publication date
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _publishDateController,
                  decoration: const InputDecoration(
                    labelText: 'Publication Date',
                    border: OutlineInputBorder(),
                    hintText: 'YYYY-MM-DD',
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Tags field
          TextFormField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: 'Tags',
              border: OutlineInputBorder(),
              hintText: 'Separate tags with commas',
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Rating
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Rating',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _userRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        // Toggle rating if clicking the same star
                        if (_userRating == index + 1) {
                          _userRating = 0;
                        } else {
                          _userRating = index + 1;
                        }
                      });
                    },
                  );
                }),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Save button
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              onPressed: _saveMetadata,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build cover image section
  Widget _buildCoverImageSection() {
    final metadata = widget.file.metadata;
    
    return Center(
      child: Column(
        children: [
          // Cover image
          Container(
            width: 180,
            height: 240,
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: metadata?.thumbnailUrl.isNotEmpty == true
                ? Image.file(
                    File(metadata!.thumbnailUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildCoverPlaceholder();
                    },
                  )
                : _buildCoverPlaceholder(),
          ),
          
          const SizedBox(height: 16),
          
          // Change cover button
          TextButton.icon(
            icon: const Icon(Icons.photo),
            label: const Text('Change Cover'),
            onPressed: _changeCover,
          ),
        ],
      ),
    );
  }
  
  // Cover placeholder
  Widget _buildCoverPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.book, size: 64, color: Colors.grey),
        SizedBox(height: 8),
        Text(
          'No Cover',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
  
  // Change cover image
  void _changeCover() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Select from Gallery'),
            onTap: () async {
              Navigator.pop(context);
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.gallery);
              
              if (pickedFile != null) {
                _updateCoverImage(pickedFile.path);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Search Online'),
            onTap: () {
              Navigator.pop(context);
              _showSearchCoversDialog(context);
            },
          ),
        ],
      ),
    );
  }
  
  // Update cover image
  Future<void> _updateCoverImage(String imagePath) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final libraryManager = Provider.of<LibraryManager>(context, listen: false);
      
      final success = await libraryManager.updateCoverImage(widget.file, imagePath);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cover image updated'),
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
      Logger.error('Error updating cover image', e);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating cover image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Show search dialog
  void _showSearchDialog(BuildContext context) async {
    // Create providers
    final googleProvider = GoogleBooksProvider(apiKey: '');
    final openLibraryProvider = OpenLibraryProvider();
    
    // Show the dialog and wait for result
    final selectedMetadata = await ManualMetadataSearchDialog.show(
      context: context,
      initialQuery: _titleController.text,
      providers: [googleProvider, openLibraryProvider],
    );
    
    // If metadata was selected, apply it
    if (selectedMetadata != null) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        _applyMetadataFromSearch(selectedMetadata);
      } finally {
        // We'll set loading to false in _applyMetadataFromSearch after download completes
      }
    }
  }
  
  // Perform search
  Future<void> _performSearch(String query, StateSetter dialogSetState) async {
    if (query.isEmpty) return;
    
    dialogSetState(() {
      _isSearching = true;
      _searchResults = [];
    });
    
    try {
      // Create providers
      final googleProvider = GoogleBooksProvider(apiKey: '');
      final openLibraryProvider = OpenLibraryProvider();
      
      // Search with both providers
      final googleResults = await googleProvider.search(query);
      final openLibraryResults = await openLibraryProvider.search(query);
      
      // Combine results
      final results = [...googleResults, ...openLibraryResults];
      
      // Update state
      dialogSetState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      Logger.error('Error searching for metadata', e);
      
      dialogSetState(() {
        _isSearching = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching for metadata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Apply metadata from search result
  void _applyMetadataFromSearch(AudiobookMetadata result) async {
    setState(() {
      _titleController.text = result.title;
      _authorController.text = result.authors.join(', ');
      _descriptionController.text = result.description;
      _publisherController.text = result.publisher;
      _publishDateController.text = result.publishedDate;
      _seriesController.text = result.series;
      _seriesPositionController.text = result.seriesPosition;
      _userRating = result.userRating;
    });
    
    try {
      // Create a copy of metadata for saving
      final currentMetadata = widget.file.metadata;
      
      // Create updated metadata with result data but preserve user data
      final updatedMetadata = AudiobookMetadata(
        id: currentMetadata?.id ?? widget.file.path,
        title: result.title,
        authors: result.authors,
        description: result.description,
        publisher: result.publisher,
        publishedDate: result.publishedDate,
        categories: result.categories,
        averageRating: result.averageRating,
        ratingsCount: result.ratingsCount,
        thumbnailUrl: currentMetadata?.thumbnailUrl ?? '', // Keep existing thumbnail for now
        language: result.language,
        series: result.series,
        seriesPosition: result.seriesPosition,
        audioDuration: currentMetadata?.audioDuration,
        bitrate: currentMetadata?.bitrate,
        channels: currentMetadata?.channels,
        sampleRate: currentMetadata?.sampleRate,
        fileFormat: currentMetadata?.fileFormat ?? '',
        provider: result.provider,
        userRating: _userRating,
        lastPlayedPosition: currentMetadata?.lastPlayedPosition,
        playbackPosition: currentMetadata?.playbackPosition,
        userTags: currentMetadata?.userTags ?? [],
        isFavorite: currentMetadata?.isFavorite ?? false,
        bookmarks: currentMetadata?.bookmarks ?? [],
        notes: currentMetadata?.notes ?? [],
      );
      
      // First save the metadata
      final libraryManager = Provider.of<LibraryManager>(context, listen: false);
      final success = await libraryManager.updateMetadata(widget.file, updatedMetadata);
      
      if (success && result.thumbnailUrl.isNotEmpty) {
        // Now download and update the cover image if available
        await _downloadCoverImage(result.thumbnailUrl);
      }
      
      // Notify user of success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Metadata updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Logger.error('Error applying metadata from search', e);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error applying metadata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadCoverImage(String imageUrl) async {
    try {
      if (imageUrl.isEmpty) {
        Logger.warning('Empty image URL provided');
        return;
      }
      
      Logger.debug('Downloaded image to: $imageUrl');
      Logger.log('Updating cover image: ${widget.file.filename} with URL: $imageUrl');
      
      // Create a temporary file only if needed (for web URLs)
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
        
        // Download the image
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode != 200) {
          Logger.warning('Failed to download image: ${response.statusCode}');
          return;
        }
        
        // Write the image to the file
        await tempFile.writeAsBytes(response.bodyBytes);
        Logger.debug('Downloaded image to: ${tempFile.path}');
        
        // Use this temp file path for the update
        _updateCoverImage(tempFile.path);
      } else {
        // It's already a local file path, use it directly
        _updateCoverImage(imageUrl);
      }
    } catch (e) {
      Logger.error('Error downloading cover image', e);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading cover image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Show search covers dialog
  void _showSearchCoversDialog(BuildContext context) async {
    // Create providers
    final googleProvider = GoogleBooksProvider(apiKey: '');
    final openLibraryProvider = OpenLibraryProvider();
    
    // Show the dialog and wait for result
    final selectedMetadata = await ManualMetadataSearchDialog.show(
      context: context,
      initialQuery: _titleController.text,
      providers: [googleProvider, openLibraryProvider],
    );
    
    // If metadata was selected, update the cover image
    if (selectedMetadata != null && selectedMetadata.thumbnailUrl.isNotEmpty) {
      _updateCoverImage(selectedMetadata.thumbnailUrl);
    }
  }
  
  // Save metadata
  Future<void> _saveMetadata() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final libraryManager = Provider.of<LibraryManager>(context, listen: false);
      
      // Parse authors from comma-separated string
      final authors = _authorController.text
          .split(',')
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList();
      
      // Parse tags from comma-separated string
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      
      // Create updated metadata
      final currentMetadata = widget.file.metadata;
      
      final updatedMetadata = AudiobookMetadata(
        id: currentMetadata?.id ?? widget.file.path,
        title: _titleController.text,
        authors: authors,
        description: _descriptionController.text,
        publisher: _publisherController.text,
        publishedDate: _publishDateController.text,
        categories: currentMetadata?.categories ?? [],
        averageRating: currentMetadata?.averageRating ?? 0.0,
        ratingsCount: currentMetadata?.ratingsCount ?? 0,
        thumbnailUrl: currentMetadata?.thumbnailUrl ?? '',
        language: currentMetadata?.language ?? '',
        series: _seriesController.text,
        seriesPosition: _seriesPositionController.text,
        audioDuration: currentMetadata?.audioDuration,
        bitrate: currentMetadata?.bitrate,
        channels: currentMetadata?.channels,
        sampleRate: currentMetadata?.sampleRate,
        fileFormat: currentMetadata?.fileFormat ?? '',
        provider: 'User edited',
        userRating: _userRating,
        lastPlayedPosition: currentMetadata?.lastPlayedPosition,
        playbackPosition: currentMetadata?.playbackPosition,
        userTags: tags,
        isFavorite: currentMetadata?.isFavorite ?? false,
        bookmarks: currentMetadata?.bookmarks ?? [],
        notes: currentMetadata?.notes ?? [],
      );
      
      // Save metadata
      final success = await libraryManager.updateMetadata(
        widget.file,
        updatedMetadata,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metadata saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save metadata'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error saving metadata', e);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving metadata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}