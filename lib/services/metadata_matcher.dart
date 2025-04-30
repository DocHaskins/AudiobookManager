// File: lib/services/metadata_matcher.dart (improved implementation)
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/metadata_manager.dart';
import 'package:fuzzy/fuzzy.dart';

/// Service for matching audiobook files with metadata from various sources
class MetadataMatcher {
  /// List of metadata providers to search with
  final List<MetadataProvider> providers;
  
  /// Cache for storing and retrieving metadata
  final MetadataCache cache;
  
  /// HTTP client for downloading cover images
  final http.Client _httpClient;
  
  /// Threshold for accepting a match (adjusted for better accuracy)
  final double matchThreshold = 0.3;
  
  /// Weights for different match components - adjusted to prioritize exact matches
  static const double _titleWeight = 0.5;
  static const double _authorWeight = 0.4;
  static const double _seriesWeight = 0.1;
  
  /// Constructor
  MetadataMatcher({
    required this.providers, 
    required this.cache,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client() {
    Logger.log('MetadataMatcher initialized with ${providers.length} providers');
  }
  
  /// Match a file with metadata - improved to properly prioritize metadata
  Future<AudiobookMetadata?> matchFile(AudiobookFile file) async {
    try {
      // Step 1: Check cache for this specific file first (single cache lookup)
      final cachedMetadata = await cache.getMetadataForFile(file.path);
      if (cachedMetadata != null) {
        Logger.log('Found cached metadata for ${file.filename}');
        file.metadata = cachedMetadata;
        return cachedMetadata;
      }
      
      // Step 2: Extract file metadata (if not already done)
      final fileMetadata = await file.extractFileMetadata();
      
      // Step 3: Build search query
      String searchQuery = file.filename.trim();
      
      if (searchQuery.isEmpty) {
        Logger.warning('Empty search query for file: ${file.path}');
        
        if (fileMetadata != null) {
          file.metadata = fileMetadata;
          await cache.saveMetadataForFile(file.path, fileMetadata);
          return fileMetadata;
        }
        
        return null;
      }
      
      Logger.log('Searching for metadata with query: "$searchQuery" for file: ${file.filename}');
      
      // Step 4: Try to find online metadata
      AudiobookMetadata? onlineMetadata = await _searchOnlineProviders(searchQuery, fileMetadata);
      
      if (onlineMetadata != null) {
        // Handle thumbnail and audio quality info
        if (onlineMetadata.thumbnailUrl.isNotEmpty) {
          final localCoverPath = await _downloadCoverImage(onlineMetadata.thumbnailUrl, file.path);
          if (localCoverPath != null) {
            onlineMetadata = MetadataManager.updateThumbnail(onlineMetadata, localCoverPath);
          }
        } else if (fileMetadata != null && fileMetadata.thumbnailUrl.isNotEmpty) {
          onlineMetadata = MetadataManager.updateThumbnail(onlineMetadata, fileMetadata.thumbnailUrl);
        }
        
        // Merge metadata - preserving audio quality info from file
        final mergedMetadata = fileMetadata != null ? 
            _mergeWithPreservedAudioInfo(fileMetadata, onlineMetadata) : onlineMetadata;
        
        // Save to cache ONCE with both keys
        await _saveToCacheEfficiently(searchQuery, file.path, mergedMetadata);
        
        file.metadata = mergedMetadata;
        return mergedMetadata;
      }
      
      // Fallback to file metadata
      if (fileMetadata != null) {
        Logger.log('Using file metadata as fallback for ${file.filename}');
        
        if (_appearsSwapped(fileMetadata)) {
          final correctedMetadata = _correctSwappedMetadata(fileMetadata);
          file.metadata = correctedMetadata;
          await cache.saveMetadataForFile(file.path, correctedMetadata);
          return correctedMetadata;
        }
        
        file.metadata = fileMetadata;
        await cache.saveMetadataForFile(file.path, fileMetadata);
        return fileMetadata;
      }
      
      return null;
    } catch (e) {
      Logger.error('Error matching metadata for file: ${file.path}', e);
      return null;
    }
  }

  Future<void> _saveToCacheEfficiently(String searchQuery, String filePath, AudiobookMetadata metadata) async {
    try {
      // Reduce debug logging
      Logger.log('Saving metadata for "${metadata.title}" to cache');
      
      // Only convert to map once
      await cache.saveMetadata(searchQuery, metadata);
      await cache.saveMetadataForFile(filePath, metadata);
    } catch (e) {
      Logger.error('Error saving metadata to cache', e);
    }
  }
  
  /// Check if metadata fields appear to be swapped (title contains author name and vice versa)
  bool _appearsSwapped(AudiobookMetadata metadata) {
    // Skip check if either field is empty
    if (metadata.title.isEmpty || metadata.authors.isEmpty) {
      return false;
    }
    
    final title = metadata.title.toLowerCase();
    final author = metadata.authors.first.toLowerCase();
    
    // Common indicators of swapped metadata:
    // 1. Title contains words like "by" followed by what looks like an author name
    if (title.contains(" by ")) {
      return true;
    }
    
    // 2. Author field contains words typically found in titles (The, A, An) at the beginning
    if (author.startsWith("the ") || author.startsWith("a ") || author.startsWith("an ")) {
      return true;
    }
    
    // 3. Title is a typical person name format (FirstName LastName)
    final namePattern = RegExp(r'^[A-Z][a-z]+ [A-Z][a-z]+$');
    if (namePattern.hasMatch(metadata.title)) {
      return true;
    }
    
    // 4. Filename parsing suggests swap
    final filenameTitle = metadata.title;
    final filenameAuthor = metadata.authorsFormatted;
    
    // If filename has format like "BookTitle - AuthorName"
    // but metadata has "AuthorName" as title and "BookTitle" as author
    if (filenameTitle.contains(author) && filenameAuthor.contains(title)) {
      return true;
    }
    
    return false;
  }
  
  /// Create corrected metadata when fields are swapped
  AudiobookMetadata _correctSwappedMetadata(AudiobookMetadata metadata) {
    // Create a new metadata object with swapped title and author
    Logger.log('Correcting swapped metadata: Title was "${metadata.title}", Author was "${metadata.authorsFormatted}"');
    
    String correctedTitle = metadata.authorsFormatted;
    List<String> correctedAuthors = [metadata.title];
    
    // Clean up the corrected title (remove " by Author" if present)
    if (correctedTitle.contains(" by ")) {
      correctedTitle = correctedTitle.split(" by ").first.trim();
    }
    
    return AudiobookMetadata(
      id: metadata.id,
      title: correctedTitle,
      authors: correctedAuthors,
      description: metadata.description,
      publisher: metadata.publisher,
      publishedDate: metadata.publishedDate,
      categories: metadata.categories,
      averageRating: metadata.averageRating,
      ratingsCount: metadata.ratingsCount,
      thumbnailUrl: metadata.thumbnailUrl,
      language: metadata.language,
      series: metadata.series,
      seriesPosition: metadata.seriesPosition,
      audioDuration: metadata.audioDuration,
      bitrate: metadata.bitrate,
      channels: metadata.channels,
      sampleRate: metadata.sampleRate,
      fileFormat: metadata.fileFormat,
      provider: '${metadata.provider} (Corrected)',
    );
  }
  
  /// Improved merging that preserves file audio quality information while using online content info
  AudiobookMetadata _mergeWithPreservedAudioInfo(AudiobookMetadata fileMetadata, AudiobookMetadata onlineMetadata) {
    // Get descriptive fields from online metadata (always preferred)
    final title = onlineMetadata.title.isNotEmpty ? onlineMetadata.title : fileMetadata.title;
    final authors = onlineMetadata.authors.isNotEmpty ? onlineMetadata.authors : fileMetadata.authors;
    final description = onlineMetadata.description.isNotEmpty ? onlineMetadata.description : fileMetadata.description;
    final publisher = onlineMetadata.publisher.isNotEmpty ? onlineMetadata.publisher : fileMetadata.publisher;
    final publishedDate = onlineMetadata.publishedDate.isNotEmpty ? onlineMetadata.publishedDate : fileMetadata.publishedDate;
    final categories = onlineMetadata.categories.isNotEmpty ? onlineMetadata.categories : fileMetadata.categories;
    final series = onlineMetadata.series.isNotEmpty ? onlineMetadata.series : fileMetadata.series;
    final seriesPosition = onlineMetadata.seriesPosition.isNotEmpty ? onlineMetadata.seriesPosition : fileMetadata.seriesPosition;
    final language = onlineMetadata.language.isNotEmpty ? onlineMetadata.language : fileMetadata.language;
    
    // For ratings/reviews, only use online data
    final averageRating = onlineMetadata.averageRating;
    final ratingsCount = onlineMetadata.ratingsCount;
    
    // For thumbnail, use the best available source
    // Online is normally better, but if we've extracted embedded art, use that
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
    Logger.debug('Merging metadata sources: file=${fileMetadata.provider}, online=${onlineMetadata.provider}');
    Logger.debug('Merged metadata: Title=$title, Authors=${authors.join(", ")}, Using Online Thumbnail=${onlineMetadata.thumbnailUrl.isNotEmpty}');
    
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
  
  /// Download a cover image to a local file and return the path
  Future<String?> _downloadCoverImage(String imageUrl, String filePath) async {
    try {
      if (imageUrl.isEmpty) return null;
      
      Logger.log('Downloading cover image from: $imageUrl');
      
      // Get the directory where the audio file is located
      final directory = path_util.dirname(filePath);
      final filename = path_util.basenameWithoutExtension(filePath);
      
      // Create a cover directory if it doesn't exist
      final coverDir = Directory('$directory/covers');
      if (!await coverDir.exists()) {
        await coverDir.create();
      }
      
      // Define the local path for the cover image
      final coverPath = '${coverDir.path}/$filename.jpg';
      
      // Download the image
      final response = await _httpClient.get(Uri.parse(imageUrl))
                       .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        // Save the image to the local file
        final coverFile = File(coverPath);
        await coverFile.writeAsBytes(response.bodyBytes);
        
        Logger.log('Successfully downloaded cover image to: $coverPath');
        return coverPath;
      } else {
        Logger.warning('Failed to download cover image. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      Logger.error('Error downloading cover image', e);
      return null;
    }
  }
  
  /// Search all online providers with a query
  Future<AudiobookMetadata?> _searchOnlineProviders(String searchQuery, AudiobookMetadata? fileMetadata) async {
    for (final provider in providers) {
      try {
        Logger.debug('Trying provider: ${provider.runtimeType}');
        final results = await provider.search(searchQuery);
        
        if (results.isEmpty) {
          Logger.debug('No results from ${provider.runtimeType} for query: "$searchQuery"');
          continue;
        }
        
        //Logger.log('Found ${results.length} results from ${provider.runtimeType}');
        
        // Find the best match using improved matching algorithm
        AudiobookMetadata? bestMatch = _findBestMatch(results, searchQuery, fileMetadata);
        if (bestMatch != null) {
          return bestMatch;
        }
      } catch (e) {
        Logger.error('Error matching with provider ${provider.runtimeType}', e);
      }
    }
    
    return null;
  }
  
  /// Helper method to create a search query from file metadata
  String _createSearchQueryFromMetadata(AudiobookMetadata metadata) {
    // Format as "Title - Author" - using full strings without truncation
    if (metadata.title.isNotEmpty && metadata.authors.isNotEmpty) {
      return "${metadata.title} - ${metadata.authors.first}";
    }
    
    // Fallback if missing either title or author
    List<String> queryParts = [];
    
    if (metadata.title.isNotEmpty) {
      queryParts.add(metadata.title); // Use complete title with no truncation
    }
    
    if (metadata.authors.isNotEmpty) {
      queryParts.add(metadata.authors.first); // Use complete author name
    }
    
    return queryParts.join(' - ');
  }
  
  /// Helper method to find the best match from a list of results
  AudiobookMetadata? _findBestMatch(List<AudiobookMetadata> results, String searchQuery, AudiobookMetadata? fileMetadata) {
    double bestScore = 0;
    AudiobookMetadata? bestMatch;
    
    // Extract terms from search query for better matching
    final queryTerms = searchQuery.toLowerCase().split(' ')
                      .where((term) => term.length > 2)
                      .toList();
                      
    // Log all results for debugging
    for (int i = 0; i < results.length; i++) {
      final metadata = results[i];
      
      // Calculate match score with improved algorithm
      final score = _calculateImprovedMatchScore(metadata, queryTerms, fileMetadata);
      
      //Logger.debug('Result #${i+1} - Title: "${metadata.title}", Author: "${metadata.authorsFormatted}", Score: $score');
      
      if (score > bestScore) {
        bestScore = score;
        bestMatch = metadata;
      }
    }
    
    // Return if we found a decent match
    if (bestScore >= matchThreshold && bestMatch != null) {
      Logger.log('Found best match - Title: "${bestMatch.title}", Author: "${bestMatch.authorsFormatted}", Score: $bestScore');
      return bestMatch;
    } else if (bestMatch != null) {
      Logger.debug('Best match score ($bestScore) too low for: "${bestMatch.title}" by ${bestMatch.authorsFormatted}');
    }
    
    return null;
  }
  
  /// Improved match scoring algorithm
  double _calculateImprovedMatchScore(AudiobookMetadata metadata, List<String> queryTerms, AudiobookMetadata? fileMetadata) {
    // Direct exact matches should score higher than fuzzy matches
    double titleScore = 0;
    double authorScore = 0;
    double seriesScore = 0;
    
    // Title matching - check for exact matches first
    final title = metadata.title.toLowerCase();
    // Direct exact match is best
    if (fileMetadata != null && title == fileMetadata.title.toLowerCase()) {
      titleScore = 1.0;
    } 
    // Check if all terms in title are in the query terms
    else {
      int matchedTerms = 0;
      final titleTerms = title.split(' ').where((term) => term.length > 2).toList();
      for (final term in titleTerms) {
        if (queryTerms.contains(term)) {
          matchedTerms++;
        }
      }
      
      if (titleTerms.isNotEmpty) {
        titleScore = matchedTerms / titleTerms.length;
      }
      
      // Add fuzzy matching as fallback
      if (titleScore < 0.5) {
        final fuzzy = Fuzzy([metadata.title], options: FuzzyOptions(
          threshold: 0.2,
          keys: [],
        ));
        
        // Use the highest query term match
        double highestTermScore = 0;
        for (final term in queryTerms) {
          final results = fuzzy.search(term);
          if (results.isNotEmpty && results.first.score > highestTermScore) {
            highestTermScore = results.first.score;
          }
        }
        
        // Use whichever is higher - the term matches or fuzzy score
        titleScore = titleScore > highestTermScore ? titleScore : highestTermScore;
      }
    }
    
    // Author matching - check for exact matches first
    for (final author in metadata.authors) {
      final authorLower = author.toLowerCase();
      
      // Direct exact match
      if (fileMetadata != null && fileMetadata.authors.isNotEmpty && 
          authorLower == fileMetadata.authors.first.toLowerCase()) {
        authorScore = 1.0;
        break;
      }
      
      // Check if author name is in the query
      int matchedTerms = 0;
      final authorTerms = authorLower.split(' ').where((term) => term.length > 2).toList();
      for (final term in authorTerms) {
        if (queryTerms.contains(term)) {
          matchedTerms++;
        }
      }
      
      if (authorTerms.isNotEmpty) {
        double score = matchedTerms / authorTerms.length;
        if (score > authorScore) {
          authorScore = score;
        }
      }
    }
    
    // Add fuzzy author matching if score is low
    if (authorScore < 0.5 && metadata.authors.isNotEmpty) {
      final authorFuzzy = Fuzzy(metadata.authors);
      
      // Try each query term
      double bestAuthorScore = 0;
      for (final term in queryTerms) {
        final results = authorFuzzy.search(term);
        if (results.isNotEmpty && results.first.score > bestAuthorScore) {
          bestAuthorScore = results.first.score;
        }
      }
      
      // Use whichever is higher
      authorScore = authorScore > bestAuthorScore ? authorScore : bestAuthorScore;
    }
    
    // Series matching - simpler since it's less critical
    if (metadata.series.isNotEmpty) {
      if (fileMetadata != null && fileMetadata.series.isNotEmpty && 
          metadata.series.toLowerCase() == fileMetadata.series.toLowerCase()) {
        seriesScore = 1.0;
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
        }
      }
    }
    
    // Apply weights to get final score
    double weightedScore = (titleScore * _titleWeight) + 
                           (authorScore * _authorWeight) + 
                           (seriesScore * _seriesWeight);
                           
    // Bonus for having both good title and author matches
    if (titleScore > 0.7 && authorScore > 0.7) {
      weightedScore += 0.2;
    }
    
    // Cap at 1.0
    return weightedScore > 1.0 ? 1.0 : weightedScore;
  }
  
  /// Get metadata from cache for a file
  Future<AudiobookMetadata?> getMetadataFromCache(String filePath) async {
    try {
      return await cache.getMetadataForFile(filePath);
    } catch (e) {
      Logger.error('Error retrieving metadata from cache', e);
      return null;
    }
  }
  
  /// Save metadata to cache for a file
  Future<bool> saveMetadataToCache(String filePath, AudiobookMetadata metadata) async {
    try {
      Logger.log('Saving metadata for "${metadata.title}" to cache for file: $filePath');
      
      // Create a search query to use as the cache key
      final AudiobookFile tempFile = AudiobookFile(
        path: filePath,
        filename: path_util.basenameWithoutExtension(filePath),
        extension: path_util.extension(filePath),
        size: 0,
        lastModified: DateTime.now(),
      );
      
      final searchQuery = tempFile.generateSearchQuery();
      
      // Save with both the file path and the search query for better cache hits
      await cache.saveMetadataForFile(filePath, metadata);
      if (searchQuery.isNotEmpty) {
        await cache.saveMetadata(searchQuery, metadata);
      }
      
      return true;
    } catch (e) {
      Logger.error('Error saving metadata to cache', e);
      return false;
    }
  }
  
  /// Update the cover image for an existing metadata entry
  Future<bool> updateCoverImage(AudiobookFile file, String coverUrl) async {
    try {
      if (file.metadata == null) {
        Logger.warning('No metadata available to update cover image');
        return false;
      }
      
      // Download the new cover image
      final localCoverPath = await _downloadCoverImage(coverUrl, file.path);
      if (localCoverPath == null) {
        return false;
      }
      
      // Update the metadata with the new cover path
      final updatedMetadata = MetadataManager.updateThumbnail(file.metadata!, localCoverPath);
      file.metadata = updatedMetadata;
      
      // Save to cache
      await cache.saveMetadataForFile(file.path, updatedMetadata);
      
      Logger.log('Successfully updated cover image for: ${file.filename}');
      return true;
    } catch (e) {
      Logger.error('Error updating cover image', e);
      return false;
    }
  }
  
  /// Manually update metadata for a file (used for user corrections)
  Future<bool> updateMetadataForFile(
    AudiobookFile file,
    AudiobookMetadata updatedMetadata,
  ) async {
    try {
      // Extract file metadata first to preserve audio quality info
      final fileMetadata = await file.extractFileMetadata();
      
      // Merge with updated metadata to preserve audio quality info
      final mergedMetadata = fileMetadata != null
          ? _mergeWithPreservedAudioInfo(fileMetadata, updatedMetadata)
          : updatedMetadata;
      
      // Save to cache and update file
      await cache.saveMetadataForFile(file.path, mergedMetadata);
      file.metadata = mergedMetadata;
      
      // Also save under search query for better future matches
      final searchQuery = _createSearchQueryFromMetadata(mergedMetadata);
      if (searchQuery.isNotEmpty) {
        await cache.saveMetadata(searchQuery, mergedMetadata);
      }
      
      Logger.log('Manually updated metadata for: ${file.filename}');
      return true;
    } catch (e) {
      Logger.error('Error updating metadata for file', e);
      return false;
    }
  }
}