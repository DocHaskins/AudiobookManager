// File: lib/ui/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import 'package:audiobook_organizer/storage/user_preferences.dart';
import 'package:audiobook_organizer/services/audiobook_scanner.dart';
import 'package:audiobook_organizer/services/providers/google_books_provider.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/storage/library_storage.dart';
import 'package:audiobook_organizer/main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Controllers
  final _apiKeyController = TextEditingController();
  final _namingPatternController = TextEditingController();
  
  // State variables
  String? _defaultDirectory;
  bool _isLoading = true;
  bool _isTestingApiKey = false;
  bool _includeSubfolders = true;
  bool _autoMatchNewFiles = false;
  bool _useDarkMode = false;
  List<String> _supportedExtensions = [];
  
  // API key test result
  String? _apiKeyTestResult;
  bool? _apiKeyValid;
  
  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadSupportedExtensions();
  }
  
  @override
  void dispose() {
    _apiKeyController.dispose();
    _namingPatternController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPreferences() async {
    if (!mounted) return;
    
    try {
      final prefs = Provider.of<UserPreferences>(context, listen: false);
      final themeProvider = Provider.of<ThemeModeProvider>(context, listen: false);
      
      final apiKey = await prefs.getApiKey();
      final defaultDir = await prefs.getDefaultDirectory();
      final pattern = await prefs.getNamingPattern();
      final includeSubfolders = await prefs.getIncludeSubfolders();
      final autoMatchNewFiles = await prefs.getAutoMatchNewFiles();
      final useDarkMode = await prefs.getUseDarkMode();
      
      setState(() {
        _apiKeyController.text = apiKey ?? '';
        _defaultDirectory = defaultDir;
        _namingPatternController.text = pattern;
        _includeSubfolders = includeSubfolders;
        _autoMatchNewFiles = autoMatchNewFiles;
        _useDarkMode = useDarkMode ?? false;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading preferences: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _loadSupportedExtensions() async {
    try {
      final scanner = Provider.of<AudiobookScanner>(context, listen: false);
      
      setState(() {
        _supportedExtensions = scanner.supportedExtensions;
      });
    } catch (e) {
      print('Error loading supported extensions: $e');
    }
  }
  
  Future<void> _savePreferences() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final prefs = Provider.of<UserPreferences>(context, listen: false);
      final themeProvider = Provider.of<ThemeModeProvider>(context, listen: false);
      
      await prefs.saveApiKey(_apiKeyController.text.trim());
      await prefs.saveNamingPattern(_namingPatternController.text.trim());
      await prefs.saveIncludeSubfolders(_includeSubfolders);
      await prefs.saveAutoMatchNewFiles(_autoMatchNewFiles);
      await prefs.saveUseDarkMode(_useDarkMode);
      
      if (_defaultDirectory != null) {
        await prefs.saveDefaultDirectory(_defaultDirectory!);
      }
      
      // Update the theme mode
      themeProvider.setThemeMode(_useDarkMode ? ThemeMode.dark : ThemeMode.light);
      
      // Update the GoogleBooksProvider with the new API key
      final googleProvider = Provider.of<GoogleBooksProvider>(context, listen: false);
      googleProvider.updateApiKey(_apiKeyController.text.trim());
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error saving preferences: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _selectDefaultDirectory() async {
    try {
      final String? directory = await getDirectoryPath(
        confirmButtonText: 'Select Folder',
      );
      
      if (directory != null && mounted) {
        setState(() {
          _defaultDirectory = directory;
        });
      }
    } catch (e) {
      print('Error selecting directory: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting directory: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _testApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _apiKeyTestResult = 'Please enter an API key';
        _apiKeyValid = false;
      });
      return;
    }
    
    setState(() {
      _isTestingApiKey = true;
      _apiKeyTestResult = null;
      _apiKeyValid = null;
    });
    
    try {
      final googleProvider = Provider.of<GoogleBooksProvider>(context, listen: false);
      googleProvider.updateApiKey(apiKey);
      
      // Try a simple search to test the API key
      final results = await googleProvider.search('Harry Potter');
      
      setState(() {
        _isTestingApiKey = false;
        if (results.isNotEmpty) {
          _apiKeyTestResult = 'API key is valid! Found ${results.length} books.';
          _apiKeyValid = true;
        } else {
          _apiKeyTestResult = 'API key may be valid, but no results were found.';
          _apiKeyValid = null;
        }
      });
    } catch (e) {
      setState(() {
        _isTestingApiKey = false;
        _apiKeyTestResult = 'Error: ${e.toString()}';
        _apiKeyValid = false;
      });
    }
  }
  
  Future<void> _clearMetadataCache() async {
    try {
      final metadataCache = Provider.of<MetadataCache>(context, listen: false);
      await metadataCache.clearCache();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metadata cache cleared'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error clearing metadata cache: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing metadata cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _resetAllSettings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'This will reset all settings to their default values and clear your library. '
          'Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        print('Starting library reset process...');
        
        // Reset user preferences
        final prefs = Provider.of<UserPreferences>(context, listen: false);
        await prefs.resetAllSettings();
        print('User preferences reset...');
        
        // Clear the metadata cache
        final metadataCache = Provider.of<MetadataCache>(context, listen: false);
        await metadataCache.clearCache();
        print('Metadata cache cleared...');
        
        // Clear the library storage
        final libraryStorage = Provider.of<LibraryStorage>(context, listen: false);
        await libraryStorage.clearLibrary();
        print('Library storage cleared...');
        
        // Reload preferences
        await _loadPreferences();
        
        // Force app to reload library screen when returning
        Navigator.of(context).pop(true); // Return true to indicate changes
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All settings reset to defaults and library cleared'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        print('Error resetting settings and library: $e');
        
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting settings: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton.icon(
            onPressed: _savePreferences,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // API Section
                  _buildApiSection(theme),
                  const SizedBox(height: 24),
                  
                  // Appearance Section
                  _buildAppearanceSection(theme),
                  const SizedBox(height: 24),
                  
                  // File Management Section
                  _buildFileManagementSection(theme),
                  const SizedBox(height: 24),
                  
                  // Scanning Options Section
                  _buildScanningOptionsSection(theme),
                  const SizedBox(height: 24),
                  
                  // Advanced Section
                  _buildAdvancedSection(theme),
                  const SizedBox(height: 24),
                  
                  // About Section
                  _buildAboutSection(theme),
                  const SizedBox(height: 32),
                  
                  // Save button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _savePreferences,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildApiSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.api,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'API Configuration',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Google Books API Key
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'Google Books API Key',
                border: const OutlineInputBorder(),
                helperText: 'Required for metadata lookup',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: _isTestingApiKey
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.check_circle),
                        onPressed: _testApiKey,
                        tooltip: 'Test API key',
                      ),
              ),
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
            ),
            
            if (_apiKeyTestResult != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _apiKeyValid == true
                      ? Colors.green.withOpacity(0.1)
                      : _apiKeyValid == false
                          ? Colors.red.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _apiKeyValid == true
                          ? Icons.check_circle
                          : _apiKeyValid == false
                              ? Icons.error
                              : Icons.info,
                      size: 16,
                      color: _apiKeyValid == true
                          ? Colors.green
                          : _apiKeyValid == false
                              ? Colors.red
                              : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _apiKeyTestResult!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _apiKeyValid == true
                              ? Colors.green
                              : _apiKeyValid == false
                                  ? Colors.red
                                  : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('https://console.cloud.google.com/apis/library/books.googleapis.com')),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Get API Key'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAppearanceSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Appearance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Dark mode toggle
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Use dark theme for the app'),
              value: _useDarkMode,
              onChanged: (value) {
                setState(() {
                  _useDarkMode = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileManagementSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'File Management',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Default Naming Pattern
            TextField(
              controller: _namingPatternController,
              decoration: const InputDecoration(
                labelText: 'Default Naming Pattern',
                border: OutlineInputBorder(),
                helperText: 'Example: {Author} - {Title}',
                prefixIcon: Icon(Icons.text_fields),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Default Directory
            ListTile(
              title: const Text('Default Directory'),
              subtitle: Text(_defaultDirectory ?? 'Not set'),
              trailing: IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: _selectDefaultDirectory,
              ),
              onTap: _selectDefaultDirectory,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScanningOptionsSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.search,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Scanning Options',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Include Subfolders
            SwitchListTile(
              title: const Text('Include Subfolders'),
              subtitle: const Text('Scan subfolders when scanning a directory'),
              value: _includeSubfolders,
              onChanged: (value) {
                setState(() {
                  _includeSubfolders = value;
                });
              },
            ),
            
            // Auto-match new files
            SwitchListTile(
              title: const Text('Auto-Match New Files'),
              subtitle: const Text('Automatically search for metadata when scanning new files'),
              value: _autoMatchNewFiles,
              onChanged: (value) {
                setState(() {
                  _autoMatchNewFiles = value;
                });
              },
            ),
            
            // Supported file extensions
            if (_supportedExtensions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Supported File Extensions:',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _supportedExtensions
                    .map((ext) => Chip(
                          label: Text(ext),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          labelStyle: const TextStyle(fontSize: 12),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildAdvancedSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Advanced',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text('Clear Metadata Cache'),
              subtitle: const Text('Remove saved metadata from cache'),
              onTap: _clearMetadataCache,
            ),
            
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.red),
              title: const Text('Reset All Settings'),
              subtitle: const Text('Restore default settings'),
              onTap: _resetAllSettings,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAboutSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'About',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            const ListTile(
              title: Text('AudioBook Organizer'),
              subtitle: Text('Version 1.0.0'),
            ),
            
            ListTile(
              title: const Text('Platform'),
              subtitle: Text(Platform.operatingSystem),
            ),
            
            const Divider(),
            
            Center(
              child: Text(
                '© 2025 AudioBook Organizer',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}