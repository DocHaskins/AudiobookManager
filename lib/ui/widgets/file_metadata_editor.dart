// File: lib/widgets/file_metadata_editor.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';

class FileMetadataEditor extends StatefulWidget {
  final AudiobookFile file;
  final Function(AudiobookMetadata) onMetadataUpdated;
  final Function(String)? onSearchRequested;
  
  const FileMetadataEditor({
    Key? key,
    required this.file,
    required this.onMetadataUpdated,
    this.onSearchRequested,
  }) : super(key: key);
  
  @override
  FileMetadataEditorState createState() => FileMetadataEditorState();
}

class FileMetadataEditorState extends State<FileMetadataEditor> {
  late TextEditingController titleController;
  late TextEditingController authorController;
  late TextEditingController seriesController;
  late TextEditingController seriesPositionController;
  late TextEditingController publisherController;
  late TextEditingController yearController;
  late TextEditingController descriptionController;
  bool isEdited = false;
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }
  
  @override
  void didUpdateWidget(FileMetadataEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Re-initialize controllers if the file changes
    if (oldWidget.file.path != widget.file.path) {
      _initializeControllers();
    }
  }
  
  void _initializeControllers() {
    // Get the most complete metadata
    final metadata = widget.file.metadata ?? widget.file.fileMetadata;
    
    titleController = TextEditingController(text: metadata?.title ?? widget.file.displayName);
    authorController = TextEditingController(text: metadata?.authorsFormatted ?? widget.file.author);
    seriesController = TextEditingController(text: metadata?.series ?? '');
    seriesPositionController = TextEditingController(text: metadata?.seriesPosition ?? '');
    publisherController = TextEditingController(text: metadata?.publisher ?? '');
    yearController = TextEditingController(text: metadata?.year ?? '');
    descriptionController = TextEditingController(text: metadata?.description ?? '');
    
    // Add listeners to detect changes
    titleController.addListener(_onFieldChanged);
    authorController.addListener(_onFieldChanged);
    seriesController.addListener(_onFieldChanged);
    seriesPositionController.addListener(_onFieldChanged);
    publisherController.addListener(_onFieldChanged);
    yearController.addListener(_onFieldChanged);
    descriptionController.addListener(_onFieldChanged);
    
    isEdited = false;
  }
  
  void _onFieldChanged() {
    if (!isEdited) {
      setState(() {
        isEdited = true;
      });
    }
  }
  
  @override
  void dispose() {
    titleController.dispose();
    authorController.dispose();
    seriesController.dispose();
    seriesPositionController.dispose();
    publisherController.dispose();
    yearController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info header
            _buildFileInfoHeader(),
            const SizedBox(height: 16),
            
            // Main form fields
            _buildMainFormFields(),
            
            // Additional fields
            _buildAdditionalFields(),
            
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileInfoHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.file.filename}${widget.file.extension}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatFileSize(widget.file.size)} • ${_formatLastModified(widget.file.lastModified)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          'Metadata source: ${_getMetadataSource()}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
  
  Widget _buildMainFormFields() {
    return Column(
      children: [
        // Title field
        TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        
        // Author field
        TextField(
          controller: authorController,
          decoration: const InputDecoration(
            labelText: 'Author(s)',
            border: OutlineInputBorder(),
            helperText: 'Separate multiple authors with commas',
          ),
        ),
        const SizedBox(height: 8),
        
        // Series fields in a row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: seriesController,
                decoration: const InputDecoration(
                  labelText: 'Series',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: seriesPositionController,
                decoration: const InputDecoration(
                  labelText: 'Position',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildAdditionalFields() {
    return ExpansionTile(
      title: const Text('Additional Information'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: publisherController,
                  decoration: const InputDecoration(
                    labelText: 'Publisher',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
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
        ),
        const SizedBox(height: 8),
        TextField(
          controller: descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.onSearchRequested != null)
            OutlinedButton.icon(
              onPressed: _searchOnline,
              icon: const Icon(Icons.search),
              label: const Text('SEARCH ONLINE'),
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: isEdited ? _saveMetadata : null,
            icon: const Icon(Icons.save),
            label: const Text('SAVE TO FILE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isEdited ? null : Colors.grey[300],
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
  
  String _formatLastModified(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays < 1) {
      return 'Today, ${_formatTime(dateTime)}';
    } else if (difference.inDays < 2) {
      return 'Yesterday, ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
  
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  String _getMetadataSource() {
    if (widget.file.metadata != null) {
      return widget.file.metadata!.provider;
    } else if (widget.file.fileMetadata != null) {
      return 'File Metadata';
    } else {
      return 'None';
    }
  }
  
  void _searchOnline() {
    if (widget.onSearchRequested != null) {
      // Create a search query based on current field values
      final searchQuery = [
        titleController.text,
        authorController.text
      ].where((text) => text.isNotEmpty).join(' ');
      
      if (searchQuery.isNotEmpty) {
        widget.onSearchRequested!(searchQuery);
      }
    }
  }
  
  void _saveMetadata() {
    // Create a new metadata object with the edited values
    final newMetadata = AudiobookMetadata(
      id: widget.file.path,
      title: titleController.text.trim(),
      authors: authorController.text
          .split(',')
          .map((a) => a.trim())
          .where((a) => a.isNotEmpty)
          .toList(),
      description: descriptionController.text.trim(),
      publisher: publisherController.text.trim(),
      publishedDate: yearController.text.trim(),
      categories: [], // Maintain existing categories if needed
      averageRating: widget.file.metadata?.averageRating ?? 0.0,
      ratingsCount: widget.file.metadata?.ratingsCount ?? 0,
      thumbnailUrl: widget.file.metadata?.thumbnailUrl ?? '',
      language: widget.file.metadata?.language ?? '',
      series: seriesController.text.trim(),
      seriesPosition: seriesPositionController.text.trim(),
      provider: 'User Edited',
    );
    
    // Notify parent of update
    widget.onMetadataUpdated(newMetadata);
    
    // Reset edited state
    setState(() {
      isEdited = false;
    });
  }
}