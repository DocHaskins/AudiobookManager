// lib/ui/widgets/detail/sections/title_author_section.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_controllers_mixin.dart';

class TitleAuthorSection extends StatelessWidget {
  final AudiobookFile book;
  final DetailControllersMixin controllers;
  final VoidCallback onSave;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  const TitleAuthorSection({
    Key? key,
    required this.book,
    required this.controllers,
    required this.onSave,
    required this.onEdit,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final metadata = book.metadata;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and Edit button row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: controllers.isEditingMetadata
                  ? _buildTitleEditField()
                  : _buildTitleDisplay(metadata?.title ?? book.filename),
            ),
            const SizedBox(width: 16),
            _buildEditControls(),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Author field
        _buildAuthorField(metadata?.authorsFormatted ?? 'Unknown'),
      ],
    );
  }

  Widget _buildTitleEditField() {
    return TextField(
      controller: controllers.titleController!,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
      decoration: const InputDecoration(
        border: UnderlineInputBorder(),
        hintText: 'Enter book title',
      ),
    );
  }

  Widget _buildTitleDisplay(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
    );
  }

  Widget _buildEditControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: controllers.isEditingMetadata ? onSave : onEdit,
          icon: Icon(controllers.isEditingMetadata ? Icons.save : Icons.edit),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF2A2A2A),
            foregroundColor: Colors.white,
          ),
        ),
        if (controllers.isEditingMetadata)
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF2A2A2A),
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Widget _buildAuthorField(String author) {
    return controllers.isEditingMetadata
        ? TextField(
            controller: controllers.authorController,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              border: UnderlineInputBorder(),
              hintText: 'Author name',
            ),
          )
        : InkWell(
            onTap: () {
              // TODO: Navigate to author page or search
            },
            child: Text(
              author,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          );
  }
}