// lib/services/metadata_matcher.dart - REFACTORED
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/storage/audiobook_storage_manager.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/services/cover_art_manager.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/file_utils.dart';

/// Service for matching audiobook files with metadata from various sources
class MetadataMatcher {
  /// List of metadata providers to search with
  final List<MetadataProvider> providers;
  
  /// Cache for storing and retrieving search results
  final MetadataCache cache;
  
  /// Storage manager for persisting metadata
  final AudiobookStorageManager storageManager;
  
  /// Cover art manager
  final CoverArtManager _coverArtManager = CoverArtManager();
  
  /// Match threshold
  final double matchThreshold = 0.5;
  
  /// Whether to automatically download covers from online sources
  /// Set to false to only use embedded covers
  bool autoDownloadCovers = false;
  
  MetadataMatcher({
    required this.providers, 
    required this.cache,
    required this.storageManager,
    this.autoDownloadCovers = false,
  });
  
  /// Initialize the matcher
  Future<void> initialize() async {
    await _coverArtManager.initialize();
  }
  
  /// Match a file with online metadata
  Future<AudiobookMetadata?> matchWithOnlineSources(AudiobookMetadata metadata, String filePath) async {
    try {
      // FIRST: Ensure we have the cover from the file (embedded or existing)
      final coverPath = await _coverArtManager.ensureCoverForFile(filePath, metadata);
      if (coverPath != null && coverPath != metadata.thumbnailUrl) {
        // Update metadata with cover path
        metadata = metadata.copyWith(thumbnailUrl: coverPath);
        Logger.log('Using cover for: ${metadata.title}');
      }
      
      // Build search query from the provided metadata
      String searchQuery = _buildSimpleSearchQuery(metadata);
      Logger.log('Search query from metadata: "$searchQuery"');
      
      // Check cache first for this search query
      final cachedResult = cache.getMetadata(searchQuery);
      if (cachedResult != null) {
        Logger.log('Found cached result for query: "$searchQuery"');
        // Merge with cached result but preserve file-specific data
        final mergedMetadata = metadata.merge(cachedResult);
        await storageManager.updateMetadataForFile(filePath, mergedMetadata, force: true);
        return mergedMetadata;
      }
      
      // Search for matches
      AudiobookMetadata? onlineMetadata = await _searchForMetadata(searchQuery);
      
      if (onlineMetadata != null) {
        Logger.log('Found online metadata match: "${onlineMetadata.title}" by ${onlineMetadata.authorsFormatted}');
        
        // Cache the search result
        await cache.saveMetadata(searchQuery, onlineMetadata);
        
        // Merge the metadata (using built-in merge method)
        AudiobookMetadata mergedMetadata = metadata.merge(onlineMetadata);
        
        // Handle cover image ONLY if auto-download is enabled AND we don't have a cover
        if (autoDownloadCovers && 
            onlineMetadata.thumbnailUrl.isNotEmpty && 
            coverPath == null) {
          
          Logger.log('No existing cover found, attempting to download online cover');
          final downloadedCoverPath = await _coverArtManager.downloadCover(filePath, onlineMetadata.thumbnailUrl);
          if (downloadedCoverPath != null) {
            // Update merged metadata with downloaded cover path
            mergedMetadata = mergedMetadata.copyWith(thumbnailUrl: downloadedCoverPath);
            Logger.log('Downloaded and set cover image: $downloadedCoverPath');
          }
        } else if (coverPath != null) {
          Logger.log('Keeping existing cover instead of downloading online cover');
          // Ensure the existing cover path is preserved
          mergedMetadata = mergedMetadata.copyWith(thumbnailUrl: coverPath);
        } else if (!autoDownloadCovers) {
          Logger.log('Auto-download covers disabled, skipping online cover');
        }
        
        // Save the final merged metadata using storage manager
        await storageManager.updateMetadataForFile(filePath, mergedMetadata, force: true);
        
        return mergedMetadata;
      }
      
      // If no online match, just ensure we have the cover
      Logger.log('No online match found, using existing metadata with cover');
      
      // Save the metadata with cover
      await storageManager.updateMetadataForFile(filePath, metadata);
      
      return metadata;
    } catch (e) {
      Logger.error('Error matching metadata for file: $filePath', e);
      return null;
    }
  }
  
  /// Manually download cover for a file (user-initiated)
  Future<AudiobookMetadata?> downloadCoverForFile(AudiobookFile file, String imageUrl) async {
    try {
      if (file.metadata == null) return null;
      
      Logger.log('User-initiated cover download for: ${file.filename}');
      
      final downloadedCoverPath = await _coverArtManager.downloadCover(file.path, imageUrl);
      if (downloadedCoverPath != null) {
        // Update metadata with downloaded cover
        final updatedMetadata = file.metadata!.copyWith(thumbnailUrl: downloadedCoverPath);
        
        // Save the updated metadata using storage manager
        await storageManager.updateMetadataForFile(file.path, updatedMetadata, force: true);
        
        // Update the file object
        file.metadata = updatedMetadata;
        
        Logger.log('Successfully downloaded cover for: ${file.filename}');
        return updatedMetadata;
      }
      
      return null;
    } catch (e) {
      Logger.error('Error downloading cover for file: ${file.path}', e);
      return null;
    }
  }
  
  /// Search for potential covers online (without automatically downloading)
  Future<List<String>> searchCoversOnline(AudiobookMetadata metadata) async {
    try {
      final searchQuery = _buildSimpleSearchQuery(metadata);
      final onlineMetadata = await _searchForMetadata(searchQuery);
      
      final coverUrls = <String>[];
      
      if (onlineMetadata != null && onlineMetadata.thumbnailUrl.isNotEmpty) {
        coverUrls.add(onlineMetadata.thumbnailUrl);
      }
      
      // Could extend this to search all providers and collect multiple cover options
      for (final provider in providers) {
        try {
          final results = await provider.search(searchQuery);
          for (final result in results.take(3)) { // Limit to top 3 results
            if (result.thumbnailUrl.isNotEmpty && !coverUrls.contains(result.thumbnailUrl)) {
              coverUrls.add(result.thumbnailUrl);
            }
          }
        } catch (e) {
          Logger.error('Error searching covers with provider ${provider.runtimeType}', e);
        }
      }
      
      Logger.log('Found ${coverUrls.length} potential cover URLs for: ${metadata.title}');
      return coverUrls;
    } catch (e) {
      Logger.error('Error searching covers online', e);
      return [];
    }
  }
  
  /// Build a simple search query with title and author
  String _buildSimpleSearchQuery(AudiobookMetadata metadata) {
    // Use centralized title cleaning
    String title = FileUtils.cleanAudiobookTitle(metadata.title);
    
    // If we have an author, include it
    if (metadata.authors.isNotEmpty) {
      return '$title ${metadata.authors.first}';
    }
    
    return title;
  }
  
  /// Search for metadata using all providers
  Future<AudiobookMetadata?> _searchForMetadata(String query) async {
    for (final provider in providers) {
      try {
        Logger.debug('Searching with provider: ${provider.runtimeType}');
        final results = await provider.search(query);
        
        if (results.isEmpty) {
          Logger.debug('No results from ${provider.runtimeType}');
          continue;
        }
        
        // Find best match by title and author
        final bestMatch = _findBestMatch(results, query);
        if (bestMatch != null) {
          return bestMatch;
        }
      } catch (e) {
        Logger.error('Error with provider ${provider.runtimeType}', e);
      }
    }
    
    return null;
  }
  
  /// Find the best match based on title and author
  AudiobookMetadata? _findBestMatch(List<AudiobookMetadata> results, String query) {
    double bestScore = 0;
    AudiobookMetadata? bestMatch;
    
    // Get query terms for matching
    final queryTerms = query.toLowerCase().split(' ')
                  .where((term) => term.length > 2)
                  .toList();
    
    for (int i = 0; i < results.length; i++) {
      final metadata = results[i];
      
      // Calculate match score based on title and author
      double score = _calculateMatchScore(metadata, queryTerms);
      
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
    }
    
    return null;
  }
  
  /// Calculate match score based on title and author
  double _calculateMatchScore(AudiobookMetadata metadata, List<String> queryTerms) {
    double titleScore = 0;
    double authorScore = 0;
    
    // Title matching
    final title = metadata.title.toLowerCase();
    final titleTerms = title.split(' ').where((term) => term.length > 2).toList();
    
    int matchedTitleTerms = 0;
    for (final term in titleTerms) {
      if (queryTerms.contains(term)) {
        matchedTitleTerms++;
      }
    }
    
    if (titleTerms.isNotEmpty) {
      titleScore = matchedTitleTerms / titleTerms.length;
      Logger.debug('Title term match: $matchedTitleTerms/${titleTerms.length} = $titleScore');
    }
    
    // Author matching
    for (final author in metadata.authors) {
      final authorLower = author.toLowerCase();
      final authorTerms = authorLower.split(' ').where((term) => term.length > 2).toList();
      
      int matchedAuthorTerms = 0;
      for (final term in authorTerms) {
        if (queryTerms.contains(term)) {
          matchedAuthorTerms++;
        }
      }
      
      if (authorTerms.isNotEmpty) {
        double score = matchedAuthorTerms / authorTerms.length;
        Logger.debug('Author term match: $matchedAuthorTerms/${authorTerms.length} = $score');
        
        if (score > authorScore) {
          authorScore = score;
        }
      }
    }
    
    // Combine scores with weighting (70% title, 30% author)
    double finalScore = (titleScore * 0.7) + (authorScore * 0.3);
    
    // Bonus for having both good title and author matches
    if (titleScore > 0.5 && authorScore > 0.5) {
      finalScore += 0.1;
      Logger.debug('High title & author bonus: +0.1');
    }
    
    return finalScore;
  }
  
  /// Update metadata for a file (public method)
  Future<bool> updateMetadataForFile(AudiobookFile file, AudiobookMetadata metadata) async {
    try {
      final success = await storageManager.updateMetadataForFile(file.path, metadata, force: true);
      if (success) {
        file.metadata = metadata;
        Logger.log('Updated file metadata object for: ${file.filename}');
        return true;
      }
      return false;
    } catch (e) {
      Logger.error('Error updating metadata for file', e);
      return false;
    }
  }
  
  /// Update cover image for a file (public method)
  Future<bool> updateCoverImage(AudiobookFile file, String coverSource) async {
    try {
      if (file.metadata == null) return false;
      
      String? localPath;
      if (coverSource.startsWith('http://') || coverSource.startsWith('https://')) {
        // Download from URL
        localPath = await _coverArtManager.updateCover(file.path, downloadUrl: coverSource);
      } else {
        // Set from local file
        localPath = await _coverArtManager.updateCover(file.path, localImagePath: coverSource);
      }
      
      if (localPath == null) return false;
      
      // Update metadata with new cover path
      final updatedMetadata = file.metadata!.copyWith(thumbnailUrl: localPath);
      return await updateMetadataForFile(file, updatedMetadata);
    } catch (e) {
      Logger.error('Error updating cover image', e);
      return false;
    }
  }
}