// =============================================================================
// lib/ui/widgets/detail/metadata_utils.dart
// =============================================================================

class MetadataUtils {
  static String formatPublishedDate(String date) {
    if (date.isEmpty) return '';
    
    try {
      // Handle different date formats from Google Books
      if (date.length == 4) {
        // Just year
        return date;
      } else if (date.length == 7) {
        // Year-Month
        final parts = date.split('-');
        if (parts.length == 2) {
          final year = parts[0];
          final month = int.tryParse(parts[1]);
          if (month != null && month >= 1 && month <= 12) {
            const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            return '${months[month - 1]} $year';
          }
        }
      } else if (date.length == 10) {
        // Full date
        final parsedDate = DateTime.tryParse(date);
        if (parsedDate != null) {
          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                         'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          return '${months[parsedDate.month - 1]} ${parsedDate.day}, ${parsedDate.year}';
        }
      }
    } catch (e) {
      // Return original if parsing fails
    }
    
    return date;
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String formatRatingCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}