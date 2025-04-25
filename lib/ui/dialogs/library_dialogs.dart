// File: lib/ui/dialogs/library_dialogs.dart
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_collection.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';

class LibraryDialogs {
  // Show book context menu
  static void showBookContextMenu({
    required BuildContext context,
    required AudiobookFile book,
    required List<AudiobookCollection> collections,
    required Function(AudiobookCollection) onAddToCollection,
    required Function(String) onCreateCollection,
    required VoidCallback onFindMetadata,
    required VoidCallback onRemove,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(
              book.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            enabled: false,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.library_add),
            title: const Text('Add to Collection'),
            onTap: () {
              Navigator.pop(context);
              showAddToCollectionDialog(
                context: context,
                book: book,
                collections: collections,
                onAddToCollection: onAddToCollection,
                onCreateCollection: onCreateCollection,
              );
            },
          ),
          if (!book.hasMetadata)
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Find Metadata'),
              onTap: () {
                Navigator.pop(context);
                onFindMetadata();
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Remove from Library'),
            onTap: () {
              Navigator.pop(context);
              showConfirmRemoveBookDialog(
                context: context,
                book: book,
                onConfirm: onRemove,
              );
            },
          ),
        ],
      ),
    );
  }
  
  // Show collection context menu
  static void showCollectionContextMenu({
    required BuildContext context,
    required AudiobookCollection collection,
    required VoidCallback onFindMetadata,
    required VoidCallback onApplyMetadata,
    required Function(String) onRename,
    required Function(bool) onRemove,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(
              collection.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${collection.author} • ${collection.fileCount} files',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            enabled: false,
          ),
          const Divider(),
          if (!collection.hasMetadata)
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Find Metadata'),
              onTap: () {
                Navigator.pop(context);
                onFindMetadata();
              },
            ),
          if (collection.metadata != null)
            ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: const Text('Apply Metadata to All Files'),
              onTap: () {
                Navigator.pop(context);
                onApplyMetadata();
              },
            ),
          ListTile(
            leading: const Icon(Icons.drive_file_move),
            title: const Text('Rename Collection'),
            onTap: () {
              Navigator.pop(context);
              showRenameCollectionDialog(
                context: context,
                collection: collection,
                onRename: onRename,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Collection'),
            onTap: () {
              Navigator.pop(context);
              showConfirmRemoveCollectionDialog(
                context: context,
                collection: collection,
                onRemove: onRemove,
              );
            },
          ),
        ],
      ),
    );
  }
  
  // Show add to collection dialog
  static void showAddToCollectionDialog({
    required BuildContext context,
    required AudiobookFile book,
    required List<AudiobookCollection> collections,
    required Function(AudiobookCollection) onAddToCollection,
    required Function(String) onCreateCollection,
  }) {
    if (collections.isEmpty) {
      // If no collections exist, prompt to create a new one
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create New Collection'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Collection Name',
              hintText: 'e.g., The Hunger Games Series',
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final controller = TextEditingController();
                final value = controller.text;
                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                } else {
                  // Use a default name if empty
                  Navigator.pop(context, 'New Collection');
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ).then((collectionName) {
        if (collectionName != null && collectionName.isNotEmpty) {
          onCreateCollection(collectionName);
        }
      });
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Collection'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select a collection:'),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    return ListTile(
                      leading: collection.metadata?.thumbnailUrl.isNotEmpty ?? false
                        ? CachedNetworkImage(
                            imageUrl: collection.metadata!.thumbnailUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.library_books),
                      title: Text(collection.displayName),
                      subtitle: Text('${collection.fileCount} files'),
                      onTap: () {
                        Navigator.pop(context, collection);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Prompt to create a new collection
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Create New Collection'),
                  content: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Collection Name',
                      hintText: 'e.g., The Hunger Games Series',
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        Navigator.pop(context, value);
                      }
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final controller = TextEditingController();
                        final value = controller.text;
                        if (value.isNotEmpty) {
                          Navigator.pop(context, value);
                        } else {
                          // Use a default name if empty
                          Navigator.pop(context, 'New Collection');
                        }
                      },
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ).then((collectionName) {
                if (collectionName != null && collectionName.isNotEmpty) {
                  onCreateCollection(collectionName);
                }
              });
            },
            child: const Text('Create New Collection'),
          ),
        ],
      ),
    ).then((selectedCollection) {
      if (selectedCollection != null && selectedCollection is AudiobookCollection) {
        onAddToCollection(selectedCollection);
      }
    });
  }
  
  // Show confirm remove book dialog
  static void showConfirmRemoveBookDialog({
    required BuildContext context,
    required AudiobookFile book,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Library'),
        content: Text(
          'Are you sure you want to remove "${book.displayName}" from your library? '
          'This won\'t delete the actual file from your device.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        onConfirm();
      }
    });
  }
  
  // Show rename collection dialog
  static void showRenameCollectionDialog({
    required BuildContext context,
    required AudiobookCollection collection,
    required Function(String) onRename,
  }) {
    final TextEditingController controller = TextEditingController(text: collection.title);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Collection Name',
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context, value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text;
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    ).then((newName) {
      if (newName != null && newName.isNotEmpty) {
        onRename(newName);
      }
    });
  }
  
  // Show confirm remove collection dialog
  static void showConfirmRemoveCollectionDialog({
    required BuildContext context,
    required AudiobookCollection collection,
    required Function(bool) onRemove,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete the collection "${collection.displayName}"?'
            ),
            const SizedBox(height: 16),
            const Text('Choose what to do with the files:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Keep files but remove collection
              Navigator.pop(context, 'keep');
            },
            child: const Text('Keep Files'),
          ),
          ElevatedButton(
            onPressed: () {
              // Remove files with collection
              Navigator.pop(context, 'remove');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove Files Too'),
          ),
        ],
      ),
    ).then((action) {
      if (action == 'keep') {
        onRemove(true);
      } else if (action == 'remove') {
        onRemove(false);
      }
    });
  }
  
  // Show apply metadata dialog
  static void showApplyMetadataDialog({
    required BuildContext context,
    required AudiobookMetadata metadata,
    required int fileCount,
    required VoidCallback onApply,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply to All Files?'),
        content: Text(
          'Found metadata for "${metadata.title}" by ${metadata.authorsFormatted}. '
          'Do you want to apply this metadata to all $fileCount files in the collection?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Yes, Apply to All'),
          ),
        ],
      ),
    ).then((applyToAll) {
      if (applyToAll == true) {
        onApply();
      }
    });
  }
  
  // Show collection details dialog
  static Future<Map<String, dynamic>?> showCollectionDetailsDialog({
    required BuildContext context,
    required AudiobookCollection collection,
  }) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(collection.displayName),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Collection metadata section
              if (collection.metadata != null) ...[
                ListTile(
                  leading: collection.metadata?.thumbnailUrl.isNotEmpty ?? false
                    ? CachedNetworkImage(
                        imageUrl: collection.metadata!.thumbnailUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.library_books),
                  title: Text(collection.metadata!.title),
                  subtitle: Text(collection.metadata!.authorsFormatted),
                ),
                const Divider(),
              ],
              
              // File list
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: collection.files.length,
                  itemBuilder: (context, index) {
                    final file = collection.files[index];
                    return ListTile(
                      leading: const Icon(Icons.audiotrack),
                      title: Text(
                        path.basename(file.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          Navigator.pop(context, {'action': 'remove_file', 'file': file});
                        },
                        tooltip: 'Remove from collection',
                      ),
                      onTap: () {
                        Navigator.pop(context, {'action': 'open_file', 'file': file});
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              // Open metadata search dialog for the entire collection
              Navigator.pop(context, {'action': 'find_metadata'});
            },
            child: const Text('Find Metadata'),
          ),
          if (collection.metadata != null)
            TextButton(
              onPressed: () {
                // Apply collection metadata to all files
                Navigator.pop(context, {'action': 'apply_metadata'});
              },
              child: const Text('Apply to All Files'),
            ),
        ],
      ),
    );
  }
  
  // Show library statistics dialog
  static void showLibraryStats({
    required BuildContext context,
    required List<AudiobookFile> individualBooks,
    required List<AudiobookCollection> collections,
    required List<String> genres,
  }) async {
    final metadataCache = Provider.of<MetadataCache>(context, listen: false);
    final cacheSize = await metadataCache.getCacheSize();
    
    // Calculate total file count
    int collectionFiles = collections.fold(
      0, (sum, collection) => sum + collection.fileCount);
    final totalFiles = individualBooks.length + collectionFiles;
    
    // Calculate matched/pending count
    int pendingIndividuals = individualBooks.where((book) => !book.hasMetadata).length;
    int pendingCollections = collections.where((coll) => !coll.hasMetadata).length;
    final pendingCount = pendingIndividuals + pendingCollections;
    
    // Calculate file metadata count
    int fileMetadataCount = individualBooks.where((book) => book.hasFileMetadata).length;
    for (var collection in collections) {
      fileMetadataCount += collection.files.where((file) => file.hasFileMetadata).length;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Library Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Individual Audiobooks', individualBooks.length.toString()),
            _buildStatRow('Collections', collections.length.toString()),
            _buildStatRow('Total Files', totalFiles.toString()),
            _buildStatRow('Pending Metadata', pendingCount.toString()),
            _buildStatRow('Files with ID3 Tags', fileMetadataCount.toString()),
            _buildStatRow('Cached Metadata Entries', cacheSize.toString()),
            _buildStatRow('Available Genres', (genres.length - 1).toString()), // -1 for "All"
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  // Show confirm clear library dialog
  static void showConfirmClearLibraryDialog({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Library Data'),
        content: const Text(
          'This will remove all scanned audiobooks and their metadata from the app. '
          'Your actual files will not be deleted. Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }
  
  // Helper method to build a stat row
  static Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}