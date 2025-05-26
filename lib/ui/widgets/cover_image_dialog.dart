// lib/ui/widgets/cover_image_dialog.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'dart:io';

class CoverImageDialog extends StatefulWidget {
  final AudiobookMetadata? currentMetadata;
  final MetadataMatcher metadataMatcher;
  
  const CoverImageDialog({
    Key? key,
    this.currentMetadata,
    required this.metadataMatcher,
  }) : super(key: key);

  /// Static method to show the dialog and return the cover source
  static Future<String?> show({
    required BuildContext context,
    AudiobookMetadata? currentMetadata,
    required MetadataMatcher metadataMatcher,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => CoverImageDialog(
        currentMetadata: currentMetadata,
        metadataMatcher: metadataMatcher,
      ),
    );
  }

  @override
  State<CoverImageDialog> createState() => _CoverImageDialogState();
}

class _CoverImageDialogState extends State<CoverImageDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  List<String> _onlineCovers = [];
  bool _isSearching = false;
  String? _selectedFilePath;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Search for online covers if we have metadata
    if (widget.currentMetadata != null) {
      _searchOnlineCovers();
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }
  
  Future<void> _searchOnlineCovers() async {
    if (widget.currentMetadata == null) return;
    
    setState(() {
      _isSearching = true;
    });
    
    try {
      _onlineCovers = await widget.metadataMatcher.searchCoversOnline(widget.currentMetadata!);
      Logger.log('Found ${_onlineCovers.length} online cover options');
    } catch (e) {
      Logger.error('Error searching online covers', e);
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }
  
  Future<void> _pickLocalFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path!;
        });
      }
    } catch (e) {
      Logger.error('Error picking file', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.image, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Change Cover Image',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Tab bar
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.indigo,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[400],
              tabs: const [
                Tab(
                  icon: Icon(Icons.link),
                  text: 'From URL',
                ),
                Tab(
                  icon: Icon(Icons.folder),
                  text: 'From File',
                ),
                Tab(
                  icon: Icon(Icons.search),
                  text: 'Search Online',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUrlTab(),
                  _buildFileTab(),
                  _buildOnlineSearchTab(),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey[600]!),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _canApply() ? _applySelection : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUrlTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Image URL',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _urlController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'https://example.com/cover.jpg',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.link, color: Colors.white),
          ),
          onChanged: (value) => setState(() {}),
        ),
        const SizedBox(height: 24),
        
        // Preview
        if (_urlController.text.isNotEmpty) ...[
          Text(
            'Preview',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 200,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _urlController.text,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.grey[600],
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        color: Colors.indigo,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildFileTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Local Image File',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        InkWell(
          onTap: _pickLocalFile,
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!, style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFilePath != null ? 'Change selected file' : 'Click to select image file',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                if (_selectedFilePath != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _selectedFilePath!.split('/').last,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Preview selected file
        if (_selectedFilePath != null) ...[
          Text(
            'Preview',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 200,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_selectedFilePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.grey[600],
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildOnlineSearchTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Online Cover Options',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (widget.currentMetadata != null)
              TextButton.icon(
                onPressed: _isSearching ? null : _searchOnlineCovers,
                icon: _isSearching 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isSearching ? 'Searching...' : 'Refresh'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: _isSearching
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.indigo),
                      SizedBox(height: 16),
                      Text(
                        'Searching for cover images...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                )
              : _onlineCovers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            size: 64,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No online covers found',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                          if (widget.currentMetadata == null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Metadata required for online search',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.67,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _onlineCovers.length,
                      itemBuilder: (context, index) {
                        final coverUrl = _onlineCovers[index];
                        final isSelected = _urlController.text == coverUrl;
                        
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _urlController.text = coverUrl;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected 
                                  ? Border.all(color: Colors.indigo, width: 3)
                                  : Border.all(color: Colors.grey[700]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey[800],
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[800],
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.indigo,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
  
  bool _canApply() {
    return _urlController.text.isNotEmpty || _selectedFilePath != null;
  }
  
  void _applySelection() {
    String? result;
    
    if (_selectedFilePath != null) {
      result = _selectedFilePath;
    } else if (_urlController.text.isNotEmpty) {
      result = _urlController.text;
    }
    
    Navigator.of(context).pop(result);
  }
}