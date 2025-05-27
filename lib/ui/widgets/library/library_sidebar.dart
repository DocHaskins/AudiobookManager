// lib/ui/widgets/library_sidebar.dart - Updated sidebar component
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/collection.dart';
import 'package:audiobook_organizer/utils/genre_icon_utils.dart';
import 'package:audiobook_organizer/utils/duration_utils.dart';
import 'package:audiobook_organizer/utils/library_filter_utils.dart';

class LibrarySidebar extends StatelessWidget {
  final bool showSettings;
  final bool showCollections;
  final String searchQuery;
  final String selectedCategory;
  final SortOption selectedSortOption;
  final Map<String, int> availableGenres;
  final Map<String, int> availableAuthors;
  final List<AudiobookFile> filteredBooks;
  final List<Collection> filteredCollections;
  final VoidCallback onToggleSettings;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<SortOption> onSortOptionChanged;
  final ValueChanged<bool> onShowCollectionsToggle;

  const LibrarySidebar({
    Key? key,
    required this.showSettings,
    required this.showCollections,
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedSortOption,
    required this.availableGenres,
    required this.availableAuthors,
    required this.filteredBooks,
    required this.filteredCollections,
    required this.onToggleSettings,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onSortOptionChanged,
    required this.onShowCollectionsToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return showSettings 
        ? _buildSettingsSidebar(context)
        : _buildMainSidebar(context);
  }

  Widget _buildMainSidebar(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        _buildViewToggle(context),
        const SizedBox(height: 16),
        _buildSearchBar(),
        const SizedBox(height: 16),
        _buildSortDropdown(context),
        const SizedBox(height: 24),
        Expanded(child: _buildCategories(context)),
        _buildBottomStats(),
      ],
    );
  }

  Widget _buildSettingsSidebar(BuildContext context) {
    return Column(
      children: [
        _buildSettingsHeader(context),
        _buildSettingsCategories(context),
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
            color: Theme.of(context).primaryColor,
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
          IconButton(
            icon: const Icon(
              Icons.settings,
              color: Colors.white70,
              size: 24,
            ),
            onPressed: onToggleSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search ${showCollections ? "collections" : "books"}...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: onSearchChanged,
        ),
      ),
    );
  }

  Widget _buildSortDropdown(BuildContext context) {
    if (showCollections) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<SortOption>(
          value: selectedSortOption,
          onChanged: (SortOption? newValue) {
            if (newValue != null) {
              onSortOptionChanged(newValue);
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

  Widget _buildViewToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
                !showCollections,
                () => onShowCollectionsToggle(false),
              ),
            ),
            Expanded(
              child: _buildToggleButton(
                context,
                'Collections',
                showCollections,
                () => onShowCollectionsToggle(true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(BuildContext context, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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

  Widget _buildCategories(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryItem(context, 'All', Icons.library_books),
          if (!showCollections) ...[
            _buildCategoryItem(context, 'Favorites', Icons.favorite),
            _buildCategoryItem(context, 'Recently Added', Icons.new_releases),
            _buildCategoryItem(context, 'In Progress', Icons.play_circle_outline),
            if (availableGenres.isNotEmpty) ...[
              const Divider(color: Color(0xFF2A2A2A), height: 32),
              _buildSectionTitle('GENRES'),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.25,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: availableGenres.length,
                  itemBuilder: (context, index) {
                    final entry = availableGenres.entries.elementAt(index);
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
            if (availableAuthors.isNotEmpty) ...[
              const Divider(color: Color(0xFF2A2A2A), height: 32),
              _buildSectionTitle('AUTHORS'),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.25,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: availableAuthors.length,
                  itemBuilder: (context, index) {
                    final entry = availableAuthors.entries.elementAt(index);
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
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, String title, IconData icon) {
    final isSelected = selectedCategory == title;
    return InkWell(
      onTap: () => onCategoryChanged(title),
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
    final isSelected = selectedCategory == title;
    return InkWell(
      onTap: () => onCategoryChanged(title),
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
      padding: const EdgeInsets.only(left: 12, bottom: 8),
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
          Text(
            showCollections
                ? '${filteredCollections.length} Collections'
                : '${filteredBooks.length} Books',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          if (!showCollections)
            Text(
              DurationUtils.calculateTotalDuration(filteredBooks),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white70,
              size: 24,
            ),
            onPressed: onToggleSettings,
          ),
          const SizedBox(width: 8),
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCategories(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingsCategoryItem(context, 'Library', Icons.library_books, 'Library'),
            _buildSettingsCategoryItem(context, 'Theme', Icons.palette, 'Theme'),
            _buildSettingsCategoryItem(context, 'Collections', Icons.collections_bookmark, 'Collections'),
            _buildSettingsCategoryItem(context, 'Playback', Icons.play_circle, 'Playback'),
            _buildSettingsCategoryItem(context, 'Storage', Icons.storage, 'Storage'),
            _buildSettingsCategoryItem(context, 'About', Icons.info_outline, 'About'),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCategoryItem(BuildContext context, String title, IconData icon, String category) {
    final isSelected = selectedCategory == category;
    return InkWell(
      onTap: () => onCategoryChanged(category),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A2A2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400],
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}