// lib/ui/widgets/metadata_search_dialog.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/utils/logger.dart';

// Enums and Result Classes
enum MetadataUpdateType {
  enhance,    // Fill in missing data only
  update,     // Better version of same book (keep user data)
  replace,    // Completely different book (reset user data)
}

class MetadataSearchResult {
  final AudiobookMetadata metadata;
  final bool updateCover;
  final MetadataUpdateType updateType;
  
  MetadataSearchResult({
    required this.metadata,
    required this.updateCover,
    required this.updateType,
  });
}

class MetadataSearchDialog extends StatefulWidget {
  final String initialQuery;
  final List<MetadataProvider> providers;
  final AudiobookMetadata? currentMetadata;
  
  const MetadataSearchDialog({
    Key? key,
    required this.initialQuery,
    required this.providers,
    this.currentMetadata,
  }) : super(key: key);

  /// Static method to show the dialog and return the selected metadata
  static Future<MetadataSearchResult?> show({
    required BuildContext context,
    required String initialQuery,
    required List<MetadataProvider> providers,
    AudiobookMetadata? currentMetadata,
  }) async {
    Logger.log('MetadataSearchDialog.show called with query: "$initialQuery"');
    
    final result = await showDialog<MetadataSearchResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MetadataSearchDialog(
        initialQuery: initialQuery,
        providers: providers,
        currentMetadata: currentMetadata,
      ),
    );
    
    Logger.log('MetadataSearchDialog.show returning result: ${result != null ? "Found" : "Null"}');
    return result;
  }

  @override
  State<MetadataSearchDialog> createState() => _MetadataSearchDialogState();
}

class _MetadataSearchDialogState extends State<MetadataSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _resultsScrollController = ScrollController();
  
  List<AudiobookMetadata> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  int _activeProviderIndex = 0;
  AudiobookMetadata? _selectedMetadata;
  String _searchResultsKey = '';
  
  // Pagination
  int _currentPage = 1;
  bool _hasMoreResults = true;
  final int _resultsPerPage = 20;
  
  // Smart operation suggestion
  MetadataUpdateType _suggestedOperation = MetadataUpdateType.enhance;
  MetadataUpdateType _selectedOperation = MetadataUpdateType.enhance;
  bool _updateCover = true;
  
  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _resultsScrollController.addListener(_onScroll);
    
    // Start initial search with slight delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performSearch(reset: true);
      }
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_resultsScrollController.position.pixels >= 
        _resultsScrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore && _hasMoreResults) {
      _loadMoreResults();
    }
  }
  
  Future<void> _performSearch({bool reset = false}) async {
    final query = _searchController.text.trim();
    if (query.isEmpty || !mounted) return;
    
    if (reset) {
      _currentPage = 1;
      _hasMoreResults = true;
    }
    
    setState(() {
      _isSearching = reset;
      if (reset) {
        _searchResults = [];
        _selectedMetadata = null;
      }
      _searchResultsKey = '${query}_${_activeProviderIndex}_${DateTime.now().millisecondsSinceEpoch}';
    });
    
    try {
      if (_activeProviderIndex < widget.providers.length) {
        final activeProvider = widget.providers[_activeProviderIndex];
        Logger.log('Searching with ${activeProvider.runtimeType} for: "$query" (page $_currentPage)');
        
        final results = await activeProvider.search(query);
        
        // Simulate pagination (since most providers don't support it natively)
        final startIndex = (_currentPage - 1) * _resultsPerPage;
        final endIndex = startIndex + _resultsPerPage;
        final pageResults = results.length > startIndex 
            ? results.sublist(startIndex, endIndex < results.length ? endIndex : results.length)
            : <AudiobookMetadata>[];
        
        if (mounted && _searchResultsKey.startsWith('${query}_${_activeProviderIndex}_')) {
          setState(() {
            if (reset) {
              _searchResults = pageResults;
            } else {
              _searchResults.addAll(pageResults);
            }
            _hasMoreResults = endIndex < results.length;
          });
          Logger.log('Found ${pageResults.length} results for page $_currentPage');
        }
      }
    } catch (e) {
      Logger.error('Error searching metadata', e);
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
          _isLoadingMore = false;
        });
      }
    }
  }
  
  Future<void> _loadMoreResults() async {
    if (_isLoadingMore || !_hasMoreResults) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    _currentPage++;
    await _performSearch(reset: false);
  }
  
  double _calculateSimilarity(AudiobookMetadata current, AudiobookMetadata new_) {
    if (widget.currentMetadata == null) return 0.0;
    
    double score = 0.0;
    int checks = 0;
    
    // Title similarity (40% weight)
    if (current.title.isNotEmpty && new_.title.isNotEmpty) {
      final titleSimilarity = _stringSimilarity(current.title.toLowerCase(), new_.title.toLowerCase());
      score += titleSimilarity * 0.4;
      checks++;
    }
    
    // Author similarity (40% weight)
    if (current.authors.isNotEmpty && new_.authors.isNotEmpty) {
      final authorSimilarity = _listSimilarity(
        current.authors.map((a) => a.toLowerCase()).toList(),
        new_.authors.map((a) => a.toLowerCase()).toList(),
      );
      score += authorSimilarity * 0.4;
      checks++;
    }
    
    // Series similarity (20% weight)
    if (current.series.isNotEmpty && new_.series.isNotEmpty) {
      final seriesSimilarity = _stringSimilarity(current.series.toLowerCase(), new_.series.toLowerCase());
      score += seriesSimilarity * 0.2;
      checks++;
    }
    
    return checks > 0 ? score : 0.0;
  }
  
  double _stringSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    
    final wordsA = a.split(' ').where((w) => w.length > 2).toSet();
    final wordsB = b.split(' ').where((w) => w.length > 2).toSet();
    
    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;
    
    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    
    return intersection / union;
  }
  
  double _listSimilarity(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    
    int matches = 0;
    for (final itemA in a) {
      for (final itemB in b) {
        if (_stringSimilarity(itemA, itemB) > 0.8) {
          matches++;
          break;
        }
      }
    }
    
    return matches / (a.length > b.length ? a.length : b.length);
  }
  
  void _onMetadataSelected(AudiobookMetadata metadata) {
    Logger.log('Selected metadata: "${metadata.title}" by ${metadata.authorsFormatted}');
    
    setState(() {
      _selectedMetadata = metadata;
      
      // Smart operation suggestion
      if (widget.currentMetadata != null) {
        final similarity = _calculateSimilarity(widget.currentMetadata!, metadata);
        Logger.log('Similarity score: $similarity');
        
        if (similarity < 0.3) {
          _suggestedOperation = MetadataUpdateType.replace; // Very different = replace
          Logger.log('Suggesting REPLACE operation (low similarity)');
        } else if (similarity > 0.8) {
          _suggestedOperation = MetadataUpdateType.enhance; // Very similar = enhance
          Logger.log('Suggesting ENHANCE operation (high similarity)');
        } else {
          _suggestedOperation = MetadataUpdateType.update; // Somewhat similar = update
          Logger.log('Suggesting UPDATE operation (medium similarity)');
        }
        _selectedOperation = _suggestedOperation;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1200,
        height: 1200,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),
            
            // Search Controls
            _buildSearchControls(),
            const SizedBox(height: 24),
            
            // Main Content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Current metadata (if exists)
                  if (widget.currentMetadata != null) ...[
                    Expanded(
                      flex: 1,
                      child: _buildCurrentMetadataPanel(),
                    ),
                    const SizedBox(width: 16),
                  ],
                  
                  // Center: Search results
                  Expanded(
                    flex: 2,
                    child: _buildResultsPanel(),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Right: Selected metadata details + operation choice
                  Expanded(
                    flex: 1,
                    child: _selectedMetadata != null
                        ? _buildDetailsAndOperationPanel()
                        : _buildEmptyDetailsPanel(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.search, color: Colors.white, size: 28),
        const SizedBox(width: 12),
        const Text(
          'Search Online Metadata',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {
            Logger.log('Dialog cancelled by user');
            Navigator.of(context).pop(null);
          },
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildSearchControls() {
    return Column(
      children: [
        // Search bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Search Query',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  hintText: 'Enter book title, author, ISBN, or series name',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.search, color: Colors.white),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _performSearch(reset: true),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isSearching ? null : () => _performSearch(reset: true),
              icon: _isSearching 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_isSearching ? 'Searching...' : 'Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Provider selector
        if (widget.providers.length > 1) ...[
          Row(
            children: [
              Text(
                'Search Provider:',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 8,
                children: List.generate(
                  widget.providers.length,
                  (index) => ChoiceChip(
                    label: Text(_getProviderName(widget.providers[index])),
                    selected: _activeProviderIndex == index,
                    onSelected: (selected) {
                      if (selected && _activeProviderIndex != index) {
                        setState(() {
                          _activeProviderIndex = index;
                        });
                        _performSearch(reset: true);
                      }
                    },
                    selectedColor: Colors.indigo,
                    backgroundColor: const Color(0xFF2A2A2A),
                    labelStyle: TextStyle(
                      color: _activeProviderIndex == index ? Colors.white : Colors.grey[400],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCurrentMetadataPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.library_books, color: Colors.blue[400], size: 20),
              const SizedBox(width: 8),
              Text(
                'Current Book',
                style: TextStyle(
                  color: Colors.blue[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: SingleChildScrollView(
              child: _buildMetadataDisplay(widget.currentMetadata!, isCompact: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Results header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.green[400], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Search Results (${_searchResults.length}${_hasMoreResults ? '+' : ''})',
                  style: TextStyle(
                    color: Colors.green[400],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_searchResults.isNotEmpty)
                  Text(
                    'Page $_currentPage',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
              ],
            ),
          ),
          
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          
          // Results list
          Expanded(
            child: _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.indigo),
            SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different search terms or check another provider',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _resultsScrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length + (_hasMoreResults ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _searchResults.length) {
          // Load more indicator
          return Container(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _loadMoreResults,
                      child: const Text('Load More Results'),
                    ),
            ),
          );
        }
        
        final metadata = _searchResults[index];
        final isSelected = _selectedMetadata?.id == metadata.id;
        final similarity = widget.currentMetadata != null 
            ? _calculateSimilarity(widget.currentMetadata!, metadata)
            : 0.0;
        
        return _buildResultCard(metadata, isSelected, similarity, () {
          _onMetadataSelected(metadata);
        });
      },
    );
  }

  Widget _buildResultCard(AudiobookMetadata metadata, bool isSelected, double similarity, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? Colors.indigo.withAlpha(60) : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isSelected 
                  ? Border.all(color: Colors.indigo, width: 2)
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover thumbnail
                Container(
                  width: 50,
                  height: 75,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                    border: isSelected 
                        ? Border.all(color: Colors.indigo, width: 1)
                        : null,
                  ),
                  child: metadata.thumbnailUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            metadata.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.book,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.book,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                ),
                
                const SizedBox(width: 12),
                
                // Metadata column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with similarity indicator
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              metadata.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Author
                      Text(
                        metadata.authorsFormatted,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Additional info in a compact row
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          // Series info
                          if (metadata.series.isNotEmpty)
                            _buildInfoChip(
                              '${metadata.series} ${metadata.seriesPosition.isNotEmpty ? "#${metadata.seriesPosition}" : ""}',
                              Icons.book_outlined,
                              Colors.blue[400]!,
                            ),
                          
                          // Publication year
                          if (metadata.publishedDate.isNotEmpty)
                            _buildInfoChip(
                              metadata.publishedDate,
                              Icons.calendar_today,
                              Colors.green[400]!,
                            ),
                          
                          // Rating
                          if (metadata.averageRating > 0)
                            _buildInfoChip(
                              '${metadata.averageRating}⭐',
                              Icons.star,
                              Colors.amber[400]!,
                            ),
                          
                          // Provider
                          if (metadata.provider.isNotEmpty)
                            _buildInfoChip(
                              metadata.provider,
                              Icons.source,
                              Colors.purple[400]!,
                            ),
                        ],
                      ),
                      
                      // Genres (if available)
                      if (metadata.categories.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          metadata.categories.take(3).join(' • '),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      // Description preview (first line only)
                      if (metadata.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          metadata.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Selection indicator and data completeness
                Column(
                  children: [
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.indigo,
                        size: 20,
                      )
                    else
                      const SizedBox(height: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsAndOperationPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.preview, color: Colors.purple[400], size: 20),
              const SizedBox(width: 8),
              Text(
                'Selected Result',
                style: TextStyle(
                  color: Colors.purple[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Metadata display
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildMetadataDisplay(_selectedMetadata!, isCompact: true),
                  
                  const SizedBox(height: 24),
                  
                  // Operation selection
                  _buildOperationSelection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Update Type',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Operation options
        _buildOperationOption(
          MetadataUpdateType.enhance,
          'Enhance',
          'Fill in missing information only',
          Icons.auto_fix_high,
          Colors.green,
          'Keeps all existing data, only adds what\'s missing',
        ),
        
        const SizedBox(height: 8),
        
        _buildOperationOption(
          MetadataUpdateType.update,
          'Update Version',
          'Better version of same book',
          Icons.update,
          Colors.blue,
          'Replaces metadata but preserves bookmarks, notes, and progress',
        ),
        
        const SizedBox(height: 8),
        
        _buildOperationOption(
          MetadataUpdateType.replace,
          'Replace Book',
          'Completely different book',
          Icons.swap_horiz,
          Colors.orange,
          'Replaces everything and resets all user data',
        ),
        
        // Cover update option
        if (_selectedMetadata?.thumbnailUrl.isNotEmpty ?? false) ...[
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Icon(Icons.image, color: Colors.grey[400], size: 16),
              const SizedBox(width: 8),
              Text(
                'Cover Image',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          CheckboxListTile(
            title: Text(
              'Update cover image',
              style: TextStyle(color: Colors.grey[300], fontSize: 12),
            ),
            subtitle: Text(
              'Replace current cover with selected result\'s cover',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
            value: _updateCover,
            onChanged: (value) => setState(() => _updateCover = value ?? false),
            activeColor: Colors.indigo,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ],
    );
  }

  Widget _buildOperationOption(
    MetadataUpdateType type, 
    String title, 
    String subtitle, 
    IconData icon, 
    Color color,
    String description,
  ) {
    final isSelected = _selectedOperation == type;
    final isSuggested = _suggestedOperation == type;
    
    return InkWell(
      onTap: () => setState(() => _selectedOperation = type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(60) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isSelected ? color : Colors.grey[400], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[300],
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isSuggested && !isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withAlpha(60),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Suggested',
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (isSelected)
                  Icon(Icons.radio_button_checked, color: color, size: 18)
                else
                  Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDetailsPanel() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Select a result',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose from search results to view details and update options',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataDisplay(AudiobookMetadata metadata, {bool isCompact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover image
        if (!isCompact) ...[
          Center(
            child: Container(
              width: 140,
              height: 210,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(90),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: metadata.thumbnailUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        metadata.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.book,
                          color: Colors.grey[600],
                          size: 48,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.book,
                      color: Colors.grey[600],
                      size: 48,
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Title
        Text(
          metadata.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 14 : 18,
            fontWeight: FontWeight.bold,
          ),
          maxLines: isCompact ? 2 : null,
          overflow: isCompact ? TextOverflow.ellipsis : null,
        ),
        
        const SizedBox(height: 8),
        
        // Author
        Text(
          metadata.authorsFormatted,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: isCompact ? 12 : 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: isCompact ? 1 : null,
          overflow: isCompact ? TextOverflow.ellipsis : null,
        ),
        
        const SizedBox(height: 16),
        
        // Core Details Section
        if (metadata.series.isNotEmpty || metadata.publishedDate.isNotEmpty || metadata.publisher.isNotEmpty) ...[
          _buildSectionHeader('Basic Information', Icons.info_outline),
          const SizedBox(height: 8),
          
          if (metadata.series.isNotEmpty)
            _buildDetailRow('Series', '${metadata.series} ${metadata.seriesPosition.isNotEmpty ? "#${metadata.seriesPosition}" : ""}', isCompact),
          
          if (metadata.publishedDate.isNotEmpty)
            _buildDetailRow('Published', metadata.publishedDate, isCompact),
          
          if (metadata.publisher.isNotEmpty)
            _buildDetailRow('Publisher', metadata.publisher, isCompact),
          
          if (metadata.language.isNotEmpty)
            _buildDetailRow('Language', metadata.language, isCompact),
          
          const SizedBox(height: 12),
        ],
        
        // Categories and Rating Section
        if (metadata.categories.isNotEmpty || metadata.averageRating > 0) ...[
          _buildSectionHeader('Ratings & Genres', Icons.star_outline),
          const SizedBox(height: 8),
          
          if (metadata.averageRating > 0) ...[
            _buildDetailRow('Rating', '${metadata.averageRating}/5 ⭐', isCompact),
            if (metadata.ratingsCount > 0)
              _buildDetailRow('Reviews', '${metadata.ratingsCount} reviews', isCompact),
          ],
          
          if (metadata.categories.isNotEmpty)
            _buildDetailRow('Genres', metadata.categories.join(', '), isCompact),
          
          const SizedBox(height: 12),
        ],
        
        // Audio Details Section (if available)
        if (metadata.audioDuration != null || metadata.fileFormat.isNotEmpty) ...[
          _buildSectionHeader('Audio Information', Icons.headphones),
          const SizedBox(height: 8),
          
          if (metadata.audioDuration != null)
            _buildDetailRow('Duration', metadata.durationFormatted, isCompact),
          
          if (metadata.fileFormat.isNotEmpty)
            _buildDetailRow('Format', metadata.fileFormat.toUpperCase(), isCompact),
          
          const SizedBox(height: 12),
        ],
        
        // Data Source Section
        if (metadata.provider.isNotEmpty) ...[
          _buildSectionHeader('Source Information', Icons.source),
          const SizedBox(height: 8),
          _buildDetailRow('Provider', metadata.provider, isCompact),
          const SizedBox(height: 12),
        ],
        
        // Description Section
        if (metadata.description.isNotEmpty) ...[
          _buildSectionHeader('Description', Icons.description),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              metadata.description,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: isCompact ? 11 : 12,
                height: 1.5,
              ),
              maxLines: isCompact ? 4 : null,
              overflow: isCompact ? TextOverflow.ellipsis : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[500], size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isCompact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isCompact ? 60 : 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: isCompact ? 10 : 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: isCompact ? 10 : 11,
              ),
              maxLines: isCompact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final hasUserData = widget.currentMetadata?.userRating != null && widget.currentMetadata!.userRating > 0 ||
                       widget.currentMetadata?.bookmarks.isNotEmpty == true ||
                       widget.currentMetadata?.notes.isNotEmpty == true ||
                       widget.currentMetadata?.isFavorite == true;
    
    return Row(
      children: [
        // Warning about user data loss
        if (hasUserData && _selectedOperation == MetadataUpdateType.replace) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(24),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withAlpha(90)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[400], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will delete all bookmarks, notes, ratings, and progress for this book.',
                      style: TextStyle(color: Colors.orange[300], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        
        // Action buttons
        OutlinedButton(
          onPressed: () {
            Logger.log('Dialog cancelled by user');
            Navigator.of(context).pop(null);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.grey[600]!),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          child: const Text('Cancel'),
        ),
        
        const SizedBox(width: 12),
        
        ElevatedButton(
          onPressed: _selectedMetadata != null ? _confirmSelection : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          child: Text(_getActionButtonText()),
        ),
      ],
    );
  }

  String _getActionButtonText() {
    switch (_selectedOperation) {
      case MetadataUpdateType.enhance:
        return 'Enhance Metadata';
      case MetadataUpdateType.update:
        return 'Update Version';
      case MetadataUpdateType.replace:
        return 'Replace Book';
    }
  }

  void _confirmSelection() {
    if (_selectedMetadata == null) {
      Logger.log('No metadata selected, cannot confirm');
      return;
    }
    
    Logger.log('Confirming selection: "${_selectedMetadata!.title}" with operation: ${_selectedOperation.name}');
    Logger.log('Update cover: $_updateCover');
    
    final result = MetadataSearchResult(
      metadata: _selectedMetadata!,
      updateCover: _updateCover,
      updateType: _selectedOperation,
    );
    
    Logger.log('Returning result from dialog');
    Navigator.of(context).pop(result);
  }

  String _getProviderName(MetadataProvider provider) {
    final typeName = provider.runtimeType.toString();
    return typeName.replaceAll('Provider', '').replaceAll('Books', ' Books');
  }
}