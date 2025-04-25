// File: lib/ui/screens/batch_organize_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;

import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/audiobook_organizer.dart';
import 'package:audiobook_organizer/storage/user_preferences.dart';

class BatchOrganizeView extends StatefulWidget {
  final List<AudiobookFile> audiobooks;
  
  const BatchOrganizeView({
    Key? key,
    required this.audiobooks,
  }) : super(key: key);

  @override
  State<BatchOrganizeView> createState() => _BatchOrganizeViewState();
}

class _BatchOrganizeViewState extends State<BatchOrganizeView> {
  List<AudiobookFile> _selectedBooks = [];
  String _namingPattern = '{Author} - {Title}';
  String? _destinationDirectory;
  bool _isLoading = false;
  late TextEditingController _patternController;
  
  @override
  void initState() {
    super.initState();
    // Start with all books that have metadata selected
    _selectedBooks = widget.audiobooks
        .where((book) => book.hasMetadata)
        .toList();
    _patternController = TextEditingController(text: _namingPattern);
    _loadPreferences();
  }
  
  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPreferences() async {
    final prefs = Provider.of<UserPreferences>(context, listen: false);
    final pattern = await prefs.getNamingPattern();
    final defaultDir = await prefs.getDefaultDirectory();
    
    setState(() {
      _namingPattern = pattern;
      _patternController.text = pattern;
      _destinationDirectory = defaultDir;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Organize'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _destinationDirectory != null && _selectedBooks.isNotEmpty
                    ? _processBatch
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Process Batch'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfigSection(),
          const SizedBox(height: 16),
          _buildFileSelectionSection(),
        ],
      ),
    );
  }
  
  Widget _buildConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Organization Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _patternController,
              decoration: const InputDecoration(
                labelText: 'Naming Pattern',
                border: OutlineInputBorder(),
                helperText: 'Example: {Author} - {Title}',
              ),
              onChanged: (value) {
                setState(() {
                  _namingPattern = value;
                });
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Destination Directory'),
              subtitle: Text(_destinationDirectory ?? 'Not selected'),
              trailing: IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: _selectDestinationDirectory,
              ),
              onTap: _selectDestinationDirectory,
            ),
            const SizedBox(height: 16),
            Text(
              'Selected: ${_selectedBooks.length} of ${widget.audiobooks.length} books',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileSelectionSection() {
    // Filter to only show books with metadata
    final booksWithMetadata = widget.audiobooks
        .where((book) => book.hasMetadata)
        .toList();
    
    if (booksWithMetadata.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No books with metadata found. Please add metadata to your books first.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Files to Organize',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _selectAll,
                      icon: const Icon(Icons.select_all),
                      label: const Text('Select All'),
                    ),
                    TextButton.icon(
                      onPressed: _deselectAll,
                      icon: const Icon(Icons.deselect),
                      label: const Text('Deselect All'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: booksWithMetadata.length,
              itemBuilder: (context, index) {
                final book = booksWithMetadata[index];
                final isSelected = _selectedBooks.contains(book);
                
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedBooks.add(book);
                      } else {
                        _selectedBooks.remove(book);
                      }
                    });
                  },
                  title: Text(
                    book.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Text(
                          _getPreviewName(book),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  secondary: book.metadata?.thumbnailUrl.isNotEmpty ?? false
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            book.metadata!.thumbnailUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.audiotrack,
                              size: 40,
                            ),
                          ),
                        )
                      : const Icon(Icons.audiotrack, size: 40),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _selectAll() {
    setState(() {
      _selectedBooks = widget.audiobooks
          .where((book) => book.hasMetadata)
          .toList();
    });
  }
  
  void _deselectAll() {
    setState(() {
      _selectedBooks = [];
    });
  }
  
  Future<void> _selectDestinationDirectory() async {
    final String? directory = await getDirectoryPath(
      initialDirectory: _destinationDirectory,
      confirmButtonText: 'Select Destination',
    );
    if (directory != null) {
      setState(() {
        _destinationDirectory = directory;
      });
      
      // Save as default if user didn't have one before
      final prefs = Provider.of<UserPreferences>(context, listen: false);
      final currentDefault = await prefs.getDefaultDirectory();
      if (currentDefault == null) {
        await prefs.saveDefaultDirectory(directory);
      }
    }
  }
  
  String _getPreviewName(AudiobookFile book) {
    if (!book.hasMetadata) return path.basename(book.path);
    
    final organizer = Provider.of<AudiobookOrganizer>(context, listen: false);
    return organizer.generateNewFilename(book, _namingPattern);
  }
  
  Future<void> _processBatch() async {
    if (_destinationDirectory == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final organizer = Provider.of<AudiobookOrganizer>(context, listen: false);
      final results = await organizer.batchOrganize(
        _selectedBooks,
        _destinationDirectory!,
        _namingPattern,
      );
      
      setState(() {
        _isLoading = false;
      });
      
      if (results.isNotEmpty) {
        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully organized ${results.length} files'),
          ),
        );
        
        // Return true to indicate changes were made
        Navigator.pop(context, true);
      } else {
        // Show warning
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No files were organized'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error organizing files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Update to the LibraryView to add a batch organize option
// Add this code to the lib/ui/screens/library_view.dart file

// Add a new action in the AppBar:
/*
IconButton(
  icon: const Icon(Icons.playlist_add_check),
  onPressed: _audiobooks.isEmpty ? null : _batchOrganize,
  tooltip: 'Batch organize',
),
*/

// Add this method to the _LibraryViewState class:
/*
void _batchOrganize() async {
  final result = await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => BatchOrganizeView(audiobooks: _audiobooks),
    ),
  );
  
  if (result == true) {
    // Refresh UI if changes were made
    setState(() {
      // Re-scan directories to refresh file list
      _scanDirectory();
    });
  }
}
*/
