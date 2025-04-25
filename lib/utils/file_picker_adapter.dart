// File: lib/utils/file_picker_adapter.dart
import 'package:file_selector/file_selector.dart';

/// This adapter connects our debug tools to the file_selector package
class FilePicker {
  static final platform = _FilePicker();
}

class _FilePicker {
  /// Pick files using the file_selector package
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    bool allowMultiple = false,
  }) async {
    try {
      List<XFile> files = [];
      
      if (allowMultiple) {
        // Handle multiple file selection
        final List<XFile>? result = await openFiles(
          acceptedTypeGroups: [
            _getTypeGroup(type),
          ],
        );
        if (result != null) {
          files = result;
        }
      } else {
        // Handle single file selection
        final XFile? result = await openFile(
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
      print('Error picking files: $e');
      return null;
    }
  }
  
  /// Create the appropriate XTypeGroup based on the FileType
  XTypeGroup _getTypeGroup(FileType type) {
    switch (type) {
      case FileType.audio:
        return XTypeGroup(
          label: 'Audio Files',
          extensions: ['mp3', 'm4a', 'm4b', 'aac', 'flac', 'ogg', 'wma', 'wav', 'opus'],
        );
      case FileType.image:
        return XTypeGroup(
          label: 'Image Files',
          extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'],
        );
      case FileType.video:
        return XTypeGroup(
          label: 'Video Files',
          extensions: ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm'],
        );
      case FileType.media:
        return XTypeGroup(
          label: 'Media Files',
          extensions: [
            'mp3', 'm4a', 'm4b', 'aac', 'flac', 'ogg', 'wma', 'wav', 'opus',
            'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
          ],
        );
      case FileType.any:
      default:
        return XTypeGroup(
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