// File: lib/storage/user_preferences.dart
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  // Keys for SharedPreferences
  static const String _apiKeyKey = 'google_books_api_key';
  static const String _defaultDirKey = 'default_directory';
  static const String _namingPatternKey = 'naming_pattern';
  static const String _includeSubfoldersKey = 'include_subfolders';
  static const String _lastScanDirectoryKey = 'last_scan_directory';
  static const String _useDarkModeKey = 'use_dark_mode';
  static const String _autoMatchNewFilesKey = 'auto_match_new_files';
  
  // Default values
  static const String defaultNamingPattern = '{Author} - {Title}';
  
  // Save API key
  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
  }
  
  // Get API key
  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }
  
  // Save default directory
  Future<void> saveDefaultDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultDirKey, path);
  }
  
  // Get default directory
  Future<String?> getDefaultDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultDirKey);
  }
  
  // Save naming pattern
  Future<void> saveNamingPattern(String pattern) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_namingPatternKey, pattern);
  }
  
  // Get naming pattern
  Future<String> getNamingPattern() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_namingPatternKey) ?? defaultNamingPattern;
  }
  
  // Save include subfolders setting
  Future<void> saveIncludeSubfolders(bool include) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_includeSubfoldersKey, include);
  }
  
  // Get include subfolders setting
  Future<bool> getIncludeSubfolders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_includeSubfoldersKey) ?? true;
  }
  
  // Save last scan directory
  Future<void> saveLastScanDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastScanDirectoryKey, path);
  }
  
  // Get last scan directory
  Future<String?> getLastScanDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastScanDirectoryKey);
  }
  
  // Save dark mode setting
  Future<void> saveUseDarkMode(bool useDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDarkModeKey, useDarkMode);
  }
  
  // Get dark mode setting
  Future<bool?> getUseDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useDarkModeKey);
  }
  
  // Save auto match setting
  Future<void> saveAutoMatchNewFiles(bool autoMatch) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoMatchNewFilesKey, autoMatch);
  }
  
  // Get auto match setting
  Future<bool> getAutoMatchNewFiles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoMatchNewFilesKey) ?? false;
  }
  
  // Reset all settings to defaults
  Future<void> resetAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyKey);
    await prefs.remove(_defaultDirKey);
    await prefs.remove(_lastScanDirectoryKey);
    await prefs.setString(_namingPatternKey, defaultNamingPattern);
    await prefs.setBool(_includeSubfoldersKey, true);
    await prefs.remove(_useDarkModeKey);
    await prefs.setBool(_autoMatchNewFilesKey, false);
  }
}