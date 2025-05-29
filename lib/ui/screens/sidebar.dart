// lib/ui/widgets/sidebar.dart
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/ui/screens/main_container.dart';
import 'package:audiobook_organizer/utils/library_filter_utils.dart';
import 'package:audiobook_organizer/utils/genre_icon_utils.dart';
import 'package:audiobook_organizer/utils/duration_utils.dart';

class Sidebar extends StatefulWidget {
  final MainSection currentSection;
  final String currentSubsection;
  final LibraryManager libraryManager;
  final CollectionManager collectionManager;
  final ValueChanged<MainSection> onSectionChanged;
  final ValueChanged<String> onSubsectionChanged;
  
  // Add callbacks for library functionality
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<SortOption>? onSortOptionChanged;
  final ValueChanged<bool>? onShowCollectionsToggle;

  const Sidebar({
    Key? key,
    required this.currentSection,
    required this.currentSubsection,
    required this.libraryManager,
    required this.collectionManager,
    required this.onSectionChanged,
    required this.onSubsectionChanged,
    this.onSearchChanged,
    this.onSortOptionChanged,
    this.onShowCollectionsToggle,
  }) : super(key: key);

  @override
  State<Sidebar> createState() => _UnifiedSidebarState();
}

class _UnifiedSidebarState extends State<Sidebar> {
  String _searchQuery = '';
  bool _showCollections = false;
  SortOption _selectedSortOption = SortOption.title;
  
  // Dynamic categories with counts for library section
  Map<String, int> _availableGenres = {};
  Map<String, int> _availableAuthors = {};

  @override
  void initState() {
    super.initState();
    _updateLibraryCategories();
    
    // Listen to library changes
    widget.libraryManager.libraryChanged.listen((_) {
      if (mounted) {
        setState(() {
          _updateLibraryCategories();
        });
      }
    });
  }

  void _updateLibraryCategories() {
    _availableGenres = LibraryFilterUtils.extractGenresWithCounts(
      widget.libraryManager.files
    );
    _availableAuthors = LibraryFilterUtils.extractAuthorsWithCounts(
      widget.libraryManager.files
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        _buildMainSectionButtons(context),
        const SizedBox(height: 16),
        Expanded(child: _buildSectionContent(context)),
        _buildBottomStats(),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Icon(
            Icons.headphones,
            color: Theme.of(context).secondaryHeaderColor,
            size: 32,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Audiobooks',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSectionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              _buildCompactSectionButton(
                context,
                MainSection.library,
                Icons.library_books,
                'Library',
              ),
              _buildCompactSectionButton(
                context,
                MainSection.tools,
                Icons.build,
                'Tools',
              ),
              _buildCompactSectionButton(
                context,
                MainSection.settings,
                Icons.settings,
                'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSectionButton(
    BuildContext context,
    MainSection section,
    IconData icon,
    String label,
  ) {
    final isSelected = widget.currentSection == section;
    
    return Expanded(
      flex: isSelected ? 3 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.8),
                    Theme.of(context).primaryColor.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onSectionChanged(section),
            borderRadius: BorderRadius.circular(12),
            splashColor: Theme.of(context).primaryColor.withOpacity(0.2),
            highlightColor: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return OverflowBox(
                    maxWidth: constraints.maxWidth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutBack,
                          child: Icon(
                            icon,
                            color: isSelected 
                                ? Colors.white 
                                : Colors.grey[400],
                            size: 24,
                          ),
                        ),
                        // Animated text container
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOutCubic,
                          width: isSelected ? null : 0,
                          child: isSelected
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 300),
                                    opacity: isSelected ? 1.0 : 0.0,
                                    curve: Curves.easeInOut,
                                    child: AnimatedSlide(
                                      duration: const Duration(milliseconds: 400),
                                      offset: isSelected ? Offset.zero : const Offset(0.5, 0),
                                      curve: Curves.easeInOutCubic,
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          letterSpacing: 0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContent(BuildContext context) {
    switch (widget.currentSection) {
      case MainSection.library:
        return _buildLibraryContent(context);
      case MainSection.tools:
        return _buildToolsContent(context);
      case MainSection.settings:
        return _buildSettingsContent(context);
    }
  }

  Widget _buildLibraryContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildViewToggle(context),
          const SizedBox(height: 16),
          if (!_showCollections) _buildSortDropdown(context),
          const SizedBox(height: 24),
          _buildLibraryCategories(context),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search ${_showCollections ? "collections" : "books"}...',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          // Notify the library content view about search changes
          if (widget.currentSection == MainSection.library && widget.onSearchChanged != null) {
            widget.onSearchChanged!(value);
          }
        },
      ),
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              context,
              'Books',
              !_showCollections,
              () => setState(() => _showCollections = false),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              context,
              'Collections',
              _showCollections,
              () => setState(() => _showCollections = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(BuildContext context, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        onTap();
        // Notify the library content view about view toggle changes
        if (widget.currentSection == MainSection.library && widget.onShowCollectionsToggle != null) {
          widget.onShowCollectionsToggle!(label == 'Collections');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortDropdown(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<SortOption>(
        value: _selectedSortOption,
        onChanged: (SortOption? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedSortOption = newValue;
            });
            // Notify the library content view about sort changes
            if (widget.currentSection == MainSection.library && widget.onSortOptionChanged != null) {
              widget.onSortOptionChanged!(newValue);
            }
          }
        },
        dropdownColor: const Color(0xFF2A2A2A),
        underline: const SizedBox.shrink(),
        isExpanded: true,
        icon: Icon(Icons.sort, color: Colors.grey[400]),
        style: const TextStyle(color: Colors.white),
        items: SortOption.values.map<DropdownMenuItem<SortOption>>((SortOption value) {
          return DropdownMenuItem<SortOption>(
            value: value,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _getSortIcon(value),
                    color: Colors.grey[400],
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sort by ${value.displayName}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getSortIcon(SortOption option) {
    switch (option) {
      case SortOption.title:
      case SortOption.titleDesc:
        return Icons.sort_by_alpha;
      case SortOption.author:
        return Icons.person;
      case SortOption.rating:
        return Icons.star;
      case SortOption.duration:
        return Icons.access_time;
      case SortOption.dateAdded:
        return Icons.schedule;
      case SortOption.series:
        return Icons.collections_bookmark;
      case SortOption.genre:
        return Icons.category;
    }
  }

  Widget _buildLibraryCategories(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryItem(context, 'All', Icons.library_books),
        if (!_showCollections) ...[
          _buildCategoryItem(context, 'Favorites', Icons.favorite),
          _buildCategoryItem(context, 'Recently Added', Icons.new_releases),
          _buildCategoryItem(context, 'In Progress', Icons.play_circle_outline),
          if (_availableGenres.isNotEmpty) ...[
            const Divider(color: Color(0xFF2A2A2A), height: 32),
            _buildSectionTitle('GENRES'),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.25,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _availableGenres.length,
                itemBuilder: (context, index) {
                  final entry = _availableGenres.entries.elementAt(index);
                  return _buildCategoryItemWithCount(
                    context,
                    entry.key,
                    GenreIconUtils.getGenreIcon(entry.key),
                    entry.value,
                  );
                },
              ),
            ),
          ],
          if (_availableAuthors.isNotEmpty) ...[
            const Divider(color: Color(0xFF2A2A2A), height: 32),
            _buildSectionTitle('AUTHORS'),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.25,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _availableAuthors.length,
                itemBuilder: (context, index) {
                  final entry = _availableAuthors.entries.elementAt(index);
                  return _buildCategoryItemWithCount(
                    context,
                    entry.key,
                    Icons.person,
                    entry.value,
                  );
                },
              ),
            ),
          ],
        ] else ...[
          _buildCategoryItem(context, 'Series', Icons.collections_bookmark),
          _buildCategoryItem(context, 'Custom', Icons.folder_special),
          _buildCategoryItem(context, 'Author', Icons.person),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildToolsContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('MEDIA TOOLS'),
          _buildCategoryItem(context, 'Mp3 Merger', Icons.merge_type_rounded),
          _buildCategoryItem(context, 'Batch Converter', Icons.transform),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryItem(context, 'Library', Icons.library_books),
          _buildCategoryItem(context, 'Theme', Icons.palette),
          _buildCategoryItem(context, 'Collections', Icons.collections_bookmark),
          _buildCategoryItem(context, 'Playback', Icons.play_circle),
          _buildCategoryItem(context, 'Storage', Icons.storage),
          _buildCategoryItem(context, 'About', Icons.info_outline),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, String title, IconData icon) {
    final isSelected = widget.currentSubsection == title;
    return InkWell(
      onTap: () => widget.onSubsectionChanged(title),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A2A2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItemWithCount(BuildContext context, String title, IconData icon, int count) {
    final isSelected = widget.currentSubsection == title;
    return InkWell(
      onTap: () => widget.onSubsectionChanged(title),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A2A2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).primaryColor.withOpacity(0.2)
                    : Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 16),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildBottomStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.currentSection == MainSection.library) ...[
            Text(
              _showCollections
                  ? '${widget.collectionManager.collections.length} Collections'
                  : '${widget.libraryManager.files.length} Books',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            if (!_showCollections)
              Text(
                DurationUtils.calculateTotalDuration(widget.libraryManager.files),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
          ] else if (widget.currentSection == MainSection.tools) ...[
            Text(
              'Tools & Utilities',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ] else if (widget.currentSection == MainSection.settings) ...[
            Text(
              'App Configuration',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}