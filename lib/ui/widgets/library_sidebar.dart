// File: lib/ui/widgets/library_sidebar.dart
import 'package:flutter/material.dart';

class LibrarySidebar extends StatelessWidget {
  final List<String> genres;
  final String selectedGenre;
  final bool showCollectionsOnly;
  final Function(String) onGenreSelected;
  final Function(bool) onShowCollectionsChanged;
  final double gridItemSize;
  final Function(double) onGridSizeChanged;

  const LibrarySidebar({
    Key? key,
    required this.genres,
    required this.selectedGenre,
    required this.showCollectionsOnly,
    required this.onGenreSelected,
    required this.onShowCollectionsChanged,
    required this.gridItemSize,
    required this.onGridSizeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Library',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // View options
          _buildSectionHeader(context, 'View'),
          
          // Collections filter
          SwitchListTile(
            title: const Text('Collections Only'),
            value: showCollectionsOnly,
            onChanged: onShowCollectionsChanged,
            dense: true,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          
          // Grid size slider (only when grid view is active)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Grid Item Size'),
                Slider(
                  value: gridItemSize,
                  min: 120,
                  max: 240,
                  divisions: 4,
                  label: '${gridItemSize.round()}',
                  onChanged: onGridSizeChanged,
                ),
              ],
            ),
          ),
          
          // Genres section
          _buildSectionHeader(context, 'Genres'),
          
          // Genre list
          Expanded(
            child: ListView.builder(
              itemCount: genres.length,
              itemBuilder: (context, index) {
                final genre = genres[index];
                final isSelected = genre == selectedGenre;
                
                return ListTile(
                  title: Text(genre),
                  selected: isSelected,
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                  dense: true,
                  leading: _getGenreIcon(genre),
                  onTap: () => onGenreSelected(genre),
                );
              },
            ),
          ),
          
          // Footer with library info
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'AudioBook Organizer',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
  
  Widget _getGenreIcon(String genre) {
    switch (genre.toLowerCase()) {
      case 'all':
        return const Icon(Icons.library_books);
      case 'fiction':
      case 'novel':
        return const Icon(Icons.auto_stories);
      case 'science fiction':
      case 'sci-fi':
        return const Icon(Icons.rocket_launch);
      case 'fantasy':
        return const Icon(Icons.auto_fix_high);
      case 'mystery':
      case 'thriller':
        return const Icon(Icons.search);
      case 'biography':
      case 'memoir':
        return const Icon(Icons.person);
      case 'history':
        return const Icon(Icons.history_edu);
      case 'science':
        return const Icon(Icons.science);
      case 'self-help':
        return const Icon(Icons.psychology);
      case 'business':
        return const Icon(Icons.business);
      case 'children':
      case 'young adult':
        return const Icon(Icons.child_care);
      case 'romance':
        return const Icon(Icons.favorite);
      case 'horror':
        return const Icon(Icons.mood_bad);
      case 'comedy':
      case 'humor':
        return const Icon(Icons.emoji_emotions);
      default:
        return const Icon(Icons.book);
    }
  }
}