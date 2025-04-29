// File: lib/ui/screens/detail_screen.dart
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path_util;
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/ui/widgets/image_loader_widget.dart';
import 'package:audiobook_organizer/ui/widgets/file_metadata_editor.dart';
import 'package:audiobook_organizer/ui/widgets/manual_metadata_search_dialog.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/services/providers/google_books_provider.dart';
import 'package:audiobook_organizer/services/providers/open_library_provider.dart';

class DetailScreen extends StatefulWidget {
  final AudiobookFile audiobook;
  
  const DetailScreen({
    Key? key,
    required this.audiobook,
  }) : super(key: key);

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isEditing = false;
  late AudiobookFile _book;
  
  @override
  void initState() {
    super.initState();
    _book = widget.audiobook;
    // If no metadata has been extracted yet, try to do it
    if (!_book.hasFileMetadata && !_book.hasMetadata) {
      _extractFileMetadata();
    }
  }
  
  // Extract metadata from the file itself
  Future<void> _extractFileMetadata() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _book.extractFileMetadata();
      
      if (!mounted) return;
      
      setState(() {
        _book = AudiobookFile(
          path: _book.path,
          filename: _book.filename,
          extension: _book.extension,
          size: _book.size,
          lastModified: _book.lastModified,
          metadata: _book.metadata,
          fileMetadata: _book.fileMetadata,
        );
        _hasChanges = true;
        _isLoading = false;
      });

      // Add this line here:
      _refreshBookState();
      
      if (_book.hasFileMetadata) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extracted file metadata for "${_book.displayName}"'),
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to extract file metadata', e);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error extracting file metadata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Find metadata online
  Future<void> _findOnlineMetadata() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get the best search query from existing data
      // We don't use the searchQuery value, so we'll remove it
      
      // Use the matcher service
      final matcher = Provider.of<MetadataMatcher>(context, listen: false);
      final metadata = await matcher.matchFile(_book);
      
      if (!mounted) return;
      
      if (metadata != null) {
        setState(() {
          _book = AudiobookFile(
            path: _book.path,
            filename: _book.filename,
            extension: _book.extension,
            size: _book.size,
            lastModified: _book.lastModified,
            metadata: metadata,
            fileMetadata: _book.fileMetadata,
          );
          _hasChanges = true;
        });
        
        // Add this line here:
        _refreshBookState();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found metadata for "${metadata.title}"'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No matching metadata found online'),
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to find online metadata', e);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding online metadata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Manual search for metadata
  Future<void> _manualSearch() async {
    try {
      // Get all providers before async operations
      final googleProvider = Provider.of<GoogleBooksProvider>(context, listen: false);
      final openLibraryProvider = Provider.of<OpenLibraryProvider>(context, listen: false);
      final matcher = Provider.of<MetadataMatcher>(context, listen: false);
      
      // Create initial search query from existing metadata or filename
      String initialQuery = '';
      
      if (_book.hasFileMetadata) {
        initialQuery = '${_book.fileMetadata!.title} ${_book.fileMetadata!.primaryAuthor}';
      } else if (_book.hasMetadata) {
        initialQuery = '${_book.metadata!.title} ${_book.metadata!.primaryAuthor}';
      } else {
        initialQuery = _book.generateSearchQuery();
      }
      
      // Show manual search dialog
      final result = await ManualMetadataSearchDialog.show(
        context: context,
        initialQuery: initialQuery,
        providers: [googleProvider, openLibraryProvider],
      );
      
      if (result != null && mounted) {
        Logger.log('Selected metadata: ${result.title} with thumbnail: ${result.thumbnailUrl}');
        
        // Create a copy of the selected metadata to ensure we're working with a new instance
        final selectedMetadata = AudiobookMetadata(
          id: result.id,
          title: result.title,
          authors: List<String>.from(result.authors),
          description: result.description,
          publisher: result.publisher,
          publishedDate: result.publishedDate,
          categories: List<String>.from(result.categories),
          averageRating: result.averageRating,
          ratingsCount: result.ratingsCount,
          thumbnailUrl: result.thumbnailUrl,
          language: result.language,
          series: result.series,
          seriesPosition: result.seriesPosition,
          provider: result.provider,
        );
        // Save to metadata cache for future use
        await matcher.saveMetadataToCache(_book.path, selectedMetadata);
        
        if (!mounted) return;
        
        // Update the book state with the new metadata
        setState(() {
          _book = AudiobookFile(
            path: _book.path,
            filename: _book.filename,
            extension: _book.extension,
            size: _book.size,
            lastModified: _book.lastModified,
            metadata: selectedMetadata,
            fileMetadata: _book.fileMetadata,
          );
          _hasChanges = true;
        });

        // Add this line here:
        _refreshBookState();

        // Show a confirmation message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected metadata for "${selectedMetadata.title}"'),
            duration: const Duration(seconds: 4),
          ),
        );
        
        // Offer to save to file automatically
        _offerToSaveMetadata(selectedMetadata);
      }
    } catch (e) {
      Logger.error('Failed in manual metadata search', e);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in manual search: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _offerToSaveMetadata(AudiobookMetadata metadata) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Would you like to save this metadata to the file?'),
        action: SnackBarAction(
          label: 'SAVE',
          onPressed: () {
            _saveMetadataToFile();
          },
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }

  void _refreshBookState() {
    setState(() {
      _book = AudiobookFile(
        path: _book.path,
        filename: _book.filename,
        extension: _book.extension,
        size: _book.size,
        lastModified: _book.lastModified,
        metadata: _book.metadata,
        fileMetadata: _book.fileMetadata,
      );
    });
  }

  Future<void> _saveMetadataToFile() async {
    final metadataToSave = _book.metadata ?? _book.fileMetadata;
    if (metadataToSave == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await _book.writeMetadataToFile(metadataToSave);
      
      if (!mounted) return;
      
      setState(() {
        _book = AudiobookFile(
          path: _book.path,
          filename: _book.filename,
          extension: _book.extension,
          size: _book.size,
          lastModified: _book.lastModified,
          metadata: _book.metadata,
          fileMetadata: metadataToSave, // Update file metadata to match
        );
        _hasChanges = true;
        _isLoading = false;
      });
      
      // Add this line here:
      _refreshBookState();
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metadata saved to file successfully'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save metadata to file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to save metadata to file', e);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving metadata to file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Handle metadata updates from the editor
  void _handleMetadataUpdated(AudiobookMetadata metadata) {
    setState(() {
      _book = AudiobookFile(
        path: _book.path,
        filename: _book.filename,
        extension: _book.extension,
        size: _book.size,
        lastModified: _book.lastModified,
        metadata: metadata,
        fileMetadata: _book.fileMetadata,
      );
      _hasChanges = true;
      _isEditing = false;
    });
    
    // Save updates to file
    _saveMetadataToFile();
  }
  
  @override
  Widget build(BuildContext context) {
    // Determine which metadata to display
    // Priority: editing state > file metadata (if complete) > online metadata > file metadata (incomplete)
    final displayMetadata = _getDisplayMetadata();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Details'),
        actions: [
          // Only show find metadata button if not editing
          if (!_isEditing) ...[
            // Metadata extraction button
            if (!_book.hasFileMetadata)
              TextButton.icon(
                onPressed: _isLoading ? null : _extractFileMetadata,
                icon: const Icon(Icons.file_copy),
                label: const Text('Extract from File'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
              ),
              
            // Online search button
            TextButton.icon(
              onPressed: _isLoading ? null : _findOnlineMetadata,
              icon: const Icon(Icons.search),
              label: const Text('Find Online'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
            
            // Manual search button
            IconButton(
              onPressed: _isLoading ? null : _manualSearch,
              icon: const Icon(Icons.manage_search),
              tooltip: 'Manual Search',
            ),
            
            // Edit button
            IconButton(
              onPressed: _isLoading ? null : () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Metadata',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isEditing
              ? _buildEditorView()
              : displayMetadata == null
                  ? _buildNoMetadataView()
                  : _buildDetailView(displayMetadata),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side - source indicator
              if (displayMetadata != null)
                Text(
                  'Source: ${displayMetadata.provider}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              
              // Right side - action buttons
              Row(
                children: [
                  if (_isEditing)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                        });
                      },
                      child: const Text('CANCEL'),
                    ),
                  if (!_isEditing && displayMetadata != null && (!_book.hasFileMetadata || _book.fileMetadata != displayMetadata))
                    TextButton.icon(
                      onPressed: _isLoading ? null : _saveMetadataToFile,
                      icon: const Icon(Icons.save),
                      label: const Text('Save to File'),
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _hasChanges),
                    child: const Text('BACK'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Determine which metadata to display based on priority rules
  AudiobookMetadata? _getDisplayMetadata() {
    // If we have file metadata and it's complete, use it
    if (_book.hasFileMetadata && _isFileMetadataComplete(_book.fileMetadata!)) {
      return _book.fileMetadata;
    }
    
    // Otherwise, prefer online metadata if available
    if (_book.hasMetadata) {
      return _book.metadata;
    }
    
    // Fall back to file metadata even if incomplete
    if (_book.hasFileMetadata) {
      return _book.fileMetadata;
    }
    
    // No metadata available
    return null;
  }
  
  // Check if file metadata is complete enough to display
  bool _isFileMetadataComplete(AudiobookMetadata metadata) {
    return metadata.title.isNotEmpty && 
           metadata.authors.isNotEmpty &&
           (metadata.description.isNotEmpty || 
            metadata.series.isNotEmpty || 
            metadata.publishedDate.isNotEmpty);
  }
  
  Widget _buildNoMetadataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No metadata available for this book',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try one of the options below:',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _extractFileMetadata,
                icon: const Icon(Icons.file_copy),
                label: const Text('Extract from File'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _findOnlineMetadata,
                icon: const Icon(Icons.search),
                label: const Text('Find Online'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _manualSearch,
            icon: const Icon(Icons.manage_search),
            label: const Text('Manual Search'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEditorView() {
    // Use the FileMetadataEditor widget to edit metadata
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FileMetadataEditor(
            file: _book,
            onMetadataUpdated: _handleMetadataUpdated,
            onSearchRequested: (query) async {
              // Exit edit mode and trigger manual search
              setState(() {
                _isEditing = false;
              });
              await _manualSearch();
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailView(AudiobookMetadata metadata) {
    final theme = Theme.of(context);
    final bool isFromFile = _book.hasFileMetadata && metadata == _book.fileMetadata;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main info card with cover
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image and basic info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover image
                    SizedBox(
                      width: 150,
                      height: 225,
                      child: metadata.thumbnailUrl.isNotEmpty
                          ? Hero(
                              tag: 'book-cover-${_book.path}',
                              child: BookCoverImage(
                                imageUrl: metadata.thumbnailUrl,
                                bookTitle: metadata.title,
                                width: 150,
                                height: 225,
                              ),
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: Center(
                                child: Icon(
                                  Icons.book,
                                  size: 64,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                    ),
                    
                    // Basic info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Metadata source badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isFromFile 
                                    ? Colors.green.withAlpha(51) 
                                    : Colors.blue.withAlpha(51),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isFromFile ? 'File Metadata' : 'Online Metadata',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isFromFile ? Colors.green[800] : Colors.blue[800],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            Text(
                              metadata.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'by ${metadata.authorsFormatted}',
                              style: theme.textTheme.titleMedium,
                            ),
                            
                            if (metadata.series.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(21),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  metadata.seriesPosition.isNotEmpty
                                      ? '${metadata.series} #${metadata.seriesPosition}'
                                      : metadata.series,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            
                            if (metadata.publishedDate.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Published: ${metadata.publishedDate}'),
                            ],
                            
                            if (metadata.publisher.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Publisher: ${metadata.publisher}'),
                            ],
                            
                            if (metadata.categories.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: metadata.categories
                                    .map((category) => Chip(
                                          label: Text(category),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          labelStyle: const TextStyle(fontSize: 12),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Description
                if (metadata.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          metadata.description,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // File information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'File Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  _buildInfoRow('Filename:', '${_book.filename}${_book.extension}'),
                  _buildInfoRow('Size:', _formatFileSize(_book.size)),
                  _buildInfoRow(
                    'Path:', 
                    path_util.dirname(_book.path)
                  ),
                  _buildInfoRow(
                    'Last Modified:', 
                    _book.lastModified.toString().split('.')[0]
                  ),
                  _buildInfoRow(
                    'File Metadata:', 
                    _book.hasFileMetadata ? 'Available' : 'Not extracted'
                  ),
                  _buildInfoRow(
                    'Online Metadata:', 
                    _book.hasMetadata ? 'Available' : 'Not found'
                  ),
                  _buildInfoRow(
                    'Current Source:', 
                    metadata.provider
                  ),
                ],
              ),
            ),
          ),
          
          // Metadata comparison (if both sources exist)
          if (_book.hasFileMetadata && _book.hasMetadata)
            _buildMetadataComparisonCard(),
        ],
      ),
    );
  }
  
  Widget _buildMetadataComparisonCard() {
    final theme = Theme.of(context);
    final fileMetadata = _book.fileMetadata!;
    final onlineMetadata = _book.metadata!;
    
    // Only show if there are actual differences
    if (_areMetadataEqual(fileMetadata, onlineMetadata)) {
      return const SizedBox.shrink();
    }
    
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Metadata Comparison',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            if (fileMetadata.title != onlineMetadata.title)
              _buildComparisonRow('Title', fileMetadata.title, onlineMetadata.title),
            if (fileMetadata.authorsFormatted != onlineMetadata.authorsFormatted)
              _buildComparisonRow('Author(s)', fileMetadata.authorsFormatted, onlineMetadata.authorsFormatted),
            if (fileMetadata.series != onlineMetadata.series)
              _buildComparisonRow('Series', fileMetadata.series, onlineMetadata.series),
            if (fileMetadata.seriesPosition != onlineMetadata.seriesPosition)
              _buildComparisonRow('Series Position', fileMetadata.seriesPosition, onlineMetadata.seriesPosition),
            if (fileMetadata.publishedDate != onlineMetadata.publishedDate)
              _buildComparisonRow('Published Date', fileMetadata.publishedDate, onlineMetadata.publishedDate),
            if (fileMetadata.publisher != onlineMetadata.publisher)
              _buildComparisonRow('Publisher', fileMetadata.publisher, onlineMetadata.publisher),
          ],
        ),
      ),
    );
  }
  
  bool _areMetadataEqual(AudiobookMetadata a, AudiobookMetadata b) {
    return a.title == b.title && 
           a.authorsFormatted == b.authorsFormatted &&
           a.series == b.series &&
           a.seriesPosition == b.seriesPosition &&
           a.publishedDate == b.publishedDate &&
           a.publisher == b.publisher;
  }
  
  Widget _buildComparisonRow(String label, String fileValue, String onlineValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(21),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(fileValue.isEmpty ? '(empty)' : fileValue),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(21),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Online:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(onlineValue.isEmpty ? '(empty)' : onlineValue),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}