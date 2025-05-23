// lib/widgets/add_to_collection_dialog.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';

class AddToCollectionDialog extends StatefulWidget {
  final CollectionManager collectionManager;
  final String bookPath;
  final List<Collection> currentCollections;

  const AddToCollectionDialog({
    Key? key,
    required this.collectionManager,
    required this.bookPath,
    required this.currentCollections,
  }) : super(key: key);

  @override
  State<AddToCollectionDialog> createState() => _AddToCollectionDialogState();
}

class _AddToCollectionDialogState extends State<AddToCollectionDialog> {
  final Set<String> _selectedCollectionIds = {};
  bool _showCreateNew = false;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-select current collections
    _selectedCollectionIds.addAll(widget.currentCollections.map((c) => c.id));
  }

  @override
  Widget build(BuildContext context) {
    final allCollections = widget.collectionManager.collections
        .where((c) => c.type == CollectionType.custom)
        .toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text(
        'Add to Collections',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 400,
        child: _showCreateNew ? _buildCreateNew() : _buildCollectionList(allCollections),
      ),
      actions: [
        if (_showCreateNew)
          TextButton(
            onPressed: () => setState(() => _showCreateNew = false),
            child: const Text('Back'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _showCreateNew ? _createCollection : () => _saveSelections(allCollections),
          child: Text(_showCreateNew ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Widget _buildCollectionList(List<Collection> collections) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Create new collection button
        InkWell(
          onTap: () => setState(() => _showCreateNew = true),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).primaryColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Create New Collection',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Collection list
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              final isSelected = _selectedCollectionIds.contains(collection.id);
              
              return CheckboxListTile(
                title: Text(
                  collection.name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: collection.description != null
                    ? Text(
                        collection.description!,
                        style: TextStyle(color: Colors.grey[400]),
                      )
                    : null,
                value: isSelected,
                activeColor: Theme.of(context).primaryColor,
                checkColor: Colors.white,
                onChanged: (value) {
                  setState(() {
                    if (value ?? false) {
                      _selectedCollectionIds.add(collection.id);
                    } else {
                      _selectedCollectionIds.remove(collection.id);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreateNew() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Collection Name',
            labelStyle: TextStyle(color: Colors.grey[400]),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Description (optional)',
            labelStyle: TextStyle(color: Colors.grey[400]),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createCollection() async {
    if (_nameController.text.isEmpty) return;
    
    final collection = await widget.collectionManager.createCollection(
      name: _nameController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      bookPaths: [widget.bookPath],
    );
    
    if (collection != null && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _saveSelections(List<Collection> allCollections) async {
    // Add to newly selected collections
    for (final collection in allCollections) {
      final wasInCollection = widget.currentCollections.any((c) => c.id == collection.id);
      final isNowSelected = _selectedCollectionIds.contains(collection.id);
      
      if (!wasInCollection && isNowSelected) {
        await widget.collectionManager.addBookToCollection(collection.id, widget.bookPath);
      } else if (wasInCollection && !isNowSelected) {
        await widget.collectionManager.removeBookFromCollection(collection.id, widget.bookPath);
      }
    }
    
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }
}