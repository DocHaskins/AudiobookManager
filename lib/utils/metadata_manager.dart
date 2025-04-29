// File: lib/utils/metadata_manager.dart
import 'package:audiobook_organizer/models/audiobook_metadata.dart';

/// Utility class for handling metadata operations
class MetadataManager {
  static T? getValueWithPriority<T>(
    AudiobookMetadata? onlineMetadata,
    AudiobookMetadata? fileMetadata,
    T? Function(AudiobookMetadata) getter,
    T? defaultValue,
  ) {
    // Check online metadata first
    if (onlineMetadata != null) {
      final value = getter(onlineMetadata);
      // For strings, check not empty; for other types just check not null
      if (value != null && (value is! String || (value as String).isNotEmpty)) {
        return value;
      }
    }
    
    // Fall back to file metadata
    if (fileMetadata != null) {
      final value = getter(fileMetadata);
      if (value != null && (value is! String || (value as String).isNotEmpty)) {
        return value;
      }
    }
    
    // Return default if no metadata found
    return defaultValue;
  }
  
  /// Get a string value from metadata with standard empty checks
  static String getStringWithPriority(
    AudiobookMetadata? onlineMetadata,
    AudiobookMetadata? fileMetadata,
    String Function(AudiobookMetadata) getter,
    String defaultValue,
  ) {
    // Check online metadata first
    if (onlineMetadata != null) {
      final value = getter(onlineMetadata);
      if (value.isNotEmpty) {
        return value;
      }
    }
    
    // Fall back to file metadata
    if (fileMetadata != null) {
      final value = getter(fileMetadata);
      if (value.isNotEmpty) {
        return value;
      }
    }
    
    // Return default if no metadata found
    return defaultValue;
  }
  
  /// Get an author from metadata with standard fallbacks
  static String getAuthor(
    AudiobookMetadata? onlineMetadata,
    AudiobookMetadata? fileMetadata,
    String defaultValue,
  ) {
    return getStringWithPriority(
      onlineMetadata,
      fileMetadata,
      (meta) => meta.authors.isNotEmpty ? meta.authors.first : '',
      defaultValue,
    );
  }
  
  /// Check if metadata has enough information to be considered complete
  static bool isMetadataComplete(AudiobookMetadata? metadata) {
    if (metadata == null) return false;
    
    // More strict criteria for complete metadata
    return metadata.title.isNotEmpty && 
          metadata.authors.isNotEmpty &&
          metadata.thumbnailUrl.isNotEmpty &&
          (metadata.description.isNotEmpty || metadata.categories.isNotEmpty) &&
          (metadata.series.isNotEmpty || 
            metadata.averageRating > 0 || 
            metadata.publishedDate.isNotEmpty);
  }
  
  /// Merge metadata from different sources with priority
  static AudiobookMetadata mergeMetadata(
    AudiobookMetadata primary,
    AudiobookMetadata secondary,
  ) {
    return AudiobookMetadata(
      id: primary.id.isNotEmpty ? primary.id : secondary.id,
      title: primary.title.isNotEmpty ? primary.title : secondary.title,
      authors: primary.authors.isNotEmpty ? primary.authors : secondary.authors,
      description: primary.description.isNotEmpty ? primary.description : secondary.description,
      publisher: primary.publisher.isNotEmpty ? primary.publisher : secondary.publisher,
      publishedDate: primary.publishedDate.isNotEmpty ? primary.publishedDate : secondary.publishedDate,
      categories: primary.categories.isNotEmpty ? primary.categories : secondary.categories,
      averageRating: primary.averageRating > 0 ? primary.averageRating : secondary.averageRating,
      ratingsCount: primary.ratingsCount > 0 ? primary.ratingsCount : secondary.ratingsCount,
      thumbnailUrl: primary.thumbnailUrl.isNotEmpty ? primary.thumbnailUrl : secondary.thumbnailUrl,
      language: primary.language.isNotEmpty ? primary.language : secondary.language,
      series: primary.series.isNotEmpty ? primary.series : secondary.series,
      seriesPosition: primary.seriesPosition.isNotEmpty ? primary.seriesPosition : secondary.seriesPosition,
      provider: '${primary.provider}, ${secondary.provider}',
    );
  }
}
