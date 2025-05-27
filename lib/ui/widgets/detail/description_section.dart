// =============================================================================
// lib/ui/widgets/detail/sections/description_section.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_controllers_mixin.dart';

class DescriptionSection extends StatefulWidget {
  final AudiobookMetadata? metadata;
  final DetailControllersMixin controllers;

  const DescriptionSection({
    Key? key,
    required this.metadata,
    required this.controllers,
  }) : super(key: key);

  @override
  State<DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<DescriptionSection> {
  bool _isDescriptionExpanded = false;
  static const int _characterLimit = 300;

  @override
  Widget build(BuildContext context) {
    final description = widget.metadata?.description ?? '';
    final hasDescription = description.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DESCRIPTION',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        
        if (widget.controllers.isEditingMetadata)
          _buildEditingField()
        else if (hasDescription)
          _buildDescriptionDisplay(description)
        else
          _buildEmptyState(),
      ],
    );
  }

  Widget _buildEditingField() {
    return TextField(
      controller: widget.controllers.descriptionController!,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        height: 1.5,
      ),
      maxLines: 6,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintText: 'Enter book description...',
        hintStyle: TextStyle(color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildDescriptionDisplay(String description) {
    final bool shouldTruncate = description.length > _characterLimit;
    final String displayText = _isDescriptionExpanded || !shouldTruncate
        ? description
        : description.substring(0, _characterLimit);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayText + (!_isDescriptionExpanded && shouldTruncate ? '...' : ''),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.6,
          ),
        ),
        if (shouldTruncate) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).secondaryHeaderColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Theme.of(context).secondaryHeaderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isDescriptionExpanded ? 'Show less' : 'Show more',
                    style: TextStyle(
                      color: Theme.of(context).secondaryHeaderColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isDescriptionExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).secondaryHeaderColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Text(
      'No description available',
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}