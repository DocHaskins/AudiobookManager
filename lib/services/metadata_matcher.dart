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
  final double matchThreshold = 0.15; // Was 0.5 before, which was too high
  
  MetadataMatcher({
    required this.providers, 
    required this.cache
  });
  
  // Update the matchFile method to use file metadata as primary source
  Future<AudiobookMetadata?> matchFile(AudiobookFile file) async {
    // Step 1: Check if we have cached metadata for this file
    final cachedMetadata = await cache.getMetadataForFile(file.path);
    if (cachedMetadata != null) {
      print('LOG: Found cached metadata for ${file.filename}');
      file.metadata = cachedMetadata;
      return cachedMetadata;
    }
    
    // Step 2: Try to extract metadata directly from the file itself
    final fileMetadata = await file.extractFileMetadata();
    
    if (fileMetadata != null) {
      print('LOG: Found metadata in the file itself for: ${file.filename}');
      
      // Save this metadata to the cache
      await cache.saveMetadataForFile(file.path, fileMetadata);
      
      // If the extracted metadata has comprehensive info, use it directly
      if (_isComprehensiveMetadata(fileMetadata)) {
        print('LOG: File metadata is comprehensive, using it directly');
        file.metadata = fileMetadata;
        return fileMetadata;
      }
      
      // If file metadata exists but is incomplete, use it to create a better search query
      String searchQuery = _createSearchQueryFromMetadata(fileMetadata);
      
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
        for (final provider in providers) {
          try {
            print('LOG: Trying provider: ${provider.runtimeType} with metadata-based query');
            final results = await provider.search(searchQuery);
            
            if (results.isNotEmpty) {
              print('LOG: Found ${results.length} results using metadata-based query');
              
              // Find the best match
              AudiobookMetadata? bestMatch = _findBestMatch(results, searchQuery);
              if (bestMatch != null) {
                // Merge with the file metadata to get the best of both worlds
                final mergedMetadata = _mergeMetadata(fileMetadata, bestMatch);
                
                // Cache the result
                await cache.saveMetadata(searchQuery, mergedMetadata);
                await cache.saveMetadataForFile(file.path, mergedMetadata);
                file.metadata = mergedMetadata;
                return mergedMetadata;
              }
            }
          } catch (e) {
            print('ERROR: Error matching with provider ${provider.runtimeType}: $e');
          }
        }
      }
    }
    
    // Step 3: If no file metadata or no match was found using file metadata,
    // fall back to the original folder and filename-based approach
    
    // Try with folder name first if file is in a dedicated folder
    final folderName = _extractFolderName(file.path);
    String searchQuery = folderName.isNotEmpty ? folderName : file.generateSearchQuery();
    
    if (searchQuery.isEmpty) {
      print('LOG: Empty search query for file: ${file.path}');
      return null;
    }
    
    print('LOG: Searching for metadata with query: "$searchQuery" for file: ${file.filename}');
    print('LOG: Using folder name: ${folderName.isNotEmpty ? "Yes - $folderName" : "No"}');
    
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
    
    // Try each provider in order
    for (final provider in providers) {
      try {
        print('LOG: Trying provider: ${provider.runtimeType}');
        final results = await provider.search(searchQuery);
        
        if (results.isEmpty) {
          print('LOG: No results from ${provider.runtimeType} for query: "$searchQuery"');
          
          // If we used folder name first and got no results, try with filename instead
          if (folderName.isNotEmpty && folderName != file.generateSearchQuery()) {
            final filenameQuery = file.generateSearchQuery();
            print('LOG: Trying alternate query with filename: "$filenameQuery"');
            final altResults = await provider.search(filenameQuery);
            if (altResults.isNotEmpty) {
              print('LOG: Found ${altResults.length} results with alternate query');
              // Process these alternate results
              final altMatch = _findBestMatch(altResults, filenameQuery);
              if (altMatch != null) {
                // If we have file metadata, merge it with the online metadata
                if (fileMetadata != null) {
                  final mergedMetadata = _mergeMetadata(fileMetadata, altMatch);
                  
                  // Cache the result
                  await cache.saveMetadata(filenameQuery, mergedMetadata);
                  await cache.saveMetadataForFile(file.path, mergedMetadata);
                  file.metadata = mergedMetadata;
                  return mergedMetadata;
                }
                
                // Cache the result
                await cache.saveMetadata(filenameQuery, altMatch);
                await cache.saveMetadataForFile(file.path, altMatch);
                file.metadata = altMatch;
                return altMatch;
              }
            } else {
              print('LOG: No results from ${provider.runtimeType} for alternate query either');
            }
          }
          
          continue;
        }
        
        print('LOG: Found ${results.length} results from ${provider.runtimeType}');
        
        // Find the best match
        AudiobookMetadata? bestMatch = _findBestMatch(results, searchQuery);
        if (bestMatch != null) {
          // If we have file metadata, merge it with the online metadata
          if (fileMetadata != null) {
            final mergedMetadata = _mergeMetadata(fileMetadata, bestMatch);
            
            // Cache the result
            await cache.saveMetadata(searchQuery, mergedMetadata);
            await cache.saveMetadataForFile(file.path, mergedMetadata);
            file.metadata = mergedMetadata;
            return mergedMetadata;
          }
          
          // Cache the result
          await cache.saveMetadata(searchQuery, bestMatch);
          await cache.saveMetadataForFile(file.path, bestMatch);
          file.metadata = bestMatch;
          return bestMatch;
        }
      } catch (e) {
        print('ERROR: Error matching with provider ${provider.runtimeType}: $e');
      }
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
      averageRating: onlineMetadata.averageRating > 0 ? onlineMetadata.averageRating : 0.0,
      ratingsCount: onlineMetadata.ratingsCount > 0 ? onlineMetadata.ratingsCount : 0,
      thumbnailUrl: onlineMetadata.thumbnailUrl.isNotEmpty ? onlineMetadata.thumbnailUrl : fileMetadata.thumbnailUrl,
      language: onlineMetadata.language.isNotEmpty ? onlineMetadata.language : fileMetadata.language,
      series: onlineMetadata.series.isNotEmpty ? onlineMetadata.series : fileMetadata.series,
      seriesPosition: onlineMetadata.seriesPosition.isNotEmpty ? onlineMetadata.seriesPosition : fileMetadata.seriesPosition,
      provider: onlineMetadata.provider.isNotEmpty ? onlineMetadata.provider : fileMetadata.provider,
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
  
  // Extract a meaningful folder name from the file path
  String _extractFolderName(String filePath) {
    try {
      final folderPath = path_util.dirname(filePath);
      final folders = folderPath.split(path_util.separator);
      
      // If we're in a subfolder at least 2 levels deep, use the immediate parent folder
      if (folders.length > 1) {
        // Clean the folder name of common patterns we don't want
        final folderName = folders.last;
        
        // Skip generic folder names
        if (['audio', 'audiobook', 'cd', 'mp3', 'disk', 'disc'].contains(folderName.toLowerCase())) {
          // Try the parent folder instead if the immediate folder is generic
          if (folders.length > 2) {
            return cleanFolderName(folders[folders.length - 2]);
          }
          return '';
        }
        
        return cleanFolderName(folderName);
      }
    } catch (e) {
      print('LOG: Error extracting folder name: $e');
    }
    return '';
  }
  
  // Clean a folder name for better searching
  String cleanFolderName(String folderName) {
    // For folder names like "Book 1 - Series Name", extract "Series Name"
    String cleaned = folderName
      .replaceAll(RegExp(r'^(?:Book|Volume|Vol|Part)\s*\d+\s*[\-\:]\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'^(?:\d+|\!)[\s\-\_]*'), '') // Remove numbers and exclamation points at start
      .replaceAll(RegExp(r'(?:Audiobook|Unabridged|Complete|Series|Collection)$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[({\[\]})]\s*\d*\s*$'), ''); // Remove any trailing brackets with numbers
      
    // Clean the filename for better searching
    cleaned = cleaned
      .replaceAll(RegExp(r'\bAudiobook\b|\bUnabridged\b'), '')
      .replaceAll(RegExp(r'[_\.\-\(\)\[\]]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
    
    return cleaned;
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