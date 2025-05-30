// lib/widgets/audiobook_card.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'dart:io';

class AudiobookCard extends StatefulWidget {
  final AudiobookFile file;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPlayTap;
  final bool showProgress;
  final bool showSeriesPosition;
  
  const AudiobookCard({
    Key? key,
    required this.file,
    this.onTap,
    this.onLongPress,
    this.onPlayTap,
    this.showProgress = true,
    this.showSeriesPosition = false,
  }) : super(key: key);
  
  @override
  State<AudiobookCard> createState() => _AudiobookCardState();
}

class _AudiobookCardState extends State<AudiobookCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }
  
  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }
  
  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }
  
  @override
  Widget build(BuildContext context) {
    final metadata = widget.file.metadata;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode 
                        ? Colors.black.withAlpha(90)
                        : Colors.black.withAlpha(24),
                    blurRadius: _isPressed ? 4 : 8,
                    offset: Offset(0, _isPressed ? 2 : 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cover section
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Cover image
                          _buildCoverImage(context),
                          
                          // Gradient overlay for better text visibility
                          if (metadata != null)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.black.withAlpha(140),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          
                          // Top badges row
                          Positioned(
                            top: 8,
                            left: 8,
                            right: 8,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Series position badge
                                if (widget.showSeriesPosition && 
                                    metadata?.seriesPosition.isNotEmpty == true)
                                  _buildBadge(
                                    context,
                                    '#${metadata!.seriesPosition}',
                                    theme.primaryColor,
                                  ),
                                
                                // Favorite badge
                                if (metadata?.isFavorite == true)
                                  _buildIconBadge(
                                    context,
                                    Icons.favorite,
                                    Colors.red,
                                  ),
                              ],
                            ),
                          ),
                          
                          // Bottom info overlay
                          if (metadata != null)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Rating and duration row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Rating
                                        if (metadata.averageRating > 0)
                                          _buildRating(metadata.averageRating),
                                        
                                        // Duration
                                        if (metadata.audioDuration != null)
                                          _buildDurationChip(metadata.durationFormatted),
                                      ],
                                    ),
                                    
                                    // Progress bar
                                    if (widget.showProgress && 
                                        metadata.playbackPosition != null && 
                                        metadata.audioDuration != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: _buildProgressBar(
                                          metadata.playbackPosition!,
                                          metadata.audioDuration!,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Play button
                          if (widget.onPlayTap != null)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Material(
                                color: theme.primaryColor,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: widget.onPlayTap,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Info section
                    Container(
                      color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            metadata?.title ?? widget.file.filename,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 4),
                          
                          // Author
                          Text(
                            metadata?.authorsFormatted ?? 'Unknown Author',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          // Series info
                          if (metadata?.series.isNotEmpty == true && !widget.showSeriesPosition)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                metadata!.series,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildCoverImage(BuildContext context) {
    final metadata = widget.file.metadata;
    final thumbnailPath = metadata?.thumbnailUrl;
    
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      final coverFile = File(thumbnailPath);
      if (coverFile.existsSync()) {
        return Image.file(
          coverFile,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
        );
      }
    }
    
    return _buildPlaceholder(context);
  }
  
  Widget _buildPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Container(
      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.headphones,
              size: 48,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
            ),
            const SizedBox(height: 8),
            Text(
              'No Cover',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildIconBadge(BuildContext context, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
        size: 16,
      ),
    );
  }
  
  Widget _buildRating(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star,
            color: Colors.amber,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDurationChip(String duration) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        duration,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  Widget _buildProgressBar(Duration position, Duration total) {
    final progress = position.inSeconds / total.inSeconds;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withAlpha(90),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatDuration(position)} / ${_formatDuration(total)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }
}