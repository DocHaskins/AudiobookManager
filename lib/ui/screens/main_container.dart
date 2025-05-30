// lib/ui/screens/main_container.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/services/audio_conversion_service.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/ui/screens/sidebar.dart';
import 'package:audiobook_organizer/ui/widgets/library/library_content_view.dart';
import 'package:audiobook_organizer/ui/widgets/tools/tools_content_view.dart';
import 'package:audiobook_organizer/ui/widgets/settings/settings_content_view.dart';
import 'package:audiobook_organizer/utils/library_filter_utils.dart';
import 'package:audiobook_organizer/utils/logger.dart';

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
  final List<MetadataProvider> metadataProviders;

  const MainContainer({
    Key? key,
    required this.libraryManager,
    required this.collectionManager,
    required this.playerService,
    required this.metadataService,
    required this.metadataProviders,
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

  // Audio conversion service
  late final AudioConversionService _audioConversionService;
  bool _servicesInitialized = false;
  String _initializationStatus = 'Loading cached hardware info...';

  @override
  void initState() {
    super.initState();
    _initializeAudioConversionService();
  }

  Future<void> _initializeAudioConversionService() async {
    try {
      Logger.log('MainContainer: Initializing AudioConversionService with hardware caching...');
      
      if (mounted) {
        setState(() {
          _initializationStatus = 'Loading hardware profile...';
        });
      }
      
      // Create AudioConversionService with required dependencies
      _audioConversionService = AudioConversionService(
        metadataService: widget.metadataService,
        libraryManager: widget.libraryManager,
      );
      
      if (mounted) {
        setState(() {
          _initializationStatus = 'Optimizing for your system...';
        });
      }
      
      // Initialize the service (this will now use cached hardware info)
      await _audioConversionService.initialize();
      
      if (mounted) {
        setState(() {
          _servicesInitialized = true;
        });
      }
    } catch (e) {
      Logger.error('MainContainer: Failed to initialize AudioConversionService', e);
      
      if (mounted) {
        setState(() {
          _servicesInitialized = true; // Still set to true to show UI, but service may be limited
          _initializationStatus = 'Initialization complete (limited functionality)';
        });
      }
    }
  }

  @override
  void dispose() {
    // Clean up the audio conversion service
    if (_servicesInitialized) {
      _audioConversionService.dispose();
    }
    super.dispose();
  }

  void _onSectionChanged(MainSection section) {
    setState(() {
      _currentSection = section;
      switch (section) {
        case MainSection.library:
          _currentSubsection = 'All';
          break;
        case MainSection.tools:
          _currentSubsection = 'Mp3 Merger';
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
    // Show initialization screen while services are being set up
    if (!_servicesInitialized) {
      return _buildInitializationScreen();
    }

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
          audioConversionService: _audioConversionService,
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

  Widget _buildInitializationScreen() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              _initializationStatus,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hardware capabilities are cached and only detected once',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}