// File: lib/ui/screens/file_detail_screen.dart
// Updated version with the fixed ManualMetadataSearchDialog implementation

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/services/providers/google_books_provider.dart';
import 'package:audiobook_organizer/services/providers/open_library_provider.dart';
import 'package:audiobook_organizer/ui/widgets/file_metadata_editor.dart';
import 'package:audiobook_organizer/ui/widgets/manual_metadata_search_dialog.dart';
import 'package:audiobook_organizer/utils/metadata_manager.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class FileDetailScreen extends StatefulWidget {
  final AudiobookFile file;
  
  const FileDetailScreen({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  State<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends State<FileDetailScreen> {
  bool _isLoading = false;
  bool _hasChanges = false;
  late AudiobookFile _file;
  
  @override
  void initState() {
    super.initState();
    // Create a copy of the file to work with
    _file = AudiobookFile(
      path: widget.file.path,
      filename: widget.file.filename,
      extension: widget.file.extension,
      size: widget.file.size,
      lastModified: widget.file.lastModified,
      metadata: widget.file.metadata,
      fileMetadata: widget.file.fileMetadata,
    );
    
    // Extract metadata if not already done
    if (!_file.hasAnyMetadata) {
      _extractFileMetadata();
    }
  }
  
  Future<void> _extractFileMetadata() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final fileMetadata = await _file.extractFileMetadata();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('ERROR: Failed to extract file metadata: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error extracting file metadata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _searchOnlineMetadata(String query) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final googleProvider = Provider.of<GoogleBooksProvider>(context, listen: false);
      final openLibraryProvider = Provider.of<OpenLibraryProvider>(context, listen: false);
      
      List<MetadataProvider> providers = [googleProvider, openLibraryProvider];
      
      // Show the dialog and wait for a result
      final result = await ManualMetadataSearchDialog.show(
        context: context,
        initialQuery: query,
        providers: providers,
      );
      
      // Check if we got a result (not canceled)
      if (result != null) {
        Logger.log('Selected metadata for "${result.title}" - thumbnail: ${result.thumbnailUrl}');
        
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
        
        // Update the file with the selected metadata
        setState(() {
          _file = AudiobookFile(
            path: _file.path,
            filename: _file.filename,
            extension: _file.extension,
            size: _file.size,
            lastModified: _file.lastModified,
            metadata: selectedMetadata,
            fileMetadata: _file.fileMetadata,
          );
          _hasChanges = true;
        });
        
        // Save to cache for future use
        final matcher = Provider.of<MetadataMatcher>(context, listen: false);
        await matcher.saveMetadataToCache(_file.path, selectedMetadata);
        
        // Immediately save to file to persist the changes
        await _saveMetadataToFile(selectedMetadata);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Metadata for "${selectedMetadata.title}" applied successfully'),
            ),
          );
        }
        
        // Check if file now has complete metadata
        if (MetadataManager.isMetadataComplete(selectedMetadata)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File now has complete metadata and will be moved to the Library'),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('ERROR: Failed to search for metadata: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching for metadata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _refreshBookState() {
    setState(() {
      _file = AudiobookFile(
        path: _file.path,
        filename: _file.filename,
        extension: _file.extension,
        size: _file.size,
        lastModified: _file.lastModified,
        metadata: _file.metadata,
        fileMetadata: _file.fileMetadata,
      );
    });
  }

  Future<void> _automaticallyFindMetadata() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final matcher = Provider.of<MetadataMatcher>(context, listen: false);
      final metadata = await matcher.matchFile(_file);
      
      if (metadata != null) {
        setState(() {
          _file = AudiobookFile(
            path: _file.path,
            filename: _file.filename,
            extension: _file.extension,
            size: _file.size,
            lastModified: _file.lastModified,
            metadata: metadata,
            fileMetadata: _file.fileMetadata,
          );
          _hasChanges = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found metadata for "${metadata.title}"'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No matching metadata found'),
            ),
          );
        }
      }
    } catch (e) {
      print('ERROR: Failed to find metadata: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding metadata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveMetadataToFile(AudiobookMetadata metadata) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await _file.writeMetadataToFile(metadata);
      
      if (success) {
        setState(() {
          _file = AudiobookFile(
            path: _file.path,
            filename: _file.filename,
            extension: _file.extension,
            size: _file.size,
            lastModified: _file.lastModified,
            metadata: metadata,
            fileMetadata: metadata, // Update file metadata as well
          );
          _hasChanges = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Metadata saved to file successfully'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save metadata to file'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('ERROR: Failed to save metadata to file: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving metadata to file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _handleMetadataUpdated(AudiobookMetadata metadata) {
    setState(() {
      _file = AudiobookFile(
        path: _file.path,
        filename: _file.filename,
        extension: _file.extension,
        size: _file.size,
        lastModified: _file.lastModified,
        metadata: metadata,
        fileMetadata: _file.fileMetadata,
      );
      _hasChanges = true;
    });
    
    // Save updates to file
    _saveMetadataToFile(metadata);
    
    // Check if this file now has complete metadata
    if (MetadataManager.isMetadataComplete(metadata)) {
      // Let the user know this file is ready for the library
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File now has complete metadata and will be moved to the Library'),
        ),
      );
    }
  }
  
  void _handleSearchRequested(String query) {
    _searchOnlineMetadata(query);
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit File Metadata'),
        actions: [
          // Find metadata button
          TextButton.icon(
            onPressed: _isLoading ? null : _automaticallyFindMetadata,
            icon: const Icon(Icons.search),
            label: const Text('Find Metadata'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File info card
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
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
                          _buildInfoRow('Path:', _file.path),
                          _buildInfoRow('Size:', _formatFileSize(_file.size)),
                          _buildInfoRow(
                            'Last Modified:', 
                            _file.lastModified.toString().split('.')[0]
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Metadata editor
                  FileMetadataEditor(
                    file: _file,
                    onMetadataUpdated: _handleMetadataUpdated,
                    onSearchRequested: _handleSearchRequested,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _hasChanges 
                    ? () => Navigator.pop(context, true) 
                    : null,
                child: const Text('SAVE CHANGES'),
              ),
            ],
          ),
        ),
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
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
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