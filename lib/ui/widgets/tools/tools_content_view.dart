// lib/ui/widgets/tools/tools_content_view.dart - Tools section content
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/ui/widgets/tools/mp3_merger_tool.dart';
import 'package:audiobook_organizer/ui/widgets/tools/mp3_batch_converter_tool.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class ToolsContentView extends StatefulWidget {
  final LibraryManager libraryManager;
  final CollectionManager collectionManager;
  final MetadataService metadataService;
  final String currentSubsection;
  final List<MetadataProvider>? metadataProviders;

  const ToolsContentView({
    Key? key,
    required this.libraryManager,
    required this.collectionManager,
    required this.metadataService,
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
      metadataProviders: providers,
    );
  }

  Widget _buildBatchConverterTool() {
    Logger.log('=== ToolsContentView: Building Batch Converter Tool ===');
    
    return Mp3BatchConverterTool(
      libraryManager: widget.libraryManager,
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
          ],
        ),
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