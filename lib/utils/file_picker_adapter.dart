// File: lib/utils/file_picker_adapter.dart
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:audiobook_organizer/utils/logger.dart';

/// This adapter connects our debug tools to the file_selector package
class FilePicker {
  static final platform = _FilePicker();
}

class _FilePicker {
  /// Pick a directory using the file_selector package
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    try {
      // Call the file_selector's getDirectoryPath
      final String? directory = await file_selector.getDirectoryPath(
        initialDirectory: initialDirectory,
        confirmButtonText: confirmButtonText ?? 'Select',
      );
      
      return directory;
    } catch (e) {
      Logger.debug('Error picking directory: $e');
      return null;
    }
  }

  /// Pick files using the file_selector package
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    bool allowMultiple = false,
  }) async {
    try {
      List<file_selector.XFile> files = [];
      
      if (allowMultiple) {
        // Handle multiple file selection
        final List<file_selector.XFile> result = await file_selector.openFiles(
          acceptedTypeGroups: [
            _getTypeGroup(type),
          ],
        );
        files = result;
      } else {
        // Handle single file selection
        final file_selector.XFile? result = await file_selector.openFile(
          acceptedTypeGroups: [
            _getTypeGroup(type),
          ],
        );
        if (result != null) {
          files = [result];
        }
      }
      
      if (files.isEmpty) {
        return null;
      }
      
      // Convert XFile to PlatformFile
      final platformFiles = files.map((file) => 
        PlatformFile(path: file.path, name: file.name)
      ).toList();
      
      return FilePickerResult(platformFiles);
    } catch (e) {
      Logger.debug('Error picking files: $e');
      return null;
    }
  }
  
  /// Create the appropriate XTypeGroup based on the FileType
  file_selector.XTypeGroup _getTypeGroup(FileType type) {
    switch (type) {
      case FileType.audio:
        return const file_selector.XTypeGroup(
          label: 'Audio Files',
          extensions: ['mp3', 'm4a', 'm4b', 'aac', 'flac', 'ogg', 'wma', 'wav', 'opus'],
        );
      case FileType.image:
        return const file_selector.XTypeGroup(
          label: 'Image Files',
          extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'],
        );
      case FileType.video:
        return const file_selector.XTypeGroup(
          label: 'Video Files',
          extensions: ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm'],
        );
      case FileType.media:
        return const file_selector.XTypeGroup(
          label: 'Media Files',
          extensions: [
            'mp3', 'm4a', 'm4b', 'aac', 'flac', 'ogg', 'wma', 'wav', 'opus',
            'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
          ],
        );
      case FileType.any:
      default:
        return const file_selector.XTypeGroup(
          label: 'All Files',
          extensions: ['*'],
        );
    }
  }
}

/// Result class for file picking
class FilePickerResult {
  final List<PlatformFile> files;
  
  FilePickerResult(this.files);
}

/// Platform file representation
class PlatformFile {
  final String path;
  final String name;
  
  PlatformFile({required this.path, required this.name});
}

/// Type of files to pick
enum FileType { 
  any, 
  audio, 
  image, 
  video, 
  media 
}