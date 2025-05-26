// lib/storage/audiobook_storage_manager.dart - UPDATED to support all three operations
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
  
  // ENHANCED: Update metadata with explicit operation type
  Future<bool> updateMetadataForFile(
    String filePath, 
    AudiobookMetadata metadata, {
    bool force = false,
    MetadataUpdateOperation operation = MetadataUpdateOperation.enhance,
  }) async {
    try {
      // Use centralized file ID generation
      final String fileId = FileUtils.generateFileId(filePath);
      final String metadataFilePath = path_util.join(_metadataDirPath, '$fileId.json');
      
      final File metadataFile = File(metadataFilePath);
      AudiobookMetadata finalMetadata = metadata;
      
      if (await metadataFile.exists() && !force) {
        // If not forcing, apply the specified operation
        try {
          final existingJson = await metadataFile.readAsString();
          final existingMetadata = AudiobookMetadata.fromJson(json.decode(existingJson));
          
          // Apply the appropriate operation
          switch (operation) {
            case MetadataUpdateOperation.enhance:
              finalMetadata = existingMetadata.enhance(metadata);
              Logger.debug('Enhanced metadata for file: $filePath');
              break;
            case MetadataUpdateOperation.updateVersion:
              finalMetadata = existingMetadata.updateVersion(metadata);
              Logger.debug('Updated to new version for file: $filePath');
              break;
            case MetadataUpdateOperation.replaceBook:
              finalMetadata = existingMetadata.replaceBook(metadata);
              Logger.debug('Replaced with different book for file: $filePath');
              break;
            case MetadataUpdateOperation.directSave:
              finalMetadata = metadata;
              Logger.debug('Direct save (no merge) for file: $filePath');
              break;
          }
        } catch (e) {
          Logger.warning('Error processing existing metadata, using new metadata: $e');
          finalMetadata = metadata;
        }
      } else {
        // Force = true or no existing file, use metadata directly
        finalMetadata = metadata;
      }
      
      // Write the final metadata
      await metadataFile.writeAsString(json.encode(finalMetadata.toJson()));
      
      Logger.log('${force ? "Force " : ""}${operation.name} metadata for file: $filePath');
      return true;
    } catch (e) {
      Logger.error('Error updating metadata for file: $filePath', e);
      return false;
    }
  }
  
  // ENHANCED: Direct methods for each operation type
  Future<bool> enhanceMetadataForFile(String filePath, AudiobookMetadata enhancement) async {
    return updateMetadataForFile(
      filePath, 
      enhancement, 
      operation: MetadataUpdateOperation.enhance,
    );
  }
  
  Future<bool> updateVersionForFile(String filePath, AudiobookMetadata newVersion) async {
    return updateMetadataForFile(
      filePath, 
      newVersion, 
      operation: MetadataUpdateOperation.updateVersion,
    );
  }
  
  Future<bool> replaceBookForFile(String filePath, AudiobookMetadata newBook) async {
    return updateMetadataForFile(
      filePath, 
      newBook, 
      operation: MetadataUpdateOperation.replaceBook,
    );
  }
  
  Future<bool> forceUpdateMetadataForFile(String filePath, AudiobookMetadata metadata) async {
    return updateMetadataForFile(
      filePath, 
      metadata, 
      force: true,
      operation: MetadataUpdateOperation.directSave,
    );
  }
  
  // Get metadata for a file
  Future<AudiobookMetadata?> getMetadataForFile(String filePath) async {
    try {
      final String fileId = FileUtils.generateFileId(filePath);
      final String metadataFilePath = path_util.join(_metadataDirPath, '$fileId.json');
      
      final File metadataFile = File(metadataFilePath);
      if (await metadataFile.exists()) {
        final String jsonString = await metadataFile.readAsString();
        final metadata = AudiobookMetadata.fromJson(json.decode(jsonString));
        Logger.debug('Retrieved metadata for file: $filePath');
        return metadata;
      }
      
      Logger.debug('No metadata found for file: $filePath');
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
      await libraryFile.writeAsString(json.encode({
        'files': fileList,
        'lastUpdated': DateTime.now().toIso8601String(),
        'version': '1.0',
      }));
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
        Logger.log('Library file does not exist, returning empty library');
        return [];
      }
      
      final String jsonString = await libraryFile.readAsString();
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> fileList = jsonData['files'] ?? [];
      
      // Convert to AudiobookFile instances
      final List<AudiobookFile> files = [];
      int loadedCount = 0;
      int missingCount = 0;
      
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
          loadedCount++;
        } else {
          Logger.warning('File no longer exists: $filePath');
          missingCount++;
        }
      }
      
      Logger.log('Loaded library: $loadedCount files loaded, $missingCount files missing');
      return files;
    } catch (e) {
      Logger.error('Error loading library', e);
      return [];
    }
  }
  
  // ENHANCED: Update user data with explicit force
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
      
      // Force save the updated metadata to ensure user data is preserved
      return await forceUpdateMetadataForFile(filePath, updatedMetadata);
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
        Logger.log('Updated existing bookmark for file: $filePath');
      } else {
        bookmarks.add(bookmark);
        Logger.log('Added new bookmark for file: $filePath');
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
      
      Logger.log('Removed bookmark $bookmarkId for file: $filePath');
      
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
        Logger.log('Updated existing note for file: $filePath');
      } else {
        notes.add(note);
        Logger.log('Added new note for file: $filePath');
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
      
      Logger.log('Removed note $noteId for file: $filePath');
      
      // Update metadata with new notes list
      return await updateUserData(filePath, notes: notes);
    } catch (e) {
      Logger.error('Error removing note for file: $filePath', e);
      return false;
    }
  }
  
  // UTILITY: Delete metadata for a file (cleanup)
  Future<bool> deleteMetadataForFile(String filePath) async {
    try {
      final String fileId = FileUtils.generateFileId(filePath);
      final String metadataFilePath = path_util.join(_metadataDirPath, '$fileId.json');
      
      final File metadataFile = File(metadataFilePath);
      if (await metadataFile.exists()) {
        await metadataFile.delete();
        Logger.log('Deleted metadata for file: $filePath');
        return true;
      }
      
      return false;
    } catch (e) {
      Logger.error('Error deleting metadata for file: $filePath', e);
      return false;
    }
  }
  
  // UTILITY: Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final metadataDir = Directory(_metadataDirPath);
      final files = await metadataDir.list().toList();
      final metadataFileCount = files.where((f) => f.path.endsWith('.json')).length;
      
      int totalSize = 0;
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }
      
      return {
        'metadataFiles': metadataFileCount,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'basePath': _baseDirPath,
      };
    } catch (e) {
      Logger.error('Error getting storage stats', e);
      return {};
    }
  }
  
  // UTILITY: Cleanup orphaned metadata files
  Future<int> cleanupOrphanedMetadata(List<String> validFilePaths) async {
    try {
      final metadataDir = Directory(_metadataDirPath);
      if (!await metadataDir.exists()) return 0;
      
      final validFileIds = validFilePaths.map((path) => FileUtils.generateFileId(path)).toSet();
      final files = await metadataDir.list().toList();
      
      int deletedCount = 0;
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          final fileName = path_util.basenameWithoutExtension(file.path);
          if (!validFileIds.contains(fileName)) {
            await file.delete();
            deletedCount++;
            Logger.log('Deleted orphaned metadata file: ${file.path}');
          }
        }
      }
      
      Logger.log('Cleanup complete: deleted $deletedCount orphaned metadata files');
      return deletedCount;
    } catch (e) {
      Logger.error('Error during metadata cleanup', e);
      return 0;
    }
  }
}

// Enum to specify the type of metadata update operation
enum MetadataUpdateOperation {
  enhance,      // Fill missing data only
  updateVersion, // Replace metadata but keep user data
  replaceBook,  // Replace everything including resetting user data
  directSave,   // Force save without any merging
}