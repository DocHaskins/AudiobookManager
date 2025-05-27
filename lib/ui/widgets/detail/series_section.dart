// =============================================================================
// lib/ui/widgets/detail/series_section.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_controllers_mixin.dart';

class SeriesSection extends StatelessWidget {
  final AudiobookMetadata? metadata;
  final DetailControllersMixin controllers;

  const SeriesSection({
    Key? key,
    required this.metadata,
    required this.controllers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (controllers.isEditingMetadata) {
      return _buildEditingFields(context);
    } else {
      return _buildDisplayFields(context);
    }
  }

  Widget _buildEditingFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SERIES INFORMATION',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: controllers.seriesController!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Series Name',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controllers.seriesPositionController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Position #',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDisplayFields(BuildContext context) {
    if (metadata?.series.isNotEmpty ?? false) {
      return Column(
        children: [
          Row(
            children: [
              Text(
                '${metadata!.series}${metadata!.seriesPosition.isNotEmpty ? " #${metadata!.seriesPosition}" : ""}',
                style: TextStyle(
                  color: Theme.of(context).secondaryHeaderColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      );
    } else {
      return const SizedBox(height: 0);
    }
  }
}