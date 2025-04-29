// File: lib/services/metadata_matcher.dart
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/metadata_manager.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:path/path.dart' as path_util;

/// Service for matching audiobook files with metadata from various sources
class MetadataMatcher {
  /// List of metadata providers to search with
  final List<MetadataProvider> providers;
  
  /// Cache for storing and retrieving metadata
  final MetadataCache cache;
  
  /// Threshold for accepting a match (lowered for better recall)
  final double matchThreshold = 0.15;
  
  /// Weights for different match components
  static const double _titleWeight = 0.6;
  static const double _authorWeight = 0.3;
  static const double _seriesWeight = 0.1;
  
  /// Constructor
  MetadataMatcher({
    required this.providers, 
    required this.cache
  }) {
    Logger.log('MetadataMatcher initialized with ${providers.length} providers');
  }
  
  /// Match a file with metadata - prioritizing embedded file metadata
  Future<AudiobookMetadata?> matchFile(AudiobookFile file) async {
    try {
      // Step 1: Always try to extract metadata from the file first
      final fileMetadata = await file.extractFileMetadata();
      
      // Step 2: If file metadata is comprehensive, use it directly
      if (fileMetadata != null && MetadataManager.isMetadataComplete(fileMetadata)) {
        Logger.log('Using comprehensive file metadata for: ${file.filename}');
        
        // Save to cache for future use
        await cache.saveMetadataForFile(file.path, fileMetadata);
        file.metadata = fileMetadata;
        return fileMetadata;
      }
      
      // Step 3: Check cache for this specific file
      final cachedMetadata = await cache.getMetadataForFile(file.path);
      if (cachedMetadata != null) {
        Logger.log('Found cached metadata for ${file.filename}');
        file.metadata = cachedMetadata;
        return cachedMetadata;
      }
      
      // Step 4: If we have partial file metadata, use it to create a better search query
      if (fileMetadata != null) {
        final searchQuery = _createSearchQueryFromMetadata(fileMetadata);
        
        if (searchQuery.isNotEmpty) {
          Logger.log('Using file metadata to create search query: "$searchQuery"');
          
          // Check if we have cached results for this query
          final cachedQueryResult = await cache.getMetadata(searchQuery);
          if (cachedQueryResult != null) {
            Logger.log('Found cached query result for "$searchQuery"');
            
            // Merge with file metadata to get the best of both worlds
            final mergedMetadata = MetadataManager.mergeMetadata(fileMetadata, cachedQueryResult);
            
            // Save this metadata specifically for this file path too
            await cache.saveMetadataForFile(file.path, mergedMetadata);
            file.metadata = mergedMetadata;
            return mergedMetadata;
          }
          
          // Use the enhanced search query to find online metadata
          AudiobookMetadata? onlineMetadata = await _searchOnlineProviders(searchQuery);
          
          if (onlineMetadata != null) {
            // Merge with the file metadata to get the best of both worlds
            final mergedMetadata = MetadataManager.mergeMetadata(fileMetadata, onlineMetadata);
            
            // Cache the result
            await cache.saveMetadata(searchQuery, mergedMetadata);
            await cache.saveMetadataForFile(file.path, mergedMetadata);
            file.metadata = mergedMetadata;
            return mergedMetadata;
          }
        }
      }
      
      // Step 5: Fall back to folder/filename-based searching if no file metadata available
      // or if file metadata search was unsuccessful
      final searchQuery = file.generateSearchQuery();
      
      if (searchQuery.isEmpty) {
        Logger.warning('Empty search query for file: ${file.path}');
        
        // If we at least have file metadata (even if incomplete), use that
        if (fileMetadata != null) {
          file.metadata = fileMetadata;
          return fileMetadata;
        }
        
        return null;
      }
      
      Logger.log('Searching for metadata with query: "$searchQuery" for file: ${file.filename}');
      
      // Check if we have cached results for this query
      final cachedQueryResult = await cache.getMetadata(searchQuery);
      if (cachedQueryResult != null) {
        Logger.log('Found cached query result for "$searchQuery"');
        
        // Save this metadata specifically for this file path too
        await cache.saveMetadataForFile(file.path, cachedQueryResult);
        
        // If we have file metadata, merge it with the cached query result
        if (fileMetadata != null) {
          final mergedMetadata = MetadataManager.mergeMetadata(fileMetadata, cachedQueryResult);
          file.metadata = mergedMetadata;
          return mergedMetadata;
        }
        
        file.metadata = cachedQueryResult;
        return cachedQueryResult;
      }
      
      // Try to find online metadata
      AudiobookMetadata? onlineMetadata = await _searchOnlineProviders(searchQuery);
      
      if (onlineMetadata != null) {
        // If we have file metadata, merge it with the online metadata
        if (fileMetadata != null) {
          final mergedMetadata = MetadataManager.mergeMetadata(fileMetadata, onlineMetadata);
          
          // Cache the result
          await cache.saveMetadata(searchQuery, mergedMetadata);
          await cache.saveMetadataForFile(file.path, mergedMetadata);
          file.metadata = mergedMetadata;
          return mergedMetadata;
        }
        
        // Cache the result
        await cache.saveMetadata(searchQuery, onlineMetadata);
        await cache.saveMetadataForFile(file.path, onlineMetadata);
        file.metadata = onlineMetadata;
        return onlineMetadata;
      }
      
      Logger.warning('No suitable metadata match found for file: ${file.filename}');
      
      // If we at least have file metadata, use that rather than returning null
      if (fileMetadata != null) {
        Logger.log('Using file metadata as fallback since no online match was found');
        file.metadata = fileMetadata;
        return fileMetadata;
      }
      
      return null;
    } catch (e) {
      Logger.error('Error matching metadata for file: ${file.path}', e);
      return null;
    }
  }
  
  /// Search all online providers with a query
  Future<AudiobookMetadata?> _searchOnlineProviders(String searchQuery) async {
    for (final provider in providers) {
      try {
        Logger.debug('Trying provider: ${provider.runtimeType}');
        final results = await provider.search(searchQuery);
        
        if (results.isEmpty) {
          Logger.debug('No results from ${provider.runtimeType} for query: "$searchQuery"');
          continue;
        }
        
        Logger.log('Found ${results.length} results from ${provider.runtimeType}');
        
        // Find the best match
        AudiobookMetadata? bestMatch = _findBestMatch(results, searchQuery);
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
    List<String> queryParts = [];
    
    if (metadata.title.isNotEmpty) {
      queryParts.add(metadata.title);
    }
    
    if (metadata.authors.isNotEmpty) {
      // Only add the first author to keep the query focused
      queryParts.add(metadata.authors.first);
    }
    
    if (metadata.series.isNotEmpty) {
      queryParts.add(metadata.series);
    }
    
    return queryParts.join(' ');
  }
  
  /// Helper method to find the best match from a list of results
  AudiobookMetadata? _findBestMatch(List<AudiobookMetadata> results, String searchQuery) {
    double bestScore = 0;
    AudiobookMetadata? bestMatch;
    
    // Log all results for debugging
    for (int i = 0; i < results.length; i++) {
      final metadata = results[i];
      final score = calculateMatchScore(searchQuery, metadata);
      
      Logger.debug('Result #${i+1} - Title: "${metadata.title}", Author: "${metadata.authorsFormatted}", Score: $score');
      
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
  
  /// Calculate a match score between a search query and metadata
  double calculateMatchScore(String searchQuery, AudiobookMetadata metadata) {
    final fuzzy = Fuzzy([metadata.title], options: FuzzyOptions(
      threshold: 0.2,
      keys: [],
    ));
    
    final titleResults = fuzzy.search(searchQuery);
    double titleScore = titleResults.isEmpty ? 0 : titleResults.first.score;
    
    // Consider author match if available
    double authorScore = 0;
    if (metadata.authors.isNotEmpty) {
      final authorFuzzy = Fuzzy(metadata.authors);
      final authorResults = authorFuzzy.search(searchQuery);
      authorScore = authorResults.isEmpty ? 0 : authorResults.first.score;
    }
    
    // Consider series match if available
    double seriesScore = 0;
    if (metadata.series.isNotEmpty) {
      final seriesFuzzy = Fuzzy([metadata.series]);
      final seriesResults = seriesFuzzy.search(searchQuery);
      seriesScore = seriesResults.isEmpty ? 0 : seriesResults.first.score;
    }
    
    // Weighted score (title is most important, then author, then series)
    return (titleScore * _titleWeight) + (authorScore * _authorWeight) + (seriesScore * _seriesWeight);
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
}