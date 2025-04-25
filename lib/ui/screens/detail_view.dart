// File: lib/ui/screens/detail_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as path;

import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/services/audiobook_organizer.dart';
import 'package:audiobook_organizer/storage/user_preferences.dart';
import 'package:audiobook_organizer/ui/widgets/manual_metadata_search_dialog.dart';

class DetailView extends StatefulWidget {
  final AudiobookFile audiobook;
  
  const DetailView({
    Key? key,
    required this.audiobook,
  }) : super(key: key);

  @override
  State<DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<DetailView> {
  late AudiobookFile _audiobook;
  bool _isLoading = false;
  String _namingPattern = '{Author} - {Title}';
  String _previewFilename = '';
  late TextEditingController _patternController;
  bool _showAdvancedOptions = false;
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _audiobook = widget.audiobook;
    _patternController = TextEditingController(text: _namingPattern);
    _loadPreferences();
  }
  
  @override
  void dispose() {
    _patternController.dispose();
    _scrollController.dispose(); // Dispose the scroll controller
    super.dispose();
  }
  
  Future<void> _loadPreferences() async {
    final prefs = Provider.of<UserPreferences>(context, listen: false);
    final pattern = await prefs.getNamingPattern();
    
    setState(() {
      _namingPattern = pattern;
      _patternController.text = pattern;
    });
    
    _updatePreview();
  }
  
  void _updatePreview() {
    if (_audiobook.metadata == null) return;
    
    final organizer = Provider.of<AudiobookOrganizer>(context, listen: false);
    final newName = organizer.generateNewFilename(_audiobook, _namingPattern);
    
    setState(() {
      _previewFilename = newName;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _audiobook.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_audiobook.metadata == null)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _findMetadata,
              tooltip: 'Find metadata',
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
            tooltip: 'Help',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: _buildBody(theme),
            ),
      bottomNavigationBar: _audiobook.metadata != null
          ? BottomAppBar(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _renameFile,
                        icon: const Icon(Icons.edit),
                        label: const Text('Rename'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _moveFile,
                        icon: const Icon(Icons.drive_file_move),
                        label: const Text('Move'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.secondary,
                          foregroundColor: colorScheme.onSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
  
  Widget _buildBody(ThemeData theme) {
  return Scrollbar(
    controller: _scrollController, // Use the class controller
    thickness: 6,
    radius: const Radius.circular(8),
    child: SingleChildScrollView(
      controller: _scrollController, // Use the same controller here
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section with cover and basic info
            if (_audiobook.metadata != null)
              _buildHeaderSection(theme),
            
            const SizedBox(height: 16),
            
            // File information
            _buildFileInfoCard(theme),
            
            const SizedBox(height: 16),
            
            // Metadata section
            if (_audiobook.metadata != null) ...[
              _buildFileManagementCard(theme),
              const SizedBox(height: 16),
              _buildMetadataSection(theme),
            ] else ...[
              _buildNoMetadataCard(theme),
            ],
            
            // Bottom padding for scrolling
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeaderSection(ThemeData theme) {
    final metadata = _audiobook.metadata!;
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image and basic info
          Container(
            color: colorScheme.surfaceVariant,
            height: 280,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image
                if (metadata.thumbnailUrl.isNotEmpty)
                  Hero(
                    tag: 'cover-${_audiobook.path}',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: metadata.thumbnailUrl,
                        width: 180,
                        height: 280,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 180,
                          height: 280,
                          color: colorScheme.surfaceVariant,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 180,
                          height: 280,
                          color: colorScheme.surfaceVariant,
                          child: Icon(
                            Icons.broken_image,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 180,
                    height: 280,
                    color: colorScheme.surfaceVariant,
                    child: Icon(
                      Icons.audiotrack,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                  
                // Basic info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          metadata.title,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Author
                        Text(
                          'By ${metadata.authorsFormatted}',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Series info (if available)
                        if (metadata.series.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              metadata.seriesPosition.isNotEmpty
                                ? '${metadata.series} #${metadata.seriesPosition}'
                                : metadata.series,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Rating
                        if (metadata.averageRating > 0) ...[
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
                                  size: 20,
                                  color: Colors.amber,
                                );
                              }),
                              const SizedBox(width: 8),
                              Text(
                                '${metadata.averageRating.toStringAsFixed(1)} (${metadata.ratingsCount} ratings)',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        const Spacer(),
                        
                        // Source info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Source: ${metadata.provider}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFileInfoCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'File Information',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              theme,
              'Filename',
              _audiobook.filename + _audiobook.extension,
              Icons.insert_drive_file_outlined,
            ),
            _buildInfoRow(
              theme,
              'Path',
              path.dirname(_audiobook.path),
              Icons.folder_outlined,
            ),
            _buildInfoRow(
              theme,
              'Size',
              '${(_audiobook.size / (1024 * 1024)).toStringAsFixed(2)} MB',
              Icons.data_usage_outlined,
            ),
            _buildInfoRow(
              theme,
              'Last Modified',
              _audiobook.lastModified.toString().split('.').first,
              Icons.access_time,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNoMetadataCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: colorScheme.tertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Metadata Available',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This audiobook doesn\'t have associated metadata yet. '
              'Find metadata to enable renaming and organization features.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _findMetadata,
                icon: const Icon(Icons.search),
                label: const Text('Find Metadata'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileManagementCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.manage_accounts_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'File Management',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    _showAdvancedOptions
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: colorScheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showAdvancedOptions = !_showAdvancedOptions;
                    });
                  },
                  tooltip: _showAdvancedOptions
                      ? 'Hide advanced options'
                      : 'Show advanced options',
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              theme,
              'Current Filename',
              path.basename(_audiobook.path),
              Icons.insert_drive_file_outlined,
              isPreview: false,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _patternController,
              decoration: InputDecoration(
                labelText: 'Naming Pattern',
                border: const OutlineInputBorder(),
                helperText: 'Example: {Author} - {Title}',
                prefixIcon: const Icon(Icons.format_shapes),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: _showPatternHelp,
                  tooltip: 'Pattern help',
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _namingPattern = value;
                });
                _updatePreview();
              },
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              theme,
              'Preview',
              _previewFilename,
              Icons.preview_outlined,
              isPreview: true,
            ),
            if (_showAdvancedOptions) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: Text(
                  'Pattern Variables',
                  style: textTheme.titleSmall,
                ),
                initiallyExpanded: false,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVariableRow(theme, '{Title}', 'Book title'),
                        _buildVariableRow(theme, '{Author}', 'Primary author'),
                        _buildVariableRow(theme, '{Authors}', 'All authors, comma separated'),
                        _buildVariableRow(theme, '{Series}', 'Series name'),
                        _buildVariableRow(theme, '{SeriesPosition}', 'Position in series'),
                        _buildVariableRow(theme, '{Year}', 'Publication year'),
                        _buildVariableRow(theme, '{Publisher}', 'Publisher name'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildQuickPatternChip(theme, '{Author} - {Title}'),
                  _buildQuickPatternChip(theme, '{Series} {SeriesPosition} - {Title}'),
                  _buildQuickPatternChip(theme, '{Title} ({Year})'),
                  _buildQuickPatternChip(theme, '{Author} - {Series} {SeriesPosition} - {Title}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetadataSection(ThemeData theme) {
    final metadata = _audiobook.metadata!;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description
        if (metadata.description.isNotEmpty)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Description',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    metadata.description,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          
        if (metadata.description.isNotEmpty)
          const SizedBox(height: 16),
        
        // Additional metadata
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Additional Information',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (metadata.publisher.isNotEmpty)
                  _buildInfoRow(theme, 'Publisher', metadata.publisher, Icons.business),
                if (metadata.publishedDate.isNotEmpty)
                  _buildInfoRow(theme, 'Published Date', metadata.publishedDate, Icons.calendar_today),
                if (metadata.language.isNotEmpty)
                  _buildInfoRow(theme, 'Language', metadata.language, Icons.language),
                if (metadata.categories.isNotEmpty)
                  _buildInfoRow(
                    theme, 
                    'Categories', 
                    metadata.categories.join(', '), 
                    Icons.category
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(
    ThemeData theme, 
    String label, 
    String value, 
    IconData icon, 
    {bool isPreview = false}
  ) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: isPreview 
                ? colorScheme.primary 
                : colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: textTheme.bodyMedium?.copyWith(
                color: isPreview ? colorScheme.primary : null,
                fontWeight: isPreview ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVariableRow(ThemeData theme, String variable, String description) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              variable,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickPatternChip(ThemeData theme, String pattern) {
    final colorScheme = theme.colorScheme;
    
    return ActionChip(
      avatar: const Icon(Icons.format_quote, size: 16),
      label: Text(pattern),
      backgroundColor: colorScheme.primaryContainer.withOpacity(0.5),
      onPressed: () {
        setState(() {
          _namingPattern = pattern;
          _patternController.text = pattern;
        });
        _updatePreview();
      },
    );
  }
  
  void _showPatternHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Naming Pattern Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Use these variables in your naming pattern:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildVariableRow(Theme.of(context), '{Title}', 'Book title'),
              _buildVariableRow(Theme.of(context), '{Author}', 'Primary author'),
              _buildVariableRow(Theme.of(context), '{Authors}', 'All authors, comma separated'),
              _buildVariableRow(Theme.of(context), '{Series}', 'Series name'),
              _buildVariableRow(Theme.of(context), '{SeriesPosition}', 'Position in series'),
              _buildVariableRow(Theme.of(context), '{Year}', 'Publication year'),
              _buildVariableRow(Theme.of(context), '{Publisher}', 'Publisher name'),
              const SizedBox(height: 16),
              const Text(
                'Example: "{Author} - {Title} ({Year})" will result in "J.K. Rowling - Harry Potter (1997)"',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AudioBook Organizer Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This screen allows you to manage your audiobook:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('• View and edit metadata information'),
              const Text('• Rename files using customizable patterns'),
              const Text('• Move files to different locations'),
              const Text('• View detailed book information'),
              const SizedBox(height: 16),
              const Text(
                'If no metadata is available, use the "Find Metadata" button to search online.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _findMetadata() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final matcher = Provider.of<MetadataMatcher>(context, listen: false);
      final metadata = await matcher.matchFile(_audiobook);
      
      if (metadata != null) {
        // Automatic match found
        setState(() {
          _audiobook = AudiobookFile(
            path: _audiobook.path,
            filename: _audiobook.filename,
            extension: _audiobook.extension,
            size: _audiobook.size,
            lastModified: _audiobook.lastModified,
            metadata: metadata,
          );
          _isLoading = false;
        });
        
        _updatePreview();
      } else {
        // No automatic match found, show manual search dialog
        setState(() {
          _isLoading = false;
        });
        
        _showManualSearchDialog();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Show error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding metadata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showManualSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => ManualMetadataSearchDialog(
        initialQuery: _audiobook.generateSearchQuery(),
        onMetadataSelected: (metadata) {
          setState(() {
            _audiobook = AudiobookFile(
              path: _audiobook.path,
              filename: _audiobook.filename,
              extension: _audiobook.extension,
              size: _audiobook.size,
              lastModified: _audiobook.lastModified,
              metadata: metadata,
            );
          });
          
          _updatePreview();
        },
      ),
    );
  }
  
  Future<void> _renameFile() async {
    if (_audiobook.metadata == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final organizer = Provider.of<AudiobookOrganizer>(context, listen: false);
      final newFilename = organizer.generateNewFilename(_audiobook, _namingPattern);
      final success = await organizer.renameFile(_audiobook, newFilename);
      
      setState(() {
        _isLoading = false;
      });
      
      if (success) {
        // Show success
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File renamed successfully'),
          ),
        );
        
        // Update audiobook path
        setState(() {
          final dir = path.dirname(_audiobook.path);
          _audiobook = AudiobookFile(
            path: path.join(dir, newFilename),
            filename: path.basenameWithoutExtension(newFilename),
            extension: path.extension(newFilename),
            size: _audiobook.size,
            lastModified: _audiobook.lastModified,
            metadata: _audiobook.metadata,
          );
        });
        
        // Return true to indicate changes were made
        Navigator.pop(context, true);
      } else {
        // Show error
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to rename file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Show error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error renaming file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _moveFile() async {
    final String? directory = await getDirectoryPath(
      confirmButtonText: 'Select',
    );
    if (directory == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final organizer = Provider.of<AudiobookOrganizer>(context, listen: false);
      final success = await organizer.moveFile(_audiobook, directory);
      
      setState(() {
        _isLoading = false;
      });
      
      if (success) {
        // Show success
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File moved to $directory'),
          ),
        );
        
        // Update audiobook path
        setState(() {
          final filename = path.basename(_audiobook.path);
          _audiobook = AudiobookFile(
            path: path.join(directory, filename),
            filename: _audiobook.filename,
            extension: _audiobook.extension,
            size: _audiobook.size,
            lastModified: _audiobook.lastModified,
            metadata: _audiobook.metadata,
          );
        });
        
        // Return true to indicate changes were made
        Navigator.pop(context, true);
      } else {
        // Show error
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to move file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Show error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error moving file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}