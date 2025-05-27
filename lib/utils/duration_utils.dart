// lib/utils/duration_utils.dart - Duration calculation utilities
// =============================================================================

import 'package:audiobook_organizer/models/audiobook_file.dart';

class DurationUtils {
  static String calculateTotalDuration(List<AudiobookFile> books) {
    Duration total = Duration.zero;
    for (final book in books) {
      if (book.metadata?.audioDuration != null) {
        total += book.metadata!.audioDuration!;
      }
    }
    
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '$hours hours, $minutes minutes';
    } else {
      return '$minutes minutes';
    }
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}