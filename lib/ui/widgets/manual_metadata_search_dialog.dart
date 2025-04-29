// File: lib/ui/widgets/manual_metadata_search_dialog.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';

class ManualMetadataSearchDialog extends StatefulWidget {
  final String initialQuery;
  final List<MetadataProvider> providers;
  final Function(AudiobookMetadata) onMetadataSelected;
  
  const ManualMetadataSearchDialog({
    Key? key,
    required this.initialQuery,
    required this.providers,
    required this.onMetadataSelected,
  }) : super(key: key);

  /// Static method to show the dialog and return the selected metadata
  static Future<AudiobookMetadata?> show({
    required BuildContext context,
    required String initialQuery,
    required List<MetadataProvider> providers,
  }) async {
    return showDialog<AudiobookMetadata>(
      context: context,
      builder: (context) => ManualMetadataSearchDialog(
        initialQuery: initialQuery,
        providers: providers,
        onMetadataSelected: (metadata) {
          Navigator.of(context).pop(metadata);
        },
      ),
    );
  }

  @override
  State<ManualMetadataSearchDialog> createState() => _ManualMetadataSearchDialogState();
}

class _ManualMetadataSearchDialogState extends State<ManualMetadataSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<AudiobookMetadata> _searchResults = [];
  bool _isSearching = false;
  String _activeProviderIndex = '0'; // Store the index as string for ChoiceChip
  
  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    // Start initial search with slight delay to allow dialog to show
    Future.delayed(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });
    
    try {
      final providerIndex = int.parse(_activeProviderIndex);
      if (providerIndex < widget.providers.length) {
        final activeProvider = widget.providers[providerIndex];
        _searchResults = await activeProvider.search(query);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Metadata Search',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search Query',
                      hintText: 'Enter book title or author',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _performSearch,
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.providers.length > 1) ...[
              Row(
                children: [
                  const Text('Provider:'),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 8,
                    children: List.generate(
                      widget.providers.length,
                      (index) => ChoiceChip(
                        label: Text(widget.providers[index].runtimeType.toString().replaceAll('Provider', '')),
                        selected: _activeProviderIndex == index.toString(),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _activeProviderIndex = index.toString();
                            });
                            _performSearch();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? const Center(child: Text('No results found. Try refining your search.'))
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final metadata = _searchResults[index];
                            return _buildResultCard(context, metadata);
                          },
                        ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultCard(BuildContext context, AudiobookMetadata metadata) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          widget.onMetadataSelected(metadata);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              SizedBox(
                width: 60,
                height: 90,
                child: metadata.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: metadata.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.book, size: 32),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.book, size: 32),
                      ),
              ),
              const SizedBox(width: 12),
              // Metadata details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metadata.authorsFormatted,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (metadata.publishedDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Published: ${metadata.publishedDate}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (metadata.series.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Series: ${metadata.series} ${metadata.seriesPosition.isNotEmpty ? "#${metadata.seriesPosition}" : ""}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (metadata.averageRating > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < metadata.averageRating.floor()
                                  ? Icons.star
                                  : (index < metadata.averageRating.ceil() &&
                                          metadata.averageRating > index)
                                      ? Icons.star_half
                                      : Icons.star_outline,
                              size: 14,
                              color: Colors.amber,
                            );
                          }),
                          const SizedBox(width: 4),
                          Text(
                            '(${metadata.ratingsCount})',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Selection button
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () {
                  widget.onMetadataSelected(metadata);
                },
                tooltip: 'Select this metadata',
              ),
            ],
          ),
        ),
      ),
    );
  }
}