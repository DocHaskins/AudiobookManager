// lib/ui/widgets/tools/tools_content_view.dart - Tools section content
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/services/audio_conversion_service.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/ui/widgets/tools/mp3_merger_tool.dart';
import 'package:audiobook_organizer/ui/widgets/tools/mp3_batch_converter_tool.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class ToolsContentView extends StatefulWidget {
  final LibraryManager libraryManager;
  final CollectionManager collectionManager;
  final MetadataService metadataService;
  final AudioConversionService audioConversionService;
  final String currentSubsection;
  final List<MetadataProvider>? metadataProviders;

  const ToolsContentView({
    Key? key,
    required this.libraryManager,
    required this.collectionManager,
    required this.metadataService,
    required this.audioConversionService,
    required this.currentSubsection,
    this.metadataProviders,
  }) : super(key: key);

  @override
  State<ToolsContentView> createState() => _ToolsContentViewState();
}

class _ToolsContentViewState extends State<ToolsContentView> {
  final bool _isLoading = false;
  final String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    switch (widget.currentSubsection) {
      case 'Mp3 Merger':
        return _buildMp3MergerTool();
      case 'Batch Converter':
        return _buildBatchConverterTool();
      default:
        return _buildDefaultView();
    }
  }

  Widget _buildMp3MergerTool() {
    // Debug logging to see what providers are available
    Logger.log('=== ToolsContentView: Building MP3 Merger Tool ===');
    Logger.log('MetadataProviders available: ${widget.metadataProviders?.length ?? 0}');
    
    if (widget.metadataProviders != null) {
      for (int i = 0; i < widget.metadataProviders!.length; i++) {
        Logger.log('Provider $i: ${widget.metadataProviders![i].runtimeType}');
      }
    } else {
      Logger.log('MetadataProviders is null');
    }
    
    final providers = widget.metadataProviders ?? [];
    Logger.log('Passing ${providers.length} providers to Mp3MergerTool');
    
    return Mp3MergerTool(
      libraryManager: widget.libraryManager,
      audioConversionService: widget.audioConversionService,
      metadataProviders: providers,
    );
  }

  Widget _buildBatchConverterTool() {
    Logger.log('=== ToolsContentView: Building Batch Converter Tool ===');
    
    return Mp3BatchConverterTool(
      libraryManager: widget.libraryManager,
      audioConversionService: widget.audioConversionService,
    );
  }

  Widget _buildDefaultView() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.build,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Tools & Utilities',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a tool from the sidebar to get started',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // Show available tools with descriptions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Tools',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildToolCard(
                    icon: Icons.merge_type_rounded,
                    title: 'MP3 to M4B Merger',
                    description: 'Combine multiple MP3 files into a single M4B audiobook with chapters',
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildToolCard(
                    icon: Icons.transform,
                    title: 'MP3 to M4B Batch Converter',
                    description: 'Convert multiple MP3 audiobooks to M4B format with parallel processing',
                    color: const Color.fromARGB(255, 39, 176, 69),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Spacer(),
          if (_isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}