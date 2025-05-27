// lib/ui/widgets/settings_content.dart - Settings display component
// =============================================================================

import 'package:flutter/material.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/ui/screens/settings_screen.dart';

class SettingsContent extends StatelessWidget {
  final String selectedCategory;
  final LibraryManager libraryManager;
  final CollectionManager collectionManager;

  const SettingsContent({
    Key? key,
    required this.selectedCategory,
    required this.libraryManager,
    required this.collectionManager,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SettingsPanel(
      selectedCategory: selectedCategory,
      libraryManager: libraryManager,
      collectionManager: collectionManager,
    );
  }
}