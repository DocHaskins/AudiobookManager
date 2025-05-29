// lib/ui/widgets/tools/mp3_merger_tool.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/models/chapter_info.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/ui/widgets/dialogs/metadata_search_dialog.dart';
import 'package:audiobook_organizer/ui/widgets/dialogs/conversion_progress_dialog.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/file_utils.dart';

class Mp3MergerTool extends StatefulWidget {
  final LibraryManager libraryManager;
  final List<MetadataProvider> metadataProviders;

  const Mp3MergerTool({
    Key? key,
    required this.libraryManager,
    required this.metadataProviders,
  }) : super(key: key);

  @override
  State<Mp3MergerTool> createState() => _Mp3MergerToolState();
}

class _Mp3MergerToolState extends State<Mp3MergerTool> {
  final MetadataService _metadataService = MetadataService();
  
  List<ChapterInfo> _chapters = [];
  AudiobookMetadata? _bookMetadata;
  String? _selectedFolder;
  bool _isScanning = false;
  bool _isProcessing = false;
  String _statusMessage = '';
  
  // Book-level metadata
  String _bookTitle = '';
  String _bookAuthor = '';
  String _outputFileName = '';
  
  @override
  void initState() {
    super.initState();
    _initializeService();
    
    // Debug logging for providers
    Logger.log('=== Mp3MergerTool: InitState ===');
    Logger.log('Received ${widget.metadataProviders.length} metadata providers');
    
    for (int i = 0; i < widget.metadataProviders.length; i++) {
      final provider = widget.metadataProviders[i];
      Logger.log('Provider $i: ${provider.runtimeType}');
      
      // Check Google Books provider specifically
      if (provider.runtimeType.toString().contains('GoogleBooksProvider')) {
        Logger.log('Found GoogleBooksProvider');
        // Use reflection-safe approach since we can't cast directly
        Logger.log('GoogleBooksProvider detected');
      }
    }
    
    if (widget.metadataProviders.isEmpty) {
      Logger.error('NO METADATA PROVIDERS RECEIVED IN MP3 MERGER TOOL!');
      Logger.error('This means the providers are not being passed correctly from the parent widget');
    }
    
    Logger.log('=== End Mp3MergerTool InitState Debug ===');
  }

  Future<void> _initializeService() async {
    await _metadataService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFolderSelection(),
            const SizedBox(height: 24),
            if (_selectedFolder != null) ...[
              _buildBookMetadataSection(),
              const SizedBox(height: 24),
              _buildChaptersList(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildStatusMessage(),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.merge_type_rounded,
            color: Colors.indigo,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MP3 to M4B Merger',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Combine multiple MP3 files into a single M4B audiobook with chapters',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFolderSelection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_open, color: Colors.blue[400], size: 20),
              const SizedBox(width: 8),
              Text(
                'Select Source Folder',
                style: TextStyle(
                  color: Colors.blue[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_selectedFolder != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder, color: Colors.grey[400]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedFolder!,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _isScanning ? null : _clearFolder,
                    icon: const Icon(Icons.clear, color: Colors.red),
                    tooltip: 'Clear selection',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isScanning ? null : _selectFolder,
                icon: _isScanning 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open),
                label: Text(_isScanning ? 'Scanning...' : 'Select Folder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              if (_selectedFolder != null && !_isScanning) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _rescanFolder,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rescan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 12),
          Text(
            'Select a folder containing MP3 files that you want to merge into a single M4B audiobook.',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookMetadataSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.book, color: Colors.green[400], size: 20),
              const SizedBox(width: 8),
              Text(
                'Book Metadata',
                style: TextStyle(
                  color: Colors.green[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_bookMetadata == null)
                OutlinedButton.icon(
                  onPressed: _searchOnlineMetadata,
                  icon: const Icon(Icons.search),
                  label: const Text('Search Online'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[400],
                    side: BorderSide(color: Colors.green[400]!),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_bookMetadata != null) ...[
            _buildMetadataDisplay(),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _searchOnlineMetadata,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Metadata'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _clearMetadata,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
          ] else ...[
            _buildManualMetadataInput(),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataDisplay() {
    if (_bookMetadata == null) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              if (_bookMetadata!.thumbnailUrl.isNotEmpty)
                Container(
                  width: 80,
                  height: 120,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _bookMetadata!.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.book,
                        color: Colors.grey[600],
                        size: 32,
                      ),
                    ),
                  ),
                ),
              
              // Metadata details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bookMetadata!.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bookMetadata!.authorsFormatted,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    if (_bookMetadata!.series.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_bookMetadata!.series} #${_bookMetadata!.seriesPosition}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    if (_bookMetadata!.publishedDate.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Published: ${_bookMetadata!.publishedDate}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          if (_bookMetadata!.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _bookMetadata!.description,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualMetadataInput() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Book Title',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  hintText: 'Enter the book title',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _bookTitle = value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Author',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  hintText: 'Enter the author name',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _bookAuthor = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Output Filename (without extension)',
            labelStyle: TextStyle(color: Colors.grey[400]),
            hintText: 'Enter the output filename',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) => setState(() => _outputFileName = value),
        ),
      ],
    );
  }

  Widget _buildChaptersList() {
    if (_chapters.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.audiotrack_outlined,
                size: 48,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'No chapters found',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a folder containing MP3 files to see chapters',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.playlist_play, color: Colors.purple[400], size: 20),
              const SizedBox(width: 8),
              Text(
                'Chapters (${_chapters.length})',
                style: TextStyle(
                  color: Colors.purple[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Total: ${_getTotalDuration()}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            height: 300,
            child: ReorderableListView.builder(
              itemCount: _chapters.length,
              onReorder: _reorderChapters,
              itemBuilder: (context, index) {
                final chapter = _chapters[index];
                return _buildChapterCard(chapter, index, key: ValueKey(chapter.filePath));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(ChapterInfo chapter, int index, {required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Row(
        children: [
          // Drag handle
          Icon(
            Icons.drag_handle,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          
          // Chapter number
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Chapter info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  path_util.basename(chapter.filePath),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Duration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              chapter.formattedDuration,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final canProcess = _chapters.isNotEmpty && 
                     (_bookMetadata != null || (_bookTitle.isNotEmpty && _bookAuthor.isNotEmpty)) &&
                     !_isProcessing;

    return Column(
      children: [
        // Primary action row - Merge and Reset
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: canProcess ? _startMergeProcess : null,
              icon: _isProcessing 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.merge_type),
              label: Text(_isProcessing ? 'Processing...' : 'Merge to M4B'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _isProcessing ? null : _resetTool,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.grey[600]!),
              ),
            ),
          ],
        ),
        
        // Secondary action row - Clear All button
        if (_selectedFolder != null || _chapters.isNotEmpty || _bookMetadata != null || 
            _bookTitle.isNotEmpty || _bookAuthor.isNotEmpty || _outputFileName.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _clearAllData,
              icon: const Icon(Icons.clear_all, color: Colors.orange),
              label: const Text(
                'Clear All & Start Fresh',
                style: TextStyle(color: Colors.orange),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isProcessing ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isProcessing ? Colors.blue.withOpacity(0.3) : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          if (_isProcessing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.check_circle,
              color: Colors.green[400],
              size: 16,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: _isProcessing ? Colors.blue[300] : Colors.green[300],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null && mounted) {
        setState(() {
          _selectedFolder = result;
          _statusMessage = 'Selected folder: ${path_util.basename(result)}';
        });
        await _scanFolder(result);
      }
    } catch (e) {
      Logger.error('Error selecting folder', e);
      _showErrorSnackBar('Error selecting folder: $e');
    }
  }

  Future<void> _scanFolder(String folderPath) async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning folder for MP3 files...';
      _chapters = [];
    });

    try {
      final directory = Directory(folderPath);
      final files = await directory
          .list(recursive: false)
          .where((entity) => entity is File && 
                 path_util.extension(entity.path).toLowerCase() == '.mp3')
          .cast<File>()
          .toList();

      if (files.isEmpty) {
        setState(() {
          _statusMessage = 'No MP3 files found in selected folder';
          _isScanning = false;
        });
        return;
      }

      // Sort files naturally (accounting for numbers)
      files.sort((a, b) => _naturalSort(path_util.basename(a.path), path_util.basename(b.path)));

      final chapters = <ChapterInfo>[];
      Duration currentTime = Duration.zero;

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        setState(() {
          _statusMessage = 'Processing file ${i + 1}/${files.length}: ${path_util.basename(file.path)}';
        });

        try {
          final metadata = await _metadataService.extractMetadata(file.path);
          final duration = metadata?.audioDuration ?? const Duration(minutes: 3); // Fallback duration
          
          final chapterTitle = metadata?.title.isNotEmpty == true 
              ? metadata!.title 
              : _generateChapterTitle(path_util.basenameWithoutExtension(file.path), i + 1);

          chapters.add(ChapterInfo(
            filePath: file.path,
            title: chapterTitle,
            startTime: currentTime,
            duration: duration,
            metadata: metadata,
            order: i,
          ));

          currentTime += duration;

          // Auto-detect book info from first file
          if (i == 0 && metadata != null) {
            if (metadata.authors.isNotEmpty && _bookAuthor.isEmpty) {
              _bookAuthor = metadata.authors.first;
            }
            if (_bookTitle.isEmpty) {
              // Try to extract book title from filename or metadata
              _bookTitle = _extractBookTitle(folderPath, metadata);
            }
            if (_outputFileName.isEmpty) {
              _outputFileName = _generateOutputFileName();
            }
          }
        } catch (e) {
          Logger.error('Error processing file: ${file.path}', e);
          // Add file with basic info even if metadata extraction fails
          chapters.add(ChapterInfo(
            filePath: file.path,
            title: _generateChapterTitle(path_util.basenameWithoutExtension(file.path), i + 1),
            startTime: currentTime,
            duration: const Duration(minutes: 3), // Fallback duration
            order: i,
          ));
          currentTime += const Duration(minutes: 3);
        }
      }

      setState(() {
        _chapters = chapters;
        _statusMessage = 'Found ${chapters.length} MP3 files (Total: ${_getTotalDuration()})';
        _isScanning = false;
      });

    } catch (e) {
      Logger.error('Error scanning folder', e);
      setState(() {
        _statusMessage = 'Error scanning folder: $e';
        _isScanning = false;
      });
    }
  }

  void _reorderChapters(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final ChapterInfo item = _chapters.removeAt(oldIndex);
      _chapters.insert(newIndex, item);
      
      // Recalculate start times
      Duration currentTime = Duration.zero;
      for (int i = 0; i < _chapters.length; i++) {
        _chapters[i] = ChapterInfo(
          filePath: _chapters[i].filePath,
          title: _chapters[i].title,
          startTime: currentTime,
          duration: _chapters[i].duration,
          metadata: _chapters[i].metadata,
          order: i,
        );
        currentTime += _chapters[i].duration;
      }
    });
  }

  Future<void> _searchOnlineMetadata() async {
    final searchQuery = _bookTitle.isNotEmpty && _bookAuthor.isNotEmpty
        ? '$_bookTitle $_bookAuthor'
        : _bookTitle.isNotEmpty
            ? _bookTitle
            : path_util.basename(_selectedFolder ?? '');

    if (searchQuery.isEmpty) {
      _showErrorSnackBar('Please enter a book title to search for metadata');
      return;
    }

    if (widget.metadataProviders.isEmpty) {
      _showErrorSnackBar('No metadata providers available');
      return;
    }

    try {
      Logger.log('=== Starting metadata search for MP3 merger ===');
      Logger.log('Search query: "$searchQuery"');
      Logger.log('Available providers: ${widget.metadataProviders.length}');
      
      // Ensure context is mounted before showing dialog
      if (!mounted) {
        Logger.error('Widget not mounted, cannot search metadata');
        return;
      }

      Logger.log('Showing metadata search dialog...');
      
      final result = await MetadataSearchDialog.show(
        context: context,
        initialQuery: searchQuery,
        providers: widget.metadataProviders,
        currentMetadata: _bookMetadata,
      );

      Logger.log('Dialog completed. Result: ${result != null ? 'Found result' : 'No result'}');

      if (result != null && mounted) {
        Logger.log('Processing metadata result: ${result.metadata.title}');
        Logger.log('Update type: ${result.updateType.name}');
        Logger.log('Update cover: ${result.updateCover}');
        
        setState(() {
          _bookMetadata = result.metadata;
          _bookTitle = result.metadata.title;
          _bookAuthor = result.metadata.authorsFormatted;
          if (_outputFileName.isEmpty) {
            _outputFileName = _generateOutputFileName();
          }
        });
        
        _showSuccessSnackBar('Metadata found and applied: "${result.metadata.title}"');
        Logger.log('Successfully applied metadata from search result');
      } else if (result == null) {
        Logger.log('No result from dialog - user cancelled or no selection made');
      }
    } catch (e) {
      Logger.error('Error searching metadata for MP3 merger: $e');
      Logger.error('Stack trace: ${StackTrace.current}');
      if (mounted) {
        _showErrorSnackBar('Error searching metadata: ${e.toString()}');
      }
    } finally {
      Logger.log('=== MP3 merger metadata search completed ===');
    }
  }

  Future<void> _startMergeProcess() async {
    if (_chapters.isEmpty) return;

    // Get output location
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save M4B File',
      fileName: '${_outputFileName.isNotEmpty ? _outputFileName : 'merged_audiobook'}.m4b',
      type: FileType.custom,
      allowedExtensions: ['m4b'],
    );

    if (outputPath == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Starting merge process...';
    });

    try {
      // Show progress dialog
      if (!mounted) return;
      final progressResult = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _MergeProgressDialog(
          chapters: _chapters,
          outputPath: outputPath,
          bookMetadata: _bookMetadata ?? _createBasicMetadata(),
          metadataService: _metadataService,
        ),
      );

      if (progressResult == true && mounted) {
        setState(() {
          _statusMessage = 'Successfully created M4B file: ${path_util.basename(outputPath)}';
          _isProcessing = false;
        });
        
        // Offer to add to library
        await _offerAddToLibrary(outputPath);
      } else {
        setState(() {
          _statusMessage = 'Merge process cancelled or failed';
          _isProcessing = false;
        });
      }
    } catch (e) {
      Logger.error('Error in merge process', e);
      setState(() {
        _statusMessage = 'Error during merge: $e';
        _isProcessing = false;
      });
    }
  }

  AudiobookMetadata _createBasicMetadata() {
    return AudiobookMetadata(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _bookTitle.isNotEmpty ? _bookTitle : 'Merged Audiobook',
      authors: _bookAuthor.isNotEmpty ? [_bookAuthor] : ['Unknown Author'],
      audioDuration: _getTotalDurationObject(),
      fileFormat: 'M4B',
      provider: 'mp3_merger',
    );
  }

  Future<void> _offerAddToLibrary(String filePath) async {
    if (!mounted) return;
    
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Add to Library', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Would you like to add the created M4B file to your audiobook library?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (shouldAdd == true) {
      try {
        Logger.log('Adding M4B file to library: ${path_util.basename(filePath)}');
        
        // Create AudiobookFile from the M4B file with metadata extraction
        final audioFile = await AudiobookFile.fromFile(File(filePath), extractMetadata: true);
        
        if (audioFile != null) {
          // If we have book metadata from the merger, use it to enhance the extracted metadata
          if (_bookMetadata != null && audioFile.metadata != null) {
            // Enhance the extracted metadata with our book metadata
            final enhancedMetadata = audioFile.metadata!.enhance(_bookMetadata!);
            audioFile.metadata = enhancedMetadata;
            Logger.log('Enhanced extracted metadata with merger book metadata');
          } else if (_bookMetadata != null) {
            // Use the book metadata if no metadata was extracted
            audioFile.metadata = _bookMetadata!;
            Logger.log('Using merger book metadata for new M4B file');
          }
          
          // Add the file to the library using the new method
          final success = await widget.libraryManager.addSingleFile(audioFile);
          
          if (success) {
            _showSuccessSnackBar('M4B file added to library successfully: "${audioFile.metadata?.title ?? audioFile.filename}"');
            Logger.log('Successfully added M4B file to library: ${audioFile.filename}');
          } else {
            _showErrorSnackBar('Failed to add M4B file to library');
            Logger.error('LibraryManager.addSingleFile returned false');
          }
        } else {
          _showErrorSnackBar('Could not create AudiobookFile from M4B file');
          Logger.error('AudiobookFile.fromFile returned null for: $filePath');
        }
      } catch (e) {
        Logger.error('Error adding M4B file to library: $filePath', e);
        _showErrorSnackBar('Error adding file to library: ${e.toString()}');
      }
    }
  }

  void _clearFolder() {
    setState(() {
      _selectedFolder = null;
      _chapters = [];
      _statusMessage = '';
    });
  }

  void _clearMetadata() {
    setState(() {
      _bookMetadata = null;
    });
  }

  void _resetTool() {
    setState(() {
      _selectedFolder = null;
      _chapters = [];
      _bookMetadata = null;
      _bookTitle = '';
      _bookAuthor = '';
      _outputFileName = '';
      _statusMessage = '';
    });
  }

  Future<void> _rescanFolder() async {
    if (_selectedFolder != null) {
      await _scanFolder(_selectedFolder!);
    }
  }

  // Helper methods
  String _getTotalDuration() {
    final total = _getTotalDurationObject();
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Duration _getTotalDurationObject() {
    return _chapters.fold(Duration.zero, (total, chapter) => total + chapter.duration);
  }

  String _generateChapterTitle(String filename, int chapterNumber) {
    // Clean up filename and create a nice chapter title
    final cleaned = filename
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\d+'), '')
        .trim();
    
    if (cleaned.isEmpty) {
      return 'Chapter $chapterNumber';
    }
    
    return 'Chapter $chapterNumber: $cleaned';
  }

  String _extractBookTitle(String folderPath, AudiobookMetadata metadata) {
    // Try metadata first
    if (metadata.title.isNotEmpty) {
      return metadata.title;
    }
    
    // Use folder name as fallback
    return path_util.basename(folderPath);
  }

  String _generateOutputFileName() {
    if (_bookTitle.isNotEmpty && _bookAuthor.isNotEmpty) {
      return '$_bookAuthor - $_bookTitle';
    } else if (_bookTitle.isNotEmpty) {
      return _bookTitle;
    } else if (_selectedFolder != null) {
      return path_util.basename(_selectedFolder!);
    }
    return 'merged_audiobook';
  }

  int _naturalSort(String a, String b) {
    // Natural sorting that handles numbers correctly
    final regex = RegExp(r'(\d+)');
    final aMatches = regex.allMatches(a).toList();
    final bMatches = regex.allMatches(b).toList();
    
    if (aMatches.isNotEmpty && bMatches.isNotEmpty) {
      final aNum = int.tryParse(aMatches.first.group(0)!) ?? 0;
      final bNum = int.tryParse(bMatches.first.group(0)!) ?? 0;
      return aNum.compareTo(bNum);
    }
    
    return a.compareTo(b);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _clearAllData() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear All Data', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'This will clear all current data including:\n'
          '• Selected folder\n'
          '• All chapters\n'
          '• Book metadata\n'
          '• Manual input fields\n'
          '• Output filename\n\n'
          'Are you sure you want to start fresh?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      setState(() {
        // Clear folder and chapters
        _selectedFolder = null;
        _chapters = [];
        
        // Clear metadata
        _bookMetadata = null;
        
        // Clear manual input fields
        _bookTitle = '';
        _bookAuthor = '';
        _outputFileName = '';
        
        // Clear status
        _statusMessage = '';
        _isScanning = false;
        _isProcessing = false;
      });
      
      _showSuccessSnackBar('All data cleared. Ready for a new merge project!');
      Logger.log('MP3 Merger: All data cleared by user');
    }
  }
}

// Progress Dialog for the merge process
class _MergeProgressDialog extends StatefulWidget {
  final List<ChapterInfo> chapters;
  final String outputPath;
  final AudiobookMetadata bookMetadata;
  final MetadataService metadataService;

  const _MergeProgressDialog({
    required this.chapters,
    required this.outputPath,
    required this.bookMetadata,
    required this.metadataService,
  });

  @override
  State<_MergeProgressDialog> createState() => _MergeProgressDialogState();
}

class _MergeProgressDialogState extends State<_MergeProgressDialog> {
  String _currentStage = 'Preparing merge process...';
  double _progress = 0.0;
  bool _isComplete = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startMergeProcess();
  }

  Future<void> _startMergeProcess() async {
    try {
      final success = await widget.metadataService.mergeMP3FilesToM4B(
        widget.chapters,
        widget.outputPath,
        widget.bookMetadata,
        onProgress: (stage, progress) {
          if (mounted) {
            setState(() {
              _currentStage = stage;
              _progress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isComplete = true;
          if (success) {
            _currentStage = 'Merge completed successfully!';
            _progress = 1.0;
          } else {
            _errorMessage = 'Merge process failed';
          }
        });

        // Auto-close after success
        if (success) {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        }
      }
    } catch (e) {
      Logger.error('Error in merge process', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isComplete = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final outputFileName = path_util.basename(widget.outputPath);
    
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Row(
        children: [
          Icon(
            _isComplete 
                ? (_errorMessage == null ? Icons.check_circle : Icons.error)
                : Icons.merge_type,
            color: _isComplete 
                ? (_errorMessage == null ? Colors.green : Colors.red)
                : Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isComplete 
                  ? (_errorMessage == null ? 'Merge Complete' : 'Merge Failed')
                  : 'Merging MP3 Files',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              outputFileName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Progress bar
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[700],
              valueColor: AlwaysStoppedAnimation<Color>(
                _isComplete 
                    ? (_errorMessage == null ? Colors.green : Colors.red)
                    : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            
            // Progress percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(_progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: Colors.grey[300]),
                ),
                Text(
                  '${widget.chapters.length} chapters',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Current stage
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ] else ...[
              Text(
                _currentStage,
                style: TextStyle(
                  color: _isComplete ? Colors.green : Colors.grey[300],
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isComplete || _errorMessage != null) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(_errorMessage == null),
            style: TextButton.styleFrom(
              foregroundColor: _errorMessage == null ? Colors.green : Colors.red,
            ),
            child: Text(_errorMessage != null ? 'Close' : 'Done'),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ],
    );
  }
}