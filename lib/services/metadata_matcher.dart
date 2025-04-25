// File: lib/services/metadata_matcher.dart
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:path/path.dart' as path_util;

class MetadataMatcher {
  final List<MetadataProvider> providers;
  final MetadataCache cache;
  
  // Lowered threshold for match acceptance
  final double matchThreshold = 0.15;
  
  MetadataMatcher({
    required this.providers, 
    required this.cache
  });
  
  // Match a file with metadata - prioritizing embedded file metadata
  Future<AudiobookMetadata?> matchFile(AudiobookFile file) async {
    // Step 1: Always try to extract metadata from the file first
    final fileMetadata = await file.extractFileMetadata();
    
    // Step 2: If file metadata is comprehensive, use it directly
    if (fileMetadata != null && _isComprehensiveMetadata(fileMetadata)) {
      print('LOG: Using comprehensive file metadata for: ${file.filename}');
      
      // Save to cache for future use
      await cache.saveMetadataForFile(file.path, fileMetadata);
      file.metadata = fileMetadata;
      return fileMetadata;
    }
    
    // Step 3: Check cache for this specific file
    final cachedMetadata = await cache.getMetadataForFile(file.path);
    if (cachedMetadata != null) {
      print('LOG: Found cached metadata for ${file.filename}');
      file.metadata = cachedMetadata;
      return cachedMetadata;
    }
    
    // Step 4: If we have partial file metadata, use it to create a better search query
    String searchQuery = '';
    if (fileMetadata != null) {
      searchQuery = _createSearchQueryFromMetadata(fileMetadata);
      
      if (searchQuery.isNotEmpty) {
        print('LOG: Using file metadata to create search query: "$searchQuery"');
        
        // Check if we have cached results for this query
        final cachedQueryResult = await cache.getMetadata(searchQuery);
        if (cachedQueryResult != null) {
          print('LOG: Found cached query result for "$searchQuery"');
          
          // Merge with file metadata to get the best of both worlds
          final mergedMetadata = _mergeMetadata(fileMetadata, cachedQueryResult);
          
          // Save this metadata specifically for this file path too
          await cache.saveMetadataForFile(file.path, mergedMetadata);
          file.metadata = mergedMetadata;
          return mergedMetadata;
        }
        
        // Use the enhanced search query to find online metadata
        AudiobookMetadata? onlineMetadata = await _searchOnlineProviders(searchQuery);
        
        if (onlineMetadata != null) {
          // Merge with the file metadata to get the best of both worlds
          final mergedMetadata = _mergeMetadata(fileMetadata, onlineMetadata);
          
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
    searchQuery = file.generateSearchQuery();
    
    if (searchQuery.isEmpty) {
      print('LOG: Empty search query for file: ${file.path}');
      
      // If we at least have file metadata (even if incomplete), use that
      if (fileMetadata != null) {
        file.metadata = fileMetadata;
        return fileMetadata;
      }
      
      return null;
    }
    
    print('LOG: Searching for metadata with query: "$searchQuery" for file: ${file.filename}');
    
    // Check if we have cached results for this query
    final cachedQueryResult = await cache.getMetadata(searchQuery);
    if (cachedQueryResult != null) {
      print('LOG: Found cached query result for "$searchQuery"');
      
      // Save this metadata specifically for this file path too
      await cache.saveMetadataForFile(file.path, cachedQueryResult);
      
      // If we have file metadata, merge it with the cached query result
      if (fileMetadata != null) {
        final mergedMetadata = _mergeMetadata(fileMetadata, cachedQueryResult);
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
        final mergedMetadata = _mergeMetadata(fileMetadata, onlineMetadata);
        
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
    
    print('LOG: No suitable metadata match found for file: ${file.filename}');
    
    // If we at least have file metadata, use that rather than returning null
    if (fileMetadata != null) {
      print('LOG: Using file metadata as fallback since no online match was found');
      file.metadata = fileMetadata;
      return fileMetadata;
    }
    
    return null;
  }
  
  // Search all online providers with a query
  Future<AudiobookMetadata?> _searchOnlineProviders(String searchQuery) async {
    for (final provider in providers) {
      try {
        print('LOG: Trying provider: ${provider.runtimeType}');
        final results = await provider.search(searchQuery);
        
        if (results.isEmpty) {
          print('LOG: No results from ${provider.runtimeType} for query: "$searchQuery"');
          continue;
        }
        
        print('LOG: Found ${results.length} results from ${provider.runtimeType}');
        
        // Find the best match
        AudiobookMetadata? bestMatch = _findBestMatch(results, searchQuery);
        if (bestMatch != null) {
          return bestMatch;
        }
      } catch (e) {
        print('ERROR: Error matching with provider ${provider.runtimeType}: $e');
      }
    }
    
    return null;
  }
  
  // Helper method to check if metadata is comprehensive enough to use directly
  bool _isComprehensiveMetadata(AudiobookMetadata metadata) {
    // Consider metadata comprehensive if it has title, author, and some additional info
    bool hasTitle = metadata.title.isNotEmpty;
    bool hasAuthor = metadata.authors.isNotEmpty;
    bool hasAdditionalInfo = metadata.series.isNotEmpty || 
                           metadata.publishedDate.isNotEmpty || 
                           metadata.description.isNotEmpty;
    
    return hasTitle && hasAuthor && hasAdditionalInfo;
  }
  
  // Helper method to create a search query from file metadata
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
  
  // Helper method to merge file metadata with online metadata
  AudiobookMetadata _mergeMetadata(AudiobookMetadata fileMetadata, AudiobookMetadata onlineMetadata) {
    // Create a new merged metadata object that prioritizes online data 
    // but keeps file data when online is missing or empty
    return AudiobookMetadata(
      id: onlineMetadata.id.isNotEmpty ? onlineMetadata.id : fileMetadata.id,
      title: onlineMetadata.title.isNotEmpty ? onlineMetadata.title : fileMetadata.title,
      authors: onlineMetadata.authors.isNotEmpty ? onlineMetadata.authors : fileMetadata.authors,
      description: onlineMetadata.description.isNotEmpty ? onlineMetadata.description : fileMetadata.description,
      publisher: onlineMetadata.publisher.isNotEmpty ? onlineMetadata.publisher : fileMetadata.publisher,
      publishedDate: onlineMetadata.publishedDate.isNotEmpty ? onlineMetadata.publishedDate : fileMetadata.publishedDate,
      categories: onlineMetadata.categories.isNotEmpty ? onlineMetadata.categories : fileMetadata.categories,
      averageRating: onlineMetadata.averageRating > 0 ? onlineMetadata.averageRating : fileMetadata.averageRating,
      ratingsCount: onlineMetadata.ratingsCount > 0 ? onlineMetadata.ratingsCount : fileMetadata.ratingsCount,
      thumbnailUrl: onlineMetadata.thumbnailUrl.isNotEmpty ? onlineMetadata.thumbnailUrl : fileMetadata.thumbnailUrl,
      language: onlineMetadata.language.isNotEmpty ? onlineMetadata.language : fileMetadata.language,
      series: onlineMetadata.series.isNotEmpty ? onlineMetadata.series : fileMetadata.series,
      seriesPosition: onlineMetadata.seriesPosition.isNotEmpty ? onlineMetadata.seriesPosition : fileMetadata.seriesPosition,
      provider: 'Combined (${onlineMetadata.provider} + File Metadata)',
    );
  }
  
  // Helper method to find the best match from a list of results
  AudiobookMetadata? _findBestMatch(List<AudiobookMetadata> results, String searchQuery) {
    double bestScore = 0;
    AudiobookMetadata? bestMatch;
    
    // Log all results for debugging
    for (int i = 0; i < results.length; i++) {
      final metadata = results[i];
      final score = calculateMatchScore(searchQuery, metadata);
      
      print('LOG: Result #${i+1} - Title: "${metadata.title}", Author: "${metadata.authorsFormatted}", Score: $score');
      
      if (score > bestScore) {
        bestScore = score;
        bestMatch = metadata;
      }
    }
    
    // Return if we found a decent match
    if (bestScore >= matchThreshold && bestMatch != null) {
      print('LOG: Found best match - Title: "${bestMatch.title}", Author: "${bestMatch.authorsFormatted}", Score: $bestScore');
      return bestMatch;
    } else if (bestMatch != null) {
      print('LOG: Best match score ($bestScore) too low for: "${bestMatch.title}" by ${bestMatch.authorsFormatted}');
    }
    
    return null;
  }
  
  // Calculate a match score between a search query and metadata
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
    return (titleScore * 0.6) + (authorScore * 0.3) + (seriesScore * 0.1);
  }
}