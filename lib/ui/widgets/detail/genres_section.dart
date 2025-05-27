// lib/ui/widgets/detail/genres_section.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_controllers_mixin.dart';

class GenresSection extends StatelessWidget {
  final AudiobookMetadata? metadata;
  final DetailControllersMixin controllers;

  const GenresSection({
    Key? key,
    required this.metadata,
    required this.controllers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final genres = metadata?.categories ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GENRES',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        
        if (controllers.isEditingMetadata && controllers.genresController != null)
          _buildEditingField(context)
        else if (genres.isNotEmpty)
          _buildGenreChips(context, genres)
        else
          _buildEmptyState(),
      ],
    );
  }

  Widget _buildEditingField(BuildContext context) {
    return TextField(
      controller: controllers.genresController!,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Enter genres separated by commas (e.g., Fiction, Mystery, Thriller)',
        hintStyle: TextStyle(color: Colors.grey[500]),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      maxLines: 2,
    );
  }

  Widget _buildGenreChips(BuildContext context, List<String> genres) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: genres.map((genre) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).secondaryHeaderColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).secondaryHeaderColor.withOpacity(0.5),
          ),
        ),
        child: Text(
          genre,
          style: TextStyle(
            color: Theme.of(context).secondaryHeaderColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Text(
      'No genres specified',
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}