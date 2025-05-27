// lib/ui/widgets/tools/tools_content_view.dart - Tools section content
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';

class ToolsContentView extends StatefulWidget {
  final LibraryManager libraryManager;
  final CollectionManager collectionManager;
  final MetadataService metadataService;
  final String currentSubsection;

  const ToolsContentView({
    Key? key,
    required this.libraryManager,
    required this.collectionManager,
    required this.metadataService,
    required this.currentSubsection,
  }) : super(key: key);

  @override
  State<ToolsContentView> createState() => _ToolsContentViewState();
}

class _ToolsContentViewState extends State<ToolsContentView> {
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
      ],
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