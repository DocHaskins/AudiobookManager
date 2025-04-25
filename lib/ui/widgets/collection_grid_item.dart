// File: lib/ui/widgets/collection_grid_item.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';

class CollectionGridItem extends StatelessWidget {
  final AudiobookCollection collection;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  
  const CollectionGridItem({
    Key? key,
    required this.collection,
    required this.onTap,
    this.onLongPress,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Collection cover
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image or placeholder
                  collection.metadata?.thumbnailUrl.isNotEmpty ?? false
                    ? Hero(
                        tag: 'collection-${collection.title}',
                        child: CachedNetworkImage(
                          imageUrl: collection.metadata!.thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: Colors.indigo.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.indigo.shade100,
                            child: const Center(
                              child: Icon(Icons.library_books, size: 48),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.indigo.shade100,
                        child: Center(
                          child: Icon(
                            Icons.library_books,
                            size: 48,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                      ),
                  
                  // Collection indicator
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.library_books,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${collection.fileCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Collection info
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    collection.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Author
                  Text(
                    collection.author,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Build status/info badges
                  _buildInfoBadges(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoBadges(BuildContext context) {
    final badges = <Widget>[];
    
    // Pending badge
    if (!collection.hasMetadata) {
      badges.add(
        Container(
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
            style: TextStyle(fontSize: 10),
          ),
        ),
      );
    }
    
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