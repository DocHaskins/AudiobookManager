// lib/ui/widgets/detail/sections/collections_section.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/ui/widgets/collections/add_to_collection_dialog.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class CollectionsSection extends StatefulWidget {
  final AudiobookFile book;
  final LibraryManager libraryManager;

  const CollectionsSection({
    Key? key,
    required this.book,
    required this.libraryManager,
  }) : super(key: key);

  @override
  State<CollectionsSection> createState() => _CollectionsSectionState();
}

class _CollectionsSectionState extends State<CollectionsSection> {
  @override
  Widget build(BuildContext context) {
    final collectionManager = widget.libraryManager.collectionManager;
    
    if (collectionManager == null) {
      return Text(
        'Collections not available',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final currentCollections = collectionManager.getCollectionsForBook(widget.book.path);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Collections:',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (currentCollections.isNotEmpty)
              TextButton.icon(
                onPressed: () => _addToCollections(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add More', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        if (currentCollections.isEmpty)
          Row(
            children: [
              Text(
                'Not in any collections',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: currentCollections.map((collection) => 
              Material(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _removeFromCollection(collection),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_special, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          collection.name,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.close, color: Colors.blue.withOpacity(0.7), size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ).toList(),
          ),
      ],
    );
  }

  Future<void> _addToCollections(BuildContext context) async {
    final collectionManager = widget.libraryManager.collectionManager;
    if (collectionManager == null) return;
    
    final currentCollections = collectionManager.getCollectionsForBook(widget.book.path);
    
    await showDialog(
      context: context,
      builder: (context) => AddToCollectionDialog(
        collectionManager: collectionManager,
        bookPath: widget.book.path,
        currentCollections: currentCollections,
      ),
    );
    
    // Refresh the collections display
    setState(() {});
  }

  Future<void> _removeFromCollection(dynamic collection) async {
    try {
      final collectionManager = widget.libraryManager.collectionManager;
      if (collectionManager == null) return;
      
      final success = await collectionManager.removeBookFromCollection(collection.id, widget.book.path);
      
      if (success) {
        setState(() {}); // Refresh the collections display
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed from ${collection.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error removing from collection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove from collection: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}