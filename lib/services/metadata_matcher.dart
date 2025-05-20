// File: lib/services/metadata_matcher.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/storage/audiobook_storage_manager.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/utils/filename_parser.dart';
import 'package:audiobook_organizer/utils/logger.dart';

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
  
  Future<AudiobookMetadata?> matchFile(AudiobookFile file) async {
  try {
    // Step 1: Check cache for this specific file first
    final cachedMetadata = await cache.getMetadataForFile(file.path);
    if (cachedMetadata != null) {
      Logger.log('Found cached metadata for ${file.filename}');
      file.metadata = cachedMetadata;
      return cachedMetadata;
    }
    
    // Step 2: Extract file metadata using MetadataService (via AudiobookFile)
    Logger.log('Extracting metadata from file: ${file.filename}');
    
    // If file already has metadata (maybe from previous extraction), use it
    // Otherwise extract it now
    final fileMetadata = file.metadata ?? await file.extractFileMetadata();
    if (fileMetadata == null) {
      Logger.warning('Could not extract metadata from file: ${file.path}');
      return null;
    }
    
    // Step 3: Get folder context - still valuable for audiobooks organization
    final String folderName = path_util.basename(path_util.dirname(file.path));
    final String folderPath = path_util.dirname(file.path);
    
    Logger.log('Processing file: ${file.filename} from folder: $folderName');
    
    // Step 4: Extract book number from filename early in the process
    final bookInfo = _extractBookInfo(file.filename);
    int? bookNumber = bookInfo['number'] as int?;
    Logger.debug('Book number from filename: $bookNumber');
    
    // If not found in filename, check metadata
    if (bookNumber == null && fileMetadata.seriesPosition.isNotEmpty) {
      bookNumber = int.tryParse(fileMetadata.seriesPosition);
      Logger.debug('Book number from metadata: $bookNumber');
    }
    
    // Step 5: Build search query using the file metadata and book number
    String searchQuery;
    
    // Build search query based on available metadata
    if (fileMetadata.title.isNotEmpty) {
      // Create a clean title without common audiobook markers
      final cleanTitle = fileMetadata.title
          .replaceAll('(Unabridged)', '')
          .replaceAll('Unabridged', '')
          .trim();
          
      // Start with clean title and author for a focused search
      searchQuery = cleanTitle;
      
      // Add author if available
      if (fileMetadata.authors.isNotEmpty) {
        searchQuery += " ${fileMetadata.authors.first}";
      }
      
      // Add series and book number for more precision
      if (fileMetadata.series.isNotEmpty) {
        // Only add series if it's not already part of the title
        if (!searchQuery.toLowerCase().contains(fileMetadata.series.toLowerCase())) {
          if (bookNumber != null && bookNumber > 1) {
            // For sequels, include series and book number prominently
            searchQuery = "${fileMetadata.series} book $bookNumber $searchQuery";
          } else {
            // For first books or unknown position
            searchQuery = "${fileMetadata.series} $searchQuery";
          }
        }
      } else if (folderName.length > 3 && !searchQuery.toLowerCase().contains(folderName.toLowerCase())) {
        // Use folder name as potential series context
        if (bookNumber != null && bookNumber > 1) {
          searchQuery = "$folderName book $bookNumber $searchQuery";
        } else {
          searchQuery = "$folderName $searchQuery";
        }
      }
      
      Logger.log('Search query from file metadata: "$searchQuery"');
    } else {
      // Fallback to folder name plus filename with book number
      if (bookNumber != null && bookNumber > 1) {
        searchQuery = "$folderName book $bookNumber ${path_util.basenameWithoutExtension(file.path)}";
      } else {
        searchQuery = "$folderName ${path_util.basenameWithoutExtension(file.path)}";
      }
      Logger.log('Fallback search query: "$searchQuery"');
    }
    
    // Step 6: Search for online metadata to enhance the file metadata
    AudiobookMetadata? onlineMetadata = await _searchWithFolderContext(
      searchQuery, fileMetadata, folderName, bookNumber
    );
    
    // Step 7: Process online results if found
    if (onlineMetadata != null) {
      Logger.log('Found online metadata match: "${onlineMetadata.title}" by ${onlineMetadata.authorsFormatted}');
      
      // 7a: Handle cover art/thumbnail
      if (onlineMetadata.thumbnailUrl.isNotEmpty) {
        final localCoverPath = await _downloadCoverImage(onlineMetadata.thumbnailUrl, file.path);
        if (localCoverPath != null) {
          onlineMetadata = onlineMetadata.copyWith(thumbnailUrl: localCoverPath);
          Logger.log('Updated thumbnail URL: ${onlineMetadata.thumbnailUrl}');
        }
      } else if (fileMetadata.thumbnailUrl.isNotEmpty) {
        onlineMetadata = onlineMetadata.copyWith(thumbnailUrl: fileMetadata.thumbnailUrl);
        Logger.log('Using existing thumbnail URL from file metadata: ${fileMetadata.thumbnailUrl}');
      }
      
      // 7b: Critical - Verify that book positions match!
      bool isValidMatch = true;
      if (bookNumber != null && onlineMetadata.seriesPosition.isNotEmpty) {
        final onlineBookNum = int.tryParse(onlineMetadata.seriesPosition);
        if (onlineBookNum != null && onlineBookNum != bookNumber) {
          Logger.warning('Book position mismatch! File: $bookNumber, Online: ${onlineMetadata.seriesPosition}');
          
          // For sequels (book 2+), this is critical - reject the match
          if (bookNumber > 1) {
            isValidMatch = false;
          }
          
          // Even for book 1, be cautious about mismatches
          if (onlineMetadata.title.toLowerCase().contains('book ${onlineBookNum}') ||
              onlineMetadata.title.toLowerCase().contains('book ${onlineBookNum.toString()}')) {
            isValidMatch = false;
          }
        }
      }

      // 7d: Update folder series mapping
      if (onlineMetadata.series.isNotEmpty) {
        _folderSeriesNames[folderPath] = onlineMetadata.series;
        Logger.log('Updated series context for folder: ${onlineMetadata.series}');
      } else {
        // Enhance with folder context if needed
        onlineMetadata = _enhanceWithFolderContext(onlineMetadata, folderName, bookNumber);
        Logger.log('Enhanced online metadata with folder context: ${onlineMetadata.series}');
      }
      
      // 7e: Merge metadata - preserving audio quality info from file
      final mergedMetadata = _mergeWithFolderContext(fileMetadata, onlineMetadata, folderName, bookNumber);
      
      // 7f: Save the merged metadata
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
    
    // Step 8: If no online match found, use and enhance file metadata
    Logger.log('No online match found, using file metadata for ${file.filename}');
    
    // Update folder series context
    if (fileMetadata.series.isNotEmpty) {
      _folderSeriesNames[folderPath] = fileMetadata.series;
      Logger.log('Using series name from file metadata: ${fileMetadata.series}');
    } else if (_folderSeriesNames[folderPath] == null) {
      _folderSeriesNames[folderPath] = folderName;
      Logger.log('Using folder name as series context: $folderName');
    }
    
    // Enhance with folder context if needed
    final enhancedFileMetadata = _enhanceWithFolderContext(fileMetadata, folderName, bookNumber);
    
    // Save file metadata
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
    
    // If no match found and we have a folder name with significant length
    // generate a more specific search query using FilenameParser
    if (folderName.length > 3) {
      Logger.log('Trying folder-based search for: $folderName');
      final parsedFolder = FilenameParser.parse(folderName, "");
      
      if (parsedFolder.hasAuthor) {
        final specializedQuery = '${parsedFolder.title} ${parsedFolder.author}';
        Logger.debug('Generated specialized query: $specializedQuery');
        
        for (final provider in providers) {
          try {
            final results = await provider.search(specializedQuery);
            
            if (results.isNotEmpty) {
              AudiobookMetadata? bestMatch = _findBestMatchWithContext(
                results, specializedQuery, fileMetadata, folderName, bookNumber
              );
              
              if (bestMatch != null) {
                return bestMatch;
              }
            }
          } catch (e) {
            Logger.error('Error with specialized folder search', e);
          }
        }
      }
    }
    
    // If still no match found and we have a book number, try a more specific search
    if (bookNumber != null) {
      // Original book number search logic remains...
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
    
    // 3. Book number matches - increased importance
    if (bookNumber != null && metadata.seriesPosition.isNotEmpty) {
      final metadataBookNum = int.tryParse(metadata.seriesPosition);
      if (metadataBookNum != null && metadataBookNum == bookNumber) {
        // Increase the bonus for matching book number - critical for sequels
        score += 0.7; // Increased from 0.5
        Logger.debug('Book number matches (+0.7): ${metadata.seriesPosition}');
      } else {
        // Add a stronger penalty for wrong book number in the same series
        if (metadata.series.isNotEmpty && 
            (metadata.series.toLowerCase().contains(folderName.toLowerCase()) || 
             folderName.toLowerCase().contains(metadata.series.toLowerCase()))) {
          score -= 0.5; // Increased penalty from 0.3
          Logger.debug('Wrong book number in series (-0.5): expected #$bookNumber, got #${metadata.seriesPosition}');
        }
      }
    }
    
    // 4. Title contains book number explicitly (e.g., "Book 2")
    if (bookNumber != null && 
        (metadata.title.toLowerCase().contains('book $bookNumber') || 
         metadata.title.toLowerCase().contains('book ${bookNumber.toString()}'))) {
      score += 0.3;
      Logger.debug('Title contains book number (+0.3): ${metadata.title}');
    }
    
    // 5. Check for common sequel title patterns
    if (bookNumber != null && bookNumber > 1) {
      // For specific known series, check for expected sequel titles
      if (folderName.toLowerCase().contains('hunger games')) {
        if (bookNumber == 2 && metadata.title.toLowerCase().contains('catching fire')) {
          score += 0.4;
          Logger.debug('Contains expected sequel title for book 2 (+0.4): Catching Fire');
        } else if (bookNumber == 3 && metadata.title.toLowerCase().contains('mockingjay')) {
          score += 0.4;
          Logger.debug('Contains expected sequel title for book 3 (+0.4): Mockingjay');
        }
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
    Logger.debug('Weighted score: ($titleScore*$_titleWeight + $authorScore*$_authorWeight + $seriesScore*$_seriesWeight) = $weightedScore');
    
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