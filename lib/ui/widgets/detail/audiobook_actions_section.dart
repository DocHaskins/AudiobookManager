// lib/ui/widgets/detail/audiobook_actions_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/ui/screens/player_screen.dart';
import 'package:audiobook_organizer/ui/widgets/collections/add_to_collection_dialog.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_actions.dart';
import 'package:audiobook_organizer/ui/widgets/detail/detail_controllers_mixin.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class AudiobookActionsSection extends StatefulWidget {
  final AudiobookFile book;
  final LibraryManager libraryManager;
  final VoidCallback onRefreshBook;
  final ValueChanged<bool> onUpdateMetadataStatus;
  final Function(AudiobookFile)? onBookUpdated;
  final bool isUpdatingMetadata;
  final DetailControllersMixin? controllers;

  const AudiobookActionsSection({
    Key? key,
    required this.book,
    required this.libraryManager,
    required this.onRefreshBook,
    required this.onUpdateMetadataStatus,
    this.onBookUpdated,
    this.isUpdatingMetadata = false,
    this.controllers, // ADD THIS LINE
  }) : super(key: key);

  @override
  State<AudiobookActionsSection> createState() => _AudiobookActionsSectionState();
}

class _AudiobookActionsSectionState extends State<AudiobookActionsSection>
    with TickerProviderStateMixin {
  late AnimationController _favoriteController;
  late AnimationController _collectionController;
  late AnimationController _goodreadsController;
  late Animation<double> _favoriteScaleAnimation;
  late Animation<double> _collectionScaleAnimation;
  late Animation<double> _goodreadsScaleAnimation;
  late Animation<Color?> _favoriteColorAnimation;
  late Animation<Color?> _collectionColorAnimation;
  late Animation<Color?> _goodreadsColorAnimation;
  
  bool _isFavoriteAnimating = false;
  bool _isCollectionAnimating = false;
  bool _isGoodreadsAnimating = false;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    
    // Favorite animation controller
    _favoriteController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _favoriteScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _favoriteController,
      curve: Curves.elasticOut,
    ));
    _favoriteColorAnimation = ColorTween(
      begin: Colors.grey[600],
      end: Colors.red,
    ).animate(CurvedAnimation(
      parent: _favoriteController,
      curve: Curves.easeInOut,
    ));

    // Collection animation controller
    _collectionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _collectionScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _collectionController,
      curve: Curves.bounceOut,
    ));
    _collectionColorAnimation = ColorTween(
      begin: Colors.grey[600],
      end: Colors.blue,
    ).animate(CurvedAnimation(
      parent: _collectionController,
      curve: Curves.easeInOut,
    ));

    _goodreadsController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _goodreadsScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _goodreadsController,
      curve: Curves.easeInOut,
    ));
    _goodreadsColorAnimation = ColorTween(
      begin: Colors.grey[600],
      end: Colors.orange,
    ).animate(CurvedAnimation(
      parent: _goodreadsController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _favoriteController.dispose();
    _collectionController.dispose();
    _goodreadsController.dispose();
    super.dispose();
  }

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
        // Collection button with animation
        Expanded(
          child: AnimatedBuilder(
            animation: _collectionController,
            builder: (context, child) {
              return Transform.scale(
                scale: _collectionScaleAnimation.value,
                child: _buildSecondaryButton(
                  context,
                  onPressed: _isCollectionAnimating ? null : () => _addToCollections(context),
                  icon: Icons.add,
                  label: 'Add to Collection',
                  iconColor: _collectionColorAnimation.value,
                  isLoading: _isCollectionAnimating,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        // Favorite button with animation
        Expanded(
          child: AnimatedBuilder(
            animation: _favoriteController,
            builder: (context, child) {
              final isFavorite = widget.book.metadata?.isFavorite ?? false;
              return Transform.scale(
                scale: _favoriteScaleAnimation.value,
                child: _buildSecondaryButton(
                  context,
                  onPressed: _isFavoriteAnimating ? null : () => _toggleFavorite(context),
                  icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                  label: isFavorite ? 'Favorited' : 'Favorite',
                  iconColor: isFavorite ? Colors.red : _favoriteColorAnimation.value,
                  isLoading: _isFavoriteAnimating,
                ),
              );
            },
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
            onPressed: widget.isUpdatingMetadata ? null : () => _searchOnlineMetadata(context),
            icon: Icons.search,
            label: 'Search Online Metadata',
            isLoading: widget.isUpdatingMetadata,
          ),
        ),
        
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _goodreadsController,
            builder: (context, child) {
              return Transform.scale(
                scale: _goodreadsScaleAnimation.value,
                child: _buildSecondaryButton(
                  context,
                  onPressed: (widget.isUpdatingMetadata || _isGoodreadsAnimating) ? null : () => _browseGoodreads(context),
                  icon: Icons.menu_book,
                  label: 'Browse Goodreads',
                  iconColor: _goodreadsColorAnimation.value,
                  isLoading: _isGoodreadsAnimating,
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Save to File button
        SizedBox(
          width: double.infinity,
          child: _buildSecondaryButton(
            context,
            onPressed: widget.isUpdatingMetadata ? null : () => _saveMetadataToFile(context),
            icon: Icons.save_alt,
            label: 'Save Metadata to File',
            isLoading: widget.isUpdatingMetadata,
          ),
        ),
        
        // Convert to M4B button (only show for MP3 files)
        if (widget.book.extension.toLowerCase() == '.mp3') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _buildSecondaryButton(
              context,
              onPressed: (_isConverting || widget.isUpdatingMetadata) ? null : () => _convertToM4B(context),
              icon: Icons.transform,
              label: 'Convert to M4B (FFMPEG)',
              iconColor: Colors.purple,
              isLoading: _isConverting,
            ),
          ),
        ],
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

  // Enhanced action methods with animations
  Future<void> _playAudiobook(BuildContext context) async {
    try {
      final playerService = Provider.of<AudioPlayerService>(context, listen: false);
      final success = await playerService.play(widget.book);
      
      if (success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlayerScreen(file: widget.book),
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
    if (_isFavoriteAnimating) return;
    
    setState(() {
      _isFavoriteAnimating = true;
    });

    final wasFavorite = widget.book.metadata?.isFavorite ?? false;
    
    try {
      // Start animation immediately for visual feedback
      if (mounted) {
        _favoriteController.forward();
      }
      
      final success = await widget.libraryManager.updateUserData(
        widget.book,
        isFavorite: !wasFavorite,
      );
      
      if (success) {
        widget.onRefreshBook();
        
        // Show enhanced success message with animation
        final isFavorite = !wasFavorite;
        _showEnhancedSnackBar(
          context,
          message: isFavorite 
              ? 'Added "${widget.book.metadata?.title ?? widget.book.filename}" to favorites!' 
              : 'Removed "${widget.book.metadata?.title ?? widget.book.filename}" from favorites',
          color: isFavorite ? Colors.red : Colors.orange,
          icon: isFavorite ? Icons.favorite : Icons.favorite_border,
        );
        
        // Complete animation - only if widget is still mounted
        if (mounted) {
          try {
            await _favoriteController.forward();
            await Future.delayed(const Duration(milliseconds: 200));
            if (mounted) {
              await _favoriteController.reverse();
            }
          } catch (e) {
            // Animation controller was disposed, ignore
            Logger.debug('Animation controller disposed during favorite animation: $e');
          }
        }
      } else {
        if (mounted) {
          try {
            _favoriteController.reverse();
          } catch (e) {
            // Animation controller was disposed, ignore
            Logger.debug('Animation controller disposed during favorite reverse: $e');
          }
        }
        _showSnackBar(context, 'Failed to update favorite status', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        try {
          _favoriteController.reverse();
        } catch (e) {
          // Animation controller was disposed, ignore
          Logger.debug('Animation controller disposed during favorite error handling: $e');
        }
      }
      Logger.error('Error toggling favorite: $e');
      _showSnackBar(context, 'Error updating favorite: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isFavoriteAnimating = false;
        });
      }
    }
  }

  Future<void> _addToCollections(BuildContext context) async {
    if (_isCollectionAnimating) return;
    
    final collectionManager = widget.libraryManager.collectionManager;
    if (collectionManager == null) {
      _showSnackBar(context, 'Collections not available', Colors.orange);
      return;
    }
    
    setState(() {
      _isCollectionAnimating = true;
    });

    try {
      // Start animation for visual feedback
      if (mounted) {
        try {
          _collectionController.forward();
        } catch (e) {
          Logger.debug('Animation controller disposed during collection forward: $e');
        }
      }
      
      final currentCollections = collectionManager.getCollectionsForBook(widget.book.path);
      final initialCollectionCount = currentCollections.length;
      
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AddToCollectionDialog(
          collectionManager: collectionManager,
          bookPath: widget.book.path,
          currentCollections: currentCollections,
        ),
      );
      
      if (result == true) {
        widget.onRefreshBook();
        
        // Check new collection count for enhanced message
        final newCollections = collectionManager.getCollectionsForBook(widget.book.path);
        final newCollectionCount = newCollections.length;
        
        String message;
        if (newCollectionCount > initialCollectionCount) {
          final addedCount = newCollectionCount - initialCollectionCount;
          message = 'Added "${widget.book.metadata?.title ?? widget.book.filename}" to $addedCount collection${addedCount > 1 ? 's' : ''}!';
        } else if (newCollectionCount < initialCollectionCount) {
          final removedCount = initialCollectionCount - newCollectionCount;
          message = 'Removed "${widget.book.metadata?.title ?? widget.book.filename}" from $removedCount collection${removedCount > 1 ? 's' : ''}';
        } else {
          message = 'Collection membership updated';
        }
        
        _showEnhancedSnackBar(
          context,
          message: message,
          color: Colors.blue,
          icon: Icons.folder_special,
        );
        
        // Complete animation - only if widget is still mounted
        if (mounted) {
          try {
            await _collectionController.forward();
            await Future.delayed(const Duration(milliseconds: 200));
            if (mounted) {
              await _collectionController.reverse();
            }
          } catch (e) {
            Logger.debug('Animation controller disposed during collection animation: $e');
          }
        }
      } else {
        if (mounted) {
          try {
            _collectionController.reverse();
          } catch (e) {
            Logger.debug('Animation controller disposed during collection reverse: $e');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        try {
          _collectionController.reverse();
        } catch (e) {
          Logger.debug('Animation controller disposed during collection error handling: $e');
        }
      }
      Logger.error('Error managing collections: $e');
      _showSnackBar(context, 'Error managing collections: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isCollectionAnimating = false;
        });
      }
    }
  }

  Future<void> _searchOnlineMetadata(BuildContext context) async {
    final actions = DetailActions(
      libraryManager: widget.libraryManager,
      onRefreshBook: widget.onRefreshBook,
      onUpdateMetadataStatus: widget.onUpdateMetadataStatus,
      onBookUpdated: widget.onBookUpdated,
    );
    
    await actions.searchOnlineMetadata(context, widget.book);
  }

  Future<void> _saveMetadataToFile(BuildContext context) async {
    final actions = DetailActions(
      libraryManager: widget.libraryManager,
      onRefreshBook: widget.onRefreshBook,
      onUpdateMetadataStatus: widget.onUpdateMetadataStatus,
    );
    
    await actions.saveMetadataToFile(
      context, 
      widget.book,
      controllers: widget.controllers,
    );
  }

  Future<void> _browseGoodreads(BuildContext context) async {
    if (_isGoodreadsAnimating) return;
    
    setState(() {
      _isGoodreadsAnimating = true;
    });

    try {
      // Start animation for visual feedback
      if (mounted) {
        try {
          _goodreadsController.forward();
        } catch (e) {
          Logger.debug('Animation controller disposed during Goodreads forward: $e');
        }
      }

      final actions = DetailActions(
        libraryManager: widget.libraryManager,
        onRefreshBook: widget.onRefreshBook,
        onUpdateMetadataStatus: widget.onUpdateMetadataStatus,
        onBookUpdated: widget.onBookUpdated,
      );
      
      await actions.browseGoodreads(context, widget.book);

      // Complete animation - only if widget is still mounted
      if (mounted) {
        try {
          await _goodreadsController.forward();
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted) {
            await _goodreadsController.reverse();
          }
        } catch (e) {
          Logger.debug('Animation controller disposed during Goodreads animation: $e');
        }
      }
    } catch (e) {
      if (mounted && _goodreadsController.isAnimating) {
        try {
          _goodreadsController.reverse();
        } catch (animationError) {
          Logger.debug('Animation controller disposed during Goodreads error handling: $animationError');
        }
      }
      Logger.error('Error browsing Goodreads: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Error browsing Goodreads: ${e.toString()}', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoodreadsAnimating = false;
        });
      }
    }
  }

  // Convert MP3 to M4B method
  Future<void> _convertToM4B(BuildContext context) async {
    if (_isConverting) return;
    
    setState(() {
      _isConverting = true;
    });

    try {
      final actions = DetailActions(
        libraryManager: widget.libraryManager,
        onRefreshBook: widget.onRefreshBook,
        onUpdateMetadataStatus: widget.onUpdateMetadataStatus,
        onBookUpdated: widget.onBookUpdated,
      );
      
      await actions.convertToM4B(context, widget.book);
    } catch (e) {
      Logger.error('Error in convert to M4B: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Error converting to M4B: ${e.toString()}', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConverting = false;
        });
      }
    }
  }

  Future<void> _showDebugInfo(BuildContext context) async {
    try {
      // Get detailed information about this file
      final detailedInfo = await widget.book.extractDetailedInfoFromFile();
      
      // Get library statistics
      final stats = await widget.libraryManager.getMetadataStatistics();
      
      // Create comprehensive debug information
      final debugInfo = '''
📁 FILE INFORMATION:
${_formatMapForDisplay(detailedInfo['file_info'] as Map<String, dynamic>)}

🔍 RAW METADATA_GOD INFO:
${_formatMapForDisplay(detailedInfo['raw_metadata_god_info'] as Map<String, dynamic>)}

📊 LIBRARY STATISTICS:
${_formatMapForDisplay(stats)}

🏥 HEALTH CHECK:
  • Needs Repair: ${widget.book.needsMetadataRepair ? 'YES' : 'NO'}
  • Completion: ${widget.book.metadata?.completionPercentage.toStringAsFixed(1) ?? '0'}%
  • Has Duration: ${widget.book.hasDuration ? 'YES' : 'NO'}
  • Has Complete Metadata: ${widget.book.hasCompleteMetadata ? 'YES' : 'NO'}
  • Metadata Provider: ${widget.book.metadata?.provider ?? 'None'}

🎵 AUDIO INFORMATION:
  • Duration: ${widget.book.metadata?.durationFormatted ?? 'Unknown'}
  • File Format: ${widget.book.metadata?.fileFormat ?? widget.book.extension.toUpperCase()}
  • File Size: ${widget.book.formattedFileSize}

📚 CONTENT INFORMATION:
  • Title: ${widget.book.metadata?.title ?? 'None'}
  • Authors: ${widget.book.metadata?.authorsFormatted ?? 'None'}
  • Series: ${widget.book.metadata?.series ?? 'None'}
  • Position: ${widget.book.metadata?.seriesPosition ?? 'None'}
  • Genres: ${widget.book.metadata?.categories.join(', ') ?? 'None'}
  • Publisher: ${widget.book.metadata?.publisher ?? 'None'}
  • Published: ${widget.book.metadata?.publishedDate ?? 'None'}
  • Description Length: ${widget.book.metadata?.description.length ?? 0} chars

⭐ USER DATA:
  • Rating: ${widget.book.metadata?.userRating ?? 0}/5
  • Favorite: ${widget.book.metadata?.isFavorite ?? false ? 'YES' : 'NO'}
  • Tags: ${widget.book.metadata?.userTags.join(', ') ?? 'None'}
  • Bookmarks: ${widget.book.metadata?.bookmarks.length ?? 0}
  • Notes: ${widget.book.metadata?.notes.length ?? 0}
  • Last Played: ${widget.book.metadata?.lastPlayedPosition?.toIso8601String() ?? 'Never'}
  • Playback Position: ${widget.book.metadata?.playbackPosition?.inSeconds ?? 0}s
      ''';
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text('Debug Info: ${widget.book.filename}')),
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
                  Logger.log('Debug Info for ${widget.book.filename}:\n$debugInfo');
                  Navigator.of(context).pop();
                  _showSnackBar(context, 'Debug info logged to console', Colors.blue);
                },
                child: const Text('Log to Console'),
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

  void _showEnhancedSnackBar(
    BuildContext context, {
    required String message,
    required Color color,
    required IconData icon,
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 6,
        ),
      );
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }
}