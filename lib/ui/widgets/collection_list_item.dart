// File: lib/ui/widgets/collection_list_item.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';

class CollectionListItem extends StatelessWidget {
  final AudiobookCollection collection;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  
  const CollectionListItem({
    Key? key,
    required this.collection,
    required this.onTap,
    this.onLongPress,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            // Collection thumbnail
            leading: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                children: [
                  // Cover image or placeholder
                  collection.metadata?.thumbnailUrl.isNotEmpty ?? false
                    ? Hero(
                        tag: 'collection-${collection.title}',
                        child: CachedNetworkImage(
                          imageUrl: collection.metadata!.thumbnailUrl,
                          fit: BoxFit.cover,
                          width: 56,
                          height: 56,
                          placeholder: (context, url) => Container(
                            color: Colors.indigo.shade100,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.indigo.shade100,
                            child: const Center(
                              child: Icon(Icons.library_books, size: 32),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.indigo.shade100,
                        child: Center(
                          child: Icon(
                            Icons.library_books,
                            size: 32,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                      ),
                    
                  // Collection indicator
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.indigo,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${collection.fileCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Title and author
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    collection.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!collection.hasMetadata)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collection.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _buildInfoBadges(context),
              ],
            ),
            
            // Controls or additional info
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: onLongPress,
              tooltip: 'Collection Options',
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoBadges(BuildContext context) {
    final badges = <Widget>[];
    
    // Series badge
    if (collection.metadata?.series.isNotEmpty ?? false) {
      final seriesText = collection.metadata!.seriesPosition.isNotEmpty
          ? '${collection.metadata!.series} #${collection.metadata!.seriesPosition}'
          : collection.metadata!.series;
      
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            seriesText,
            style: const TextStyle(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: badges,
    );
  }
}