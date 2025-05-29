// lib/ui/widgets/dialogs/goodreads_search_dialog.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/providers/goodreads_service.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class GoodreadsSelectionOptions {
  bool updateTitle;
  bool updateAuthors;
  bool updateDescription;
  bool updateGenres;
  bool updateRating;
  bool updateCover;
  bool updatePublisher;
  bool updatePublishedDate;
  bool updateSeries;
  bool updateISBN;

  GoodreadsSelectionOptions({
    this.updateTitle = false,
    this.updateAuthors = false,
    this.updateDescription = true,
    this.updateGenres = true,
    this.updateRating = true,
    this.updateCover = false,
    this.updatePublisher = true,
    this.updatePublishedDate = true,
    this.updateSeries = true,
    this.updateISBN = true,
  });
}

class GoodreadsResult {
  final GoodreadsMetadata metadata;
  final GoodreadsSelectionOptions options;

  GoodreadsResult({
    required this.metadata,
    required this.options,
  });
}

class GoodreadsSearchDialog extends StatefulWidget {
  final String initialTitle;
  final String initialAuthor;
  final AudiobookMetadata? currentMetadata;

  const GoodreadsSearchDialog({
    Key? key,
    required this.initialTitle,
    required this.initialAuthor,
    this.currentMetadata,
  }) : super(key: key);

  @override
  State<GoodreadsSearchDialog> createState() => _GoodreadsSearchDialogState();

  static Future<GoodreadsResult?> show({
    required BuildContext context,
    required String title,
    required String author,
    AudiobookMetadata? currentMetadata,
  }) async {
    return await showDialog<GoodreadsResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GoodreadsSearchDialog(
        initialTitle: title,
        initialAuthor: author,
        currentMetadata: currentMetadata,
      ),
    );
  }
}

class _GoodreadsSearchDialogState extends State<GoodreadsSearchDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  
  List<GoodreadsSearchResult> _searchResults = [];
  GoodreadsMetadata? _selectedMetadata;
  bool _isSearching = false;
  bool _isLoadingDetails = false;
  String _searchError = '';
  int _selectedIndex = -1;
  
  final GoodreadsSelectionOptions _selectionOptions = GoodreadsSelectionOptions();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle;
    _authorController.text = widget.initialAuthor;
    
    // Auto-search on open if we have title/author
    if (widget.initialTitle.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();
    
    if (title.isEmpty) {
      setState(() {
        _searchError = 'Please enter a book title';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
      _searchResults.clear();
      _selectedMetadata = null;
      _selectedIndex = -1;
    });

    try {
      Logger.log('Searching Goodreads for: "$title" by "$author"');
      
      final results = await GoodreadsService.searchBooks(title, author);
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
      
      if (results.isEmpty) {
        setState(() {
          _searchError = 'No books found. Try adjusting your search terms.';
        });
      } else {
        Logger.log('Found ${results.length} search results');
        
        // Auto-select first result if it looks like a good match
        if (results.isNotEmpty && _isGoodMatch(results.first, title, author)) {
          await _selectBook(0);
        }
      }
      
    } catch (e) {
      Logger.error('Error searching Goodreads: $e');
      setState(() {
        _isSearching = false;
        _searchError = 'Search failed: ${e.toString()}';
      });
    }
  }

  bool _isGoodMatch(GoodreadsSearchResult result, String searchTitle, String searchAuthor) {
    final titleMatch = result.title.toLowerCase().contains(searchTitle.toLowerCase()) ||
                      searchTitle.toLowerCase().contains(result.title.toLowerCase());
    
    bool authorMatch = false;
    if (searchAuthor.isNotEmpty) {
      authorMatch = result.authors.any((author) => 
        author.toLowerCase().contains(searchAuthor.toLowerCase()) ||
        searchAuthor.toLowerCase().contains(author.toLowerCase())
      );
    } else {
      authorMatch = true; // No author to match against
    }
    
    return titleMatch && authorMatch;
  }

  Future<void> _selectBook(int index) async {
    if (index < 0 || index >= _searchResults.length) return;
    
    setState(() {
      _isLoadingDetails = true;
      _selectedIndex = index;
      _selectedMetadata = null;
    });

    try {
      final result = _searchResults[index];
      Logger.log('Loading details for: ${result.title}');
      
      final metadata = await GoodreadsService.getBookMetadata(result.bookUrl);
      
      if (metadata != null) {
        setState(() {
          _selectedMetadata = metadata;
          _isLoadingDetails = false;
        });
        Logger.log('Successfully loaded book details');
      } else {
        setState(() {
          _isLoadingDetails = false;
          _searchError = 'Failed to load book details';
        });
      }
    } catch (e) {
      Logger.error('Error loading book details: $e');
      setState(() {
        _isLoadingDetails = false;
        _searchError = 'Error loading details: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.9;
    final dialogHeight = screenSize.height * 0.9;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                children: [
                  // Search and results section
                  Expanded(
                    flex: 3,
                    child: _buildSearchSection(),
                  ),
                  
                  // Options sidebar
                  Container(
                    width: 300,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      border: Border(
                        left: BorderSide(color: Colors.grey[700]!, width: 1),
                      ),
                    ),
                    child: _buildOptionsSection(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Search Goodreads',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_isSearching || _isLoadingDetails)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search form
          _buildSearchForm(),
          const SizedBox(height: 16),
          
          // Results area
          Expanded(
            child: _buildResultsArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search for Book',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Title field
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Book Title*',
              hintText: 'Enter the book title',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          
          // Author field
          TextField(
            controller: _authorController,
            decoration: const InputDecoration(
              labelText: 'Author (optional)',
              hintText: 'Enter the author name',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          
          // Search button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSearching ? null : _performSearch,
              icon: _isSearching 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_isSearching ? 'Searching...' : 'Search Goodreads'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          // Error message
          if (_searchError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _searchError,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsArea() {
    if (_searchResults.isEmpty && !_isSearching) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[600]!, width: 1),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Enter a book title and click Search',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Results header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3A),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Search Results',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_searchResults.isNotEmpty)
                  Text(
                    '${_searchResults.length} books found',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
              ],
            ),
          ),
          
          // Results list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) => _buildResultItem(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(int index) {
    final result = _searchResults[index];
    final isSelected = index == _selectedIndex;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.orange.withOpacity(0.1) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.orange : Colors.grey[700]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: result.coverUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  result.coverUrl,
                  width: 40,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 40,
                    height: 60,
                    color: Colors.grey[800],
                    child: const Icon(Icons.book, color: Colors.grey),
                  ),
                ),
              )
            : Container(
                width: 40,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.book, color: Colors.grey),
              ),
        title: Text(
          result.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.authors.isNotEmpty)
              Text(
                'by ${result.authors.join(", ")}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (result.rating > 0) ...[
                  Icon(Icons.star, color: Colors.orange, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    result.rating.toStringAsFixed(1),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                ],
                if (result.publishedYear.isNotEmpty) ...[
                  Icon(Icons.calendar_today, color: Colors.grey[500], size: 12),
                  const SizedBox(width: 4),
                  Text(
                    result.publishedYear,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ],
            ),
            if (result.series.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Series: ${result.series}',
                style: TextStyle(color: Colors.blue[300], fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: isSelected && _isLoadingDetails
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isSelected
                ? const Icon(Icons.check_circle, color: Colors.orange)
                : null,
        onTap: () => _selectBook(index),
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: const Text(
            'Update Options',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Selected book preview
        if (_selectedMetadata != null) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Book:',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Title: ${_selectedMetadata!.title}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  'Author: ${_selectedMetadata!.authors.join(", ")}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  'Rating: ${_selectedMetadata!.rating}/5 (${_selectedMetadata!.ratingsCount} ratings)',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  'Genres: ${_selectedMetadata!.genres.take(3).join(", ")}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Options checkboxes
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildCheckboxOption(
                  'Title',
                  _selectionOptions.updateTitle,
                  (value) => setState(() => _selectionOptions.updateTitle = value!),
                ),
                _buildCheckboxOption(
                  'Authors',
                  _selectionOptions.updateAuthors,
                  (value) => setState(() => _selectionOptions.updateAuthors = value!),
                ),
                _buildCheckboxOption(
                  'Description',
                  _selectionOptions.updateDescription,
                  (value) => setState(() => _selectionOptions.updateDescription = value!),
                ),
                _buildCheckboxOption(
                  'Genres/Categories',
                  _selectionOptions.updateGenres,
                  (value) => setState(() => _selectionOptions.updateGenres = value!),
                ),
                _buildCheckboxOption(
                  'Rating',
                  _selectionOptions.updateRating,
                  (value) => setState(() => _selectionOptions.updateRating = value!),
                ),
                _buildCheckboxOption(
                  'Cover Image',
                  _selectionOptions.updateCover,
                  (value) => setState(() => _selectionOptions.updateCover = value!),
                ),
                _buildCheckboxOption(
                  'Publisher',
                  _selectionOptions.updatePublisher,
                  (value) => setState(() => _selectionOptions.updatePublisher = value!),
                ),
                _buildCheckboxOption(
                  'Published Date',
                  _selectionOptions.updatePublishedDate,
                  (value) => setState(() => _selectionOptions.updatePublishedDate = value!),
                ),
                _buildCheckboxOption(
                  'Series Info',
                  _selectionOptions.updateSeries,
                  (value) => setState(() => _selectionOptions.updateSeries = value!),
                ),
                _buildCheckboxOption(
                  'ISBN',
                  _selectionOptions.updateISBN,
                  (value) => setState(() => _selectionOptions.updateISBN = value!),
                ),
              ],
            ),
          ),
        ),
        
        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Apply button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedMetadata != null ? _applyMetadata : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Apply Selected Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxOption(String title, bool value, ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.orange,
      checkColor: Colors.white,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _applyMetadata() {
    if (_selectedMetadata == null) return;
    
    final result = GoodreadsResult(
      metadata: _selectedMetadata!,
      options: _selectionOptions,
    );
    
    Navigator.of(context).pop(result);
  }
}