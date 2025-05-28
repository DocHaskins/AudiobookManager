// lib/ui/screens/main_container.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/ui/screens/sidebar.dart';
import 'package:audiobook_organizer/ui/widgets/library/library_content_view.dart';
import 'package:audiobook_organizer/ui/widgets/tools/tools_content_view.dart';
import 'package:audiobook_organizer/ui/widgets/settings/settings_content_view.dart';
import 'package:audiobook_organizer/utils/library_filter_utils.dart';

enum MainSection {
  library,
  tools,
  settings,
}

class MainContainer extends StatefulWidget {
  final LibraryManager libraryManager;
  final CollectionManager collectionManager;
  final AudioPlayerService playerService;
  final MetadataService metadataService;
  final List<MetadataProvider> metadataProviders; // ADD THIS LINE

  const MainContainer({
    Key? key,
    required this.libraryManager,
    required this.collectionManager,
    required this.playerService,
    required this.metadataService,
    required this.metadataProviders, // ADD THIS LINE
  }) : super(key: key);

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  MainSection _currentSection = MainSection.library;
  String _currentSubsection = 'All';
  
  String _searchQuery = '';
  SortOption _sortOption = SortOption.title;
  bool _showCollections = false;

  void _onSectionChanged(MainSection section) {
    setState(() {
      _currentSection = section;
      switch (section) {
        case MainSection.library:
          _currentSubsection = 'All';
          break;
        case MainSection.tools:
          _currentSubsection = 'Metadata';
          break;
        case MainSection.settings:
          _currentSubsection = 'Library';
          break;
      }
    });
  }

  void _onSubsectionChanged(String subsection) {
    setState(() {
      _currentSubsection = subsection;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onSortOptionChanged(SortOption sortOption) {
    setState(() {
      _sortOption = sortOption;
    });
  }

  void _onShowCollectionsToggle(bool showCollections) {
    setState(() {
      _showCollections = showCollections;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Sidebar
        Container(
          width: 280,
          color: const Color(0xFF000000),
          child: Sidebar(
            currentSection: _currentSection,
            currentSubsection: _currentSubsection,
            libraryManager: widget.libraryManager,
            collectionManager: widget.collectionManager,
            onSectionChanged: _onSectionChanged,
            onSubsectionChanged: _onSubsectionChanged,
            onSearchChanged: _onSearchChanged,
            onSortOptionChanged: _onSortOptionChanged,
            onShowCollectionsToggle: _onShowCollectionsToggle,
          ),
        ),
        
        // Main Content Area
        Expanded(
          child: Container(
            color: const Color(0xFF121212),
            child: _buildMainContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    switch (_currentSection) {
      case MainSection.library:
        return LibraryContentView(
          libraryManager: widget.libraryManager,
          collectionManager: widget.collectionManager,
          playerService: widget.playerService,
          currentSubsection: _currentSubsection,
          searchQuery: _searchQuery,
          sortOption: _sortOption,
          showCollections: _showCollections,
        );
      case MainSection.tools:
        return ToolsContentView(
          libraryManager: widget.libraryManager,
          collectionManager: widget.collectionManager,
          metadataService: widget.metadataService,
          currentSubsection: _currentSubsection,
          metadataProviders: widget.metadataProviders,
        );
      case MainSection.settings:
        return SettingsContentView(
          libraryManager: widget.libraryManager,
          collectionManager: widget.collectionManager,
          metadataService: widget.metadataService,
          currentSubsection: _currentSubsection,
        );
    }
  }
}