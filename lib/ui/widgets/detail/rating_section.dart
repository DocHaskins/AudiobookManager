// lib/ui/widgets/detail/sections/rating_section.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/ui/widgets/detail/metadata_utils.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class RatingSection extends StatefulWidget {
  final AudiobookFile book;
  final LibraryManager libraryManager;
  final VoidCallback onRefreshBook;

  const RatingSection({
    Key? key,
    required this.book,
    required this.libraryManager,
    required this.onRefreshBook,
  }) : super(key: key);

  @override
  State<RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<RatingSection>
    with TickerProviderStateMixin {
  int _hoveredRating = 0;
  bool _isUpdating = false;
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  int _animatingStarIndex = -1;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for hover effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Scale animation for click effect
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.book.metadata;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Online rating
          if (metadata?.averageRating != null && metadata!.averageRating > 0) ...[
            Row(
              children: [
                _buildStarRating(metadata.averageRating),
                const SizedBox(width: 12),
                Text(
                  '${metadata.averageRating.toStringAsFixed(2)} avg rating',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                if (metadata.ratingsCount > 0) ...[
                  Text(
                    ' • ${MetadataUtils.formatRatingCount(metadata.ratingsCount)} ratings',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          // User rating section with enhanced interactivity
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Your rating: ',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  if (_isUpdating)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                    )
                  else
                    _buildUserRating(metadata?.userRating ?? 0),
                ],
              ),
              
              // Hover feedback text
              if (_hoveredRating > 0 && !_isUpdating) ...[
                const SizedBox(height: 8),
                AnimatedOpacity(
                  opacity: _hoveredRating > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _getRatingText(_hoveredRating),
                    style: TextStyle(
                      color: Colors.amber.withAlpha(160),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 18);
        } else if (index < rating) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 18);
        } else {
          return Icon(Icons.star_border, color: Colors.grey[400], size: 18);
        }
      }),
    );
  }

  Widget _buildUserRating(int userRating) {
    return MouseRegion(
      onExit: (_) {
        setState(() {
          _hoveredRating = 0;
        });
        _pulseController.reset();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final starIndex = index + 1;
          final isHovered = _hoveredRating >= starIndex;
          final isFilled = starIndex <= userRating || isHovered;
          final isAnimating = _animatingStarIndex == index;
          
          return MouseRegion(
            onEnter: (_) {
              setState(() {
                _hoveredRating = starIndex;
              });
              _pulseController.repeat(reverse: true);
            },
            child: GestureDetector(
              onTap: () => _updateUserRating(starIndex, index),
              child: Container(
                padding: const EdgeInsets.all(2),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
                  builder: (context, child) {
                    double scale = 1.0;
                    
                    if (isAnimating) {
                      scale = _scaleAnimation.value;
                    } else if (isHovered) {
                      scale = _pulseAnimation.value;
                    }
                    
                    return Transform.scale(
                      scale: scale,
                      child: Icon(
                        isFilled ? Icons.star : Icons.star_border,
                        color: _getStarColor(starIndex, userRating, isHovered),
                        size: 20,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Color _getStarColor(int starIndex, int userRating, bool isHovered) {
    if (starIndex <= userRating) {
      return Colors.amber;
    } else if (isHovered) {
      return Colors.amber.withAlpha(140);
    } else {
      return Colors.grey[400]!;
    }
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor - Not worth the time';
      case 2:
        return 'Fair - Had some issues';
      case 3:
        return 'Good - Enjoyed it overall';
      case 4:
        return 'Great - Really liked it';
      case 5:
        return 'Excellent - Absolutely loved it!';
      default:
        return '';
    }
  }

  Future<void> _updateUserRating(int rating, int starIndex) async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
      _animatingStarIndex = starIndex;
      _hoveredRating = 0;
    });

    // Stop pulse animation and start scale animation
    _pulseController.stop();
    await _scaleController.forward();
    await _scaleController.reverse();

    try {
      final success = await widget.libraryManager.updateUserData(
        widget.book, 
        userRating: rating
      );
      
      if (success) {
        widget.onRefreshBook();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rating updated for "${widget.book.metadata?.title ?? widget.book.filename}"',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(12),
            ),
          );
        }
      } else {
        _showErrorMessage('Failed to update rating');
      }
    } catch (e) {
      Logger.error('Error updating user rating: $e');
      _showErrorMessage('Error updating rating: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _animatingStarIndex = -1;
        });
      }
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
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