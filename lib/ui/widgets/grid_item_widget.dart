// File: lib/ui/widgets/grid_item_widget.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/ui/widgets/image_loader_widget.dart';

/// Grid item widget for displaying audiobooks in grid view
class AudiobookGridItem extends StatelessWidget {
  final dynamic item; // Can be AudiobookFile or AudiobookCollection
  final VoidCallback onTap;
  
  const AudiobookGridItem({
    Key? key,
    required this.item,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (item is AudiobookFile) {
      return _buildFileGridItem(context, item as AudiobookFile);
    } else if (item is AudiobookCollection) {
      return _buildCollectionGridItem(context, item as AudiobookCollection);
    }
    
    // Fallback for unsupported types
    return Card(
      child: const Center(
        child: Text('Unsupported item type'),
      ),
    );
  }
  
  Widget _buildFileGridItem(BuildContext context, AudiobookFile audiobook) {
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                child: BookCoverImage(
                  imageUrl: audiobook.metadata?.thumbnailUrl,
                  bookTitle: audiobook.displayName,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audiobook.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    audiobook.author,
                    style: TextStyle(color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!audiobook.hasMetadata)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Pending Match',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCollectionGridItem(BuildContext context, AudiobookCollection collection) {
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                child: BookCoverImage(
                  imageUrl: collection.metadata?.thumbnailUrl,
                  bookTitle: collection.displayName,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    collection.author,
                    style: TextStyle(color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(Icons.audiotrack, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${collection.fileCount} files',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  if (!collection.hasMetadata)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Pending Match',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}