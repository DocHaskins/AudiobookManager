// =============================================================================
// lib/ui/widgets/detail/sections/publisher_section.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_controllers_mixin.dart';
import 'package:audiobook_organizer/ui/widgets/detail/metadata_utils.dart';

class PublisherSection extends StatelessWidget {
  final AudiobookMetadata? metadata;
  final DetailControllersMixin controllers;

  const PublisherSection({
    Key? key,
    required this.metadata,
    required this.controllers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final publisher = metadata?.publisher ?? '';
    final publishedDate = metadata?.publishedDate ?? '';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PUBLICATION INFORMATION',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        
        if (controllers.isEditingMetadata && 
            controllers.publisherController != null && 
            controllers.publishedDateController != null)
          _buildEditingFields(context)
        else if (publisher.isNotEmpty || publishedDate.isNotEmpty)
          _buildDisplayInfo(publisher, publishedDate)
        else
          _buildEmptyState(),
      ],
    );
  }

  Widget _buildEditingFields(BuildContext context) {
    return Column(
      children: [
        // Publisher field
        TextField(
          controller: controllers.publisherController!,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Publisher',
            hintText: 'Enter publisher name',
            hintStyle: TextStyle(color: Colors.grey[500]),
            labelStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        // Published date field
        TextField(
          controller: controllers.publishedDateController!,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Published Date',
            hintText: 'Enter publication date (e.g., 2023, 2023-05, 2023-05-15)',
            hintStyle: TextStyle(color: Colors.grey[500]),
            labelStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDisplayInfo(String publisher, String publishedDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (publisher.isNotEmpty)
          _buildInfoDisplayRow('Publisher', publisher),
        if (publishedDate.isNotEmpty)
          _buildInfoDisplayRow('Published', MetadataUtils.formatPublishedDate(publishedDate)),
      ],
    );
  }

  Widget _buildInfoDisplayRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Text(
      'No publication information available',
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}