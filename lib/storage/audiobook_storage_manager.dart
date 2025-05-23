// lib/storage/audiobook_storage_manager.dart - REFACTORED
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/file_utils.dart';

/// Manages persistent storage for audiobook metadata (covers handled by CoverArtManager)
class AudiobookStorageManager {
  // Directory structure constants
  static const String _baseDir = 'audiobooks';
  static const String _metadataDir = 'metadata';
  static const String _libraryFile = 'library.json';
  
  // Base directory for all storage
  late final String _baseDirPath;
  late final String _metadataDirPath;
  
  // Initialize storage manager
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _baseDirPath = path_util.join(appDir.path, _baseDir);
      _metadataDirPath = path_util.join(_baseDirPath, _metadataDir);
      
      // Ensure directories exist
      await Directory(_baseDirPath).create(recursive: true);
      await Directory(_metadataDirPath).create(recursive: true);
      
      Logger.log('AudiobookStorageManager initialized');
    } catch (e) {
      Logger.error('Error initializing AudiobookStorageManager', e);
      rethrow;
    }
  }
  
  // Get the library JSON file path
  String get libraryFilePath => path_util.join(_baseDirPath, _libraryFile);
  
  // Update metadata for a file
  Future<bool> updateMetadataForFile(String filePath, AudiobookMetadata metadata, {bool force = false}) async {
    try {
      // Use centralized file ID generation
      final String fileId = FileUtils.generateFileId(filePath);
      final String metadataFilePath = path_util.join(_metadataDirPath, '$fileId.json');
      
      final File metadataFile = File(metadataFilePath);
      AudiobookMetadata finalMetadata = metadata;
      
      if (await metadataFile.exists() && !force) {
        // If not forcing, merge with existing metadata
        try {
          final existingJson = await metadataFile.readAsString();
          final existingMetadata = AudiobookMetadata.fromJson(json.decode(existingJson));
          
          // Use the built-in merge method
          finalMetadata = metadata.merge(existingMetadata);
          
          Logger.debug('Merged metadata for file: $filePath');
        } catch (e) {
          Logger.warning('Error merging existing metadata, using new metadata: $e');
          finalMetadata = metadata;
        }
      }
      
      // Write the final metadata
      await metadataFile.writeAsString(json.encode(finalMetadata.toJson()));
      
      Logger.log('${force ? "Force u" : "U"}pdated metadata for file: $filePath');
      return true;
    } catch (e) {
      Logger.error('Error updating metadata for file: $filePath', e);
      return false;
    }
  }
  
  // Get metadata for a file
  Future<AudiobookMetadata?> getMetadataForFile(String filePath) async {
    try {
      final String fileId = FileUtils.generateFileId(filePath);
      final String metadataFilePath = path_util.join(_metadataDirPath, '$fileId.json');
      
      final File metadataFile = File(metadataFilePath);
      if (await metadataFile.exists()) {
        final String jsonString = await metadataFile.readAsString();
        return AudiobookMetadata.fromJson(json.decode(jsonString));
      }
      
      return null;
    } catch (e) {
      Logger.error('Error getting metadata for file: $filePath', e);
      return null;
    }
  }

  // Save the library state (list of all audiobooks)
  Future<bool> saveLibrary(List<AudiobookFile> files) async {
    try {
      final File libraryFile = File(libraryFilePath);
      
      // Convert files to a simpler format for storage
      final List<Map<String, dynamic>> fileList = files.map((file) => {
        'path': file.path,
        'lastModified': file.lastModified.toIso8601String(),
        'fileSize': file.fileSize,
      }).toList();
      
      // Save to file
      await libraryFile.writeAsString(json.encode({'files': fileList}));
      Logger.log('Saved library with ${files.length} files');
      return true;
    } catch (e) {
      Logger.error('Error saving library', e);
      return false;
    }
  }
  
  // Load the library state
  Future<List<AudiobookFile>> loadLibrary() async {
    try {
      final File libraryFile = File(libraryFilePath);
      
      if (!await libraryFile.exists()) {
        Logger.log('Library file does not exist');
        return [];
      }
      
      final String jsonString = await libraryFile.readAsString();
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> fileList = jsonData['files'] ?? [];
      
      // Convert to AudiobookFile instances
      final List<AudiobookFile> files = [];
      
      for (final fileData in fileList) {
        final String filePath = fileData['path'];
        final File file = File(filePath);
        
        // Check if file still exists
        if (await file.exists()) {
          final audioFile = AudiobookFile(
            path: filePath,
            lastModified: DateTime.parse(fileData['lastModified']),
            fileSize: fileData['fileSize'],
          );
          
          // Load metadata
          audioFile.metadata = await getMetadataForFile(filePath);
          
          files.add(audioFile);
        } else {
          Logger.warning('File no longer exists: $filePath');
        }
      }
      
      Logger.log('Loaded library with ${files.length} files');
      return files;
    } catch (e) {
      Logger.error('Error loading library', e);
      return [];
    }
  }
  
  // Update user data for a file
  Future<bool> updateUserData(String filePath, {
    int? userRating,
    DateTime? lastPlayedPosition,
    Duration? playbackPosition,
    List<String>? userTags,
    bool? isFavorite,
    List<AudiobookBookmark>? bookmarks,
    List<AudiobookNote>? notes,
  }) async {
    try {
      final metadata = await getMetadataForFile(filePath);
      if (metadata == null) {
        Logger.warning('No metadata found for file: $filePath');
        return false;
      }
      
      // Update with new user data
      final updatedMetadata = metadata.copyWith(
        userRating: userRating ?? metadata.userRating,
        lastPlayedPosition: lastPlayedPosition ?? metadata.lastPlayedPosition,
        playbackPosition: playbackPosition ?? metadata.playbackPosition,
        userTags: userTags ?? metadata.userTags,
        isFavorite: isFavorite ?? metadata.isFavorite,
        bookmarks: bookmarks ?? metadata.bookmarks,
        notes: notes ?? metadata.notes,
      );
      
      // Save the updated metadata with force=true to ensure it's written
      return await updateMetadataForFile(filePath, updatedMetadata, force: true);
    } catch (e) {
      Logger.error('Error updating user data for file: $filePath', e);
      return false;
    }
  }
  
  // Add a bookmark for a file
  Future<bool> addBookmark(String filePath, AudiobookBookmark bookmark) async {
    try {
      final metadata = await getMetadataForFile(filePath);
      if (metadata == null) {
        Logger.warning('No metadata found for file: $filePath');
        return false;
      }
      
      // Create new list with added bookmark
      final bookmarks = List<AudiobookBookmark>.from(metadata.bookmarks);
      
      // Check if bookmark with same ID exists and replace it
      final existingIndex = bookmarks.indexWhere((b) => b.id == bookmark.id);
      if (existingIndex >= 0) {
        bookmarks[existingIndex] = bookmark;
      } else {
        bookmarks.add(bookmark);
      }
      
      // Update metadata with new bookmarks list
      return await updateUserData(filePath, bookmarks: bookmarks);
    } catch (e) {
      Logger.error('Error adding bookmark for file: $filePath', e);
      return false;
    }
  }
  
  // Remove a bookmark for a file
  Future<bool> removeBookmark(String filePath, String bookmarkId) async {
    try {
      final metadata = await getMetadataForFile(filePath);
      if (metadata == null) {
        Logger.warning('No metadata found for file: $filePath');
        return false;
      }
      
      // Create new list without the bookmark
      final bookmarks = metadata.bookmarks.where((b) => b.id != bookmarkId).toList();
      
      // Update metadata with new bookmarks list
      return await updateUserData(filePath, bookmarks: bookmarks);
    } catch (e) {
      Logger.error('Error removing bookmark for file: $filePath', e);
      return false;
    }
  }
  
  // Add a note for a file
  Future<bool> addNote(String filePath, AudiobookNote note) async {
    try {
      final metadata = await getMetadataForFile(filePath);
      if (metadata == null) {
        Logger.warning('No metadata found for file: $filePath');
        return false;
      }
      
      // Create new list with added note
      final notes = List<AudiobookNote>.from(metadata.notes);
      
      // Check if note with same ID exists and replace it
      final existingIndex = notes.indexWhere((n) => n.id == note.id);
      if (existingIndex >= 0) {
        notes[existingIndex] = note;
      } else {
        notes.add(note);
      }
      
      // Update metadata with new notes list
      return await updateUserData(filePath, notes: notes);
    } catch (e) {
      Logger.error('Error adding note for file: $filePath', e);
      return false;
    }
  }
  
  // Remove a note for a file
  Future<bool> removeNote(String filePath, String noteId) async {
    try {
      final metadata = await getMetadataForFile(filePath);
      if (metadata == null) {
        Logger.warning('No metadata found for file: $filePath');
        return false;
      }
      
      // Create new list without the note
      final notes = metadata.notes.where((n) => n.id != noteId).toList();
      
      // Update metadata with new notes list
      return await updateUserData(filePath, notes: notes);
    } catch (e) {
      Logger.error('Error removing note for file: $filePath', e);
      return false;
    }
  }
}