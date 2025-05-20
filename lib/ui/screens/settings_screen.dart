// lib/ui/screens/settings_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/storage/audiobook_storage_manager.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // App info
  String _appVersion = '';
  String _cacheSize = '';
  bool _isLoading = false;
  
  // Settings
  final bool _darkMode = true;
  double _defaultPlaybackSpeed = 1.0;
  bool _autoSavePlaybackPosition = true;
  int _skipForwardSeconds = 30;
  int _skipBackwardSeconds = 10;
  
  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }
  
  // Load app info
  Future<void> _loadAppInfo() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      
      // Calculate cache size
      _cacheSize = await _calculateCacheSize();
    } catch (e) {
      Logger.error('Error loading app info', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Calculate cache size
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
      
      // Format size
      if (totalSize < 1024) {
        return '$totalSize B';
      } else if (totalSize < 1024 * 1024) {
        return '${(totalSize / 1024).toStringAsFixed(1)} KB';
      } else if (totalSize < 1024 * 1024 * 1024) {
        return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      }
    } catch (e) {
      Logger.error('Error calculating cache size', e);
      return 'Unknown';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Library section
                  _buildSection(
                    title: 'Library',
                    children: [
                      _buildDirectoriesList(),
                      _buildSettingTile(
                        title: 'Clear Cache',
                        subtitle: 'Current size: $_cacheSize',
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _clearCache,
                        ),
                      ),
                      _buildSettingTile(
                        title: 'Rescan Library',
                        subtitle: 'Scan for new files and update metadata',
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _rescanLibrary,
                        ),
                      ),
                    ],
                  ),
                  
                  // Playback section
                  _buildSection(
                    title: 'Playback',
                    children: [
                      _buildSettingTile(
                        title: 'Default Playback Speed',
                        subtitle: '${_defaultPlaybackSpeed.toStringAsFixed(1)}x',
                        trailing: DropdownButton<double>(
                          value: _defaultPlaybackSpeed,
                          items: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                              .map((speed) => DropdownMenuItem(
                                    value: speed,
                                    child: Text('${speed.toStringAsFixed(1)}x'),
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
                      SwitchListTile(
                        title: const Text('Auto-save Playback Position'),
                        subtitle: const Text('Automatically save your position when pausing'),
                        value: _autoSavePlaybackPosition,
                        onChanged: (value) {
                          setState(() {
                            _autoSavePlaybackPosition = value;
                          });
                          _saveSettings();
                        },
                      ),
                      _buildSettingTile(
                        title: 'Skip Forward Duration',
                        subtitle: '$_skipForwardSeconds seconds',
                        trailing: DropdownButton<int>(
                          value: _skipForwardSeconds,
                          items: [15, 30, 45, 60, 90]
                              .map((seconds) => DropdownMenuItem(
                                    value: seconds,
                                    child: Text('$seconds s'),
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
                      _buildSettingTile(
                        title: 'Skip Backward Duration',
                        subtitle: '$_skipBackwardSeconds seconds',
                        trailing: DropdownButton<int>(
                          value: _skipBackwardSeconds,
                          items: [5, 10, 15, 20, 30]
                              .map((seconds) => DropdownMenuItem(
                                    value: seconds,
                                    child: Text('$seconds s'),
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
                  
                  // App info section
                  _buildSection(
                    title: 'About',
                    children: [
                      ListTile(
                        title: const Text('Version'),
                        subtitle: Text(_appVersion),
                      ),
                      const ListTile(
                        title: Text('Developer'),
                        subtitle: Text('YourCompany'),
                      ),
                      ListTile(
                        title: const Text('View Logs'),
                        subtitle: const Text('View application logs for troubleshooting'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _viewLogs,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
  
  // Build a section with header and children
  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  // Build a setting tile
  Widget _buildSettingTile({required String title, String? subtitle, Widget? trailing}) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
    );
  }
  
  // Build the list of watched directories
  Widget _buildDirectoriesList() {
    final libraryManager = Provider.of<LibraryManager>(context);
    final directories = libraryManager.watchedDirectories;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Row(
            children: [
              const Text(
                'Watched Directories',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add Directory',
                onPressed: () => _addDirectory(libraryManager),
              ),
            ],
          ),
        ),
        if (directories.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No directories added yet',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: directories.length,
            itemBuilder: (context, index) {
              final directory = directories[index];
              
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(
                  Directory(directory).uri.pathSegments.last,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  directory,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeDirectory(libraryManager, directory),
                ),
              );
            },
          ),
      ],
    );
  }
  
  // Add a directory to watch
  Future<void> _addDirectory(LibraryManager libraryManager) async {
    try {
      // Show directory picker
      String? selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Audiobooks Folder',
      );
      
      if (selectedDir != null) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            title: Text('Scanning Folder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Scanning for audiobooks...'),
              ],
            ),
          ),
        );
        
        // Add the directory to library manager
        await libraryManager.addDirectory(selectedDir);
        
        // Close loading dialog
        Navigator.of(context).pop();
        
        // Refresh the UI
        setState(() {});
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Folder added to library'),
        ));
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error adding folder: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
      
      Logger.error('Error adding folder', e);
    }
  }
  
  // Remove a directory from watch list
  Future<void> _removeDirectory(LibraryManager libraryManager, String directory) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Directory'),
          content: const Text('Are you sure you want to remove this directory? Files in this directory will be removed from your library.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      
      if (confirmed == true) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            title: Text('Removing Directory'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Removing directory from library...'),
              ],
            ),
          ),
        );
        
        // Remove the directory
        await libraryManager.removeDirectory(directory);
        
        // Close loading dialog
        Navigator.of(context).pop();
        
        // Refresh the UI
        setState(() {});
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Directory removed from library'),
        ));
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error removing directory: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
      
      Logger.error('Error removing directory', e);
    }
  }
  
  // Clear cache
  Future<void> _clearCache() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<String>( // Change from bool to String
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Cache'),
          content: const Text('What would you like to clear?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'cache'),
              child: const Text('Search Cache Only'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'all'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('All Metadata'),
            ),
          ],
        ),
      );
      
      if (confirmed == 'cache' || confirmed == 'all') {
        setState(() {
          _isLoading = true;
        });
        
        // Clear the metadata cache
        final metadataCache = Provider.of<MetadataCache>(context, listen: false);
        await metadataCache.clearCache();
        
        // Clear storage manager metadata if requested
        if (confirmed == 'all') {
          final storageManager = Provider.of<AudiobookStorageManager>(context, listen: false);
          
          // Get application documents directory
          final appDir = await getApplicationDocumentsDirectory();
          final metadataPath = path.join(appDir.path, 'audiobooks', 'metadata');
          
          // Delete the metadata directory and recreate it
          final metadataDir = Directory(metadataPath);
          if (await metadataDir.exists()) {
            await metadataDir.delete(recursive: true);
            await metadataDir.create(recursive: true);
          }
          
          // Optionally, also reset the library file
          final libraryFile = File(storageManager.libraryFilePath);
          if (await libraryFile.exists()) {
            await libraryFile.writeAsString(json.encode({'files': []}));
          }
        }
        
        // Refresh cache size
        _cacheSize = await _calculateCacheSize();
        
        setState(() {
          _isLoading = false;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(confirmed == 'all' ? 'All metadata cleared' : 'Cache cleared'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error clearing cache: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
      
      Logger.error('Error clearing cache', e);
    }
  }
  
  // Rescan library
  Future<void> _rescanLibrary() async {
    try {
      // Show confirmation dialog
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rescan Library'),
          content: const Text('How would you like to rescan your library?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'scan'),
              child: const Text('Scan for New Files'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'full'),
              child: const Text('Full Rescan (Update All Metadata)'),
            ),
          ],
        ),
      );
      
      if (result == 'scan' || result == 'full') {
        setState(() {
          _isLoading = true;
        });
        
        // Rescan the library
        final libraryManager = Provider.of<LibraryManager>(context, listen: false);
        await libraryManager.rescanLibrary(forceMetadataUpdate: result == 'full');
        
        setState(() {
          _isLoading = false;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Library rescan complete'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error rescanning library: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
      
      Logger.error('Error rescanning library', e);
    }
  }
  
  // Save settings
  Future<void> _saveSettings() async {
    try {
      // Save settings - This would typically use SharedPreferences
      // For now, we'll just update the audio player service
      final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
      
      // Update skip durations
      // Note: This would actually be implemented in the AudioPlayerService class
      // These are placeholder calls for now
      // audioPlayerService.setSkipForwardDuration(Duration(seconds: _skipForwardSeconds));
      // audioPlayerService.setSkipBackwardDuration(Duration(seconds: _skipBackwardSeconds));
      
      // Would normally save these to SharedPreferences
    } catch (e) {
      Logger.error('Error saving settings', e);
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error saving settings: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
    }
  }
  
  // View logs
  void _viewLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LogViewerScreen(),
      ),
    );
  }
}

// Log viewer screen
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  _LogViewerScreenState createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  String _logs = '';
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadLogs();
  }
  
  // Load logs
  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDir.path}/logs');
      
      if (!await logDir.exists()) {
        setState(() {
          _logs = 'No logs found';
          _isLoading = false;
        });
        return;
      }
      
      // Find the most recent log file
      File? latestLogFile;
      DateTime latestDate = DateTime(1970);
      
      await for (final entity in logDir.list()) {
        if (entity is File && entity.path.endsWith('.txt')) {
          final fileName = path.basename(entity.path);
          final match = RegExp(r'log_(\d{4})-(\d{1,2})-(\d{1,2})\.txt').firstMatch(fileName);
          
          if (match != null) {
            final year = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final day = int.parse(match.group(3)!);
            
            final fileDate = DateTime(year, month, day);
            if (fileDate.isAfter(latestDate)) {
              latestDate = fileDate;
              latestLogFile = entity;
            }
          }
        }
      }
      
      if (latestLogFile != null) {
        _logs = await latestLogFile.readAsString();
      } else {
        _logs = 'No logs found';
      }
    } catch (e) {
      _logs = 'Error loading logs: ${e.toString()}';
      Logger.error('Error loading logs', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(_logs),
              ),
            ),
    );
  }
  
  // Share logs
  Future<void> _shareLogs() async {
    // This would typically use a share plugin
    // For now, we'll just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Sharing logs is not implemented yet'),
    ));
  }
}