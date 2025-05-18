// File: lib/services/metadata_matcher.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/storage/audiobook_storage_manager.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/metadata_manager.dart';

/// Service for matching audiobook files with metadata from various sources
class MetadataMatcher {
  /// List of metadata providers to search with
  final List<MetadataProvider> providers;
  
  /// Cache for storing and retrieving metadata
  final MetadataCache cache;
  
  /// Storage manager for persisting metadata - this is the key integration point
  final AudiobookStorageManager? storageManager;
  
  /// HTTP client for downloading cover images
  final http.Client _httpClient;
  
  /// In-memory cache for series information by folder
  final Map<String, String> _folderSeriesNames = {};
  
  /// Threshold for accepting a match
  final double matchThreshold = 0.6;
  
  /// Weights for different match components
  static const double _titleWeight = 0.5;
  static const double _authorWeight = 0.4;
  static const double _seriesWeight = 0.2;
  
  /// Constructor with optional storage manager
  MetadataMatcher({
    required this.providers, 
    required this.cache,
    this.storageManager,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client() {
    Logger.log('MetadataMatcher initialized with ${providers.length} providers');
    if (storageManager != null) {
      Logger.log('MetadataMatcher integrated with AudiobookStorageManager');
    } else {
      Logger.warning('MetadataMatcher initialized without StorageManager - functionality limited');
    }
  }
  
  /// Match a file with metadata using folder name as series context
  Future<AudiobookMetadata?> matchFile(AudiobookFile file) async {
    try {
      // Step 1: Check cache for this specific file first
      final cachedMetadata = await cache.getMetadataForFile(file.path);
      if (cachedMetadata != null) {
        Logger.log('Found cached metadata for ${file.filename}');
        file.metadata = cachedMetadata;
        return cachedMetadata;
      }
      
      // Step 2: Extract file metadata
      final fileMetadata = await file.extractFileMetadata();
      
      // Step 3: Build search query with folder context
      final String folderName = path_util.basename(path_util.dirname(file.path));
      final String folderPath = path_util.dirname(file.path);
      
      Logger.log('Processing file: ${file.filename} from folder: $folderName');
      
      // Extract book number from filename if present
      final bookInfo = _extractBookInfo(file.filename);
      final int? bookNumber = bookInfo['number'] as int?;
      final String? bookTitle = bookInfo['title'] as String?;
      
      // Build the search query
      String searchQuery;
      
      if (bookTitle != null) {
        // If we extracted a clean title from "Book N - Title" pattern, use it
        searchQuery = "$folderName $bookTitle";
        Logger.log('Using book title from filename: "$bookTitle" with folder context');
      } else {
        // Otherwise use the full filename with folder context
        searchQuery = "$folderName ${file.filename}";
        Logger.log('Using full filename with folder context');
      }
      
      Logger.log('Final search query: "$searchQuery" for file: ${file.filename}');
      
      // Step 4: Try to find online metadata
      AudiobookMetadata? onlineMetadata = await _searchWithFolderContext(
        searchQuery, fileMetadata, folderName, bookNumber
      );
      
      if (onlineMetadata != null) {
        Logger.log('Found online metadata match: "${onlineMetadata.title}" by ${onlineMetadata.authorsFormatted}');
        
        // Handle thumbnail and audio quality info
        if (onlineMetadata.thumbnailUrl.isNotEmpty) {
          final localCoverPath = await _downloadCoverImage(onlineMetadata.thumbnailUrl, file.path);
          if (localCoverPath != null) {
            onlineMetadata = onlineMetadata.copyWith(thumbnailUrl: localCoverPath);
            Logger.log('Updated thumbnail URL: ${onlineMetadata.thumbnailUrl}');
          }
        } else if (fileMetadata != null && fileMetadata.thumbnailUrl.isNotEmpty) {
          onlineMetadata = onlineMetadata.copyWith(thumbnailUrl: fileMetadata.thumbnailUrl);
          Logger.log('Using existing thumbnail URL from file metadata: ${onlineMetadata.thumbnailUrl}');
        }
        
        // Verify the match makes sense with folder context
        if (!_verifyMatchWithFolderContext(onlineMetadata, folderName, bookNumber)) {
          Logger.warning('Online match doesn\'t align with folder context - may be incorrect');
          
          // Store the folder name as series if not already set
          if (_folderSeriesNames[folderPath] == null) {
            _folderSeriesNames[folderPath] = folderName;
            Logger.log('Setting series name from folder: $folderName');
          }
          
          // If file metadata is available, use it instead
          if (fileMetadata != null) {
            // Enhance file metadata with folder context
            final enhancedFileMetadata = _enhanceWithFolderContext(fileMetadata, folderName, bookNumber);
            
            // Save using storage manager if available
            if (storageManager != null) {
              final success = await storageManager!.updateMetadataForFile(file.path, enhancedFileMetadata);
              if (success) {
                file.metadata = enhancedFileMetadata;
                Logger.log('Saved enhanced file metadata via storage manager');
                return enhancedFileMetadata;
              }
            } else {
              // Fall back to direct cache update
              file.metadata = enhancedFileMetadata;
              await cache.saveMetadataForFile(file.path, enhancedFileMetadata);
              Logger.log('Saved enhanced file metadata directly to cache');
              return enhancedFileMetadata;
            }
          }
        }
        
        // Store folder series name if this metadata has a series
        if (onlineMetadata.series.isNotEmpty) {
          _folderSeriesNames[folderPath] = onlineMetadata.series;
          Logger.log('Updated folder series name to: ${onlineMetadata.series}');
        } else {
          // If metadata doesn't have series but we're in a folder, set it
          onlineMetadata = _enhanceWithFolderContext(onlineMetadata, folderName, bookNumber);
          Logger.log('Enhanced metadata with folder context: ${onlineMetadata.series}');
        }
        
        // Merge metadata - preserving audio quality info from file
        final mergedMetadata = fileMetadata != null ? 
            _mergeWithFolderContext(fileMetadata, onlineMetadata, folderName, bookNumber) : 
            onlineMetadata;
        
        // Save using storage manager if available
        if (storageManager != null) {
          final success = await storageManager!.updateMetadataForFile(file.path, mergedMetadata);
          if (success) {
            file.metadata = mergedMetadata;
            Logger.log('Saved merged metadata via storage manager');
          } else {
            Logger.warning('Failed to save metadata via storage manager');
            
            // Fall back to direct cache update
            await cache.saveMetadataForFile(file.path, mergedMetadata);
            file.metadata = mergedMetadata;
          }
        } else {
          // Also save search query for better future matches
          await cache.saveMetadata(searchQuery, mergedMetadata);
          await cache.saveMetadataForFile(file.path, mergedMetadata);
          file.metadata = mergedMetadata;
        }
        
        return mergedMetadata;
      }
      
      // Fallback to file metadata with folder context
      if (fileMetadata != null) {
        Logger.log('No online match found, using file metadata for ${file.filename}');
        
        // Store folder name as series
        if (_folderSeriesNames[folderPath] == null) {
          _folderSeriesNames[folderPath] = folderName;
          Logger.log('Using folder name as series: $folderName');
        }
        
        final enhancedFileMetadata = _enhanceWithFolderContext(fileMetadata, folderName, bookNumber);
        
        // Save using storage manager if available
        if (storageManager != null) {
          final success = await storageManager!.updateMetadataForFile(file.path, enhancedFileMetadata);
          if (success) {
            file.metadata = enhancedFileMetadata;
            Logger.log('Saved enhanced file metadata via storage manager');
          } else {
            Logger.warning('Failed to save metadata via storage manager');
            
            // Fall back to direct cache update
            await cache.saveMetadataForFile(file.path, enhancedFileMetadata);
            file.metadata = enhancedFileMetadata;
          }
        } else {
          await cache.saveMetadataForFile(file.path, enhancedFileMetadata);
          file.metadata = enhancedFileMetadata;
        }
        
        return enhancedFileMetadata;
      }
      
      return null;
    } catch (e) {
      Logger.error('Error matching metadata for file: ${file.path}', e);
      return null;
    }
  }

  /// Extract book number and title from filename
  Map<String, dynamic> _extractBookInfo(String filename) {
    final result = <String, dynamic>{'number': null, 'title': null};
    
    // Look for patterns like "Book 1 - Title"
    final RegExp bookPattern = RegExp(r'Book\s+(\d+)\s*[-:_]\s*(.+)', caseSensitive: false);
    final bookMatch = bookPattern.firstMatch(filename);
    
    if (bookMatch != null && bookMatch.groupCount >= 2) {
      result['number'] = int.tryParse(bookMatch.group(1) ?? '');
      result['title'] = bookMatch.group(2);
      Logger.debug('Extracted book number: ${result['number']}, title: ${result['title']}');
      return result;
    }
    
    // Alternative patterns like "1 - Title"
    final RegExp numberPattern = RegExp(r'^(\d+)\s*[-:_]\s*(.+)', caseSensitive: false);
    final numberMatch = numberPattern.firstMatch(filename);
    
    if (numberMatch != null && numberMatch.groupCount >= 2) {
      result['number'] = int.tryParse(numberMatch.group(1) ?? '');
      result['title'] = numberMatch.group(2);
      Logger.debug('Extracted simple number: ${result['number']}, title: ${result['title']}');
      return result;
    }
    
    Logger.debug('No book number pattern found in filename: $filename');
    return result;
  }

  /// Search with folder context
  Future<AudiobookMetadata?> _searchWithFolderContext(
      String searchQuery, 
      AudiobookMetadata? fileMetadata,
      String folderName,
      int? bookNumber) async {
    
    // Try each provider with the enhanced query
    for (final provider in providers) {
      try {
        Logger.debug('Searching with provider: ${provider.runtimeType}');
        final results = await provider.search(searchQuery);
        
        if (results.isEmpty) {
          Logger.debug('No results from ${provider.runtimeType}');
          continue;
        }
        
        Logger.debug('Found ${results.length} results from ${provider.runtimeType}');
        
        // Find the best match using folder context
        AudiobookMetadata? bestMatch = _findBestMatchWithContext(
          results, searchQuery, fileMetadata, folderName, bookNumber
        );
        
        if (bestMatch != null) {
          return bestMatch;
        }
      } catch (e) {
        Logger.error('Error with provider ${provider.runtimeType}', e);
      }
    }
    
    // If no match found, try a more specific search
    if (bookNumber != null) {
      Logger.log('Trying specific search with book number: $bookNumber');
      final specificQuery = '$folderName Book $bookNumber';
      
      for (final provider in providers) {
        try {
          final results = await provider.search(specificQuery);
          if (results.isEmpty) continue;
          
          Logger.debug('Found ${results.length} results from specific query');
          
          AudiobookMetadata? bestMatch = _findBestMatchWithContext(
            results, specificQuery, fileMetadata, folderName, bookNumber
          );
          
          if (bestMatch != null) {
            return bestMatch;
          }
        } catch (e) {
          Logger.error('Error with specific search', e);
        }
      }
    }
    
    return null;
  }

  /// Find best match using folder context
  AudiobookMetadata? _findBestMatchWithContext(
      List<AudiobookMetadata> results,
      String searchQuery,
      AudiobookMetadata? fileMetadata,
      String folderName,
      int? bookNumber) {
    
    double bestScore = 0;
    AudiobookMetadata? bestMatch;
    
    // Get search terms
    final queryTerms = searchQuery.toLowerCase().split(' ')
                      .where((term) => term.length > 2)
                      .toList();
    
    Logger.debug('Scoring matches against folder: $folderName, book #: $bookNumber');
    
    for (int i = 0; i < results.length; i++) {
      final metadata = results[i];
      
      // Calculate base score
      double score = _calculateMatchScore(metadata, queryTerms, fileMetadata);
      
      // Apply folder-specific bonuses
      
      // 1. Series name matches folder name
      if (metadata.series.isNotEmpty && 
          metadata.series.toLowerCase().contains(folderName.toLowerCase())) {
        score += 0.2;
        Logger.debug('Series name matches folder (+0.2): ${metadata.series}');
      }
      
      // 2. Title contains folder name (for series)
      if (metadata.title.toLowerCase().contains(folderName.toLowerCase())) {
        score += 0.1;
        Logger.debug('Title contains folder name (+0.1): ${metadata.title}');
      }
      
      // 3. Book number matches
      if (bookNumber != null && metadata.seriesPosition.isNotEmpty) {
        final metadataBookNum = int.tryParse(metadata.seriesPosition);
        if (metadataBookNum != null && metadataBookNum == bookNumber) {
          score += 0.3;
          Logger.debug('Book number matches (+0.3): ${metadata.seriesPosition}');
        }
      }
      
      // Log the score calculation
      Logger.debug('Result #${i+1} - Title: "${metadata.title}", Author: "${metadata.authorsFormatted}", Score: $score');
      
      if (score > bestScore) {
        bestScore = score;
        bestMatch = metadata;
      }
    }
    
    // Return if good enough
    if (bestScore >= matchThreshold && bestMatch != null) {
      Logger.log('Found best match - Title: "${bestMatch.title}", Author: "${bestMatch.authorsFormatted}", Score: $bestScore');
      return bestMatch;
    } else if (bestMatch != null) {
      Logger.debug('Best match score ($bestScore) too low for: "${bestMatch.title}" by ${bestMatch.authorsFormatted}');
    }
    
    return null;
  }

  /// Verify if a match aligns with folder context
  bool _verifyMatchWithFolderContext(
      AudiobookMetadata metadata,
      String folderName,
      int? bookNumber) {
    
    final folderLower = folderName.toLowerCase();
    final title = metadata.title.toLowerCase();
    final series = metadata.series.toLowerCase();
    
    // For Harry Potter specifically
    if (folderLower.contains('harry potter')) {
      final bool containsHarryPotter = 
          title.contains('harry potter') || series.contains('harry potter');
      
      final bool hasRowlingAuthor = metadata.authors.any((author) => 
          author.toLowerCase().contains('rowling'));
      
      if (!containsHarryPotter) {
        Logger.warning('Folder is Harry Potter but match doesn\'t contain Harry Potter in title or series');
        return false;
      }
      
      if (!hasRowlingAuthor) {
        Logger.warning('Harry Potter book without Rowling as author');
        return false;
      }
      
      return true;
    }
    
    // Generic verification - must contain folder name in title or series
    if (!title.contains(folderLower) && !series.contains(folderLower)) {
      // Only warn if folder name is significant
      if (folderLower.length > 4) {
        Logger.warning('Match doesn\'t contain folder name in title or series');
        return false;
      }
    }
    
    // Book number check if available
    if (bookNumber != null && metadata.seriesPosition.isNotEmpty) {
      final metadataBookNum = int.tryParse(metadata.seriesPosition);
      if (metadataBookNum != null && metadataBookNum != bookNumber) {
        Logger.warning('Book number mismatch: file indicates #$bookNumber but metadata shows #${metadata.seriesPosition}');
        return false;
      }
    }
    
    return true;
  }

  /// Enhance metadata with folder context information
  AudiobookMetadata _enhanceWithFolderContext(
      AudiobookMetadata metadata,
      String folderName,
      int? bookNumber) {
    
    // Don't override existing series information
    if (metadata.series.isNotEmpty) {
      return metadata;
    }
    
    // Use folder name as series if it's meaningful
    if (folderName.length > 3) {
      String series = folderName;
      String seriesPosition = bookNumber != null ? bookNumber.toString() : '';
      
      Logger.log('Enhancing metadata with folder context - Series: $series, Position: $seriesPosition');
      
      return metadata.copyWith(
        series: series,
        seriesPosition: seriesPosition
      );
    }
    
    return metadata;
  }

  /// Merge file and online metadata with folder context awareness
  AudiobookMetadata _mergeWithFolderContext(
      AudiobookMetadata fileMetadata,
      AudiobookMetadata onlineMetadata,
      String folderName,
      int? bookNumber) {
    
    // Choose the best title - usually online is better
    final title = onlineMetadata.title.isNotEmpty ? onlineMetadata.title : fileMetadata.title;
    
    // Choose the best series info
    final String series;
    final String seriesPosition;
    
    // If online has series info, use it
    if (onlineMetadata.series.isNotEmpty) {
      series = onlineMetadata.series;
      seriesPosition = onlineMetadata.seriesPosition.isNotEmpty ? 
                       onlineMetadata.seriesPosition : 
                       (bookNumber != null ? bookNumber.toString() : '');
    } 
    // Otherwise use file metadata series info
    else if (fileMetadata.series.isNotEmpty) {
      series = fileMetadata.series;
      seriesPosition = fileMetadata.seriesPosition.isNotEmpty ? 
                       fileMetadata.seriesPosition : 
                       (bookNumber != null ? bookNumber.toString() : '');
    } 
    // Last resort - use folder name
    else if (folderName.length > 3) {
      series = folderName;
      seriesPosition = bookNumber != null ? bookNumber.toString() : '';
    } else {
      series = '';
      seriesPosition = '';
    }
    
    // Rest of metadata merging
    final authors = onlineMetadata.authors.isNotEmpty ? onlineMetadata.authors : fileMetadata.authors;
    final description = onlineMetadata.description.isNotEmpty ? onlineMetadata.description : fileMetadata.description;
    final publisher = onlineMetadata.publisher.isNotEmpty ? onlineMetadata.publisher : fileMetadata.publisher;
    final publishedDate = onlineMetadata.publishedDate.isNotEmpty ? onlineMetadata.publishedDate : fileMetadata.publishedDate;
    final categories = onlineMetadata.categories.isNotEmpty ? onlineMetadata.categories : fileMetadata.categories;
    final language = onlineMetadata.language.isNotEmpty ? onlineMetadata.language : fileMetadata.language;
    
    // For ratings/reviews, only use online data
    final averageRating = onlineMetadata.averageRating;
    final ratingsCount = onlineMetadata.ratingsCount;
    
    // For thumbnail, use best available
    String thumbnailUrl = onlineMetadata.thumbnailUrl;
    if (thumbnailUrl.isEmpty && fileMetadata.thumbnailUrl.isNotEmpty) {
      thumbnailUrl = fileMetadata.thumbnailUrl;
    }
    
    // Always preserve file's audio quality information
    final audioDuration = fileMetadata.audioDuration;
    final bitrate = fileMetadata.bitrate;
    final channels = fileMetadata.channels;
    final sampleRate = fileMetadata.sampleRate;
    final fileFormat = fileMetadata.fileFormat;
    
    // Log what's being merged
    Logger.debug('Merging metadata with folder context:');
    Logger.debug('- Title: $title');
    Logger.debug('- Authors: ${authors.join(", ")}');
    Logger.debug('- Series: $series');
    Logger.debug('- Series Position: $seriesPosition');
    Logger.debug('- Thumbnail URL: $thumbnailUrl');
    
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

  /// Calculate basic match score between metadata and query
  double _calculateMatchScore(
      AudiobookMetadata metadata, 
      List<String> queryTerms, 
      AudiobookMetadata? fileMetadata) {
    
    double titleScore = 0;
    double authorScore = 0;
    double seriesScore = 0;
    
    // Title matching
    final title = metadata.title.toLowerCase();
    
    // Direct match with file metadata
    if (fileMetadata != null && title == fileMetadata.title.toLowerCase()) {
      titleScore = 1.0;
      Logger.debug('Title exact match: $title');
    } else {
      // Term matching
      int matchedTerms = 0;
      final titleTerms = title.split(' ').where((term) => term.length > 2).toList();
      
      for (final term in titleTerms) {
        if (queryTerms.contains(term)) {
          matchedTerms++;
        }
      }
      
      if (titleTerms.isNotEmpty) {
        titleScore = matchedTerms / titleTerms.length;
        Logger.debug('Title term match: $matchedTerms/${titleTerms.length} = $titleScore');
      }
    }
    
    // Author matching
    for (final author in metadata.authors) {
      final authorLower = author.toLowerCase();
      
      // Direct match
      if (fileMetadata != null && fileMetadata.authors.isNotEmpty && 
          authorLower == fileMetadata.authors.first.toLowerCase()) {
        authorScore = 1.0;
        Logger.debug('Author exact match: $author');
        break;
      }
      
      // Term matching
      int matchedTerms = 0;
      final authorTerms = authorLower.split(' ').where((term) => term.length > 2).toList();
      
      for (final term in authorTerms) {
        if (queryTerms.contains(term)) {
          matchedTerms++;
        }
      }
      
      if (authorTerms.isNotEmpty) {
        double score = matchedTerms / authorTerms.length;
        Logger.debug('Author term match: $matchedTerms/${authorTerms.length} = $score');
        
        if (score > authorScore) {
          authorScore = score;
        }
      }
    }
    
    // Series matching
    if (metadata.series.isNotEmpty) {
      if (fileMetadata != null && fileMetadata.series.isNotEmpty && 
          metadata.series.toLowerCase() == fileMetadata.series.toLowerCase()) {
        seriesScore = 1.0;
        Logger.debug('Series exact match: ${metadata.series}');
      } else {
        // Term matching
        final seriesLower = metadata.series.toLowerCase();
        final seriesTerms = seriesLower.split(' ').where((term) => term.length > 2).toList();
        int matchedTerms = 0;
        
        for (final term in seriesTerms) {
          if (queryTerms.contains(term)) {
            matchedTerms++;
          }
        }
        
        if (seriesTerms.isNotEmpty) {
          seriesScore = matchedTerms / seriesTerms.length;
          Logger.debug('Series term match: $matchedTerms/${seriesTerms.length} = $seriesScore');
        }
      }
    }
    
    // Apply weights
    double weightedScore = (titleScore * _titleWeight) + 
                           (authorScore * _authorWeight) + 
                           (seriesScore * _seriesWeight);
    
    // Bonus for having both good title and author matches
    if (titleScore > 0.7 && authorScore > 0.7) {
      weightedScore += 0.1;
      Logger.debug('High title & author bonus: +0.1');
    }
    
    // Log the combined score
    Logger.debug('Weighted score: (${titleScore}*${_titleWeight} + ${authorScore}*${_authorWeight} + ${seriesScore}*${_seriesWeight}) = $weightedScore');
    
    return weightedScore > 1.0 ? 1.0 : weightedScore;
  }

  /// Download a cover image to a local file and return the path
  Future<String?> _downloadCoverImage(String imageUrl, String filePath) async {
    try {
      if (imageUrl.isEmpty) return null;
      
      Logger.log('Downloading cover image from: $imageUrl');
      
      // Download the image to a temporary location first
      final tempDir = await Directory.systemTemp.createTemp('covers');
      final tempFile = File('${tempDir.path}/${path_util.basename(filePath)}_temp.jpg');
      
      // Download the image
      final response = await _httpClient.get(Uri.parse(imageUrl))
                      .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        // Save to temp file
        await tempFile.writeAsBytes(response.bodyBytes);
        
        // Use storage manager if available to standardize path
        if (storageManager != null) {
          Logger.log('Using storage manager to store downloaded cover image');
          final finalPath = await storageManager!.ensureCoverImage(filePath, tempFile.path, force: true);
          
          // Clean up temp files
          await tempFile.delete();
          await tempDir.delete(recursive: true);
          
          Logger.log('Cover image stored via storage manager: $finalPath');
          return finalPath;
        } else {
          // Fallback to direct file handling
          final directory = path_util.dirname(filePath);
          final filename = path_util.basenameWithoutExtension(filePath);
          final coverDir = Directory('$directory/covers');
          if (!await coverDir.exists()) {
            await coverDir.create();
          }
          final coverPath = '${coverDir.path}/$filename.jpg';
          
          // If an existing cover exists, delete it first
          final existingCover = File(coverPath);
          if (await existingCover.exists()) {
            await existingCover.delete();
            Logger.log('Deleted existing cover image');
          }
          
          await tempFile.copy(coverPath);
          
          // Clean up temp files
          await tempFile.delete();
          await tempDir.delete(recursive: true);
          
          Logger.log('Cover image stored directly: $coverPath');
          return coverPath;
        }
      } else {
        Logger.warning('Failed to download cover image. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      Logger.error('Error downloading cover image', e);
      return null;
    }
  }

  /// User-requested metadata update with option to force
  Future<bool> updateMetadataForFile(AudiobookFile file, AudiobookMetadata updatedMetadata, {bool force = false}) async {
    try {
      Logger.log('Updating metadata for file: ${file.filename} (force: $force)');
      Logger.log('Thumbnail URL: ${updatedMetadata.thumbnailUrl}');
      
      // Extract file metadata to preserve audio quality info
      final fileMetadata = await file.extractFileMetadata();
      
      // Get folder context
      final folderName = path_util.basename(path_util.dirname(file.path));
      final bookInfo = _extractBookInfo(file.filename);
      final int? bookNumber = bookInfo['number'] as int?;
      
      // Merge with updated metadata
      AudiobookMetadata mergedMetadata;
      
      if (fileMetadata != null) {
        // Preserve audio quality info from file metadata
        mergedMetadata = updatedMetadata.copyWith(
          audioDuration: fileMetadata.audioDuration,
          bitrate: fileMetadata.bitrate,
          channels: fileMetadata.channels,
          sampleRate: fileMetadata.sampleRate,
          fileFormat: fileMetadata.fileFormat,
        );
        
        // Also enhance with folder context if needed
        if (mergedMetadata.series.isEmpty && folderName.length > 3) {
          mergedMetadata = mergedMetadata.copyWith(
            series: folderName,
            seriesPosition: bookNumber != null ? bookNumber.toString() : '',
          );
        }
      } else {
        mergedMetadata = updatedMetadata;
      }
      
      // Use storage manager if available (recommended flow)
      if (storageManager != null) {
        Logger.log('Using storage manager to update metadata');
        final success = await storageManager!.updateMetadataForFile(
          file.path, mergedMetadata, force: force
        );
        
        if (success) {
          // Update local reference
          file.metadata = mergedMetadata;
          
          // Also update series info cache
          if (mergedMetadata.series.isNotEmpty) {
            _folderSeriesNames[path_util.dirname(file.path)] = mergedMetadata.series;
          }
          
          Logger.log('Successfully updated metadata via storage manager');
          return true;
        } else {
          Logger.error('Storage manager failed to update metadata');
          return false;
        }
      } else {
        // Fallback to direct updates
        
        // If there's a thumbnail URL, make sure it's saved
        if (mergedMetadata.thumbnailUrl.isNotEmpty) {
          // Try to download the image if it's a URL
          if (mergedMetadata.thumbnailUrl.startsWith('http')) {
            final localPath = await _downloadCoverImage(mergedMetadata.thumbnailUrl, file.path);
            if (localPath != null) {
              mergedMetadata = mergedMetadata.copyWith(thumbnailUrl: localPath);
            }
          }
        }
        
        // Save to cache
        await cache.saveMetadataForFile(file.path, mergedMetadata);
        file.metadata = mergedMetadata;
        
        // Also save under search query for better future matches
        final searchQuery = "$folderName ${file.filename}";
        await cache.saveMetadata(searchQuery, mergedMetadata);
        
        // Update folder series info if series is set
        if (mergedMetadata.series.isNotEmpty) {
          _folderSeriesNames[path_util.dirname(file.path)] = mergedMetadata.series;
        }
        
        Logger.log('Manually updated metadata: ${file.filename}');
        return true;
      }
    } catch (e) {
      Logger.error('Error updating metadata for file', e);
      return false;
    }
  }
  
  /// Update only the cover image
  Future<bool> updateCoverImage(AudiobookFile file, String coverUrl, {bool force = true}) async {
    try {
      if (file.metadata == null) {
        Logger.warning('No metadata available to update cover image');
        return false;
      }
      
      Logger.log('Updating cover image: ${file.filename} with URL: $coverUrl');
      
      // Download the new cover image
      final localCoverPath = await _downloadCoverImage(coverUrl, file.path);
      if (localCoverPath == null) {
        Logger.warning('Failed to download cover image');
        return false;
      }
      
      // Create updated metadata with the new cover
      final updatedMetadata = file.metadata!.copyWith(thumbnailUrl: localCoverPath);
      
      // Update using the storage manager if available
      if (storageManager != null) {
        final success = await storageManager!.updateMetadataForFile(
          file.path, updatedMetadata, force: force
        );
        
        if (success) {
          file.metadata = updatedMetadata;
          Logger.log('Successfully updated cover image via storage manager: $localCoverPath');
          return true;
        } else {
          Logger.error('Failed to update cover image via storage manager');
          return false;
        }
      } else {
        // Fall back to direct cache update
        await cache.saveMetadataForFile(file.path, updatedMetadata);
        file.metadata = updatedMetadata;
        Logger.log('Successfully updated cover image directly: $localCoverPath');
        return true;
      }
    } catch (e) {
      Logger.error('Error updating cover image', e);
      return false;
    }
  }
}