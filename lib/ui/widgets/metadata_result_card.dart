// File: lib/widgets/metadata_result_card.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MetadataResultCard extends StatelessWidget {
  final AudiobookMetadata metadata;
  final VoidCallback onSelect;

  const MetadataResultCard({
    Key? key,
    required this.metadata,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onSelect,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image (or placeholder)
            Expanded(
              child: metadata.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: metadata.thumbnailUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => _buildCoverPlaceholder(),
                      errorWidget: (context, url, error) => _buildCoverPlaceholder(),
                    )
                  : _buildCoverPlaceholder(),
            ),
            
            // Metadata info
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    metadata.title,
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
                    metadata.authorsFormatted,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // Only show more details if available
                  if (metadata.series.isNotEmpty || 
                     metadata.publishedDate.isNotEmpty ||
                     metadata.averageRating > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Series info
                          if (metadata.series.isNotEmpty)
                            Text(
                              '${metadata.series}${metadata.seriesPosition.isNotEmpty ? ' #${metadata.seriesPosition}' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                          // Year
                          if (metadata.publishedDate.isNotEmpty)
                            Text(
                              metadata.publishedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            
                          // Rating
                          if (metadata.averageRating > 0)
                            Row(
                              children: [
                                const Icon(Icons.star, size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  metadata.averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  
                  // Data source
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            metadata.provider,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Select button at bottom
            Container(
              width: double.infinity,
              color: Theme.of(context).primaryColor,
              child: TextButton(
                onPressed: onSelect,
                child: const Text(
                  'Select',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.book,
          size: 48,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}
