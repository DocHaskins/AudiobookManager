// lib/utils/genre_icon_utils.dart - Genre icon mapping
// =============================================================================

import 'package:flutter/material.dart';

class GenreIconUtils {
  static const Map<String, IconData> _genreIconMap = {
    'fiction': Icons.auto_stories,
    'non-fiction': Icons.menu_book,
    'mystery': Icons.search,
    'sci-fi': Icons.rocket_launch,
    'science fiction': Icons.rocket_launch,
    'fantasy': Icons.castle,
    'romance': Icons.favorite,
    'thriller': Icons.flash_on,
    'horror': Icons.warning,
    'biography': Icons.person,
    'autobiography': Icons.person,
    'history': Icons.history_edu,
    'business': Icons.business,
    'self-help': Icons.psychology,
    'health': Icons.health_and_safety,
    'cooking': Icons.restaurant,
    'travel': Icons.flight,
    'technology': Icons.computer,
    'science': Icons.science,
    'philosophy': Icons.psychology_alt,
    'religion': Icons.church,
    'spirituality': Icons.spa,
    'true crime': Icons.gavel,
    'comedy': Icons.sentiment_very_satisfied,
    'drama': Icons.theater_comedy,
    'adventure': Icons.explore,
    'children': Icons.child_care,
    'young adult': Icons.school,
    'classic': Icons.library_books,
    'poetry': Icons.format_quote,
  };

  static IconData getGenreIcon(String genre) {
    final lowerGenre = genre.toLowerCase();
    return _genreIconMap[lowerGenre] ?? Icons.category;
  }
}