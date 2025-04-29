// File: lib/models/audiobook_collection.dart
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// Represents a collection of audio files that belong to the same audiobook
class AudiobookCollection {
  /// The title of the audiobook
  final String title;
  
  /// List of audio files that make up this audiobook
  final List<AudiobookFile> files;
  
  /// Metadata for the audiobook, if available
  AudiobookMetadata? metadata;
  
  /// Directory path where the files are located
  String? directoryPath;
  
  /// Constructor
  AudiobookCollection({
    required this.title,
    required this.files,
    this.metadata,
    this.directoryPath,
  });
  
  /// Get the total size of all files in the collection
  int get totalSize => files.fold(0, (sum, file) => sum + file.size);
  
  /// Get the most recent modification date among all files
  DateTime get lastModified {
    if (files.isEmpty) return DateTime.now();
    
    return files.fold(
      files.first.lastModified, 
      (latest, file) => file.lastModified.isAfter(latest) ? file.lastModified : latest
    );
  }
  
  /// Check if the collection has metadata
  bool get hasMetadata => metadata != null;
  
  /// Get the number of files in the collection
  int get fileCount => files.length;
  
  /// Get the primary author from metadata
  String get author => metadata?.primaryAuthor ?? 'Unknown Author';
  
  /// Get a suitable display name
  String get displayName => metadata?.title ?? title;
  
  /// Factory method to create a collection from a group of files
  factory AudiobookCollection.fromFiles(List<AudiobookFile> files, String title) {
    String? dirPath;
    if (files.isNotEmpty) {
      try {
        // Extract directory from the first file
        final path = files.first.path;
        final lastSeparator = path.lastIndexOf(RegExp(r'[/\\]'));
        if (lastSeparator != -1) {
          dirPath = path.substring(0, lastSeparator);
        }
      } catch (e) {
        Logger.error("Error extracting directory path", e);
      }
    }
    
    return AudiobookCollection(
      title: title,
      files: files,
      directoryPath: dirPath,
    );
  }
  
  /// Update metadata for the collection
  void updateMetadata(AudiobookMetadata metadata) {
    this.metadata = metadata;
    Logger.debug("Updated collection metadata: $title");
  }
  
  /// Add a file to the collection
  void addFile(AudiobookFile file) {
    files.add(file);
  }
  
  /// Sort files by their chapter or track number
  void sortFiles() {
    try {
      // Extract numbers from filenames
      final regexNumber = RegExp(r'(\d+)');
      
      files.sort((a, b) {
        // Try to extract numbers from the filenames
        final matchA = regexNumber.firstMatch(a.filename);
        final matchB = regexNumber.firstMatch(b.filename);
        
        if (matchA != null && matchB != null) {
          try {
              final numA = int.parse(matchA.group(1)!);
              final numB = int.parse(matchB.group(1)!);
              return numA.compareTo(numB);
          } catch (e) {
              Logger.error("Error parsing numbers from filenames", e);
          }
        }
        
        // Fall back to alphabetical sorting
        return a.filename.compareTo(b.filename);
      });
      
      Logger.debug("Files sorted successfully for: $title");
    } catch (e) {
      Logger.error("Error sorting files", e);
    }
  }
  
  /// Get files that are missing metadata
  List<AudiobookFile> get filesNeedingMetadata {
    return files.where((file) => file.needsMetadataReview).toList();
  }
  
  /// Check if any files need metadata review
  bool get hasIncompleteMetadata {
    return files.any((file) => file.needsMetadataReview);
  }
}