// File: lib/utils/metadata_manager.dart
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// Utility class for handling metadata operations
class MetadataManager {
  /// Get a value from metadata with priority ordering
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
    
    // Basic criteria for complete metadata - book identification
    final hasBasicIdentification = metadata.title.isNotEmpty && metadata.authors.isNotEmpty;
    
    // Enhanced criteria for "rich" metadata - checking for additional content
    final hasEnhancedInfo = (metadata.thumbnailUrl.isNotEmpty || // Has cover image 
                           metadata.description.isNotEmpty ||   // Has description
                           metadata.categories.isNotEmpty) &&   // Has categories
                          (metadata.series.isNotEmpty ||        // Either has series info
                           metadata.averageRating > 0 ||        // Or has ratings
                           metadata.publishedDate.isNotEmpty);  // Or has publication date

    // For better user experience, we can consider metadata complete if it has:
    // 1. Basic identification (title and author) AND
    // 2. Either a cover image OR at least two enhanced metadata fields
    return hasBasicIdentification && 
           (metadata.thumbnailUrl.isNotEmpty || hasEnhancedInfo);
  }
  
  /// Merge metadata from different sources with priority
  /// Improved to properly prioritize online data for content fields while preserving file data for quality info
  static AudiobookMetadata mergeMetadata(
    AudiobookMetadata fileMetadata,
    AudiobookMetadata onlineMetadata,
  ) {
    Logger.debug('Merging metadata sources: file=${fileMetadata.provider}, online=${onlineMetadata.provider}');
    
    // Always prioritize online data for bibliographic metadata
    final title = onlineMetadata.title.isNotEmpty ? 
                 onlineMetadata.title : fileMetadata.title;
                 
    final authors = onlineMetadata.authors.isNotEmpty ? 
                   onlineMetadata.authors : fileMetadata.authors;
    
    final description = onlineMetadata.description.isNotEmpty ? 
                       onlineMetadata.description : fileMetadata.description;
                       
    final publisher = onlineMetadata.publisher.isNotEmpty ? 
                     onlineMetadata.publisher : fileMetadata.publisher;
                     
    final publishedDate = onlineMetadata.publishedDate.isNotEmpty ? 
                         onlineMetadata.publishedDate : fileMetadata.publishedDate;
                         
    final categories = onlineMetadata.categories.isNotEmpty ? 
                      onlineMetadata.categories : fileMetadata.categories;
                      
    final language = onlineMetadata.language.isNotEmpty ? 
                    onlineMetadata.language : fileMetadata.language;
                    
    final series = onlineMetadata.series.isNotEmpty ? 
                  onlineMetadata.series : fileMetadata.series;
                  
    final seriesPosition = onlineMetadata.seriesPosition.isNotEmpty ? 
                          onlineMetadata.seriesPosition : fileMetadata.seriesPosition;
                          
    // For thumbnail, prioritize any non-empty value
    // Fix: Ensure we're consistently handling thumbnailUrl in merges
    String thumbnailUrl = "";
    if (onlineMetadata.thumbnailUrl.isNotEmpty) {
      thumbnailUrl = onlineMetadata.thumbnailUrl; // Use online thumbnail if available
    } else if (fileMetadata.thumbnailUrl.isNotEmpty) {
      thumbnailUrl = fileMetadata.thumbnailUrl; // Fall back to file thumbnail
    }
    
    // For ratings/reviews, only use online data (file data wouldn't have this)
    final averageRating = onlineMetadata.averageRating;
    final ratingsCount = onlineMetadata.ratingsCount;
    
    // For audio quality information, always preserve file metadata
    final audioDuration = fileMetadata.audioDuration;
    final bitrate = fileMetadata.bitrate;
    final channels = fileMetadata.channels;
    final sampleRate = fileMetadata.sampleRate;
    final fileFormat = fileMetadata.fileFormat;
    
    // Log what's being merged
    Logger.debug('Merged metadata: Title=$title, Authors=${authors.join(", ")}, ' 
                'Using Thumbnail=$thumbnailUrl');
    
    return AudiobookMetadata(
      id: onlineMetadata.id.isNotEmpty ? onlineMetadata.id : fileMetadata.id,
      title: title,
      authors: authors,
      description: description,
      publisher: publisher,
      publishedDate: publishedDate,
      categories: categories,
      averageRating: averageRating,
      ratingsCount: ratingsCount,
      thumbnailUrl: thumbnailUrl,
      language: language,
      series: series,
      seriesPosition: seriesPosition,
      audioDuration: audioDuration,
      bitrate: bitrate,
      channels: channels,
      sampleRate: sampleRate,
      fileFormat: fileFormat,
      provider: 'Combined (${fileMetadata.provider} + ${onlineMetadata.provider})',
    );
  }
  
  /// Merge audio quality info into existing metadata
  static AudiobookMetadata mergeAudioQualityInfo(
    AudiobookMetadata metadata,
    String? audioDuration,
    String? bitrate,
    int? channels,
    String? sampleRate,
    String? fileFormat,
  ) {
    return metadata.copyWith(
      audioDuration: audioDuration,
      bitrate: bitrate,
      channels: channels,
      sampleRate: sampleRate,
      fileFormat: fileFormat,
    );
  }
  
  /// Update thumbnail in existing metadata
  static AudiobookMetadata updateThumbnail(
    AudiobookMetadata metadata,
    String thumbnailUrl,
  ) {
    // Make sure to preserve other fields when updating thumbnail
    return metadata.copyWith(
      thumbnailUrl: thumbnailUrl,
    );
  }
  
  /// Safely get composite display values combining online and file metadata
  static String getDisplayTitle(AudiobookMetadata metadata) {
    // Use the title directly
    return metadata.title;
  }
  
  /// Get formatted authors for display
  static String getDisplayAuthors(AudiobookMetadata metadata) {
    return metadata.authors.isEmpty ? "Unknown Author" : metadata.authors.join(", ");
  }
  
  /// Get audio quality information formatted nicely
  static String getAudioQualityInfo(AudiobookMetadata metadata) {
    List<String> qualities = [];
    
    if (metadata.audioDuration != null && metadata.audioDuration!.isNotEmpty) {
      qualities.add("Length: ${metadata.audioDuration}");
    }
    
    if (metadata.bitrate != null && metadata.bitrate!.isNotEmpty) {
      qualities.add("Quality: ${metadata.bitrate}");
    }
    
    if (metadata.channels != null) {
      qualities.add(metadata.channels == 2 ? "Stereo" : "Mono");
    }
    
    if (metadata.fileFormat != null && metadata.fileFormat!.isNotEmpty) {
      qualities.add(metadata.fileFormat!);
    }
    
    return qualities.isEmpty ? "" : qualities.join(' • ');
  }
}