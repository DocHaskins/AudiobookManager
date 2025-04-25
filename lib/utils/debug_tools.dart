// File: lib/utils/debug_tools.dart
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path_util;
import 'package:flutter/material.dart';

import 'package:audiobook_organizer/services/audiobook_scanner.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/utils/directory_lister.dart';
import 'package:audiobook_organizer/utils/file_picker_adapter.dart'; // Import the adapter

/// Debug widget to display directory contents
class DirectoryDebugView extends StatefulWidget {
  final String initialDirectory;
  final AudiobookScanner scanner;
  
  const DirectoryDebugView({
    Key? key,
    required this.initialDirectory,
    required this.scanner,
  }) : super(key: key);

  @override
  State<DirectoryDebugView> createState() => _DirectoryDebugViewState();
}

class _DirectoryDebugViewState extends State<DirectoryDebugView> {
  late String _currentDirectory;
  String _directoryListing = 'Loading...';
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _currentDirectory = widget.initialDirectory;
    _loadDirectoryListing();
  }
  
  Future<void> _loadDirectoryListing() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final lister = DirectoryLister(widget.scanner);
      final listing = await lister.generateDirectoryListing(_currentDirectory);
      
      setState(() {
        _directoryListing = listing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _directoryListing = 'Error loading directory: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveListingToFile() async {
    try {
      final lister = DirectoryLister(widget.scanner);
      final now = DateTime.now().toIso8601String().replaceAll(':', '-');
      final outputPath = path_util.join(
        _currentDirectory, 
        'directory_listing_$now.txt'
      );
      
      await lister.saveDirectoryListingToFile(_currentDirectory, outputPath);
      
      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Listing saved to: $outputPath'),
        ),
      );
    } catch (e) {
      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving listing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _generateAudiobookReport() async {
    try {
      final lister = DirectoryLister(widget.scanner);
      final now = DateTime.now().toIso8601String().replaceAll(':', '-');
      final outputPath = path_util.join(
        _currentDirectory, 
        'audiobook_report_$now.txt'
      );
      
      await lister.saveAudiobookReportToFile(_currentDirectory, outputPath);
      
      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Audiobook report saved to: $outputPath'),
        ),
      );
    } catch (e) {
      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _navigateToParentDirectory() async {
    final parent = path_util.dirname(_currentDirectory);
    if (parent != _currentDirectory) {
      setState(() {
        _currentDirectory = parent;
      });
      await _loadDirectoryListing();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Directory Debug: ${path_util.basename(_currentDirectory)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _saveListingToFile,
            tooltip: 'Save listing to file',
          ),
          IconButton(
            icon: const Icon(Icons.book),
            onPressed: _generateAudiobookReport,
            tooltip: 'Generate audiobook report',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDirectoryListing,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Current path display with navigation
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: _navigateToParentDirectory,
                        tooltip: 'Up to parent directory',
                      ),
                      Expanded(
                        child: Text(
                          _currentDirectory,
                          style: const TextStyle(fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Directory listing
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _directoryListing,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Debug console to show detailed logging for metadata matching
class MetadataDebugConsole extends StatefulWidget {
  final MetadataMatcher matcher;
  final AudiobookScanner scanner;
  
  const MetadataDebugConsole({
    Key? key,
    required this.matcher,
    required this.scanner,
  }) : super(key: key);

  @override
  State<MetadataDebugConsole> createState() => _MetadataDebugConsoleState();
}

class _MetadataDebugConsoleState extends State<MetadataDebugConsole> {
  final List<String> _logEntries = [];
  String? _selectedFilePath;
  bool _isMatching = false;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _log('MetadataDebugConsole initialized');
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _log(String message) {
    setState(() {
      _logEntries.add('${DateTime.now().toString().split('.')[0]} - $message');
    });
  }
  
  void _clearLog() {
    setState(() {
      _logEntries.clear();
      _log('Log cleared');
    });
  }
  
  Future<void> _selectFile() async {
    _log('Selecting file...');
    
    try {
      // Use our file picker adapter to select a file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        setState(() {
          _selectedFilePath = path;
          _log('Selected file: $path');
        });
      } else {
        _log('No file selected');
      }
    } catch (e) {
      _log('Error selecting file: $e');
    }
  }
  
  Future<void> _testMetadataMatching() async {
    if (_selectedFilePath == null) {
      _log('No file selected');
      return;
    }
    
    setState(() {
      _isMatching = true;
      _log('Testing metadata matching for file: $_selectedFilePath');
    });
    
    try {
      final file = AudiobookFile.fromFile(File(_selectedFilePath!));
      _log('File parsed: ${file.filename}${file.extension}');
      
      _log('Generating search query...');
      final searchQuery = file.generateSearchQuery();
      _log('Search query: "$searchQuery"');
      
      _log('Matching metadata...');
      final metadata = await widget.matcher.matchFile(file);
      
      if (metadata != null) {
        _log('✅ Match found!');
        _log('Title: ${metadata.title}');
        _log('Author(s): ${metadata.authorsFormatted}');
        _log('Series: ${metadata.series}');
        _log('Position: ${metadata.seriesPosition}');
        _log('Published: ${metadata.publishedDate}');
        _log('Provider: ${metadata.provider}');
      } else {
        _log('❌ No metadata match found');
      }
    } catch (e) {
      _log('Error matching metadata: $e');
    } finally {
      setState(() {
        _isMatching = false;
      });
    }
  }
  
  Future<void> _testCustomQuery() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _log('Please enter a search query');
      return;
    }
    
    setState(() {
      _isMatching = true;
      _log('Testing custom query: "$query"');
    });
    
    try {
      for (final provider in widget.matcher.providers) {
        _log('Searching with provider: ${provider.runtimeType}');
        final results = await provider.search(query);
        
        if (results.isEmpty) {
          _log('No results from ${provider.runtimeType}');
          continue;
        }
        
        _log('Found ${results.length} results:');
        for (int i = 0; i < results.length; i++) {
          final metadata = results[i];
          _log('${i+1}. ${metadata.title} by ${metadata.authorsFormatted}');
        }
      }
    } catch (e) {
      _log('Error searching with custom query: $e');
    } finally {
      setState(() {
        _isMatching = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metadata Debug Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLog,
            tooltip: 'Clear log',
          ),
        ],
      ),
      body: Column(
        children: [
          // Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File selection
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _selectFile,
                      icon: const Icon(Icons.file_open),
                      label: const Text('Select File'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _selectedFilePath ?? 'No file selected',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _selectedFilePath != null && !_isMatching
                          ? _testMetadataMatching
                          : null,
                      icon: const Icon(Icons.search),
                      label: const Text('Match'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Custom query testing
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Custom Search Query',
                          border: OutlineInputBorder(),
                          hintText: 'Enter a book title and/or author',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: !_isMatching ? _testCustomQuery : null,
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Divider
          const Divider(),
          
          // Log output
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(8),
              child: _isMatching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.green,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _logEntries[_logEntries.length - 1 - index];
                        Color textColor = Colors.grey;
                        
                        if (entry.contains('ERROR:')) {
                          textColor = Colors.red;
                        } else if (entry.contains('LOG:')) {
                          textColor = Colors.green;
                        } else if (entry.contains('✅')) {
                          textColor = Colors.lightGreen;
                        } else if (entry.contains('❌')) {
                          textColor = Colors.orange;
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SelectableText(
                            entry,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}