// File: lib/widgets/book_detail_panel.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/ui/widgets/metadata_search.dart';
import 'package:audiobook_organizer/utils/metadata_manager.dart';
import 'package:path/path.dart' as path_util;
import 'dart:io';

class BookDetailPanel extends StatefulWidget {
  final AudiobookFile book;
  final VoidCallback onClose;
  final Function(AudiobookMetadata) onUpdateMetadata;

  const BookDetailPanel({
    Key? key,
    required this.book,
    required this.onClose,
    required this.onUpdateMetadata,
  }) : super(key: key);

  @override
  State<BookDetailPanel> createState() => _BookDetailPanelState();
}

class _BookDetailPanelState extends State<BookDetailPanel> {
  // Add state variable for metadata
  AudiobookMetadata? _currentMetadata;

  @override
  void initState() {
    super.initState();
    // Initialize the current metadata
    _currentMetadata = widget.book.metadata ?? widget.book.fileMetadata;
  }

  void _updateMetadata(AudiobookMetadata newMetadata) {
    // Update the local state first
    setState(() {
      _currentMetadata = newMetadata;
    });
    
    // Then notify the parent widget about the update
    widget.onUpdateMetadata(newMetadata);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onClose,
        ),
        title: const Text('Book Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Metadata',
            onPressed: () {
              _showEditDialog(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book header with cover and basic info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book cover
                  _buildCover(_currentMetadata),
                  
                  const SizedBox(width: 16),
                  
                  // Book info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          _currentMetadata?.title ?? widget.book.displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Author
                        if (_currentMetadata?.authorsFormatted != 'Unknown Author' || widget.book.author != 'Unknown Author')
                          Text(
                            'by ${_currentMetadata?.authorsFormatted ?? widget.book.author}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        
                        const SizedBox(height: 16),
                        
                        // Series info
                        if (_currentMetadata != null && _currentMetadata!.series.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.bookmark, size: 18),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'Series: ',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        TextSpan(text: _currentMetadata!.series),
                                        if (_currentMetadata!.seriesPosition.isNotEmpty)
                                          TextSpan(
                                            text: ' (Book ${_currentMetadata!.seriesPosition})',
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Rating
                        if (_currentMetadata != null && _currentMetadata!.averageRating > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                _buildStarRating(_currentMetadata!.averageRating),
                                const SizedBox(width: 8),
                                Text(
                                  '${_currentMetadata!.averageRating.toStringAsFixed(1)} (${_currentMetadata!.ratingsCount} ratings)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Categories/Genres
                        if (_currentMetadata != null && _currentMetadata!.categories.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _currentMetadata!.categories.map((category) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          
                        // Publisher & Date
                        if (_currentMetadata != null && 
                           (_currentMetadata!.publisher.isNotEmpty || _currentMetadata!.publishedDate.isNotEmpty))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.business, size: 18),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    [
                                      if (_currentMetadata!.publisher.isNotEmpty) _currentMetadata!.publisher,
                                      if (_currentMetadata!.publishedDate.isNotEmpty) _currentMetadata!.publishedDate,
                                    ].join(', '),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Audio quality info
                        if (_currentMetadata != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.headphones, size: 18),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _getAudioQualityText(_currentMetadata!),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Provider info
                        if (_currentMetadata != null && _currentMetadata!.provider.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 18),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Metadata from: ${_currentMetadata!.provider}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Description section
              if (_currentMetadata != null && _currentMetadata!.description.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentMetadata!.description,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              
              // File details section
              const Text(
                'File Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildFileDetailItem('Filename', path_util.basename(widget.book.path)),
              _buildFileDetailItem('Location', path_util.dirname(widget.book.path)),
              _buildFileDetailItem('Format', widget.book.extension.toUpperCase().replaceAll('.', '')),
              _buildFileDetailItem('Size', _formatFileSize(widget.book.size)),
              _buildFileDetailItem('Last Modified', _formatDate(widget.book.lastModified)),
            ],
          ),
        ),
      ),
    );
  }

  String _getAudioQualityText(AudiobookMetadata metadata) {
    List<String> info = [];
    
    if (metadata.audioDuration != null && metadata.audioDuration!.isNotEmpty) {
      info.add('Length: ${metadata.audioDuration}');
    }
    
    if (metadata.bitrate != null && metadata.bitrate!.isNotEmpty) {
      info.add(metadata.bitrate!);
    }
    
    if (metadata.channels != null) {
      info.add(metadata.channels == 2 ? 'Stereo' : 'Mono');
    }
    
    if (info.isEmpty) {
      return 'Audio quality information not available';
    }
    
    return info.join(' · ');
  }

  Widget _buildCover(AudiobookMetadata? metadata) {
    String? coverUrl = metadata?.thumbnailUrl;
    
    return Container(
      width: 180,
      height: 270,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(2, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: coverUrl != null && coverUrl.isNotEmpty
            ? _buildCoverImage(coverUrl)
            : _buildCoverPlaceholder(),
      ),
    );
  }

  Widget _buildCoverImage(String coverUrl) {
    // Check if the cover URL is a local file path
    if (coverUrl.startsWith('/') || coverUrl.contains(':\\')) {
      final file = File(coverUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildCoverPlaceholder(),
        );
      }
      return _buildCoverPlaceholder();
    } 
    
    // Otherwise treat as a network URL
    return Image.network(
      coverUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / 
                  loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildCoverPlaceholder(),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.audiotrack,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            const Text(
              'No Cover',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    final fullStars = rating.floor();
    final halfStar = (rating - fullStars) >= 0.5;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return const Icon(Icons.star, color: Colors.amber, size: 20);
        } else if (index == fullStars && halfStar) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 20);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 20);
        }
      }),
    );
  }

  Widget _buildFileDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
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
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Book Metadata'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How would you like to update the metadata?'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search Online'),
                subtitle: const Text('Find this book in online databases'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showMetadataSearch(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Manual Edit'),
                subtitle: const Text('Edit metadata fields manually'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showManualEditDialog(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _showMetadataSearch(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 800,
            height: 600,
            padding: const EdgeInsets.all(16),
            child: MetadataSearch(
              initialQuery: widget.book.generateSearchQuery(),
              onSelectMetadata: (metadata) {
                Navigator.of(context).pop();
                // Update the metadata with audio quality preserved
                _updateMetadataWithQualityPreserved(metadata);
              },
              onCancel: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }
  
  void _updateMetadataWithQualityPreserved(AudiobookMetadata newMetadata) {
    // If we have current metadata with audio quality info, preserve it
    if (_currentMetadata != null) {
      final mergedMetadata = MetadataManager.mergeMetadata(_currentMetadata!, newMetadata);
      _updateMetadata(mergedMetadata);
    } else {
      // No current metadata to merge with
      _updateMetadata(newMetadata);
    }
  }
  
  void _showManualEditDialog(BuildContext context) {
    // Get current metadata values to pre-fill
    final currentMetadata = _currentMetadata;
    
    // Controllers for text fields
    final titleController = TextEditingController(
      text: currentMetadata?.title ?? widget.book.displayName
    );
    final authorController = TextEditingController(
      text: currentMetadata?.authors.isNotEmpty ?? false 
          ? currentMetadata!.authors.join(', ') 
          : widget.book.author
    );
    final seriesController = TextEditingController(
      text: currentMetadata?.series ?? ''
    );
    final seriesPositionController = TextEditingController(
      text: currentMetadata?.seriesPosition ?? ''
    );
    final publisherController = TextEditingController(
      text: currentMetadata?.publisher ?? ''
    );
    final yearController = TextEditingController(
      text: currentMetadata?.year ?? ''
    );
    final descriptionController = TextEditingController(
      text: currentMetadata?.description ?? ''
    );
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 600,
            height: 500,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Metadata',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: authorController,
                        decoration: const InputDecoration(
                          labelText: 'Author(s)',
                          border: OutlineInputBorder(),
                          helperText: 'Separate multiple authors with commas',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: seriesController,
                              decoration: const InputDecoration(
                                labelText: 'Series',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: seriesPositionController,
                              decoration: const InputDecoration(
                                labelText: 'Book #',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: publisherController,
                              decoration: const InputDecoration(
                                labelText: 'Publisher',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: yearController,
                              decoration: const InputDecoration(
                                labelText: 'Year',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      child: const Text('Save'),
                      onPressed: () {
                        // Create new metadata object from form values
                        final newMetadata = AudiobookMetadata(
                          id: currentMetadata?.id ?? '',
                          title: titleController.text,
                          authors: authorController.text
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList(),
                          description: descriptionController.text,
                          publisher: publisherController.text,
                          publishedDate: yearController.text,
                          categories: currentMetadata?.categories ?? [],
                          averageRating: currentMetadata?.averageRating ?? 0.0,
                          ratingsCount: currentMetadata?.ratingsCount ?? 0,
                          thumbnailUrl: currentMetadata?.thumbnailUrl ?? '',
                          language: currentMetadata?.language ?? '',
                          series: seriesController.text,
                          seriesPosition: seriesPositionController.text,
                          // Preserve audio quality info
                          audioDuration: currentMetadata?.audioDuration,
                          bitrate: currentMetadata?.bitrate,
                          channels: currentMetadata?.channels,
                          sampleRate: currentMetadata?.sampleRate,
                          fileFormat: currentMetadata?.fileFormat,
                          provider: 'Manual Edit',
                        );
                        
                        Navigator.of(context).pop();
                        
                        // Update metadata in our widget
                        _updateMetadata(newMetadata);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}