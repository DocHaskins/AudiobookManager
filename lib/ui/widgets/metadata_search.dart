// File: lib/widgets/metadata_search.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/providers/google_books_provider.dart';
import 'package:audiobook_organizer/services/providers/open_library_provider.dart';
import 'package:audiobook_organizer/ui/widgets/metadata_result_card.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class MetadataSearch extends StatefulWidget {
  final String initialQuery;
  final Function(AudiobookMetadata) onSelectMetadata;
  final VoidCallback onCancel;

  const MetadataSearch({
    Key? key,
    required this.initialQuery,
    required this.onSelectMetadata,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<MetadataSearch> createState() => MetadataSearchState();
}

// Changed from private to public state class to fix "library_private_types_in_public_api" warning
class MetadataSearchState extends State<MetadataSearch> {
  late TextEditingController _searchController;
  List<AudiobookMetadata> _searchResults = [];
  bool _isLoading = false;
  String _errorMessage = '';
  int _selectedProvider = 0; // 0 = Google Books, 1 = Open Library

  // Initialize providers
  final GoogleBooksProvider _googleBooksProvider = GoogleBooksProvider(apiKey: '');
  final OpenLibraryProvider _openLibraryProvider = OpenLibraryProvider();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    
    // Perform initial search if query is not empty
    if (widget.initialQuery.isNotEmpty) {
      _performSearch(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _searchResults = [];
    });

    try {
      List<AudiobookMetadata> results;
      
      // Search using selected provider
      if (_selectedProvider == 0) {
        results = await _googleBooksProvider.search(query);
      } else {
        results = await _openLibraryProvider.search(query);
      }
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
      
      if (results.isEmpty) {
        setState(() {
          _errorMessage = 'No results found. Try adjusting your search query.';
        });
      }
    } catch (e) {
      Logger.error('Error searching for metadata', e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search for Audiobook Metadata',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Search bar and provider selector
        Row(
          children: [
            // Provider selector
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<int>(
                value: _selectedProvider,
                underline: const SizedBox(), // Remove the default underline
                items: const [
                  DropdownMenuItem(
                    value: 0,
                    child: Text('Google Books'),
                  ),
                  DropdownMenuItem(
                    value: 1,
                    child: Text('Open Library'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedProvider = value!;
                    // Refresh search with new provider
                    if (_searchController.text.isNotEmpty) {
                      _performSearch(_searchController.text);
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            
            // Search field
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Enter book title, author, or series',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  _performSearch(value);
                },
              ),
            ),
            
            // Search button
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading 
                  ? null 
                  : () {
                      _performSearch(_searchController.text);
                    },
              child: const Text('Search'),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Results area
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.grey[700]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.search,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Enter a search query and press Search',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            return MetadataResultCard(
                              metadata: _searchResults[index],
                              onSelect: () {
                                widget.onSelectMetadata(_searchResults[index]);
                              },
                            );
                          },
                        ),
        ),
        
        // Bottom buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }
}