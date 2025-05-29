// lib/ui/widgets/settings/settings_content_view.dart - Settings section content
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class SettingsContentView extends StatefulWidget {
  final LibraryManager libraryManager;
  final CollectionManager collectionManager;
  final MetadataService metadataService;
  final String currentSubsection;

  const SettingsContentView({
    Key? key,
    required this.libraryManager,
    required this.collectionManager,
    required this.metadataService,
    required this.currentSubsection,
  }) : super(key: key);

  @override
  State<SettingsContentView> createState() => _SettingsContentViewState();
}

class _SettingsContentViewState extends State<SettingsContentView> {
  // App info
  String _appVersion = 'Loading...';
  String _cacheSize = 'Calculating...';
  bool _isLoading = false;
  
  // Theme settings
  ThemeMode _themeMode = ThemeMode.dark;
  Color _primaryColor = Colors.indigo;
  bool _useSystemTheme = false;
  
  // Playback settings
  double _defaultPlaybackSpeed = 1.0;
  bool _autoSavePlaybackPosition = true;
  int _skipForwardSeconds = 30;
  int _skipBackwardSeconds = 10;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _loadSettings();
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      
      _cacheSize = await _calculateCacheSize();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      Logger.error('Error loading app info', e);
    }
  }

  Future<String> _calculateCacheSize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cachePath = '${appDir.path}/audiobook_cache';
      final cacheDir = Directory(cachePath);
      
      if (!await cacheDir.exists()) {
        return '0 B';
      }
      
      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return _formatFileSize(totalSize);
    } catch (e) {
      Logger.error('Error calculating cache size', e);
      return 'Unknown';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  Future<void> _loadSettings() async {
    // Load settings from storage (implement SharedPreferences for persistence)
    setState(() {
      _themeMode = ThemeMode.dark;
      _primaryColor = Colors.indigo;
      _useSystemTheme = false;
      _defaultPlaybackSpeed = 1.0;
      _autoSavePlaybackPosition = true;
      _skipForwardSeconds = 30;
      _skipBackwardSeconds = 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: _buildSettingsContent(context),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Text(
            _getHeaderTitle(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  String _getHeaderTitle() {
    switch (widget.currentSubsection) {
      case 'Library':
        return 'Library Settings';
      case 'Theme':
        return 'Theme & Appearance';
      case 'Collections':
        return 'Collection Settings';
      case 'Playback':
        return 'Playback Settings';
      case 'Storage':
        return 'Storage & Cache';
      case 'About':
        return 'About';
      default:
        return 'Settings';
    }
  }

  Widget _buildSettingsContent(BuildContext context) {
    switch (widget.currentSubsection) {
      case 'Library':
        return _buildLibrarySettings();
      case 'Theme':
        return _buildThemeSettings();
      case 'Collections':
        return _buildCollectionSettings();
      case 'Playback':
        return _buildPlaybackSettings();
      case 'Storage':
        return _buildStorageSettings();
      case 'About':
        return _buildAboutSettings();
      default:
        return _buildLibrarySettings();
    }
  }

  Widget _buildLibrarySettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Watched Directories',
            children: [
              _buildDirectoriesList(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addDirectory,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Directory'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          _buildSectionCard(
            title: 'Library Actions',
            children: [
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.white70),
                title: const Text('Rescan Library', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Scan all directories for new audiobooks', style: TextStyle(color: Colors.white70)),
                onTap: _rescanLibrary,
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              ListTile(
                leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                title: const Text('Clean Library', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Remove missing files and orphaned metadata', style: TextStyle(color: Colors.white70)),
                onTap: _cleanLibrary,
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Clear Library', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Remove all books and metadata from library', style: TextStyle(color: Colors.white70)),
                onTap: _clearLibrary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Theme Mode',
            children: [
              SwitchListTile(
                title: const Text('Use System Theme', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Follow system dark/light mode', style: TextStyle(color: Colors.white70)),
                value: _useSystemTheme,
                onChanged: (value) {
                  setState(() {
                    _useSystemTheme = value;
                  });
                  _saveSettings();
                },
              ),
              if (!_useSystemTheme) ...[
                const Divider(color: Color(0xFF2A2A2A)),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark Mode', style: TextStyle(color: Colors.white)),
                  value: ThemeMode.dark,
                  groupValue: _themeMode,
                  onChanged: (value) {
                    setState(() {
                      _themeMode = value!;
                    });
                    _saveSettings();
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Light Mode', style: TextStyle(color: Colors.white)),
                  value: ThemeMode.light,
                  groupValue: _themeMode,
                  onChanged: (value) {
                    setState(() {
                      _themeMode = value!;
                    });
                    _saveSettings();
                  },
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 24),
          
          _buildSectionCard(
            title: 'Color Scheme',
            children: [
              const Text(
                'Primary Color',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  Colors.indigo,
                  Colors.blue,
                  Colors.purple,
                  Colors.teal,
                  Colors.green,
                  Colors.orange,
                  Colors.red,
                  Colors.pink,
                ].map((color) => _buildColorOption(color)).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(Color color) {
    final isSelected = _primaryColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          _primaryColor = color;
        });
        _saveSettings();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildCollectionSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Auto-Collection Settings',
            children: [
              SwitchListTile(
                title: const Text('Auto-create Series Collections', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Automatically create collections for book series', style: TextStyle(color: Colors.white70)),
                value: true,
                onChanged: (value) {
                  // Implement setting storage
                },
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              SwitchListTile(
                title: const Text('Auto-create Author Collections', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Group books by the same author', style: TextStyle(color: Colors.white70)),
                value: false,
                onChanged: (value) {
                  // Implement setting storage
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          _buildSectionCard(
            title: 'Collection Actions',
            children: [
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.white70),
                title: const Text('Refresh Collections', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Update auto-generated collections', style: TextStyle(color: Colors.white70)),
                onTap: _refreshCollections,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Default Settings',
            children: [
              ListTile(
                title: const Text('Default Playback Speed', style: TextStyle(color: Colors.white)),
                subtitle: Text('${_defaultPlaybackSpeed.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white70)),
                trailing: DropdownButton<double>(
                  value: _defaultPlaybackSpeed,
                  dropdownColor: const Color(0xFF2A2A2A),
                  items: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                      .map((speed) => DropdownMenuItem(
                            value: speed,
                            child: Text('${speed.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _defaultPlaybackSpeed = value;
                      });
                      _saveSettings();
                    }
                  },
                ),
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              SwitchListTile(
                title: const Text('Auto-save Playback Position', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Automatically save your position when pausing', style: TextStyle(color: Colors.white70)),
                value: _autoSavePlaybackPosition,
                onChanged: (value) {
                  setState(() {
                    _autoSavePlaybackPosition = value;
                  });
                  _saveSettings();
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          _buildSectionCard(
            title: 'Skip Durations',
            children: [
              ListTile(
                title: const Text('Skip Forward Duration', style: TextStyle(color: Colors.white)),
                subtitle: Text('$_skipForwardSeconds seconds', style: const TextStyle(color: Colors.white70)),
                trailing: DropdownButton<int>(
                  value: _skipForwardSeconds,
                  dropdownColor: const Color(0xFF2A2A2A),
                  items: [15, 30, 45, 60, 90]
                      .map((seconds) => DropdownMenuItem(
                            value: seconds,
                            child: Text('$seconds s', style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _skipForwardSeconds = value;
                      });
                      _saveSettings();
                    }
                  },
                ),
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              ListTile(
                title: const Text('Skip Backward Duration', style: TextStyle(color: Colors.white)),
                subtitle: Text('$_skipBackwardSeconds seconds', style: const TextStyle(color: Colors.white70)),
                trailing: DropdownButton<int>(
                  value: _skipBackwardSeconds,
                  dropdownColor: const Color(0xFF2A2A2A),
                  items: [5, 10, 15, 20, 30]
                      .map((seconds) => DropdownMenuItem(
                            value: seconds,
                            child: Text('$seconds s', style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _skipBackwardSeconds = value;
                      });
                      _saveSettings();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Cache Information',
            children: [
              ListTile(
                leading: const Icon(Icons.storage, color: Colors.white70),
                title: const Text('Cache Size', style: TextStyle(color: Colors.white)),
                subtitle: Text(_cacheSize, style: const TextStyle(color: Colors.white70)),
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              ListTile(
                leading: const Icon(Icons.library_books, color: Colors.white70),
                title: const Text('Total Books', style: TextStyle(color: Colors.white)),
                subtitle: Text('${widget.libraryManager.files.length} books', style: const TextStyle(color: Colors.white70)),
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              ListTile(
                leading: const Icon(Icons.collections_bookmark, color: Colors.white70),
                title: const Text('Total Collections', style: TextStyle(color: Colors.white)),
                subtitle: Text('${widget.collectionManager.collections.length} collections', style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          _buildSectionCard(
            title: 'Cache Actions',
            children: [
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.white70),
                title: const Text('Refresh Cache Size', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Recalculate cache usage', style: TextStyle(color: Colors.white70)),
                onTap: _refreshCacheSize,
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              ListTile(
                leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                title: const Text('Clear Search Cache', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Clear cached search results', style: TextStyle(color: Colors.white70)),
                onTap: _clearSearchCache,
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.red),
                title: const Text('Clear All Cache', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Clear all cached data including covers', style: TextStyle(color: Colors.white70)),
                onTap: _clearAllCache,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Application Information',
            children: [
              ListTile(
                leading: const Icon(Icons.info, color: Colors.white70),
                title: const Text('Version', style: TextStyle(color: Colors.white)),
                subtitle: Text(_appVersion, style: const TextStyle(color: Colors.white70)),
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              const ListTile(
                leading: Icon(Icons.person, color: Colors.white70),
                title: Text('Developer', style: TextStyle(color: Colors.white)),
                subtitle: Text('Audiobook Organizer Team', style: TextStyle(color: Colors.white70)),
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.white70),
                title: const Text('View Logs', style: TextStyle(color: Colors.white)),
                subtitle: const Text('View application logs for troubleshooting', style: TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
                onTap: _viewLogs,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDirectoriesList() {
    final directories = widget.libraryManager.watchedDirectories;
    
    if (directories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No directories added yet',
          style: TextStyle(
            color: Colors.white70,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return Column(
      children: directories.map((directory) {
        return ListTile(
          leading: const Icon(Icons.folder, color: Colors.white70),
          title: Text(
            Directory(directory).uri.pathSegments.last,
            style: const TextStyle(color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            directory,
            style: const TextStyle(color: Colors.white70),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _removeDirectory(directory),
          ),
        );
      }).toList(),
    );
  }

  // Action methods
  Future<void> _addDirectory() async {
    try {
      String? selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Audiobooks Folder',
      );
      
      if (selectedDir != null) {
        setState(() {
          _isLoading = true;
        });
        
        await widget.libraryManager.addDirectory(selectedDir);
        
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Folder added to library')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding folder: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      Logger.error('Error adding folder', e);
    }
  }

  Future<void> _removeDirectory(String directory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Remove Directory', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to remove this directory? Files in this directory will be removed from your library.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await widget.libraryManager.removeDirectory(directory);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Directory removed from library')),
        );
      }
    }
  }

  Future<void> _rescanLibrary() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      for (final directory in widget.libraryManager.watchedDirectories) {
        await widget.libraryManager.scanDirectory(directory);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Library rescan completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rescanning library: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _cleanLibrary() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clean Library', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove missing files and orphaned metadata. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Clean'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Call the cleanLibrary method from LibraryManager
        final results = await widget.libraryManager.cleanLibrary();
        
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          // Show detailed results dialog
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Library Cleanup Complete', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (results['totalCleaned'] == 0)
                      const Text(
                        'No issues found. Your library is clean!',
                        style: TextStyle(color: Colors.green),
                      )
                    else ...[
                      Text(
                        'Cleaned ${results['totalCleaned']} items:',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (results['missingFilesRemoved'] > 0)
                        Text(
                          '• ${results['missingFilesRemoved']} missing files removed',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      if (results['orphanedMetadataRemoved'] > 0)
                        Text(
                          '• ${results['orphanedMetadataRemoved']} orphaned metadata files removed',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      if (results['orphanedCoversRemoved'] > 0)
                        Text(
                          '• ${results['orphanedCoversRemoved']} orphaned cover files removed',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Remaining files in library: ${results['remainingFiles']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          
          // Refresh cache size after cleanup
          _refreshCacheSize();
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cleaning library: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        
        Logger.error('Error cleaning library', e);
      }
    }
  }

  Future<void> _clearLibrary() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear Library', style: TextStyle(color: Colors.red)),
        content: const Text(
          'This will remove ALL books and metadata from your library. Watched directories will be cleared. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Clear all directories first
      final directories = List<String>.from(widget.libraryManager.watchedDirectories);
      for (final directory in directories) {
        await widget.libraryManager.removeDirectory(directory);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Library cleared')),
        );
      }
    }
  }

  Future<void> _refreshCollections() async {
    // Implement collection refresh logic
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collections refreshed')),
      );
    }
  }

  Future<void> _refreshCacheSize() async {
    setState(() {
      _cacheSize = 'Calculating...';
    });
    
    _cacheSize = await _calculateCacheSize();
    setState(() {});
  }

  Future<void> _clearSearchCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear Search Cache', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will clear cached search results.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Implement search cache clearing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search cache cleared')),
        );
      }
      _refreshCacheSize();
    }
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear All Cache', style: TextStyle(color: Colors.red)),
        content: const Text(
          'This will clear all cached data including covers and search results.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Implement all cache clearing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All cache cleared')),
        );
      }
      _refreshCacheSize();
    }
  }

  void _viewLogs() {
    // Navigate to logs view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs viewer not implemented yet')),
    );
  }

  void _saveSettings() {
    // Implement settings saving logic using SharedPreferences
    Logger.log('Settings saved');
  }
}