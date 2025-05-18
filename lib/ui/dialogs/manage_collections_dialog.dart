// lib/ui/dialogs/manage_collections_dialog.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class ManageCollectionsDialog extends StatefulWidget {
  final List<AudiobookCollection> collections;
  final List<AudiobookFile> allBooks;
  
  const ManageCollectionsDialog({
    Key? key,
    required this.collections,
    required this.allBooks,
  }) : super(key: key);
  
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required List<AudiobookCollection> collections,
    required List<AudiobookFile> allBooks,
  }) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ManageCollectionsDialog(
        collections: collections,
        allBooks: allBooks,
      ),
    );
  }

  @override
  State<ManageCollectionsDialog> createState() => _ManageCollectionsDialogState();
}

class _ManageCollectionsDialogState extends State<ManageCollectionsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AudiobookCollection? _selectedCollection;
  String _newCollectionName = '';
  final List<AudiobookFile> _selectedBooks = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Collections',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Create New Collection'),
                Tab(text: 'Edit Existing Collection'),
              ],
            ),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCreateCollectionTab(),
                  _buildEditCollectionTab(),
                ],
              ),
            ),
            
            const Divider(),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _tabController.index == 0 
                      ? _createNewCollection 
                      : _updateExistingCollection,
                  child: Text(_tabController.index == 0 ? 'CREATE' : 'UPDATE'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCreateCollectionTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Collection Name',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _newCollectionName = value;
            });
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Select Books to Include:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildBookSelectionGrid(
            widget.allBooks,
            _selectedBooks,
            (book, isSelected) {
              setState(() {
                if (isSelected) {
                  _selectedBooks.add(book);
                } else {
                  _selectedBooks.remove(book);
                }
              });
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildEditCollectionTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        DropdownButtonFormField<AudiobookCollection>(
          decoration: const InputDecoration(
            labelText: 'Select Collection',
            border: OutlineInputBorder(),
          ),
          value: _selectedCollection,
          items: widget.collections.map((collection) {
            return DropdownMenuItem<AudiobookCollection>(
              value: collection,
              child: Text(collection.displayName),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCollection = value;
              _selectedBooks.clear();
              if (value != null) {
                _selectedBooks.addAll(value.files);
              }
            });
          },
        ),
        if (_selectedCollection != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Modify Books in Collection:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildBookSelectionGrid(
              widget.allBooks,
              _selectedBooks,
              (book, isSelected) {
                setState(() {
                  if (isSelected) {
                    _selectedBooks.add(book);
                  } else {
                    _selectedBooks.remove(book);
                  }
                });
              },
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildBookSelectionGrid(
    List<AudiobookFile> books,
    List<AudiobookFile> selectedBooks,
    Function(AudiobookFile, bool) onToggle,
  ) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final isSelected = selectedBooks.contains(book);
        
        return InkWell(
          onTap: () => onToggle(book, !isSelected),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Book cover
              Card(
                elevation: isSelected ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: isSelected
                      ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                      : BorderSide.none,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildCoverImage(book, context),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            book.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Selection indicator
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildCoverImage(AudiobookFile book, BuildContext context) {
    final coverUrl = book.metadata?.thumbnailUrl ?? book.fileMetadata?.thumbnailUrl;
    
    if (coverUrl == null || coverUrl.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Center(
          child: Icon(
            Icons.book_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    
    if (coverUrl.startsWith('/') || coverUrl.contains(':\\')) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        child: Image.file(
          File(coverUrl),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Center(
              child: Icon(
                Icons.book_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: CachedNetworkImage(
        imageUrl: coverUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Center(
            child: Icon(
              Icons.book_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
  
  void _createNewCollection() {
    if (_newCollectionName.isEmpty || _selectedBooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a collection name and select at least one book'),
        ),
      );
      return;
    }
    
    // Create new collection
    final newCollection = AudiobookCollection(
      title: _newCollectionName,
      files: List<AudiobookFile>.from(_selectedBooks),
    );
    
    // Return the new collection
    Navigator.pop(context, {
      'action': 'create',
      'collection': newCollection,
    });
  }
  
  void _updateExistingCollection() {
    if (_selectedCollection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a collection'),
        ),
      );
      return;
    }
    
    // Update collection files
    _selectedCollection!.files.clear();
    _selectedCollection!.files.addAll(_selectedBooks);
    
    // Return the updated collection
    Navigator.pop(context, {
      'action': 'update',
      'collection': _selectedCollection,
    });
  }
}