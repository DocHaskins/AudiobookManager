// lib/ui/screens/audiobook_details_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/ui/screens/player_screen.dart';
import 'package:audiobook_organizer/ui/screens/metadata_edit_screen.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart' as UrlLauncher;

class AudiobookDetailsScreen extends StatefulWidget {
  final AudiobookFile file;
  // Add navigation callback
  final Function(Widget)? onNavigate;
  
  const AudiobookDetailsScreen({
    Key? key, 
    required this.file,
    this.onNavigate,
  }) : super(key: key);
  
  @override
  _AudiobookDetailsScreenState createState() => _AudiobookDetailsScreenState();
}

class _AudiobookDetailsScreenState extends State<AudiobookDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDescriptionExpanded = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize tab controller
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final playerService = Provider.of<AudioPlayerService>(context);
    final libraryManager = Provider.of<LibraryManager>(context);
    final metadata = widget.file.metadata;
    
    return Column(
      children: [
        // Header with edit button
        Padding(
          padding: const EdgeInsets.only(right: 8.0, top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Only show the write button if metadata exists
              if (metadata != null)
                IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: 'Write to File',
                  onPressed: () => _writeMetadataToFile(context),
                ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Metadata',
                onPressed: () => _navigateToEditScreen(context),
              ),
            ],
          ),
        ),
        
        // Cover and info section
        _buildHeaderSection(context, metadata),
        
        // Tab bar
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Notes & Bookmarks'),
          ],
        ),
        
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Details tab
              _buildDetailsTab(metadata),
              
              // Notes & Bookmarks tab
              _buildNotesBookmarksTab(metadata),
            ],
          ),
        ),
      ],
    );
  }
  
  // Enhanced header section with cover, title, series, and play button
  Widget _buildHeaderSection(BuildContext context, AudiobookMetadata? metadata) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image with shadow effect
          Container(
            width: 120,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: metadata?.thumbnailUrl.isNotEmpty == true
                ? Image.file(
                    File(metadata!.thumbnailUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.book, size: 60, color: Colors.white54);
                    },
                  )
                : const Icon(Icons.book, size: 60, color: Colors.white54),
          ),
          
          const SizedBox(width: 16),
          
          // Title and info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata?.title ?? widget.file.filename,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                
                if (metadata?.authors.isNotEmpty == true)
                  Text(
                    metadata!.authorsFormatted,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[300],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                
                const SizedBox(height: 10),
                
                // Series information with visual highlight
                if (metadata?.series.isNotEmpty == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${metadata!.series} ${metadata.seriesPosition.isNotEmpty ? "#${metadata.seriesPosition}" : ""}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Average rating
                if ((metadata?.averageRating ?? 0) > 0)
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          index < metadata!.averageRating.floor()
                              ? Icons.star
                              : (index < metadata.averageRating.ceil() &&
                                      metadata.averageRating > index)
                                  ? Icons.star_half
                                  : Icons.star_outline,
                          size: 18,
                          color: Colors.amber,
                        );
                      }),
                      const SizedBox(width: 6),
                      Text(
                        '${metadata!.averageRating.toStringAsFixed(1)} (${metadata.ratingsCount} ratings)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 16),
                
                // Play button
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                  onPressed: () => _playAudiobook(context, Provider.of<AudioPlayerService>(context, listen: false)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build an info row with label and value
  Widget _buildInfoRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
  
  // Enhanced details tab with improved metadata display
  Widget _buildDetailsTab(AudiobookMetadata? metadata) {
    if (metadata == null) {
      return const Center(
        child: Text('No metadata available'),
      );
    }
    
    // Check if description might contain HTML content
    final bool mightContainHtml = metadata.description.contains('<') && 
                               metadata.description.contains('>');
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description section with HTML support
          if (metadata.description.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.description, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (metadata.description.length > 200)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isDescriptionExpanded = !_isDescriptionExpanded;
                              });
                            },
                            child: Text(_isDescriptionExpanded ? 'Show Less' : 'Show More'),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: mightContainHtml
                        ? Html(
                            data: _isDescriptionExpanded 
                                ? metadata.description 
                                : _truncateHtml(metadata.description, 300),
                            style: {
                              "body": Style(
                                margin: EdgeInsets.zero as Margins,
                                //padding: EdgeInsets.zero,
                                fontSize: FontSize.medium,
                              ),
                              "p": Style(
                                margin: const EdgeInsets.only(bottom: 8) as Margins,
                              ),
                            },
                          )
                        : Text(
                            _isDescriptionExpanded 
                                ? metadata.description 
                                : (metadata.description.length > 300
                                    ? '${metadata.description.substring(0, 300)}...'
                                    : metadata.description),
                            style: const TextStyle(fontSize: 15),
                          ),
                  ),
                ],
              ),
            ),
          
          // Publication information (publisher, date, language)
          if (metadata.publisher.isNotEmpty || metadata.publishedDate.isNotEmpty || metadata.language.isNotEmpty)
            _buildInfoCard(
              title: 'Publication Information',
              icon: Icons.menu_book,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (metadata.publisher.isNotEmpty)
                    _buildInfoRow(
                      'Publisher',
                      metadata.publisher,
                    ),
                  if (metadata.publishedDate.isNotEmpty)
                    _buildInfoRow(
                      'Published',
                      metadata.publishedDate,
                    ),
                  if (metadata.language.isNotEmpty)
                    _buildInfoRow(
                      'Language',
                      metadata.language,
                    ),
                ],
              ),
            ),
          
          // Categories and tags card
          if (metadata.categories.isNotEmpty || metadata.userTags.isNotEmpty)
            _buildInfoCard(
              title: 'Categories & Tags',
              icon: Icons.category,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (metadata.categories.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Genres',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: metadata.categories.map((category) {
                        return Chip(
                          label: Text(category),
                          backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (metadata.userTags.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'User Tags',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: metadata.userTags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: Theme.of(context).primaryColor,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          
          // Ratings card (user & average)
          _buildInfoCard(
            title: 'Ratings',
            icon: Icons.star_rate,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User rating
                if (metadata.userRating > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Rating',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ...List.generate(5, (index) {
                              return Icon(
                                index < metadata.userRating 
                                    ? Icons.star 
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 28,
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                
                // Average rating
                if (metadata.averageRating > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Average Rating',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < metadata.averageRating.floor()
                                  ? Icons.star
                                  : (index < metadata.averageRating.ceil() &&
                                          metadata.averageRating > index)
                                      ? Icons.star_half
                                      : Icons.star_border,
                              color: Colors.amber,
                              size: 28,
                            );
                          }),
                          const SizedBox(width: 12),
                          Text(
                            metadata.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${metadata.ratingsCount} ratings)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Audio information
          _buildInfoCard(
            title: 'Audio Information',
            icon: Icons.audiotrack,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metadata.audioDuration != null)
                  _buildInfoRow(
                    'Duration',
                    _formatDuration(metadata.audioDuration!),
                  ),
                if (metadata.fileFormat.isNotEmpty)
                  _buildInfoRow(
                    'Format',
                    metadata.fileFormat.toUpperCase(),
                  ),
                if (metadata.bitrate != null)
                  _buildInfoRow(
                    'Bitrate',
                    '${metadata.bitrate! ~/ 1000} kbps',
                  ),
                if (metadata.sampleRate != null)
                  _buildInfoRow(
                    'Sample Rate',
                    '${metadata.sampleRate! ~/ 1000} kHz',
                  ),
                if (metadata.channels != null)
                  _buildInfoRow(
                    'Channels',
                    metadata.channels == 1 ? 'Mono' : 'Stereo',
                  ),
              ],
            ),
          ),
          
          // Progress information
          if (metadata.playbackPosition != null)
            _buildInfoCard(
              title: 'Progress',
              icon: Icons.play_circle,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: metadata.audioDuration != null
                        ? metadata.playbackPosition!.inSeconds / 
                          metadata.audioDuration!.inSeconds
                        : 0,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(metadata.playbackPosition!),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (metadata.audioDuration != null)
                        Text(
                          '- ${_formatDuration(metadata.audioDuration! - metadata.playbackPosition!)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  if (metadata.lastPlayedPosition != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        'Last played: ${_formatDate(metadata.lastPlayedPosition!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          
          // File information
          _buildInfoCard(
            title: 'File Information',
            icon: Icons.insert_drive_file,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Filename',
                  widget.file.filename,
                ),
                _buildInfoRow(
                  'Path',
                  widget.file.path,
                ),
                _buildInfoRow(
                  'Size',
                  _formatFileSize(widget.file.fileSize),
                ),
                _buildInfoRow(
                  'Modified',
                  _formatDate(widget.file.lastModified),
                ),
              ],
            ),
          ),
          
          // Source information (where metadata came from)
          if (metadata.provider.isNotEmpty)
            _buildInfoCard(
              title: 'Metadata Source',
              icon: Icons.cloud,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    'Provider',
                    metadata.provider,
                  ),
                  if (metadata.provider == 'Google Books' && metadata.id.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('View on Google Books'),
                        onPressed: () {
                          _launchUrl('https://books.google.com/books?id=${metadata.id}');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  if (metadata.provider == 'Open Library' && metadata.id.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('View on Open Library'),
                        onPressed: () {
                          _launchUrl('https://openlibrary.org${metadata.id}');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
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
  
  // Build a standardized info card
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget content,
    bool expanded = true,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Card content
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: content,
            ),
        ],
      ),
    );
  }
  
  // Build notes and bookmarks tab
  Widget _buildNotesBookmarksTab(AudiobookMetadata? metadata) {
    if (metadata == null) {
      return const Center(
        child: Text('No metadata available'),
      );
    }
    
    final bookmarks = metadata.bookmarks;
    final notes = metadata.notes;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bookmarks section
          _buildInfoCard(
            title: 'Bookmarks (${bookmarks.length})',
            icon: Icons.bookmark,
            content: bookmarks.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No bookmarks yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : Column(
                    children: bookmarks
                        .map((bookmark) => _buildBookmarkItem(bookmark))
                        .toList(),
                  ),
          ),
          
          // Notes section
          _buildInfoCard(
            title: 'Notes (${notes.length})',
            icon: Icons.note,
            content: notes.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No notes yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : Column(
                    children: notes
                        .map((note) => _buildNoteItem(note))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
  
  // Build a bookmark item
  Widget _buildBookmarkItem(AudiobookBookmark bookmark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bookmark.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(bookmark.position),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (bookmark.note != null && bookmark.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  bookmark.note!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Build a note item
  Widget _buildNoteItem(AudiobookNote note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.note, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDate(note.createdAt),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (note.position != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(note.position!),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(note.content),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _writeMetadataToFile(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Show a confirmation dialog
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Write Metadata to File'),
        content: const Text(
          'This will modify the original audio file by writing the current metadata (including cover art) to it. '
          'This operation cannot be undone. Continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!shouldContinue) return;
    
    // Show a loading indicator
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Writing metadata to file...'),
        duration: Duration(days: 1), // Long duration that we'll dismiss manually
      ),
    );
    
    try {
      // Create and initialize metadata service
      final metadataService = MetadataService();
      await metadataService.initialize();
      
      // Determine if we have a cover image to write
      String? coverImagePath;
      if (widget.file.metadata?.thumbnailUrl != null && 
          widget.file.metadata!.thumbnailUrl.isNotEmpty &&
          !widget.file.metadata!.thumbnailUrl.startsWith('http')) {
        // Check if the cover file exists
        final coverFile = File(widget.file.metadata!.thumbnailUrl);
        if (await coverFile.exists()) {
          coverImagePath = widget.file.metadata!.thumbnailUrl;
          Logger.log('Will embed cover image from: $coverImagePath');
        }
      }
      
      // Write metadata to file (including cover if available)
      final success = await metadataService.writeMetadata(
        widget.file.path,
        widget.file.metadata!,
        coverImagePath: coverImagePath, // Pass the cover image path
      );
      
      // Dismiss the loading indicator
      scaffoldMessenger.hideCurrentSnackBar();
      
      // Show success or error message
      if (success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              coverImagePath != null 
                ? 'Metadata and cover art successfully written to file'
                : 'Metadata successfully written to file (no cover art available)'
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to write metadata to file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Log error
      Logger.error('Error writing metadata to file', e);
      
      // Dismiss the loading indicator
      scaffoldMessenger.hideCurrentSnackBar();
      
      // Show error message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error writing metadata to file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Format a duration as HH:MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }
  
  // Truncate HTML content
  String _truncateHtml(String html, int maxLength) {
    if (html.length <= maxLength) return html;
    
    // Simple truncation that tries to respect HTML tags
    int contentLength = 0;
    bool inTag = false;
    int i = 0;
    
    for (i = 0; i < html.length && contentLength < maxLength; i++) {
      if (html[i] == '<') inTag = true;
      if (!inTag) contentLength++;
      if (html[i] == '>') inTag = false;
    }
    
    String truncated = html.substring(0, i);
    
    // Make sure we don't cut in the middle of a tag
    int lastOpenTag = truncated.lastIndexOf('<');
    int lastCloseTag = truncated.lastIndexOf('>');
    
    if (lastOpenTag > lastCloseTag) {
      truncated = truncated.substring(0, lastOpenTag);
    }
    
    return '$truncated...';
  }
  
  // Format file size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
  
  // Launch a URL
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await UrlLauncher.canLaunchUrl(uri)) {
      await UrlLauncher.launchUrl(uri);
    } else {
      Logger.error('Could not launch $url');
    }
  }
  
  // Format a date
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  // Navigate to edit screen
  void _navigateToEditScreen(BuildContext context) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(MetadataEditScreen(
        file: widget.file,
      ));
    } else {
      // Fallback to traditional navigation
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MetadataEditScreen(file: widget.file),
          fullscreenDialog: true,
        ),
      ).then((_) {
        final libraryManager = Provider.of<LibraryManager>(context, listen: false);
        final updatedFile = libraryManager.getFileByPath(widget.file.path);
        
        setState(() {
          // Force update with fresh metadata
          if (updatedFile != null) {
            widget.file.metadata = updatedFile.metadata;
          }
          
          // Clear any image cache to force reload
          imageCache.clear();
          imageCache.clearLiveImages();
        });
      });
    }
  }
  
  // Play the audiobook
  void _playAudiobook(BuildContext context, AudioPlayerService playerService) async {
    try {
      final success = await playerService.play(widget.file);
      
      if (success) {
        // Navigate to player screen using callback if available
        if (widget.onNavigate != null) {
          widget.onNavigate!(PlayerScreen(
            file: widget.file,
          ));
        } else {
          // Fallback to traditional navigation
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlayerScreen(file: widget.file),
            ),
          );
        }
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to play audiobook'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error playing audiobook', e);
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing audiobook: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}