// lib/storage/audiobook_storage_manager.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// Manages persistent storage for audiobook metadata and covers
class AudiobookStorageManager {
  // Directory structure constants
  static const String _baseDir = 'audiobooks';
  static const String _metadataDir = 'metadata';
  static const String _coversDir = 'covers';
  static const String _cacheDir = 'cache';
  static const String _libraryFile = 'library.json';
  
  // Base directory for all storage
  late final String _baseDirPath;
  late final String _metadataDirPath;
  late final String _coversDirPath;
  late final String _cacheDirPath;
  
  // Initialize storage manager
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _baseDirPath = path_util.join(appDir.path, _baseDir);
      _metadataDirPath = path_util.join(_baseDirPath, _metadataDir);
      _coversDirPath = path_util.join(_baseDirPath, _coversDir);
      _cacheDirPath = path_util.join(_baseDirPath, _cacheDir);
      
      // Ensure directories exist
      await Directory(_baseDirPath).create(recursive: true);
      await Directory(_metadataDirPath).create(recursive: true);
      await Directory(_coversDirPath).create(recursive: true);
      await Directory(_cacheDirPath).create(recursive: true);
      
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
      // Generate a standardized ID for this file
      final String fileId = _generateFileId(filePath);
      final String metadataFilePath = path_util.join(_metadataDirPath, '$fileId.json');
      
      // Check if metadata already exists
      final File metadataFile = File(metadataFilePath);
      if (await metadataFile.exists() && !force) {
        // If not forcing an update, merge with existing metadata
        final existingJson = await metadataFile.readAsString();
        final existingMetadata = AudiobookMetadata.fromJson(json.decode(existingJson));
        
        // Merge the metadata, preferring the new metadata for most fields
        final mergedMetadata = existingMetadata.merge(metadata);
        
        // Write the merged metadata
        await metadataFile.writeAsString(json.encode(mergedMetadata.toJson()));
        Logger.log('Updated metadata for file: $filePath (merged)');
        return true;
      } else {
        // Write new metadata or force overwrite
        await metadataFile.writeAsString(json.encode(metadata.toJson()));
        Logger.log('Updated metadata for file: $filePath (new or forced)');
        return true;
      }
    } catch (e) {
      Logger.error('Error updating metadata for file: $filePath', e);
      return false;
    }
  }
  
  // Get metadata for a file
  Future<AudiobookMetadata?> getMetadataForFile(String filePath) async {
    try {
      final String fileId = _generateFileId(filePath);
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
  
  // Ensure a cover image is stored in the covers directory
  Future<String> ensureCoverImage(String filePath, String sourcePath, {bool force = false}) async {
    try {
      final String fileId = _generateFileId(filePath);
      final String coverPath = path_util.join(_coversDirPath, '$fileId.jpg');
      
      final File coverFile = File(coverPath);
      if (await coverFile.exists() && !force) {
        // Cover already exists
        return coverPath;
      }
      
      // Copy or download the cover image
      final File sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        // Copy the file
        await sourceFile.copy(coverPath);
        Logger.log('Copied cover image to: $coverPath');
        return coverPath;
      } else {
        throw Exception('Source cover image does not exist: $sourcePath');
      }
    } catch (e) {
      Logger.error('Error ensuring cover image for file: $filePath', e);
      rethrow;
    }
  }
  
  // Download a cover image from a URL
  Future<String?> downloadCoverImage(String filePath, String imageUrl) async {
    try {
      final String fileId = _generateFileId(filePath);
      final String coverPath = path_util.join(_coversDirPath, '$fileId.jpg');
      
      // Use http client to download the image
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(imageUrl));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        await File(coverPath).writeAsBytes(bytes);
        Logger.log('Downloaded cover image to: $coverPath');
        return coverPath;
      } else {
        Logger.error('Failed to download cover image. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      Logger.error('Error downloading cover image for file: $filePath', e);
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
  
  // Update user data for a file (rating, playback position, etc.)
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
      
      // Save the updated metadata
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
  
  // Generate a consistent ID for a file path
  String _generateFileId(String filePath) {
    // Create a deterministic ID based on the file path
    // This ensures the same file always gets the same ID
    return filePath.hashCode.abs().toString();
  }
  
  // Helper function to consolidate HttpClientResponse bytes
  Future<List<int>> consolidateHttpClientResponseBytes(HttpClientResponse response) async {
    final List<List<int>> chunks = [];
    final int contentLength = response.contentLength > 0 
        ? response.contentLength 
        : 1024 * 1024; // Default to 1MB if content length is unknown
    
    int totalLength = 0;
    await for (final List<int> chunk in response) {
      chunks.add(chunk);
      totalLength += chunk.length;
    }
    
    if (chunks.length == 1) {
      return chunks.first;
    }
    
    final Uint8List result = Uint8List(totalLength);
    int offset = 0;
    for (final List<int> chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }
}