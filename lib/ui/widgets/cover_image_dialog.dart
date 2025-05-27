// lib/ui/widgets/cover_image_dialog.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'dart:io';
import 'dart:typed_data';

enum CoverSource { url, file, online }

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

class _CoverImageDialogState extends State<CoverImageDialog> {
  CoverSource _selectedSource = CoverSource.online;
  final TextEditingController _urlController = TextEditingController();
  List<String> _onlineCovers = [];
  bool _isSearching = false;
  String? _selectedFilePath;
  String? _selectedCoverUrl;
  File? _selectedImageFile;
  Map<String, dynamic>? _imageInfo;
  
  @override
  void initState() {
    super.initState();
    
    // Search for online covers if we have metadata
    if (widget.currentMetadata != null) {
      _searchOnlineCovers();
    }
  }
  
  @override
  void dispose() {
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
        final file = File(result.files.single.path!);
        await _loadImageInfo(file);
        setState(() {
          _selectedFilePath = result.files.single.path!;
          _selectedImageFile = file;
          _selectedCoverUrl = null;
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
  
  Future<void> _loadImageInfo(File file) async {
    try {
      final stat = await file.stat();
      final image = await decodeImageFromList(await file.readAsBytes());
      
      setState(() {
        _imageInfo = {
          'width': image.width,
          'height': image.height,
          'fileSize': stat.size,
          'fileName': file.path.split('/').last,
          'fileType': file.path.split('.').last.toUpperCase(),
          'filePath': file.path,
        };
      });
    } catch (e) {
      Logger.error('Error loading image info', e);
      setState(() {
        _imageInfo = {
          'fileName': file.path.split('/').last,
          'fileType': file.path.split('.').last.toUpperCase(),
          'filePath': file.path,
          'error': 'Could not load image details',
        };
      });
    }
  }
  
  Future<void> _loadUrlImageInfo(String url) async {
    try {
      // This is a simplified version - in a real app you might want to
      // fetch image headers to get dimensions and file size
      setState(() {
        _imageInfo = {
          'url': url,
          'fileType': url.split('.').last.toUpperCase(),
          'source': 'URL',
        };
      });
    } catch (e) {
      Logger.error('Error loading URL image info', e);
    }
  }
  
  void _selectOnlineCover(String url) {
    setState(() {
      _selectedCoverUrl = url;
      _selectedFilePath = null;
      _selectedImageFile = null;
    });
    _loadUrlImageInfo(url);
  }
  
  void _selectUrlCover() {
    if (_urlController.text.isNotEmpty) {
      setState(() {
        _selectedCoverUrl = _urlController.text;
        _selectedFilePath = null;
        _selectedImageFile = null;
      });
      _loadUrlImageInfo(_urlController.text);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1200,
        height: 800,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
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
            ),
            
            // Main content
            Expanded(
              child: Row(
                children: [
                  // Left Panel - Source Selection
                  Container(
                    width: 250,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2A2A2A),
                      border: Border(
                        right: BorderSide(color: Color(0xFF3A3A3A)),
                      ),
                    ),
                    child: _buildSourcePanel(),
                  ),
                  
                  // Middle Panel - Browser
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      child: _buildBrowserPanel(),
                    ),
                  ),
                  
                  // Right Panel - Preview
                  Container(
                    width: 350,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2A2A2A),
                      border: Border(
                        left: BorderSide(color: Color(0xFF3A3A3A)),
                      ),
                    ),
                    child: _buildPreviewPanel(),
                  ),
                ],
              ),
            ),
            
            // Footer with action buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF2A2A2A),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(color: Color(0xFF3A3A3A)),
                ),
              ),
              child: Row(
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
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSourcePanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Image Source',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Source options
          _buildSourceOption(
            CoverSource.online,
            Icons.search,
            'Search Online',
            'Find covers from online databases',
          ),
          const SizedBox(height: 16),
          _buildSourceOption(
            CoverSource.file,
            Icons.folder,
            'From File',
            'Select image from your computer',
          ),
          const SizedBox(height: 16),
          _buildSourceOption(
            CoverSource.url,
            Icons.link,
            'From URL',
            'Enter direct image URL',
          ),
        ],
      ),
    );
  }
  
  Widget _buildSourceOption(CoverSource source, IconData icon, String title, String subtitle) {
    final isSelected = _selectedSource == source;
    
    return InkWell(
      onTap: () => setState(() => _selectedSource = source),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.indigo : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.indigo : Colors.grey[400],
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[300],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBrowserPanel() {
    switch (_selectedSource) {
      case CoverSource.url:
        return _buildUrlBrowser();
      case CoverSource.file:
        return _buildFileBrowser();
      case CoverSource.online:
        return _buildOnlineBrowser();
    }
  }
  
  Widget _buildUrlBrowser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Image URL',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
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
            suffixIcon: IconButton(
              onPressed: _urlController.text.isNotEmpty ? _selectUrlCover : null,
              icon: const Icon(Icons.search, color: Colors.indigo),
            ),
          ),
          onSubmitted: (_) => _selectUrlCover(),
          onChanged: (value) => setState(() {}),
        ),
        const SizedBox(height: 24),
        
        // URL validation info
        if (_urlController.text.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isValidUrl(_urlController.text) ? Icons.check_circle : Icons.error,
                      color: _isValidUrl(_urlController.text) ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isValidUrl(_urlController.text) ? 'Valid URL format' : 'Invalid URL format',
                      style: TextStyle(
                        color: _isValidUrl(_urlController.text) ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Press Enter or click the search icon to load the image',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildFileBrowser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Local Image File',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        
        InkWell(
          onTap: _pickLocalFile,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[600]!,
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedFilePath != null ? 'Change selected file' : 'Click to select image file',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supports JPG, PNG, GIF, WebP formats',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                if (_selectedFilePath != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _selectedFilePath!.split('/').last,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // File format info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.indigo, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Recommended Specifications',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '• Minimum resolution: 500x750 pixels\n'
                '• Recommended resolution: 1000x1500 pixels\n'
                '• Aspect ratio: 2:3 (portrait)\n'
                '• File size: Under 5MB for optimal performance',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildOnlineBrowser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Online Cover Options',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.currentMetadata != null)
              TextButton.icon(
                onPressed: _isSearching ? null : _searchOnlineCovers,
                icon: _isSearching 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo),
                      )
                    : const Icon(Icons.refresh, color: Colors.indigo),
                label: Text(
                  _isSearching ? 'Searching...' : 'Refresh',
                  style: const TextStyle(color: Colors.indigo),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        
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
                        style: TextStyle(color: Colors.white, fontSize: 16),
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
                            size: 80,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No online covers found',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.currentMetadata == null 
                                ? 'Metadata required for online search'
                                : 'Try refreshing or check your internet connection',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.67,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _onlineCovers.length,
                      itemBuilder: (context, index) {
                        final coverUrl = _onlineCovers[index];
                        final isSelected = _selectedCoverUrl == coverUrl;
                        
                        return InkWell(
                          onTap: () => _selectOnlineCover(coverUrl),
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
                                    size: 32,
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
  
  Widget _buildPreviewPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview & Details',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Image preview
          Container(
            width: double.infinity,
            height: 360,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildPreviewImage(),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Image details
          if (_imageInfo != null) ...[
            Text(
              'Image Details',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildImageDetails(),
          ] else ...[
            Center(
              child: Text(
                'Select an image to view details',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPreviewImage() {
    if (_selectedImageFile != null) {
      return Image.file(
        _selectedImageFile!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildErrorPreview(),
      );
    } else if (_selectedCoverUrl != null && _selectedCoverUrl!.isNotEmpty) {
      return Image.network(
        _selectedCoverUrl!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildErrorPreview(),
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
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No image selected',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
  }
  
  Widget _buildErrorPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.grey[600],
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load image',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImageDetails() {
    if (_imageInfo == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          if (_imageInfo!['fileName'] != null)
            _buildDetailRow('File Name', _imageInfo!['fileName']),
          if (_imageInfo!['fileType'] != null)
            _buildDetailRow('Format', _imageInfo!['fileType']),
          if (_imageInfo!['width'] != null && _imageInfo!['height'] != null)
            _buildDetailRow('Resolution', '${_imageInfo!['width']} × ${_imageInfo!['height']}'),
          if (_imageInfo!['fileSize'] != null)
            _buildDetailRow('File Size', _formatFileSize(_imageInfo!['fileSize'])),
          if (_imageInfo!['url'] != null)
            _buildDetailRow('Source', 'URL'),
          if (_imageInfo!['error'] != null)
            _buildDetailRow('Status', _imageInfo!['error'], isError: true),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? Colors.red : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
  
  bool _canApply() {
    return _selectedCoverUrl != null || _selectedFilePath != null;
  }
  
  void _applySelection() {
    String? result;
    
    if (_selectedFilePath != null) {
      result = _selectedFilePath;
    } else if (_selectedCoverUrl != null) {
      result = _selectedCoverUrl;
    }
    
    Navigator.of(context).pop(result);
  }
}