// =============================================================================
// lib/ui/widgets/detail/detail_controllers_mixin.dart - Controllers management
// =============================================================================

import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';

mixin DetailControllersMixin {
  bool _isEditingMetadata = false;
  
  TextEditingController? _titleController;
  TextEditingController? _authorController;
  TextEditingController? _genresController;
  TextEditingController? _seriesController;
  TextEditingController? _seriesPositionController;
  TextEditingController? _descriptionController;
  TextEditingController? _categoriesController;
  TextEditingController? _userTagsController;
  TextEditingController? _publisherController;
  TextEditingController? _publishedDateController;

  // Getters
  bool get isEditingMetadata => _isEditingMetadata;
  TextEditingController? get titleController => _titleController;
  TextEditingController? get authorController => _authorController;
  TextEditingController? get genresController => _genresController;
  TextEditingController? get seriesController => _seriesController;
  TextEditingController? get seriesPositionController => _seriesPositionController;
  TextEditingController? get descriptionController => _descriptionController;
  TextEditingController? get categoriesController => _categoriesController;
  TextEditingController? get userTagsController => _userTagsController;
  TextEditingController? get publisherController => _publisherController;
  TextEditingController? get publishedDateController => _publishedDateController;

  void setEditingMetadata(bool editing) {
    _isEditingMetadata = editing;
  }

  void initializeControllers(AudiobookMetadata? metadata, [String? filename]) {
    disposeControllers();
    
    _titleController = TextEditingController(text: metadata?.title ?? filename ?? '');
    _authorController = TextEditingController(text: metadata?.authorsFormatted ?? '');
    _seriesController = TextEditingController(text: metadata?.series ?? '');
    _seriesPositionController = TextEditingController(text: metadata?.seriesPosition ?? '');
    _descriptionController = TextEditingController(text: metadata?.description ?? '');
    _categoriesController = TextEditingController(
      text: metadata?.categories.isEmpty ?? true ? '' : metadata!.categories.join(', ')
    );
    _userTagsController = TextEditingController(
      text: metadata?.userTags.isEmpty ?? true ? '' : metadata!.userTags.join(', ')
    );
    _genresController = TextEditingController(
      text: metadata?.categories.isEmpty ?? true ? '' : metadata!.categories.join(', ')
    );
    _publisherController = TextEditingController(text: metadata?.publisher ?? '');
    _publishedDateController = TextEditingController(text: metadata?.publishedDate ?? '');
  }

  void disposeControllers() {
    try {
      _titleController?.dispose();
      _authorController?.dispose();
      _seriesController?.dispose();
      _seriesPositionController?.dispose();
      _descriptionController?.dispose();
      _categoriesController?.dispose();
      _userTagsController?.dispose();
      _genresController?.dispose();
      _publisherController?.dispose();
      _publishedDateController?.dispose();
    } catch (e) {
      // Expected during init
    }
  }

  List<String> parseCommaSeparatedValues(String input) {
    return input
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}