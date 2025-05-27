// lib/ui/widgets/detail/audiobook_actions_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/ui/screens/player_screen.dart';
import 'package:audiobook_organizer/ui/widgets/add_to_collection_dialog.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_actions.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class AudiobookActionsSection extends StatelessWidget {
  final AudiobookFile book;
  final LibraryManager libraryManager;
  final VoidCallback onRefreshBook;
  final ValueChanged<bool> onUpdateMetadataStatus;
  final bool isUpdatingMetadata;

  const AudiobookActionsSection({
    Key? key,
    required this.book,
    required this.libraryManager,
    required this.onRefreshBook,
    required this.onUpdateMetadataStatus,
    this.isUpdatingMetadata = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Primary action - Play button
        _buildPlayButton(context),
        
        const SizedBox(height: 16),
        
        // Secondary actions in a grid
        _buildSecondaryActionsRow(context),
        
        const SizedBox(height: 12),
        
        // Metadata actions
        _buildMetadataActionsColumn(context),
        
        // Debug button (only show in debug mode)
        if (kDebugMode) ...[
          const SizedBox(height: 12),
          _buildDebugButton(context),
        ],
      ],
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _playAudiobook(context),
        icon: const Icon(Icons.play_arrow, size: 24),
        label: const Text(
          'Play',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildSecondaryActionsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildSecondaryButton(
            context,
            onPressed: () => _addToCollections(context),
            icon: Icons.add,
            label: 'Add to Collection',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSecondaryButton(
            context,
            onPressed: () => _toggleFavorite(context),
            icon: book.metadata?.isFavorite ?? false 
                ? Icons.favorite 
                : Icons.favorite_border,
            label: book.metadata?.isFavorite ?? false 
                ? 'Favorited' 
                : 'Favorite',
            iconColor: book.metadata?.isFavorite ?? false 
                ? Colors.red 
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataActionsColumn(BuildContext context) {
    return Column(
      children: [
        // Search Online Metadata button
        SizedBox(
          width: double.infinity,
          child: _buildSecondaryButton(
            context,
            onPressed: isUpdatingMetadata ? null : () => _searchOnlineMetadata(context),
            icon: Icons.search,
            label: 'Search Online Metadata',
            isLoading: isUpdatingMetadata,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Save to File button
        SizedBox(
          width: double.infinity,
          child: _buildSecondaryButton(
            context,
            onPressed: isUpdatingMetadata ? null : () => _saveMetadataToFile(context),
            icon: Icons.save_alt,
            label: 'Save Metadata to File',
            isLoading: isUpdatingMetadata,
          ),
        ),
      ],
    );
  }

  Widget _buildDebugButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: _buildSecondaryButton(
        context,
        onPressed: () => _showDebugInfo(context),
        icon: Icons.bug_report,
        label: 'Debug File Info',
        iconColor: Colors.orange,
      ),
    );
  }

  Widget _buildSecondaryButton(
    BuildContext context, {
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Color? iconColor,
    bool isLoading = false,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: isLoading 
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
              ),
            )
          : Icon(icon, color: iconColor),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: onPressed != null ? Colors.white : Colors.grey[600],
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        foregroundColor: onPressed != null ? Colors.white : Colors.grey[600],
        side: BorderSide(
          color: onPressed != null ? Colors.grey[700]! : Colors.grey[800]!,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Action methods
  Future<void> _playAudiobook(BuildContext context) async {
    try {
      final playerService = Provider.of<AudioPlayerService>(context, listen: false);
      final success = await playerService.play(book);
      
      if (success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlayerScreen(file: book),
          ),
        );
      } else {
        _showSnackBar(context, 'Failed to play audiobook', Colors.red);
      }
    } catch (e) {
      Logger.error('Error playing audiobook: $e');
      _showSnackBar(context, 'Error playing audiobook: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    try {
      final success = await libraryManager.updateUserData(
        book,
        isFavorite: !(book.metadata?.isFavorite ?? false),
      );
      
      if (success) {
        onRefreshBook();
        final isFavorite = book.metadata?.isFavorite ?? false;
        _showSnackBar(
          context,
          isFavorite ? 'Added to favorites' : 'Removed from favorites',
          Colors.green,
        );
      } else {
        _showSnackBar(context, 'Failed to update favorite status', Colors.red);
      }
    } catch (e) {
      Logger.error('Error toggling favorite: $e');
      _showSnackBar(context, 'Error updating favorite: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _addToCollections(BuildContext context) async {
    final collectionManager = libraryManager.collectionManager;
    if (collectionManager == null) {
      _showSnackBar(context, 'Collections not available', Colors.orange);
      return;
    }
    
    final currentCollections = collectionManager.getCollectionsForBook(book.path);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddToCollectionDialog(
        collectionManager: collectionManager,
        bookPath: book.path,
        currentCollections: currentCollections,
      ),
    );
    
    if (result == true) {
      onRefreshBook();
      _showSnackBar(context, 'Collections updated', Colors.green);
    }
  }

  Future<void> _searchOnlineMetadata(BuildContext context) async {
    final actions = DetailActions(
      libraryManager: libraryManager,
      onRefreshBook: onRefreshBook,
      onUpdateMetadataStatus: onUpdateMetadataStatus,
    );
    
    await actions.searchOnlineMetadata(context, book);
  }

  Future<void> _saveMetadataToFile(BuildContext context) async {
    final actions = DetailActions(
      libraryManager: libraryManager,
      onRefreshBook: onRefreshBook,
      onUpdateMetadataStatus: onUpdateMetadataStatus,
    );
    
    await actions.saveMetadataToFile(context, book);
  }

  Future<void> _refreshMetadata(BuildContext context) async {
    onUpdateMetadataStatus(true);
    
    try {
      Logger.log('Refreshing metadata for: ${book.filename}');
      
      // Force refresh metadata from file
      final success = await book.refreshMetadata(forceRefresh: true);
      
      if (success) {
        onRefreshBook();
        _showSnackBar(context, 'Metadata refreshed successfully', Colors.green);
      } else {
        _showSnackBar(context, 'Failed to refresh metadata', Colors.orange);
      }
    } catch (e) {
      Logger.error('Error refreshing metadata: $e');
      _showSnackBar(context, 'Error refreshing metadata: ${e.toString()}', Colors.red);
    } finally {
      onUpdateMetadataStatus(false);
    }
  }

  Future<void> _showDebugInfo(BuildContext context) async {
    try {
      // Get detailed information about this file
      final detailedInfo = await book.extractDetailedInfoFromFile();
      
      // Get library statistics
      final stats = await libraryManager.getMetadataStatistics();
      
      // Create comprehensive debug information
      final debugInfo = '''
📁 FILE INFORMATION:
${_formatMapForDisplay(detailedInfo['file_info'] as Map<String, dynamic>)}

🔍 RAW METADATA_GOD INFO:
${_formatMapForDisplay(detailedInfo['raw_metadata_god_info'] as Map<String, dynamic>)}

📊 LIBRARY STATISTICS:
${_formatMapForDisplay(stats)}

🏥 HEALTH CHECK:
  • Needs Repair: ${book.needsMetadataRepair ? 'YES' : 'NO'}
  • Completion: ${book.metadata?.completionPercentage.toStringAsFixed(1) ?? '0'}%
  • Has Duration: ${book.hasDuration ? 'YES' : 'NO'}
  • Has Complete Metadata: ${book.hasCompleteMetadata ? 'YES' : 'NO'}
  • Metadata Provider: ${book.metadata?.provider ?? 'None'}

🎵 AUDIO INFORMATION:
  • Duration: ${book.metadata?.durationFormatted ?? 'Unknown'}
  • File Format: ${book.metadata?.fileFormat ?? book.extension.toUpperCase()}
  • File Size: ${book.formattedFileSize}

📚 CONTENT INFORMATION:
  • Title: ${book.metadata?.title ?? 'None'}
  • Authors: ${book.metadata?.authorsFormatted ?? 'None'}
  • Series: ${book.metadata?.series ?? 'None'}
  • Position: ${book.metadata?.seriesPosition ?? 'None'}
  • Genres: ${book.metadata?.categories.join(', ') ?? 'None'}
  • Publisher: ${book.metadata?.publisher ?? 'None'}
  • Published: ${book.metadata?.publishedDate ?? 'None'}
  • Description Length: ${book.metadata?.description.length ?? 0} chars

⭐ USER DATA:
  • Rating: ${book.metadata?.userRating ?? 0}/5
  • Favorite: ${book.metadata?.isFavorite ?? false ? 'YES' : 'NO'}
  • Tags: ${book.metadata?.userTags.join(', ') ?? 'None'}
  • Bookmarks: ${book.metadata?.bookmarks.length ?? 0}
  • Notes: ${book.metadata?.notes.length ?? 0}
  • Last Played: ${book.metadata?.lastPlayedPosition?.toIso8601String() ?? 'Never'}
  • Playback Position: ${book.metadata?.playbackPosition?.inSeconds ?? 0}s
      ''';
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text('Debug Info: ${book.filename}')),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: SingleChildScrollView(
                child: SelectableText(
                  debugInfo,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Logger.log('Debug Info for ${book.filename}:\n$debugInfo');
                  Navigator.of(context).pop();
                  _showSnackBar(context, 'Debug info logged to console', Colors.blue);
                },
                child: const Text('Log to Console'),
              ),
              TextButton(
                onPressed: () {
                  // Export debug info functionality could be added here
                  Navigator.of(context).pop();
                  _showSnackBar(context, 'Debug export not implemented yet', Colors.orange);
                },
                child: const Text('Export'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Logger.error('Error getting debug info: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Error getting debug info: ${e.toString()}', Colors.red);
      }
    }
  }

  String _formatMapForDisplay(Map<String, dynamic> map) {
    return map.entries
        .map((entry) => '  ${entry.key}: ${entry.value}')
        .join('\n');
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}