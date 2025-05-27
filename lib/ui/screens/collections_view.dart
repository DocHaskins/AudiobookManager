// lib/screens/collections_view.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import '../widgets/collection_grid_item.dart';
import 'collection_detail_screen.dart';

class CollectionsView extends StatefulWidget {
  final CollectionManager collectionManager;
  final LibraryManager libraryManager;
  
  const CollectionsView({
    Key? key,
    required this.collectionManager,
    required this.libraryManager,
  }) : super(key: key);
  
  @override
  State<CollectionsView> createState() => _CollectionsViewState();
}

class _CollectionsViewState extends State<CollectionsView> 
    with AutomaticKeepAliveClientMixin {
  CollectionType? _filterType;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  List<Collection> _getFilteredCollections(List<Collection> collections) {
    var filtered = collections;
    
    // Filter by type
    if (_filterType != null) {
      filtered = filtered.where((c) => c.type == _filterType).toList();
    }
    
    // Filter by search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((c) {
        return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (c.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }
    
    // Sort by name
    filtered.sort((a, b) => a.name.compareTo(b.name));
    
    return filtered;
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        elevation: 0,
        actions: [
          // Filter button
          PopupMenuButton<CollectionType?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (type) {
              setState(() {
                _filterType = type;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.clear, size: 20),
                    SizedBox(width: 8),
                    Text('All Collections'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: CollectionType.series,
                child: Row(
                  children: [
                    Icon(Icons.auto_stories, size: 20),
                    SizedBox(width: 8),
                    Text('Series'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: CollectionType.custom,
                child: Row(
                  children: [
                    Icon(Icons.folder_special, size: 20),
                    SizedBox(width: 8),
                    Text('Custom'),
                  ],
                ),
              ),
            ],
          ),
          // Add collection button
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateCollectionDialog,
            tooltip: 'Create Collection',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search collections...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Collection>>(
        stream: widget.collectionManager.collectionsChanged,
        builder: (context, snapshot) {
          final collections = snapshot.data ?? widget.collectionManager.collections;
          final filteredCollections = _getFilteredCollections(collections);
          
          return Column(
            children: [
              // Stats bar
              if (collections.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        context,
                        'Total',
                        collections.length.toString(),
                        Icons.collections_bookmark,
                      ),
                      _buildStatItem(
                        context,
                        'Series',
                        collections.where((c) => c.type == CollectionType.series).length.toString(),
                        Icons.auto_stories,
                      ),
                      _buildStatItem(
                        context,
                        'Custom',
                        collections.where((c) => c.type == CollectionType.custom).length.toString(),
                        Icons.folder_special,
                      ),
                    ],
                  ),
                ),
              // Collections grid with responsive layout
              Expanded(
                child: _buildCollectionsGrid(filteredCollections),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCollectionsGrid(List<Collection> filteredCollections) {
    if (filteredCollections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.collections_bookmark,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No collections found' : 'No collections yet',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Create your first collection or add books with series',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Simple calculation for collection grid: fixed item width
        const double itemWidth = 200;
        const double spacing = 20;
        
        // Calculate how many items fit across the width
        final int crossAxisCount = ((constraints.maxWidth + spacing) / (itemWidth + spacing)).floor().clamp(1, 20);
        
        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.8, // Slightly taller than books (200 width / 250 height)
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: filteredCollections.length,
          itemBuilder: (context, index) {
            final collection = filteredCollections[index];
            final collectionBooks = widget.libraryManager.getBooksForCollection(collection);
            
            return CollectionGridItem(
              collection: collection,
              books: collectionBooks,
              onTap: () => _navigateToCollection(collection),
            );
          },
        );
      },
    );
  }

  void _navigateToCollection(Collection collection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionDetailScreen(
          collection: collection,
          collectionManager: widget.collectionManager,
          libraryManager: widget.libraryManager,
        ),
      ),
    );
  }
  
  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  void _showCreateCollectionDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Collection Name',
                hintText: 'My Reading List',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Books I want to read this year',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a collection name')),
                );
                return;
              }
              
              Navigator.of(context).pop();
              
              final collection = await widget.collectionManager.createCollection(
                name: name,
                description: descriptionController.text.trim(),
              );
              
              if (collection != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Collection created: ${collection.name}')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to create collection')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  
  void _showCollectionOptions(Collection collection) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open Collection'),
              onTap: () {
                Navigator.pop(context);
                _navigateToCollection(collection);
              },
            ),
            if (collection.type == CollectionType.custom) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Collection'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Show edit dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit functionality coming soon')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Collection', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteCollection(collection);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Export Collection'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Export functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export functionality coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _confirmDeleteCollection(Collection collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Text('Are you sure you want to delete "${collection.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await widget.collectionManager.deleteCollection(collection.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Collection deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}