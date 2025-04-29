// File: lib/ui/widgets/image_loader_widget.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:developer' as developer;

/// A widget that handles loading and displaying book cover images
/// with proper error handling and debugging
class BookCoverImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final String bookTitle;
  
  const BookCoverImage({
    Key? key,
    required this.imageUrl,
    this.width = double.infinity,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.bookTitle = 'Unknown Book',
  }) : super(key: key);
  
  @override
    Widget build(BuildContext context) {
    // Handle null or empty URLs
    if (imageUrl == null || imageUrl!.isEmpty) {
      developer.log('Missing cover image URL for book: $bookTitle');
      return _buildDefaultImage(context);
    }
    
    // Log the URL for debugging
    developer.log('Loading cover image for "$bookTitle": $imageUrl');
    
    return CachedNetworkImage(
      key: ValueKey(imageUrl), // Add key based on URL to force refresh
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder ?? _defaultPlaceholder,
      errorWidget: errorWidget ?? _defaultErrorWidget,
      useOldImageOnUrlChange: false, // Force reload when URL changes
      fadeOutDuration: const Duration(milliseconds: 100),
      fadeInDuration: const Duration(milliseconds: 300),
    );
  }
    
  // Default placeholder while loading
  Widget _defaultPlaceholder(BuildContext context, String url) {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  // Default error widget
  Widget _defaultErrorWidget(BuildContext context, String url, dynamic error) {
    // Log the error for debugging
    developer.log('Error loading image for "$bookTitle": $url - $error');
    
    return _buildDefaultImage(context);
  }
  
  // Default book icon when image is unavailable
  Widget _buildDefaultImage(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: height / 3,
            color: theme.primaryColor.withOpacity(0.5),
          ),
          if (bookTitle != 'Unknown Book')
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                bookTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}