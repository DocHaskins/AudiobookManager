// File: lib/ui/screens/settings_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:async';

import 'package:audiobook_organizer/storage/user_preferences.dart';
import 'package:audiobook_organizer/services/audiobook_scanner.dart';
import 'package:audiobook_organizer/services/providers/google_books_provider.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Controllers
  final _apiKeyController = TextEditingController();
  final _namingPatternController = TextEditingController();
  final _scrollController = ScrollController(); // Add explicit ScrollController
  
  // State variables
  String? _defaultDirectory;
  bool _isLoading = true;
  bool _isTestingApiKey = false;
  bool _showScanOptions = false;
  bool _includeSubfolders = true;
  List<String> _supportedExtensions = [];
  
  // API key test result
  String? _apiKeyTestResult;
  bool? _apiKeyValid;
  
  @override
  void initState() {
    super.initState();
    // Delay loading to avoid UI blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferences();
      _loadSupportedExtensions();
    });
  }
  
  @override
  void dispose() {
    _apiKeyController.dispose();
    _namingPatternController.dispose();
    _scrollController.dispose(); // Dispose ScrollController when done
    super.dispose();
  }
  
  Future<void> _loadPreferences() async {
    if (!mounted) return;
    
    try {
      final prefs = Provider.of<UserPreferences>(context, listen: false);
      
      final apiKey = await prefs.getApiKey();
      final defaultDir = await prefs.getDefaultDirectory();
      final pattern = await prefs.getNamingPattern();
      final includeSubfolders = await prefs.getIncludeSubfolders();
      
      if (!mounted) return;
      setState(() {
        _apiKeyController.text = apiKey ?? '';
        _defaultDirectory = defaultDir;
        _namingPatternController.text = pattern;
        _includeSubfolders = includeSubfolders;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading preferences: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _loadSupportedExtensions() async {
    if (!mounted) return;
    
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
      
      await prefs.saveApiKey(_apiKeyController.text.trim());
      await prefs.saveNamingPattern(_namingPatternController.text.trim());
      await prefs.saveIncludeSubfolders(_includeSubfolders);
      
      if (_defaultDirectory != null) {
        await prefs.saveDefaultDirectory(_defaultDirectory!);
      }
      
      // Update the GoogleBooksProvider with the new API key
      final googleProvider = Provider.of<GoogleBooksProvider>(context, listen: false);
      googleProvider.updateApiKey(_apiKeyController.text.trim());
      
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error saving preferences: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      final testProvider = GoogleBooksProvider(apiKey: apiKey);
      // Use a timeout to prevent indefinite hanging
      const timeout = Duration(seconds: 10);
      
      final results = await testProvider.search('Harry Potter')
          .timeout(timeout, onTimeout: () => throw TimeoutException('Request timed out'));
      
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _isTestingApiKey = false;
        _apiKeyTestResult = 'Error: ${e.toString()}';
        _apiKeyValid = false;
      });
    }
  }
  
  Future<void> _launchGoogleCloudConsole() async {
    final Uri url = Uri.parse('https://console.cloud.google.com/apis/library/books.googleapis.com');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open URL'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening URL: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton.icon(
            onPressed: _savePreferences,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView( // Use ListView directly instead of Scrollbar+SingleChildScrollView
                controller: _scrollController, // Attach controller to ListView
                padding: const EdgeInsets.all(16),
                children: [
                  _buildApiSection(theme),
                  const SizedBox(height: 24),
                  _buildFileManagementSection(theme),
                  const SizedBox(height: 24),
                  _buildScanningOptionsSection(theme),
                  const SizedBox(height: 24),
                  _buildAboutSection(theme),
                  const SizedBox(height: 32),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _savePreferences,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
  
  Widget _buildApiSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
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
                  style: textTheme.titleMedium?.copyWith(
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
                        style: textTheme.bodySmall?.copyWith(
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
                  onPressed: _launchGoogleCloudConsole,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Get API Key'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            Text(
              'A Google Books API key is required to search for book metadata. '
              'You can get a free API key from the Google Cloud Console.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileManagementSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
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
                  style: textTheme.titleMedium?.copyWith(
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
    final textTheme = theme.textTheme;
    
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAboutSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
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
                  style: textTheme.titleMedium?.copyWith(
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
                '© 2023 AudioBook Organizer',
                style: textTheme.bodySmall?.copyWith(
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