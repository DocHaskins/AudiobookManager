// lib/services/metadata_service.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as path_util;
import 'package:mime/mime.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/models/chapter_info.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/file_utils.dart';
import 'package:audiobook_organizer/ui/widgets/dialogs/conversion_progress_dialog.dart';

class MetadataService {
  // Singleton pattern
  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;
  MetadataService._internal();

  final Map<String, AudiobookMetadata> _metadataCache = {};
  bool _isInitialized = false;
  bool _ffmpegKitAvailable = false;
  bool _systemFFmpegAvailable = false;
  String? _systemFFmpegPath;
  
  // Computed property for overall FFmpeg availability
  bool get _ffmpegAvailable => _ffmpegKitAvailable || _systemFFmpegAvailable;
  
  // Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      Logger.log('Initializing MetadataService with metadata_god and FFmpeg detection');
      
      // Check FFmpeg availability using multiple methods
      await _detectAllFFmpegSources();
      
      _isInitialized = true;
      Logger.log('MetadataService initialized successfully');
      Logger.log('- FFmpeg Kit: ${_ffmpegKitAvailable ? "✅" : "❌"}');
      Logger.log('- System FFmpeg: ${_systemFFmpegAvailable ? "✅" : "❌"}${_systemFFmpegPath != null ? " ($_systemFFmpegPath)" : ""}');
      Logger.log('- Overall FFmpeg: ${_ffmpegAvailable ? "✅" : "❌"}');
      
      if (!_ffmpegAvailable) {
        Logger.log('💡 To enable FFmpeg features, install FFmpeg and add it to your system PATH');
        Logger.log('   Download from: https://ffmpeg.org/download.html');
      }
      
      return true;
    } catch (e) {
      Logger.error('Failed to initialize MetadataService', e);
      return false;
    }
  }

  // Detect all FFmpeg sources
  Future<void> _detectAllFFmpegSources() async {
    Logger.log('Detecting FFmpeg availability from all sources...');
    
    // Check FFmpeg Kit first
    await _checkFFmpegKitAvailability();
    
    // Check system FFmpeg
    await _checkSystemFFmpegAvailability();
    
    // Log results
    if (_ffmpegKitAvailable && _systemFFmpegAvailable) {
      Logger.log('🎉 Both FFmpeg Kit and System FFmpeg available - maximum compatibility!');
    } else if (_ffmpegKitAvailable) {
      Logger.log('FFmpeg Kit available but no system FFmpeg detected');
    } else if (_systemFFmpegAvailable) {
      Logger.log('System FFmpeg available but FFmpeg Kit not working');
    } else {
      Logger.log('No FFmpeg sources available - will use metadata_god only');
    }
  }

  // Check FFmpeg Kit availability (original method)
  Future<void> _checkFFmpegKitAvailability() async {
    try {
      Logger.log('Checking FFmpeg Kit availability...');
      
      // Method 1: Try to execute a simple FFmpeg command
      final session = await FFmpegKit.execute('-version');
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        _ffmpegKitAvailable = true;
        Logger.log('✅ FFmpeg Kit is available and working');
        
        // Get FFmpeg version for logging
        final logs = await session.getAllLogsAsString();
        final versionLine = (logs ?? '').split('\n').firstWhere(
          (line) => line.contains('ffmpeg version'),
          orElse: () => 'Unknown version'
        );
        Logger.log('FFmpeg Kit version: $versionLine');
        
      } else {
        _ffmpegKitAvailable = false;
        Logger.log('FFmpeg Kit returned non-success code: $returnCode');
      }
    } catch (e) {
      _ffmpegKitAvailable = false;
      Logger.log('FFmpeg Kit not available: ${e.toString()}');
      
      // Try alternative check
      try {
        final session = await FFmpegKit.executeAsync('-f lavfi -i testsrc=duration=1:size=320x240:rate=1 -f null -', 
          (session) {
            // Success callback
          }, 
          (log) {
            // Log callback
          }, 
          (statistics) {
            // Statistics callback
          }
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        await session.cancel();
        
        final returnCode = await session.getReturnCode();
        if (returnCode != null) {
          _ffmpegKitAvailable = true;
          Logger.log('✅ FFmpeg Kit async check successful');
        }
      } catch (asyncError) {
        Logger.debug('FFmpeg Kit async check also failed: $asyncError');
      }
    }
  }

  // Check system FFmpeg availability
  Future<void> _checkSystemFFmpegAvailability() async {
    try {
      Logger.log('Checking system FFmpeg installation...');
      
      // List of possible FFmpeg executable locations
      final List<String> ffmpegCandidates = [
        'ffmpeg',           // Standard name (Unix/Linux/macOS)
        'ffmpeg.exe',       // Windows executable
        '/usr/bin/ffmpeg',  // Common Linux path
        '/usr/local/bin/ffmpeg', // Common macOS path
        'C:\\ffmpeg\\bin\\ffmpeg.exe',          // Common Windows path
        'C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe', // Program Files
        'C:\\tools\\ffmpeg\\bin\\ffmpeg.exe',   // Chocolatey installation
        Platform.environment['FFMPEG'] ?? '', // Environment variable
        // Also check PATH environment variable
        ...(_getPathExecutables('ffmpeg') + _getPathExecutables('ffmpeg.exe')),
      ];
      
      for (final candidate in ffmpegCandidates) {
        if (candidate.isEmpty) continue;
        
        try {
          Logger.debug('Testing system FFmpeg candidate: $candidate');
          
          final result = await Process.run(
            candidate,
            ['-version'],
          );
          
          if (result.exitCode == 0) {
            _systemFFmpegAvailable = true;
            _systemFFmpegPath = candidate;
            Logger.log('✅ System FFmpeg found: $candidate');
            
            // Extract version info
            final output = result.stdout.toString();
            final versionLine = output.split('\n').firstWhere(
              (line) => line.contains('ffmpeg version'),
              orElse: () => 'Version info not found'
            );
            Logger.log('System FFmpeg version: $versionLine');
            
            return; // Found working FFmpeg, stop searching
          }
        } catch (e) {
          Logger.debug('System FFmpeg candidate $candidate failed: $e');
          continue;
        }
      }
      
      Logger.log('❌ No system FFmpeg installation found');
    } catch (e) {
      Logger.warning('Error checking system FFmpeg: $e');
    }
  }

  // Helper to get executables from PATH
  List<String> _getPathExecutables(String executableName) {
    final pathEnv = Platform.environment['PATH'] ?? '';
    final pathSeparator = Platform.isWindows ? ';' : ':';
    
    return pathEnv
        .split(pathSeparator)
        .where((path) => path.isNotEmpty)
        .map((path) => path_util.join(path, executableName))
        .toList();
  }
  
  // Primary method to extract metadata with all available MetadataGod fields
  Future<AudiobookMetadata?> extractMetadata(String filePath, {bool forceRefresh = false}) async {
    try {
      // Check cache first
      if (!forceRefresh && _metadataCache.containsKey(filePath)) {
        Logger.debug('Retrieved metadata from cache for: $filePath');
        return _metadataCache[filePath];
      }
      
      // Ensure we're initialized
      if (!_isInitialized) {
        final success = await initialize();
        if (!success) {
          Logger.error('MetadataService not initialized before extraction attempt');
          return null;
        }
      }
      
      Logger.log('Extracting enhanced metadata from file: $filePath');
      
      // Use metadata_god to get metadata
      final metadata = await MetadataGod.readMetadata(file: filePath);
      
      // Enhanced title parsing
      final rawTitle = metadata.title ?? path_util.basenameWithoutExtension(filePath);
      final cleanTitle = FileUtils.cleanAudiobookTitle(rawTitle);
      
      // Parse title and subtitle
      String title = cleanTitle;
      String subtitle = '';
      
      // Check for subtitle patterns (Title: Subtitle)
      if (cleanTitle.contains(': ')) {
        final parts = cleanTitle.split(': ');
        if (parts.length >= 2) {
          title = parts[0].trim();
          subtitle = parts.sublist(1).join(': ').trim();
        }
      }
      
      // Enhanced author parsing
      final List<String> authors = [];
      if (metadata.albumArtist != null && metadata.albumArtist!.isNotEmpty) {
        authors.addAll(FileUtils.parseAuthors(metadata.albumArtist!));
      } else if (metadata.artist != null && metadata.artist!.isNotEmpty) {
        authors.addAll(FileUtils.parseAuthors(metadata.artist!));
      }
      
      // Get series from album field
      final series = metadata.album ?? '';
      
      // Enhanced series position extraction
      String seriesPosition = '';
      if (metadata.trackNumber != null) {
        seriesPosition = metadata.trackNumber.toString();
      } else {
        seriesPosition = FileUtils.extractSeriesPosition(title) ?? 
                        FileUtils.extractSeriesPosition(path_util.basenameWithoutExtension(filePath)) ?? 
                        '';
      }
      
      // Enhanced duration extraction
      Duration? audioDuration;
      if (metadata.durationMs != null && metadata.durationMs! > 0) {
        audioDuration = Duration(milliseconds: metadata.durationMs!.toInt());
        Logger.debug('Duration extracted for $title: ${audioDuration.inSeconds}s (${_formatDuration(audioDuration)})');
      } else {
        Logger.warning('No duration found in metadata for: $title (durationMs: ${metadata.durationMs})');
      }
      
      // Enhanced categories/genre handling
      final List<String> categories = [];
      if (metadata.genre != null && metadata.genre!.isNotEmpty) {
        categories.add(metadata.genre!);
      }
      
      // Create comprehensive AudiobookMetadata object
      final audiobookMetadata = AudiobookMetadata(
        id: path_util.basename(filePath),
        title: title,
        subtitle: subtitle,
        authors: authors,
        narrator: '', // metadata_god doesn't have narrator field, but we preserve it
        description: '', // metadata_god doesn't have description, but we preserve it
        publisher: '', // metadata_god doesn't have publisher, but we preserve it
        publishedDate: metadata.year?.toString() ?? '',
        categories: categories,
        mainCategory: categories.isNotEmpty ? categories.first : '',
        thumbnailUrl: '', // Cover handling done by CoverArtManager
        language: '',
        series: series,
        seriesPosition: seriesPosition,
        audioDuration: audioDuration,
        fileFormat: path_util.extension(filePath).toLowerCase().replaceFirst('.', '').toUpperCase(),
        provider: 'metadata_god',
        
        // Extended metadata - preserve these from existing data if available
        identifiers: const [],
        pageCount: 0,
        printType: 'BOOK',
        maturityRating: '',
        contentVersion: '',
        readingModes: const {},
        previewLink: '',
        infoLink: '',
        physicalDimensions: const {},
        
        // Default values for other fields
        averageRating: 0.0,
        ratingsCount: 0,
        isFavorite: false,
        userRating: 0,
        userTags: const [],
        bookmarks: const [],
        notes: const [],
      );
      
      // Cache the result
      _metadataCache[filePath] = audiobookMetadata;
      
      Logger.log('Successfully extracted enhanced metadata for: ${audiobookMetadata.fullTitle}${audioDuration != null ? " (Duration: ${_formatDuration(audioDuration)})" : " (No duration)"}');
      Logger.log('- Subtitle: ${subtitle.isNotEmpty ? subtitle : 'None'}');
      Logger.log('- Authors: ${authors.join(', ')}');
      Logger.log('- Series: ${series.isNotEmpty ? '$series #$seriesPosition' : 'None'}');
      Logger.log('- Categories: ${categories.join(', ')}');
      
      return audiobookMetadata;
    } catch (e) {
      Logger.error('Error extracting enhanced metadata from file: $filePath', e);
      return null;
    }
  }
  
  // Method to write metadata from AudiobookMetadata object with enhanced diagnostics
  Future<bool> writeMetadataFromObject(String filePath, AudiobookMetadata metadata) async {
    String? coverImagePath;
    if (metadata.thumbnailUrl.isNotEmpty && 
        !metadata.thumbnailUrl.startsWith('http')) {
      final coverFile = File(metadata.thumbnailUrl);
      if (await coverFile.exists()) {
        coverImagePath = metadata.thumbnailUrl;
        Logger.log('Using cover from metadata for writing: ${path_util.basename(coverImagePath)}');
      }
    }
    
    return writeMetadataWithDiagnostics(filePath, metadata, coverImagePath: coverImagePath);
  }
  
  // Enhanced write method with comprehensive diagnostics
  Future<bool> writeMetadataWithDiagnostics(String filePath, AudiobookMetadata metadata, {String? coverImagePath}) async {
    try {
      final fileExtension = path_util.extension(filePath).toLowerCase();
      
      if (fileExtension == '.m4b' && coverImagePath != null) {
        Logger.log('M4B file with cover detected - using enhanced FFmpeg strategies');
        
        // Try FFmpeg approaches with priority order
        bool ffmpegSuccess = false;
        
        // Priority 1: FFmpeg Kit (if available)
        if (_ffmpegKitAvailable) {
          Logger.log('Attempting FFmpeg Kit for M4B cover embedding');
          ffmpegSuccess = await _writeM4BWithFFmpegKit(filePath, metadata, coverImagePath);
          if (ffmpegSuccess) {
            Logger.log('✅ FFmpeg Kit succeeded');
            return true;
          } else {
            Logger.warning('FFmpeg Kit failed, trying system FFmpeg');
          }
        }
        
        // Priority 2: System FFmpeg (if available)
        if (_systemFFmpegAvailable && !ffmpegSuccess) {
          Logger.log('Attempting system FFmpeg for M4B cover embedding');
          ffmpegSuccess = await _writeM4BWithSystemFFmpeg(filePath, metadata, coverImagePath);
          if (ffmpegSuccess) {
            Logger.log('✅ System FFmpeg succeeded');
            return true;
          } else {
            Logger.warning('System FFmpeg failed, falling back to metadata_god strategies');
          }
        }
        
        // Priority 3: Enhanced metadata_god strategies
        if (!ffmpegSuccess) {
          Logger.log('All FFmpeg approaches failed, trying enhanced metadata_god strategies');
          return await _tryEnhancedMetadataGodStrategies(filePath, metadata, coverImagePath);
        }
        
      } else if (fileExtension == '.m4b') {
        Logger.log('Using metadata_god for M4B metadata (no cover)');
        return await _writeStandardMetadata(filePath, metadata, null);
      } else {
        Logger.log('Using standard metadata write for non-M4B files');
        return await _writeStandardMetadata(filePath, metadata, coverImagePath);
      }
      
      return false;
    } catch (e) {
      Logger.error('Error in writeMetadataWithDiagnostics', e);
      return false;
    }
  }

  // FFmpeg Kit implementation (original method)
  Future<bool> _writeM4BWithFFmpegKit(String filePath, AudiobookMetadata metadata, String? coverImagePath) async {
    FFmpegSession? session;
    String? backupPath;
    String? tempOutputPath;
    
    try {
      Logger.log('Starting FFmpeg Kit M4B metadata write');
      
      // Create backup
      backupPath = '$filePath.backup';
      await File(filePath).copy(backupPath);
      Logger.log('Created backup: $backupPath');
      
      // Create temporary output file
      final tempDir = Directory.systemTemp;
      tempOutputPath = path_util.join(tempDir.path, 'ffmpeg_kit_output_${DateTime.now().millisecondsSinceEpoch}.m4b');
      
      // Build FFmpeg command
      final ffmpegArgs = await _buildFFmpegArgs(filePath, coverImagePath, metadata, tempOutputPath);
      
      Logger.log('FFmpeg Kit command: ffmpeg ${ffmpegArgs.join(' ')}');
      
      // Execute FFmpeg with proper session handling
      session = await FFmpegKit.executeWithArguments(ffmpegArgs);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        return await _verifyAndReplaceFile(filePath, tempOutputPath, coverImagePath, backupPath, 'FFmpeg Kit');
      } else {
        // FFmpeg failed, get logs for debugging
        final logs = await session.getAllLogsAsString();
        Logger.error('FFmpeg Kit failed with return code: $returnCode');
        Logger.error('FFmpeg Kit logs: $logs');
        
        await _restoreFromBackup(filePath, backupPath);
        await _cleanupFiles([tempOutputPath]);
        return false;
      }
    } catch (e) {
      Logger.error('Error in _writeM4BWithFFmpegKit: $e');
      
      // Cancel session if it exists
      if (session != null) {
        try {
          await session.cancel();
        } catch (cancelError) {
          Logger.debug('Error canceling FFmpeg Kit session: $cancelError');
        }
      }
      
      // Cleanup and restore
      if (tempOutputPath != null) {
        await _cleanupFiles([tempOutputPath]);
      }
      if (backupPath != null) {
        await _restoreFromBackup(filePath, backupPath);
      }
      
      return false;
    }
  }

  // System FFmpeg implementation
  Future<bool> _writeM4BWithSystemFFmpeg(String filePath, AudiobookMetadata metadata, String coverImagePath) async {
    if (_systemFFmpegPath == null) return false;
    
    String? backupPath;
    String? tempOutputPath;
    
    try {
      Logger.log('Starting system FFmpeg M4B metadata write');
      
      // Create backup
      backupPath = '$filePath.backup';
      await File(filePath).copy(backupPath);
      Logger.log('Created backup: $backupPath');
      
      // Create temporary output file
      final tempDir = Directory.systemTemp;
      tempOutputPath = path_util.join(tempDir.path, 'system_ffmpeg_output_${DateTime.now().millisecondsSinceEpoch}.m4b');
      
      // Build FFmpeg command
      final ffmpegArgs = await _buildFFmpegArgs(filePath, coverImagePath, metadata, tempOutputPath);
      
      Logger.log('System FFmpeg command: $_systemFFmpegPath ${ffmpegArgs.join(' ')}');
      
      // Execute system FFmpeg
      final result = await Process.run(
        _systemFFmpegPath!,
        ffmpegArgs,
      );
      
      if (result.exitCode == 0) {
        return await _verifyAndReplaceFile(filePath, tempOutputPath, coverImagePath, backupPath, 'System FFmpeg');
      } else {
        Logger.error('System FFmpeg failed with exit code: ${result.exitCode}');
        Logger.error('System FFmpeg stderr: ${result.stderr}');
        
        await _restoreFromBackup(filePath, backupPath);
        await _cleanupFiles([tempOutputPath]);
        return false;
      }
    } catch (e) {
      Logger.error('Error in _writeM4BWithSystemFFmpeg: $e');
      
      if (tempOutputPath != null) {
        await _cleanupFiles([tempOutputPath]);
      }
      if (backupPath != null) {
        await _restoreFromBackup(filePath, backupPath);
      }
      
      return false;
    }
  }

  // Build FFmpeg arguments for M4B processing
  Future<List<String>> _buildFFmpegArgs(String inputPath, String? coverImagePath, AudiobookMetadata metadata, String outputPath) async {
    final List<String> args = [
      '-i', inputPath,  // Input file
    ];
    
    // Add cover image if provided
    if (coverImagePath != null && await File(coverImagePath).exists()) {
      args.addAll([
        '-i', coverImagePath,  // Input cover image
        '-map', '0:a',         // Map audio from first input
        '-map', '1:v',         // Map video (cover) from second input
        '-c:a', 'copy',        // Copy audio without re-encoding
        '-c:v', 'copy',        // Copy video without re-encoding
        '-disposition:v:0', 'attached_pic',  // Mark video as attached picture
      ]);
      Logger.log('Adding cover image: ${path_util.basename(coverImagePath)}');
    } else {
      args.addAll([
        '-c', 'copy',  // Copy all streams without re-encoding
      ]);
    }
    
    // Core metadata tags
    if (metadata.title.isNotEmpty) {
      args.addAll(['-metadata', 'title=${_escapeMetadataValue(metadata.title)}']);
    }
    
    // Handle subtitle by combining with title if present
    if (metadata.subtitle.isNotEmpty) {
      final fullTitle = '${metadata.title}: ${metadata.subtitle}';
      args.addAll(['-metadata', 'title=${_escapeMetadataValue(fullTitle)}']);
    }
    
    // Author handling - prefer authors over narrator for artist field
    if (metadata.authors.isNotEmpty) {
      args.addAll(['-metadata', 'artist=${_escapeMetadataValue(metadata.authors.first)}']);
      if (metadata.authors.length > 1) {
        args.addAll(['-metadata', 'albumartist=${_escapeMetadataValue(metadata.authors.join(', '))}']);
      } else {
        args.addAll(['-metadata', 'albumartist=${_escapeMetadataValue(metadata.authors.first)}']);
      }
    }
    
    // Narrator as composer field (common audiobook practice)
    if (metadata.narrator.isNotEmpty) {
      args.addAll(['-metadata', 'composer=${_escapeMetadataValue(metadata.narrator)}']);
    }
    
    // Album field - prefer series, fallback to title
    if (metadata.series.isNotEmpty) {
      args.addAll(['-metadata', 'album=${_escapeMetadataValue(metadata.series)}']);
    } else if (metadata.title.isNotEmpty) {
      args.addAll(['-metadata', 'album=${_escapeMetadataValue(metadata.title)}']);
    }
    
    // Publisher as record label
    if (metadata.publisher.isNotEmpty) {
      args.addAll(['-metadata', 'publisher=${_escapeMetadataValue(metadata.publisher)}']);
      // Also use TPUB for ID3v2 tags
      args.addAll(['-metadata', 'TPUB=${_escapeMetadataValue(metadata.publisher)}']);
    }
    
    // Publishing date
    if (metadata.publishedDate.isNotEmpty) {
      args.addAll(['-metadata', 'date=${_escapeMetadataValue(metadata.publishedDate)}']);
      args.addAll(['-metadata', 'year=${_escapeMetadataValue(metadata.publishedDate)}']);
    }
    
    // Genre/Categories
    if (metadata.categories.isNotEmpty) {
      args.addAll(['-metadata', 'genre=${_escapeMetadataValue(metadata.categories.first)}']);
    } else if (metadata.mainCategory.isNotEmpty) {
      args.addAll(['-metadata', 'genre=${_escapeMetadataValue(metadata.mainCategory)}']);
    } else {
      args.addAll(['-metadata', 'genre=Audiobook']);
    }
    
    // Description/Comment
    if (metadata.description.isNotEmpty) {
      args.addAll(['-metadata', 'comment=${_escapeMetadataValue(metadata.description)}']);
      args.addAll(['-metadata', 'description=${_escapeMetadataValue(metadata.description)}']);
    }
    
    // Series position
    if (metadata.seriesPosition.isNotEmpty) {
      args.addAll(['-metadata', 'track=${_escapeMetadataValue(metadata.seriesPosition)}']);
    }
    
    // Language
    if (metadata.language.isNotEmpty) {
      args.addAll(['-metadata', 'language=${_escapeMetadataValue(metadata.language)}']);
    }
    
    // ISBN if available
    final isbn = metadata.isbn;
    if (isbn.isNotEmpty) {
      args.addAll(['-metadata', 'ISBN=${_escapeMetadataValue(isbn)}']);
    }
    
    // User tags as keywords
    if (metadata.userTags.isNotEmpty) {
      args.addAll(['-metadata', 'keywords=${_escapeMetadataValue(metadata.userTags.join(', '))}']);
    }
    
    // Output file
    args.addAll(['-y', outputPath]);  // -y to overwrite output file
    
    return args;
  }

  // Verify FFmpeg output and replace original file
  Future<bool> _verifyAndReplaceFile(String originalPath, String tempOutputPath, String? coverImagePath, String backupPath, String method) async {
    try {
      // Verify the output file was created
      if (!await File(tempOutputPath).exists()) {
        Logger.error('$method output file was not created');
        await _restoreFromBackup(originalPath, backupPath);
        return false;
      }
      
      final outputSize = await File(tempOutputPath).length();
      final originalSize = await File(originalPath).length();
      
      Logger.log('$method verification - Original: $originalSize bytes, Output: $outputSize bytes');
      
      // Basic size sanity check (output should be similar size or larger due to metadata)
      if (outputSize < (originalSize * 0.7)) {
        Logger.error('Output file suspiciously small, aborting');
        await _cleanupFiles([tempOutputPath]);
        await _restoreFromBackup(originalPath, backupPath);
        return false;
      }
      
      // If cover was provided, verify it was embedded
      if (coverImagePath != null) {
        final verification = await diagnoseCoverEmbedding(tempOutputPath);
        final actualCoverSize = verification['picture_data_size'] ?? 0;
        
        if (actualCoverSize == 0) {
          Logger.error('$method failed to embed cover properly');
          await _cleanupFiles([tempOutputPath]);
          await _restoreFromBackup(originalPath, backupPath);
          return false;
        }
        
        Logger.log('Cover embedded successfully: $actualCoverSize bytes');
      }
      
      // Replace original file with FFmpeg output
      await File(tempOutputPath).copy(originalPath);
      await _cleanupFiles([tempOutputPath, backupPath]);
      
      // Clear cache
      _metadataCache.remove(originalPath);
      
      Logger.log('✅ Successfully wrote M4B metadata and cover using $method');
      return true;
      
    } catch (e) {
      Logger.error('Error verifying and replacing file: $e');
      await _cleanupFiles([tempOutputPath]);
      await _restoreFromBackup(originalPath, backupPath);
      return false;
    }
  }

  // Enhanced metadata_god strategies when FFmpeg is not available
  Future<bool> _tryEnhancedMetadataGodStrategies(String filePath, AudiobookMetadata metadata, String? coverImagePath) async {
    Logger.log('Trying enhanced metadata_god strategies (no FFmpeg)');
    
    // Strategy 1: Complete file replacement (most reliable for M4B)
    Logger.log('Strategy 1: Complete file replacement');
    try {
      final success = await _writeM4BWithCompleteReplacement(filePath, metadata, coverImagePath);
      if (success) {
        Logger.log('✅ Strategy 1 SUCCESS: Complete file replacement');
        return true;
      }
    } catch (e) {
      Logger.error('Strategy 1 failed: $e');
    }
    
    // Strategy 2: Two-stage write (remove existing cover first)
    if (coverImagePath != null) {
      Logger.log('Strategy 2: Two-stage cover replacement');
      try {
        final success = await _writeM4BWithTwoStageReplacement(filePath, metadata, coverImagePath);
        if (success) {
          Logger.log('✅ Strategy 2 SUCCESS: Two-stage replacement');
          return true;
        }
      } catch (e) {
        Logger.error('Strategy 2 failed: $e');
      }
    }
    
    // Strategy 3: Standard metadata_god approach (last resort)
    Logger.log('Strategy 3: Standard metadata_god (last resort)');
    try {
      final success = await _writeStandardMetadata(filePath, metadata, coverImagePath);
      if (success) {
        Logger.log('✅ Strategy 3 SUCCESS: Standard approach worked');
        return true;
      }
    } catch (e) {
      Logger.error('Strategy 3 failed: $e');
    }
    
    Logger.error('❌ All enhanced metadata_god strategies failed');
    return false;
  }

  // Complete file replacement strategy (existing method)
  Future<bool> _writeM4BWithCompleteReplacement(String filePath, AudiobookMetadata metadata, String? coverImagePath) async {
    String? backupPath;
    String? tempFilePath;
    
    try {
      // Create backup
      backupPath = '$filePath.backup';
      await File(filePath).copy(backupPath);
      Logger.log('Created backup for enhanced complete replacement');
      
      // Create temporary working copy
      final tempDir = Directory.systemTemp;
      tempFilePath = path_util.join(tempDir.path, 'temp_enhanced_replacement_${DateTime.now().millisecondsSinceEpoch}_${path_util.basename(filePath)}');
      await File(filePath).copy(tempFilePath);
      
      // Read original metadata to preserve audio stream info
      final originalMetadata = await MetadataGod.readMetadata(file: tempFilePath);
      
      // Prepare new picture
      Picture? picture;
      if (coverImagePath != null && await File(coverImagePath).exists()) {
        final imageBytes = await File(coverImagePath).readAsBytes();
        final mimeType = lookupMimeType(coverImagePath) ?? 'image/jpeg';
        
        picture = Picture(
          data: imageBytes,
          mimeType: mimeType,
        );
        Logger.log('Prepared enhanced replacement cover: ${imageBytes.length} bytes');
      }
      
      // Create comprehensive fresh metadata with all new fields
      final freshMetadata = Metadata(
        // Enhanced title handling
        title: metadata.subtitle.isNotEmpty 
            ? '${metadata.title}: ${metadata.subtitle}' 
            : metadata.title,
        
        // Author information
        artist: metadata.authors.isNotEmpty ? metadata.authors.first : null,
        albumArtist: metadata.authors.isNotEmpty ? metadata.authors.join(', ') : null,
        
        // Album/Series information
        album: metadata.series.isNotEmpty ? metadata.series : metadata.title,
        
        // Enhanced genre handling
        genre: metadata.mainCategory.isNotEmpty 
            ? metadata.mainCategory
            : (metadata.categories.isNotEmpty 
                ? metadata.categories.first 
                : 'Audiobook'),
        
        // Publishing information
        year: metadata.publishedDate.isNotEmpty ? int.tryParse(metadata.publishedDate) : null,
        
        // Series position
        trackNumber: metadata.seriesPosition.isNotEmpty ? int.tryParse(metadata.seriesPosition) : null,
        trackTotal: null,
        discNumber: null,
        discTotal: null,
        
        // Preserve original duration
        durationMs: originalMetadata.durationMs,
        
        // New cover
        picture: picture,
        fileSize: null,
      );
      
      // Write to temp file
      await MetadataGod.writeMetadata(
        file: tempFilePath,
        metadata: freshMetadata,
      );
      
      // Verification
      final verification = await diagnoseCoverEmbedding(tempFilePath);
      final expectedCoverSize = coverImagePath != null ? (await analyzeCoverFile(coverImagePath))['size'] ?? 0 : 0;
      final actualCoverSize = verification['picture_data_size'] ?? 0;
      
      Logger.log('Enhanced replacement verification:');
      Logger.log('- Title: ${metadata.fullTitle}');
      Logger.log('- Authors: ${metadata.authorsFormatted}');
      Logger.log('- Publisher: ${metadata.publisher}');
      Logger.log('- Narrator: ${metadata.narrator}');
      Logger.log('- Series: ${metadata.series} #${metadata.seriesPosition}');
      Logger.log('- Categories: ${metadata.categories.join(', ')}');
      Logger.log('- Expected cover: $expectedCoverSize, Actual: $actualCoverSize');
      
      // Check if cover was properly embedded (if cover was provided)
      if (coverImagePath != null && expectedCoverSize > 0) {
        if (actualCoverSize == 0) {
          Logger.error('Cover not embedded in enhanced replacement file');
          await _cleanupFiles([tempFilePath]);
          await _restoreFromBackup(filePath, backupPath);
          return false;
        }
      }
      
      // Replace original with enhanced temp file
      await File(tempFilePath).copy(filePath);
      await _cleanupFiles([tempFilePath, backupPath]);
      
      // Clear cache
      _metadataCache.remove(filePath);
      
      Logger.log('Enhanced complete replacement successful with all new metadata fields');
      return true;
      
    } catch (e) {
      Logger.error('Error in enhanced complete replacement strategy: $e');
      
      // Cleanup and restore
      if (tempFilePath != null) {
        await _cleanupFiles([tempFilePath]);
      }
      if (backupPath != null) {
        await _restoreFromBackup(filePath, backupPath);
      }
      
      return false;
    }
  }

  // Two-stage cover replacement (existing method)
  Future<bool> _writeM4BWithTwoStageReplacement(String filePath, AudiobookMetadata metadata, String coverImagePath) async {
    try {
      Logger.log('Starting two-stage M4B cover replacement');
      
      // Stage 1: Remove existing cover
      final currentMetadata = await MetadataGod.readMetadata(file: filePath);
      final metadataWithoutCover = Metadata(
        title: currentMetadata.title,
        artist: currentMetadata.artist,
        album: currentMetadata.album,
        albumArtist: currentMetadata.albumArtist,
        genre: currentMetadata.genre,
        year: currentMetadata.year,
        trackNumber: currentMetadata.trackNumber,
        trackTotal: currentMetadata.trackTotal,
        discNumber: currentMetadata.discNumber,
        discTotal: currentMetadata.discTotal,
        durationMs: currentMetadata.durationMs,
        picture: null, // Remove existing cover
        fileSize: currentMetadata.fileSize,
      );
      
      await MetadataGod.writeMetadata(file: filePath, metadata: metadataWithoutCover);
      Logger.log('Stage 1: Removed existing cover');
      
      // Small delay to ensure file system operations complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Stage 2: Write new metadata with cover
      final success = await _writeStandardMetadata(filePath, metadata, coverImagePath);
      if (success) {
        Logger.log('Stage 2: Added new cover and metadata');
        return true;
      } else {
        Logger.error('Stage 2 failed to add new cover');
        return false;
      }
      
    } catch (e) {
      Logger.error('Error in two-stage replacement: $e');
      return false;
    }
  }
  
  // Standard metadata writing for all file types
  Future<bool> _writeStandardMetadata(String filePath, AudiobookMetadata metadata, String? coverImagePath) async {
    try {
      // Prepare picture data
      Picture? picture;
      if (coverImagePath != null && coverImagePath.isNotEmpty && !coverImagePath.startsWith('http')) {
        final coverFile = File(coverImagePath);
        if (await coverFile.exists()) {
          final imageBytes = await coverFile.readAsBytes();
          final mimeType = lookupMimeType(coverImagePath) ?? 'image/jpeg';
          
          picture = Picture(
            data: imageBytes,
            mimeType: mimeType,
          );
          
          Logger.log('Prepared standard picture: ${imageBytes.length} bytes, type: $mimeType');
        }
      }
      
      // Create enhanced metadata with all available fields
      final newMetadata = Metadata(
        // Core metadata
        title: metadata.subtitle.isNotEmpty 
            ? '${metadata.title}: ${metadata.subtitle}' 
            : metadata.title,
        artist: metadata.authors.isNotEmpty ? metadata.authors.first : null,
        album: metadata.series.isNotEmpty ? metadata.series : metadata.title,
        albumArtist: metadata.authors.isNotEmpty ? metadata.authors.join(', ') : null,
        
        // Genre - prioritize mainCategory, then categories, then default
        genre: metadata.mainCategory.isNotEmpty 
            ? metadata.mainCategory
            : (metadata.categories.isNotEmpty 
                ? metadata.categories.first 
                : 'Audiobook'),
        
        // Publishing information
        year: metadata.publishedDate.isNotEmpty ? int.tryParse(metadata.publishedDate) : null,
        
        // Series information
        trackNumber: metadata.seriesPosition.isNotEmpty ? int.tryParse(metadata.seriesPosition) : null,
        trackTotal: null, // Could be enhanced if we track total books in series
        discNumber: null,
        discTotal: null,
        
        // Duration
        durationMs: metadata.audioDuration?.inMilliseconds.toDouble(),
        
        // Cover art
        picture: picture,
        fileSize: null,
      );
      
      await MetadataGod.writeMetadata(
        file: filePath,
        metadata: newMetadata,
      );
      
      _metadataCache.remove(filePath);
      Logger.log('Enhanced standard metadata write completed for: ${metadata.title}');
      Logger.log('- Publisher: ${metadata.publisher}');
      Logger.log('- Narrator: ${metadata.narrator}');
      Logger.log('- Description length: ${metadata.description.length} chars');
      Logger.log('- Categories: ${metadata.categories.join(', ')}');
      Logger.log('- User tags: ${metadata.userTags.join(', ')}');
      
      return true;
    } catch (e) {
      Logger.error('Error in enhanced _writeStandardMetadata', e);
      return false;
    }
  }

  // Helper method to cleanup temporary files
  Future<void> _cleanupFiles(List<String> filePaths) async {
    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          Logger.debug('Cleaned up: ${path_util.basename(filePath)}');
        }
      } catch (e) {
        Logger.debug('Failed to cleanup $filePath: $e');
      }
    }
  }

  // Helper method to restore from backup
  Future<void> _restoreFromBackup(String originalPath, String backupPath) async {
    try {
      if (await File(backupPath).exists()) {
        await File(backupPath).copy(originalPath);
        await File(backupPath).delete();
        Logger.log('Restored from backup: ${path_util.basename(originalPath)}');
      }
    } catch (e) {
      Logger.error('Failed to restore from backup: $e');
    }
  }

  // Helper method to escape metadata values for FFmpeg
  String _escapeMetadataValue(String value) {
    // Escape special characters that might cause issues in FFmpeg
    return value
        .replaceAll('\'', '\\\'')
        .replaceAll('"', '\\"')
        .replaceAll('\\', '\\\\');
  }
  
  // Comprehensive cover embedding diagnostics (existing method)
  Future<Map<String, dynamic>> diagnoseCoverEmbedding(String filePath) async {
    try {
      Logger.debug('Running cover embedding diagnostics for: ${path_util.basename(filePath)}');
      
      final file = File(filePath);
      if (!await file.exists()) {
        return {
          'error': 'File does not exist',
          'file_path': filePath,
        };
      }
      
      // Read metadata using metadata_god
      final metadata = await MetadataGod.readMetadata(file: filePath);
      
      final diagnostics = <String, dynamic>{
        'file_path': filePath,
        'file_name': path_util.basename(filePath),
        'file_extension': path_util.extension(filePath).toLowerCase(),
        'file_exists': true,
        'file_size': await file.length(),
        'metadata_title': metadata.title ?? 'null',
        'metadata_artist': metadata.artist ?? 'null',
        'has_picture_data': metadata.picture != null,
        'picture_data_size': metadata.picture?.data.length ?? 0,
        'picture_mime_type': metadata.picture?.mimeType ?? 'null',
      };
      
      // Analyze picture data if present
      if (metadata.picture != null && metadata.picture!.data.isNotEmpty) {
        final pictureData = metadata.picture!.data;
        
        // Detect image format by magic bytes
        String imageFormat = 'unknown';
        if (pictureData.length >= 4) {
          final header = pictureData.take(4).toList();
          if (header[0] == 0xFF && header[1] == 0xD8) {
            imageFormat = 'JPEG';
          } else if (header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) {
            imageFormat = 'PNG';
          } else if (header.join(',') == '71,73,70,56') {
            imageFormat = 'GIF';
          } else if (header.join(',') == '82,73,70,70') {
            imageFormat = 'WEBP';
          }
        }
        
        diagnostics.addAll({
          'picture_format_detected': imageFormat,
          'picture_is_valid': imageFormat != 'unknown',
          'picture_first_4_bytes': pictureData.take(4).toList(),
        });
        
        // Try to extract the cover to a temp file for verification
        try {
          final tempDir = Directory.systemTemp;
          final extension = imageFormat.toLowerCase() == 'jpeg' ? 'jpg' : imageFormat.toLowerCase();
          final tempFile = File('${tempDir.path}/diagnostic_cover_${DateTime.now().millisecondsSinceEpoch}.$extension');
          await tempFile.writeAsBytes(pictureData);
          
          diagnostics.addAll({
            'extracted_cover_path': tempFile.path,
            'extracted_cover_size': await tempFile.length(),
            'extraction_successful': true,
          });
          
          Logger.debug('Cover extracted to temp file: ${tempFile.path}');
        } catch (e) {
          diagnostics.addAll({
            'extraction_error': e.toString(),
            'extraction_successful': false,
          });
        }
      } else {
        diagnostics.addAll({
          'picture_format_detected': 'none',
          'picture_is_valid': false,
          'extraction_successful': false,
        });
      }
      
      return diagnostics;
    } catch (e) {
      Logger.error('Error in diagnoseCoverEmbedding', e);
      return {
        'error': e.toString(),
        'file_path': filePath,
      };
    }
  }
  
  // Analyze cover file before embedding (existing method)
  Future<Map<String, dynamic>> analyzeCoverFile(String coverPath) async {
    try {
      final file = File(coverPath);
      if (!await file.exists()) {
        return {
          'error': 'Cover file does not exist',
          'path': coverPath,
          'exists': false,
        };
      }
      
      final bytes = await file.readAsBytes();
      final mimeType = lookupMimeType(coverPath);
      
      // Detect image format by magic bytes
      String detectedFormat = 'unknown';
      if (bytes.length >= 4) {
        final header = bytes.take(4).toList();
        if (header[0] == 0xFF && header[1] == 0xD8) {
          detectedFormat = 'JPEG';
        } else if (header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) {
          detectedFormat = 'PNG';
        } else if (header.join(',') == '71,73,70,56') {
          detectedFormat = 'GIF';
        } else if (header.join(',') == '82,73,70,70') {
          detectedFormat = 'WEBP';
        }
      }
      
      return {
        'path': coverPath,
        'name': path_util.basename(coverPath),
        'exists': true,
        'size': bytes.length,
        'mime_type': mimeType ?? 'unknown',
        'detected_format': detectedFormat,
        'first_4_bytes': bytes.take(4).toList(),
        'is_valid_image': detectedFormat != 'unknown',
        'suitable_for_embedding': detectedFormat == 'JPEG' || detectedFormat == 'PNG',
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'path': coverPath,
        'exists': false,
      };
    }
  }
  
  // Legacy method maintained for backward compatibility
  Future<bool> writeMetadata(String filePath, AudiobookMetadata metadata, {String? coverImagePath}) async {
    return writeMetadataWithDiagnostics(filePath, metadata, coverImagePath: coverImagePath);
  }

  Future<bool> isFFmpegAvailableForConversion() async {
    try {
      await initialize(); // Ensure we're initialized
      return _systemFFmpegAvailable;
    } catch (e) {
      Logger.error('Error checking FFmpeg availability for conversion: $e');
      return false;
    }
  }

  // Convert MP3 to M4B with metadata preservation and progress tracking
  Future<bool> convertMP3ToM4B(
    String inputPath, 
    String outputPath, 
    AudiobookMetadata metadata, {
    StreamController<ConversionProgress>? progressController,
    Duration? totalDuration,
    String? bitrate,
    bool preserveOriginalBitrate = false,
  }) async {
    try {
      Logger.log('🎵 MetadataService: Starting MP3 to M4B conversion');
      Logger.log('📁 Input: $inputPath');
      Logger.log('📁 Output: $outputPath');
      Logger.log('🔧 Bitrate: ${bitrate ?? "default"}, Preserve original: $preserveOriginalBitrate');
      Logger.log('⏱️ Total duration: ${totalDuration != null ? _formatDuration(totalDuration) : "unknown"}');
      Logger.log('📊 Progress controller provided: ${progressController != null}');
      
      // Ensure FFmpeg is available
      if (!_systemFFmpegAvailable || _systemFFmpegPath == null) {
        Logger.error('❌ System FFmpeg not available for conversion');
        return false;
      }
      
      // Step 1: Convert audio format with progress tracking
      Logger.log('📊 Emitting initial progress');
      progressController?.add(ConversionProgress.initial());
      
      final conversionSuccess = await _convertAudioFormatWithProgress(
        inputPath, 
        outputPath,
        progressController: progressController,
        totalDuration: totalDuration,
        bitrate: bitrate,
        preserveOriginalBitrate: preserveOriginalBitrate,
      );
      
      Logger.log('🔄 Audio format conversion result: $conversionSuccess');
      
      if (!conversionSuccess) {
        Logger.error('❌ Audio format conversion failed');
        return false;
      }

      Logger.log('✅ Audio conversion successful, embedding metadata...');
      
      // Step 2: Embed metadata into the converted M4B file
      Logger.log('📊 Emitting metadata embedding progress');
      progressController?.add(ConversionProgress.embeddingMetadata());
      
      final metadataSuccess = await writeMetadataWithDiagnostics(
        outputPath,
        metadata,
        coverImagePath: metadata.thumbnailUrl.isNotEmpty && 
                      !metadata.thumbnailUrl.startsWith('http') 
                        ? metadata.thumbnailUrl 
                        : null,
      );
      
      Logger.log('🔄 Metadata embedding result: $metadataSuccess');
      
      if (metadataSuccess) {
        Logger.log('✅ MP3 to M4B conversion completed successfully');
        Logger.log('📊 Emitting completion progress');
        progressController?.add(ConversionProgress.completed());
        return true;
      } else {
        Logger.error('❌ Failed to embed metadata in converted M4B file');
        // Clean up the converted file if metadata embedding failed
        try {
          await File(outputPath).delete();
          Logger.log('🗑️ Cleaned up failed conversion file');
        } catch (e) {
          Logger.warning('⚠️ Failed to cleanup failed conversion file: $e');
        }
        return false;
      }
    } catch (e) {
      Logger.error('❌ Error in MP3 to M4B conversion: $e');
      return false;
    }
  }

  Future<bool> _convertAudioFormatWithProgress(
    String inputPath, 
    String outputPath, {
    StreamController<ConversionProgress>? progressController,
    Duration? totalDuration,
    String? bitrate,
    bool preserveOriginalBitrate = false,
    int? cpuThreads,
    bool useHardwareOptimizations = true,
  }) async {
    Process? process;
    
    try {
      Logger.log('🔄 Starting audio format conversion with debug');
      Logger.log('📁 Input: ${path_util.basename(inputPath)}');
      Logger.log('📁 Output: ${path_util.basename(outputPath)}');
      Logger.log('📊 Progress controller: ${progressController != null}');
      Logger.log('⏱️ Total duration: ${totalDuration != null ? _formatDuration(totalDuration) : "unknown"}');
      
      if (_systemFFmpegPath == null) {
        Logger.error('❌ System FFmpeg path not available');
        return false;
      }
      
      // Detect system capabilities
      final cpuCores = Platform.numberOfProcessors;
      final effectiveThreads = cpuThreads ?? _calculateOptimalThreads(cpuCores);
      
      // Build FFmpeg arguments with hardware optimizations
      final List<String> args = [
        '-i', inputPath,              // Input MP3 file
      ];
      
      // Add hardware decoding optimizations
      if (useHardwareOptimizations) {
        args.addAll([
          '-threads', effectiveThreads.toString(),
          '-thread_type', 'slice',
        ]);
      }
      
      args.addAll([
        '-map', '0:a',               // Map only audio stream
      ]);
      
      // Audio codec settings with optimizations
      if (preserveOriginalBitrate) {
        final inputBitrate = await _getAudioBitrate(inputPath);
        if (inputBitrate != null) {
          Logger.log('🔧 Preserving original bitrate: $inputBitrate');
          args.addAll([
            '-c:a', 'aac',
            '-b:a', inputBitrate,
          ]);
        } else {
          args.addAll([
            '-c:a', 'aac',
            '-q:a', '2',
          ]);
        }
      } else if (bitrate != null && bitrate.isNotEmpty) {
        args.addAll([
          '-c:a', 'aac',
          '-b:a', bitrate,
        ]);
      } else {
        args.addAll([
          '-c:a', 'aac',
          '-b:a', '128k',
        ]);
      }
      
      // Advanced encoding optimizations
      args.addAll([
        '-aac_coder', 'twoloop',
        '-cutoff', '20000',
        '-cpu-used', '0',
        '-f', 'mp4',
        '-movflags', '+faststart',
        '-avoid_negative_ts', 'make_zero',
        '-max_muxing_queue_size', '256',
        '-fflags', '+genpts+discardcorrupt',
        
        // CRITICAL: Progress reporting - this is key!
        '-progress', 'pipe:2',  // Send progress to stderr
        '-nostdin',
        '-hide_banner',
        '-loglevel', 'info',    // Changed from 'warning' to 'info' for more output
        
        '-y', outputPath,
      ]);
      
      Logger.log('🔧 FFmpeg command: $_systemFFmpegPath ${args.join(' ')}');
      Logger.log('🔧 Optimized for $effectiveThreads threads on $cpuCores core system');
      
      // Start FFmpeg process
      Logger.log('🚀 Starting FFmpeg process');
      process = await Process.start(
        _systemFFmpegPath!,
        args,
      );
      
      final Completer<bool> completer = Completer<bool>();
      StreamSubscription? stderrSubscription;
      StreamSubscription? stdoutSubscription;
      
      // Track progress updates
      int progressUpdateCount = 0;
      DateTime lastProgressTime = DateTime.now();
      
      try {
        final List<String> stderrBuffer = [];
        const maxBufferLines = 100;
        
        Logger.log('📊 Setting up progress monitoring streams');
        
        // Monitor stderr for progress updates
        stderrSubscription = process.stderr
            .transform(const SystemEncoding().decoder)
            .transform(const LineSplitter())
            .listen((line) {
          stderrBuffer.add(line);
          Logger.log('🔍 FFmpeg stderr: $line'); // Log every line for debugging
          
          if (stderrBuffer.length > maxBufferLines) {
            stderrBuffer.removeRange(0, stderrBuffer.length - maxBufferLines);
          }
          
          // Parse progress and emit updates
          final now = DateTime.now();
          if (now.difference(lastProgressTime).inMilliseconds >= 500) { // Throttle updates
            _parseFFmpegProgress(line, progressController, totalDuration);
            lastProgressTime = now;
            progressUpdateCount++;
          }
        }, onError: (error) {
          Logger.error('❌ FFmpeg stderr stream error: $error');
        });
        
        // Monitor stdout (usually empty for FFmpeg but good for debugging)
        stdoutSubscription = process.stdout
            .transform(const SystemEncoding().decoder)
            .listen((data) {
          if (data.trim().isNotEmpty) {
            Logger.log('🔍 FFmpeg stdout: $data');
          }
        }, onError: (error) {
          Logger.error('❌ FFmpeg stdout stream error: $error');
        });
        
        Logger.log('📊 Waiting for FFmpeg process to complete');
        final exitCode = await process.exitCode;
        Logger.log('🔄 FFmpeg process completed with exit code: $exitCode');
        Logger.log('📊 Total progress updates received: $progressUpdateCount');
        
        await stderrSubscription.cancel();
        await stdoutSubscription.cancel();
        
        if (exitCode == 0) {
          Logger.log('✅ Hardware-optimized conversion successful');
          
          // Emit final progress update
          if (progressController != null) {
            Logger.log('📊 Emitting final progress update');
            progressController.add(ConversionProgress.converting(
              percentage: 1.0,
              speed: 'Complete',
            ));
          }
          
          completer.complete(true);
        } else {
          Logger.error('❌ FFmpeg conversion failed with exit code: $exitCode');
          if (stderrBuffer.isNotEmpty) {
            final lastLines = stderrBuffer.sublist(stderrBuffer.length > 10 ? stderrBuffer.length - 10 : 0);
            Logger.error('📋 Last stderr output: ${lastLines.join('\n')}');
          }
          completer.complete(false);
        }
        
        return await completer.future;
        
      } catch (e) {
        Logger.error('❌ Error in conversion process: $e');
        await stderrSubscription?.cancel();
        await stdoutSubscription?.cancel();
        throw e;
      }
      
    } catch (e) {
      Logger.error('❌ Error in hardware-optimized conversion: $e');
      return false;
    } finally {
      if (process != null) {
        try {
          Logger.log('🛑 Killing FFmpeg process');
          process.kill();
        } catch (e) {
          Logger.log('⚠️ Error killing process: $e');
        }
      }
    }
  }

  int _calculateOptimalThreads(int cpuCores) {
    // For audio encoding, using all cores doesn't always help
    // Optimal is usually 2-4 threads per conversion
    if (cpuCores >= 16) return 4;
    if (cpuCores >= 8) return 3;
    if (cpuCores >= 4) return 2;
    return 1;
  }

  Future<String?> _getAudioBitrate(String inputPath) async {
    try {
      if (_systemFFmpegPath == null) return null;
      
      // Use ffprobe to get audio bitrate
      final ffprobePath = _systemFFmpegPath!.replaceAll('ffmpeg', 'ffprobe');
      
      final result = await Process.run(ffprobePath, [
        '-v', 'error',
        '-select_streams', 'a:0',
        '-show_entries', 'stream=bit_rate',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        inputPath,
      ]);
      
      if (result.exitCode == 0) {
        final bitrateStr = result.stdout.toString().trim();
        if (bitrateStr.isNotEmpty && bitrateStr != 'N/A') {
          final bitrate = int.tryParse(bitrateStr);
          if (bitrate != null) {
            // Convert to k format (e.g., 128000 -> 128k)
            final bitrateK = (bitrate / 1000).round();
            return '${bitrateK}k';
          }
        }
      }
      
      Logger.warning('Could not determine audio bitrate for: $inputPath');
      return null;
    } catch (e) {
      Logger.error('Error getting audio bitrate: $e');
      return null;
    }
  }

  // Parse FFmpeg progress output
  void _parseFFmpegProgress(
    String data, 
    StreamController<ConversionProgress>? progressController,
    Duration? totalDuration,
  ) {
    // Always log what we're parsing
    Logger.log('🔍 Parsing FFmpeg output: ${data.trim()}');
    
    if (progressController == null) {
      Logger.log('⚠️ No progress controller provided, skipping progress parsing');
      return;
    }
    
    if (totalDuration == null) {
      Logger.log('⚠️ No total duration provided, progress percentage will be unavailable');
    }
    
    try {
      // FFmpeg progress format includes lines like:
      // out_time_ms=12345678
      // progress=continue
      // speed=1.23x
      // Also check for time= format in regular output
      
      final lines = data.split('\n');
      Duration? currentTime;
      String speed = '';
      bool foundProgressData = false;
      
      for (final line in lines) {
        final trimmedLine = line.trim();
        
        // Parse progress stream format (from -progress pipe:2)
        if (trimmedLine.startsWith('out_time_ms=')) {
          final timeMs = int.tryParse(trimmedLine.substring('out_time_ms='.length));
          if (timeMs != null) {
            currentTime = Duration(microseconds: timeMs);
            foundProgressData = true;
            Logger.log('⏱️ Found out_time_ms: $timeMs (${_formatDuration(currentTime)})');
          }
        } else if (trimmedLine.startsWith('out_time=')) {
          // Alternative time format: out_time=00:01:23.45
          final timeStr = trimmedLine.substring('out_time='.length);
          currentTime = _parseTimeString(timeStr);
          if (currentTime != null) {
            foundProgressData = true;
            Logger.log('⏱️ Found out_time: $timeStr (${_formatDuration(currentTime)})');
          }
        } else if (trimmedLine.startsWith('speed=')) {
          speed = trimmedLine.substring('speed='.length);
          foundProgressData = true;
          Logger.log('🏃 Found speed: $speed');
        } else if (trimmedLine.contains('time=')) {
          // Parse regular FFmpeg output format: time=00:01:23.45
          final timeMatch = RegExp(r'time=(\d{2}:\d{2}:\d{2}\.\d{2})').firstMatch(trimmedLine);
          if (timeMatch != null) {
            currentTime = _parseTimeString(timeMatch.group(1)!);
            if (currentTime != null) {
              foundProgressData = true;
              Logger.log('⏱️ Found time from regular output: ${timeMatch.group(1)} (${_formatDuration(currentTime)})');
            }
          }
        } else if (trimmedLine.contains('speed=')) {
          // Parse speed from regular output
          final speedMatch = RegExp(r'speed=(\S+)').firstMatch(trimmedLine);
          if (speedMatch != null) {
            speed = speedMatch.group(1)!;
            foundProgressData = true;
            Logger.log('🏃 Found speed from regular output: $speed');
          }
        }
      }
      
      if (!foundProgressData) {
        Logger.log('⚠️ No progress data found in line: ${data.trim()}');
        return;
      }
      
      // Calculate progress percentage if we have both current and total time
      if (currentTime != null) {
        double percentage = 0.0;
        Duration? eta;
        
        if (totalDuration != null && totalDuration.inMicroseconds > 0) {
          percentage = (currentTime.inMicroseconds / totalDuration.inMicroseconds).clamp(0.0, 1.0);
          
          // Calculate ETA
          if (percentage > 0 && speed.isNotEmpty) {
            try {
              final speedValue = double.tryParse(speed.replaceAll('x', ''));
              if (speedValue != null && speedValue > 0) {
                final remainingTime = totalDuration - currentTime;
                eta = Duration(microseconds: (remainingTime.inMicroseconds / speedValue).round());
              }
            } catch (e) {
              Logger.log('⚠️ Error parsing speed value: $e');
            }
          }
        } else {
          // Even without total duration, we can show that progress is happening
          percentage = 0.1; // Show some progress to indicate activity
        }
        
        Logger.log('📊 Calculated progress: ${(percentage * 100).toStringAsFixed(1)}%');
        Logger.log('⏱️ Current time: ${_formatDuration(currentTime)}');
        if (totalDuration != null) Logger.log('⏱️ Total duration: ${_formatDuration(totalDuration)}');
        if (eta != null) Logger.log('⏱️ ETA: ${_formatDuration(eta)}');
        
        // Create and emit progress update
        final progressUpdate = ConversionProgress.converting(
          percentage: percentage,
          currentTime: currentTime,
          eta: eta,
          speed: speed,
        );
        
        Logger.log('📤 Emitting progress update to controller');
        progressController.add(progressUpdate);
        
      } else {
        Logger.log('⚠️ No current time found, cannot calculate progress');
      }
    } catch (e) {
      Logger.error('❌ Error parsing FFmpeg progress: $e');
      Logger.error('📋 Raw data was: ${data.trim()}');
    }
  }

  Duration? _parseTimeString(String timeStr) {
    try {
      Logger.log('🔍 Parsing time string: $timeStr');
      
      // Parse format like "00:01:23.45" or "01:23.45"
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hours = 0;
        int minutes = 0;
        double seconds = 0;
        
        if (parts.length == 3) {
          // HH:MM:SS.ss format
          hours = int.parse(parts[0]);
          minutes = int.parse(parts[1]);
          seconds = double.parse(parts[2]);
        } else if (parts.length == 2) {
          // MM:SS.ss format
          minutes = int.parse(parts[0]);
          seconds = double.parse(parts[1]);
        }
        
        final duration = Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds.floor(),
          milliseconds: ((seconds - seconds.floor()) * 1000).round(),
        );
        
        Logger.log('✅ Parsed time: ${_formatDuration(duration)}');
        return duration;
      }
    } catch (e) {
      Logger.error('❌ Error parsing time string "$timeStr": $e');
    }
    return null;
  }
  
  // Extract detailed audio information for debugging (existing method)
  Future<Map<String, dynamic>> extractDetailedAudioInfo(String filePath) async {
    try {
      final metadata = await MetadataGod.readMetadata(file: filePath);
      
      final info = {
        'title': metadata.title,
        'artist': metadata.artist,
        'album': metadata.album,
        'albumArtist': metadata.albumArtist,
        'genre': metadata.genre,
        'year': metadata.year,
        'trackNumber': metadata.trackNumber,
        'trackTotal': metadata.trackTotal,
        'discNumber': metadata.discNumber,
        'discTotal': metadata.discTotal,
        'durationMs': metadata.durationMs,
        'durationSeconds': metadata.durationMs != null ? (metadata.durationMs! / 1000).round() : null,
        'durationFormatted': metadata.durationMs != null ? _formatDuration(Duration(milliseconds: metadata.durationMs!.toInt())) : null,
        'fileSize': metadata.fileSize?.toString(),
        'hasPicture': metadata.picture != null,
        'pictureMimeType': metadata.picture?.mimeType,
        'pictureDataSize': metadata.picture?.data.length,
      };
      
      Logger.debug('Detailed audio info for ${path_util.basename(filePath)}: $info');
      return info;
    } catch (e) {
      Logger.error('Error extracting detailed audio info: $e');
      return {};
    }
  }

  Future<bool> mergeMP3FilesToM4B(
    List<ChapterInfo> chapters,
    String outputPath,
    AudiobookMetadata bookMetadata, {
    Function(String step, double progress)? onProgress,
  }) async {
    if (!_systemFFmpegAvailable || _systemFFmpegPath == null) {
      Logger.error('System FFmpeg not available for MP3 to M4B merging');
      return false;
    }

    if (chapters.isEmpty) {
      Logger.error('No chapters provided for merging');
      return false;
    }

    String? tempConcatPath;
    String? tempListPath;
    List<String> tempFiles = [];

    try {
      Logger.log('Starting MP3 to M4B merge process with ${chapters.length} chapters');
      onProgress?.call('Preparing merge process...', 0.0);

      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Create temporary concat file path
      tempConcatPath = path_util.join(tempDir.path, 'temp_concat_$timestamp.m4b');
      
      // Create FFmpeg concat file list
      tempListPath = path_util.join(tempDir.path, 'concat_list_$timestamp.txt');
      final concatListContent = chapters
          .map((chapter) => "file '${chapter.filePath.replaceAll("'", "\\'")}'")
          .join('\n');
      
      await File(tempListPath).writeAsString(concatListContent);
      tempFiles.add(tempListPath);
      
      Logger.log('Created concat list with ${chapters.length} files');
      onProgress?.call('Starting audio concatenation...', 0.05);

      // Step 1: Enhanced concatenation with progress tracking
      final concatSuccess = await _concatenateWithProgress(
        tempListPath,
        tempConcatPath,
        chapters,
        onProgress,
      );

      if (!concatSuccess) {
        Logger.error('Audio concatenation failed');
        return false;
      }

      tempFiles.add(tempConcatPath);
      Logger.log('Successfully concatenated MP3 files');
      onProgress?.call('Adding chapter metadata...', 0.6);

      // Step 2: Create chapter metadata file
      final chapterMetadataPath = await _createChapterMetadataFile(chapters, timestamp);
      if (chapterMetadataPath != null) {
        tempFiles.add(chapterMetadataPath);
      }

      onProgress?.call('Embedding chapters and metadata...', 0.7);

      // Step 3: Add chapters and metadata to the final M4B file
      final finalArgs = await _buildFinalMergeArgs(
        tempConcatPath,
        outputPath,
        bookMetadata,
        chapterMetadataPath,
      );

      Logger.log('FFmpeg final command: $_systemFFmpegPath ${finalArgs.join(' ')}');
      
      final finalResult = await Process.run(_systemFFmpegPath!, finalArgs);
      
      if (finalResult.exitCode != 0) {
        Logger.error('FFmpeg final merge failed with exit code: ${finalResult.exitCode}');
        Logger.error('FFmpeg final stderr: ${finalResult.stderr}');
        return false;
      }

      onProgress?.call('Verifying output...', 0.9);

      // Step 4: Verify the output file
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        Logger.error('Output file was not created');
        return false;
      }

      final outputSize = await outputFile.length();
      Logger.log('Created M4B file: ${path_util.basename(outputPath)} (${_formatFileSize(outputSize)})');

      // Step 5: Verify chapters were embedded correctly
      final chapterVerification = await _verifyChapters(outputPath, chapters.length);
      if (!chapterVerification) {
        Logger.warning('Chapter verification failed, but file was created');
      }

      onProgress?.call('Merge completed successfully!', 1.0);
      Logger.log('Successfully merged ${chapters.length} MP3 files into M4B audiobook');
      
      return true;

    } catch (e) {
      Logger.error('Error in mergeMP3FilesToM4B: $e');
      return false;
    } finally {
      // Cleanup temporary files
      for (final tempFile in tempFiles) {
        try {
          final file = File(tempFile);
          if (await file.exists()) {
            await file.delete();
            Logger.debug('Cleaned up: ${path_util.basename(tempFile)}');
          }
        } catch (e) {
          Logger.debug('Failed to cleanup $tempFile: $e');
        }
      }
    }
  }

  Future<bool> _concatenateWithProgress(
    String tempListPath,
    String tempConcatPath,
    List<ChapterInfo> chapters,
    Function(String step, double progress)? onProgress,
  ) async {
    try {
      Logger.log('Starting enhanced concatenation with progress tracking');
      
      // Calculate total duration for progress calculation
      final totalDuration = chapters.fold(Duration.zero, (sum, chapter) => sum + chapter.duration);
      Logger.log('Total duration for concatenation: ${_formatDuration(totalDuration)}');
      
      onProgress?.call('Concatenating ${chapters.length} audio files...', 0.1);

      final concatArgs = [
        '-f', 'concat',
        '-safe', '0',
        '-i', tempListPath,
        '-c:a', 'aac',
        '-b:a', '64k',
        '-f', 'mp4',
        '-movflags', '+faststart',
        '-progress', 'pipe:1', // Send progress to stdout instead of stderr
        '-v', 'info',           // Set verbosity level
        '-stats',               // Enable statistics
        '-y',
        tempConcatPath,
      ];

      Logger.log('FFmpeg concat command: $_systemFFmpegPath ${concatArgs.join(' ')}');
      
      // Start FFmpeg process
      final process = await Process.start(_systemFFmpegPath!, concatArgs);
      
      // Track progress by parsing stdout and stderr
      final Completer<bool> completer = Completer<bool>();
      bool hasError = false;
      
      // Enhanced progress tracking with both stdout and stderr
      final progressTracker = _EnhancedProgressTracker(
        totalDuration: totalDuration,
        onProgress: onProgress,
        baseProgress: 0.1,
        maxProgress: 0.55,
      );
      
      // Parse progress from stdout (where -progress pipe:1 sends data)
      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        progressTracker.parseFFmpegOutput(data, isProgressStream: true);
      });
      
      // Parse additional info from stderr
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        progressTracker.parseFFmpegOutput(data, isProgressStream: false);
      });
      
      // Set up a fallback progress timer in case FFmpeg progress isn't captured
      Timer? fallbackTimer;
      int fallbackStep = 0;
      
      fallbackTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (!completer.isCompleted) {
          fallbackStep++;
          final fallbackProgress = 0.1 + (fallbackStep * 0.05);
          final cappedProgress = math.min(fallbackProgress, 0.5);
          
          onProgress?.call(
            'Concatenating audio... (${fallbackStep * 2}s elapsed)', 
            cappedProgress
          );
          
          Logger.debug('Fallback progress: ${(cappedProgress * 100).toStringAsFixed(1)}%');
          
          // Stop fallback after reasonable time
          if (fallbackStep >= 20) {
            timer.cancel();
          }
        } else {
          timer.cancel();
        }
      });
      
      // Wait for process completion
      process.exitCode.then((exitCode) {
        fallbackTimer?.cancel();
        
        if (exitCode == 0) {
          Logger.log('Audio concatenation successful');
          onProgress?.call('Concatenation complete, preparing final merge...', 0.55);
          completer.complete(true);
        } else {
          Logger.error('FFmpeg concatenation failed with exit code: $exitCode');
          hasError = true;
          completer.complete(false);
        }
      });
      
      return await completer.future;
      
    } catch (e) {
      Logger.error('Error in enhanced concatenation: $e');
      return false;
    }
  }

  /// Parse FFmpeg concatenation progress output
  void _parseConcatenationProgress(
    String data, 
    Function(String step, double progress)? onProgress,
    Duration totalDuration,
  ) {
    if (onProgress == null) return;
    
    try {
      // FFmpeg progress format includes lines like:
      // out_time_ms=12345678
      // progress=continue
      // speed=1.23x
      
      final lines = data.split('\n');
      Duration? currentTime;
      String speed = '';
      
      for (final line in lines) {
        final trimmedLine = line.trim();
        
        if (trimmedLine.startsWith('out_time_ms=')) {
          final timeMs = int.tryParse(trimmedLine.substring('out_time_ms='.length));
          if (timeMs != null) {
            currentTime = Duration(microseconds: timeMs);
          }
        } else if (trimmedLine.startsWith('speed=')) {
          speed = trimmedLine.substring('speed='.length);
        }
      }
      
      // Calculate progress percentage if we have both current and total time
      if (currentTime != null && totalDuration.inMicroseconds > 0) {
        final rawProgress = (currentTime.inMicroseconds / totalDuration.inMicroseconds).clamp(0.0, 1.0);
        
        // Map concatenation progress to overall progress (10% to 55%)
        final mappedProgress = 0.1 + (rawProgress * 0.45);
        
        // Calculate ETA and format time strings
        final currentTimeStr = _formatDuration(currentTime);
        final totalTimeStr = _formatDuration(totalDuration);
        final progressPercent = (rawProgress * 100).toStringAsFixed(1);
        
        String statusMessage = 'Concatenating audio: $currentTimeStr / $totalTimeStr ($progressPercent%)';
        
        if (speed.isNotEmpty && speed != '0.0x') {
          statusMessage += ' @ $speed';
        }
        
        onProgress(statusMessage, mappedProgress);
        
        // Log progress occasionally for debugging
        if (rawProgress > 0 && (rawProgress * 100) % 10 < 1) {
          Logger.debug('Concatenation progress: $progressPercent% ($currentTimeStr / $totalTimeStr)');
        }
      }
    } catch (e) {
      Logger.debug('Error parsing concatenation progress: $e');
      // Don't fail the conversion for progress parsing errors
    }
  }

  /// Create FFmpeg chapter metadata file
  Future<String?> _createChapterMetadataFile(List<ChapterInfo> chapters, int timestamp) async {
    try {
      final tempDir = Directory.systemTemp;
      final metadataPath = path_util.join(tempDir.path, 'chapters_$timestamp.txt');
      
      final buffer = StringBuffer();
      buffer.writeln(';FFMETADATA1');
      
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        
        // Convert to milliseconds for FFmpeg
        final startMs = chapter.startTime.inMilliseconds;
        final endMs = (chapter.startTime + chapter.duration).inMilliseconds;
        
        buffer.writeln();
        buffer.writeln('[CHAPTER]');
        buffer.writeln('TIMEBASE=1/1000');
        buffer.writeln('START=$startMs');
        buffer.writeln('END=$endMs');
        buffer.writeln('title=${_escapeMetadataValue(chapter.title)}');
      }
      
      await File(metadataPath).writeAsString(buffer.toString());
      Logger.log('Created chapter metadata file with ${chapters.length} chapters');
      
      return metadataPath;
    } catch (e) {
      Logger.error('Error creating chapter metadata file: $e');
      return null;
    }
  }

  /// Build FFmpeg arguments for final merge with metadata and chapters
  Future<List<String>> _buildFinalMergeArgs(
    String inputPath,
    String outputPath,
    AudiobookMetadata bookMetadata,
    String? chapterMetadataPath,
  ) async {
    final List<String> args = [
      '-i', inputPath, // Input concatenated audio
    ];

    // Add chapter metadata file if available
    if (chapterMetadataPath != null) {
      args.addAll(['-i', chapterMetadataPath]);
      args.addAll(['-map_metadata', '1']); // Map metadata from second input
    }

    // Add cover image if available
    if (bookMetadata.thumbnailUrl.isNotEmpty && 
        !bookMetadata.thumbnailUrl.startsWith('http')) {
      final coverFile = File(bookMetadata.thumbnailUrl);
      if (await coverFile.exists()) {
        args.addAll(['-i', bookMetadata.thumbnailUrl]);
        args.addAll([
          '-map', '0:a',         // Map audio from first input
          '-map', '2:v',         // Map video (cover) from third input
          '-c:a', 'copy',        // Copy audio without re-encoding
          '-c:v', 'copy',        // Copy video without re-encoding
          '-disposition:v:0', 'attached_pic', // Mark video as attached picture
          '-threads', '0', 
        ]);
        Logger.log('Adding cover image to M4B');
      } else {
        args.addAll(['-c:a', 'copy']); // Copy audio only
      }
    } else {
      args.addAll(['-c:a', 'copy']); // Copy audio only
    }

    // Add comprehensive metadata
    _addMetadataToArgs(args, bookMetadata);

    // Output file with overwrite
    args.addAll(['-y', outputPath]);

    return args;
  }

  /// Add metadata arguments to FFmpeg command
  void _addMetadataToArgs(List<String> args, AudiobookMetadata bookMetadata) {
    // Core metadata
    if (bookMetadata.title.isNotEmpty) {
      args.addAll(['-metadata', 'title=${_escapeMetadataValue(bookMetadata.title)}']);
    }

    if (bookMetadata.subtitle.isNotEmpty) {
      final fullTitle = '${bookMetadata.title}: ${bookMetadata.subtitle}';
      args.addAll(['-metadata', 'title=${_escapeMetadataValue(fullTitle)}']);
    }

    // Author information
    if (bookMetadata.authors.isNotEmpty) {
      args.addAll(['-metadata', 'artist=${_escapeMetadataValue(bookMetadata.authors.first)}']);
      args.addAll(['-metadata', 'albumartist=${_escapeMetadataValue(bookMetadata.authors.join(', '))}']);
    }

    // Album field - prefer series, fallback to title
    if (bookMetadata.series.isNotEmpty) {
      args.addAll(['-metadata', 'album=${_escapeMetadataValue(bookMetadata.series)}']);
    } else if (bookMetadata.title.isNotEmpty) {
      args.addAll(['-metadata', 'album=${_escapeMetadataValue(bookMetadata.title)}']);
    }

    // Publisher
    if (bookMetadata.publisher.isNotEmpty) {
      args.addAll(['-metadata', 'publisher=${_escapeMetadataValue(bookMetadata.publisher)}']);
    }

    // Publishing date
    if (bookMetadata.publishedDate.isNotEmpty) {
      args.addAll(['-metadata', 'date=${_escapeMetadataValue(bookMetadata.publishedDate)}']);
      args.addAll(['-metadata', 'year=${_escapeMetadataValue(bookMetadata.publishedDate)}']);
    }

    // Genre
    if (bookMetadata.categories.isNotEmpty) {
      args.addAll(['-metadata', 'genre=${_escapeMetadataValue(bookMetadata.categories.first)}']);
    } else if (bookMetadata.mainCategory.isNotEmpty) {
      args.addAll(['-metadata', 'genre=${_escapeMetadataValue(bookMetadata.mainCategory)}']);
    } else {
      args.addAll(['-metadata', 'genre=Audiobook']);
    }

    // Description
    if (bookMetadata.description.isNotEmpty) {
      args.addAll(['-metadata', 'comment=${_escapeMetadataValue(bookMetadata.description)}']);
      args.addAll(['-metadata', 'description=${_escapeMetadataValue(bookMetadata.description)}']);
    }

    // Series position
    if (bookMetadata.seriesPosition.isNotEmpty) {
      args.addAll(['-metadata', 'track=${_escapeMetadataValue(bookMetadata.seriesPosition)}']);
    }

    // Language
    if (bookMetadata.language.isNotEmpty) {
      args.addAll(['-metadata', 'language=${_escapeMetadataValue(bookMetadata.language)}']);
    }

    // ISBN if available
    final isbn = bookMetadata.isbn;
    if (isbn.isNotEmpty) {
      args.addAll(['-metadata', 'ISBN=${_escapeMetadataValue(isbn)}']);
    }

    // Narrator (using composer field)
    if (bookMetadata.narrator.isNotEmpty) {
      args.addAll(['-metadata', 'composer=${_escapeMetadataValue(bookMetadata.narrator)}']);
    }
  }

  /// Verify that chapters were embedded correctly
  Future<bool> _verifyChapters(String outputPath, int expectedChapterCount) async {
    try {
      Logger.log('Verifying chapters in output file...');
      
      if (_systemFFmpegPath == null) return false;
      
      // Use FFprobe to check chapters
      final result = await Process.run(_systemFFmpegPath!.replaceAll('ffmpeg', 'ffprobe'), [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_chapters',
        outputPath,
      ]);
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        // Count chapter entries in JSON output
        final chapterCount = RegExp(r'"title"').allMatches(output).length;
        Logger.log('Found $chapterCount chapters in output file (expected: $expectedChapterCount)');
        return chapterCount >= expectedChapterCount;
      }
      
      Logger.warning('Could not verify chapters using FFprobe');
      return false;
    } catch (e) {
      Logger.error('Error verifying chapters: $e');
      return false;
    }
  }

  /// Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  // Extract just the cover art from a file (existing method)
  Future<Picture?> extractCoverArt(String filePath) async {
    try {
      final metadata = await MetadataGod.readMetadata(file: filePath);
      return metadata.picture;
    } catch (e) {
      Logger.error('Error extracting cover art from file: $filePath', e);
      return null;
    }
  }
  
  // Write only the cover art to a file (preserves other metadata) (existing method)
  Future<bool> writeCoverArt(String filePath, String coverImagePath) async {
    try {
      // First, read existing metadata
      final existingMetadata = await MetadataGod.readMetadata(file: filePath);
      
      // Prepare the new picture data
      final coverFile = File(coverImagePath);
      if (!await coverFile.exists()) {
        Logger.error('Cover image file does not exist: $coverImagePath');
        return false;
      }
      
      final imageBytes = await coverFile.readAsBytes();
      final mimeType = lookupMimeType(coverImagePath) ?? 'image/jpeg';
      
      final picture = Picture(
        data: imageBytes,
        mimeType: mimeType,
      );
      
      // Create new metadata with updated picture using all existing MetadataGod fields
      final newMetadata = Metadata(
        title: existingMetadata.title,
        artist: existingMetadata.artist,
        album: existingMetadata.album,
        albumArtist: existingMetadata.albumArtist,
        genre: existingMetadata.genre,
        year: existingMetadata.year,
        trackNumber: existingMetadata.trackNumber,
        trackTotal: existingMetadata.trackTotal,
        discNumber: existingMetadata.discNumber,
        discTotal: existingMetadata.discTotal,
        durationMs: existingMetadata.durationMs,
        picture: picture,
        fileSize: existingMetadata.fileSize,
      );
      
      // Write the metadata back to the file
      await MetadataGod.writeMetadata(
        file: filePath,
        metadata: newMetadata,
      );
      
      Logger.log('Successfully wrote cover art to file: $filePath');
      return true;
    } catch (e) {
      Logger.error('Error writing cover art to file: $filePath', e);
      return false;
    }
  }
  
  // Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_files': _metadataCache.length,
      'initialized': _isInitialized,
      'ffmpeg_available': _ffmpegAvailable,
      'ffmpeg_kit_available': _ffmpegKitAvailable,
      'system_ffmpeg_available': _systemFFmpegAvailable,
      'system_ffmpeg_path': _systemFFmpegPath,
    };
  }
  
  // Helper method to format duration
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  // Clear cache
  void clearCache() {
    _metadataCache.clear();
    Logger.debug('Metadata cache cleared');
  }
}

class _EnhancedProgressTracker {
  final Duration totalDuration;
  final Function(String step, double progress)? onProgress;
  final double baseProgress;
  final double maxProgress;
  
  Duration? _lastReportedTime;
  DateTime? _startTime;
  int _frameCount = 0;
  
  _EnhancedProgressTracker({
    required this.totalDuration,
    required this.onProgress,
    required this.baseProgress,
    required this.maxProgress,
  }) {
    _startTime = DateTime.now();
  }
  
  void parseFFmpegOutput(String data, {required bool isProgressStream}) {
    if (onProgress == null) return;
    
    try {
      final lines = data.split('\n');
      Duration? currentTime;
      String speed = '';
      int? currentFrame;
      
      for (final line in lines) {
        final trimmedLine = line.trim();
        
        if (isProgressStream) {
          // Parse progress stream format
          if (trimmedLine.startsWith('out_time_ms=')) {
            final timeMs = int.tryParse(trimmedLine.substring('out_time_ms='.length));
            if (timeMs != null) {
              currentTime = Duration(microseconds: timeMs);
            }
          } else if (trimmedLine.startsWith('out_time=')) {
            // Alternative time format: out_time=00:01:23.45
            final timeStr = trimmedLine.substring('out_time='.length);
            currentTime = _parseTimeString(timeStr);
          } else if (trimmedLine.startsWith('speed=')) {
            speed = trimmedLine.substring('speed='.length);
          } else if (trimmedLine.startsWith('frame=')) {
            final frameStr = trimmedLine.substring('frame='.length);
            currentFrame = int.tryParse(frameStr);
          }
        } else {
          // Parse stderr output for additional progress indicators
          if (trimmedLine.contains('time=')) {
            final timeMatch = RegExp(r'time=(\d{2}:\d{2}:\d{2}\.\d{2})').firstMatch(trimmedLine);
            if (timeMatch != null) {
              currentTime = _parseTimeString(timeMatch.group(1)!);
            }
          }
          
          if (trimmedLine.contains('speed=')) {
            final speedMatch = RegExp(r'speed=(\S+)').firstMatch(trimmedLine);
            if (speedMatch != null) {
              speed = speedMatch.group(1)!;
            }
          }
        }
      }
      
      // Update progress if we have new time information
      if (currentTime != null && currentTime != _lastReportedTime) {
        _updateProgress(currentTime, speed, currentFrame);
        _lastReportedTime = currentTime;
      }
      
    } catch (e) {
      Logger.debug('Error parsing FFmpeg output: $e');
    }
  }
  
  void _updateProgress(Duration currentTime, String speed, int? frameCount) {
    if (totalDuration.inMicroseconds <= 0) return;
    
    final rawProgress = (currentTime.inMicroseconds / totalDuration.inMicroseconds).clamp(0.0, 1.0);
    final mappedProgress = baseProgress + (rawProgress * (maxProgress - baseProgress));
    
    // Calculate elapsed time
    final elapsed = _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero;
    
    // Calculate ETA
    Duration? eta;
    if (rawProgress > 0.01 && speed.isNotEmpty) {
      try {
        final speedValue = double.tryParse(speed.replaceAll('x', ''));
        if (speedValue != null && speedValue > 0) {
          final remainingTime = totalDuration - currentTime;
          eta = Duration(microseconds: (remainingTime.inMicroseconds / speedValue).round());
        }
      } catch (e) {
        // Ignore speed parsing errors
      }
    }
    
    // Format status message
    final currentTimeStr = _formatDuration(currentTime);
    final totalTimeStr = _formatDuration(totalDuration);
    final progressPercent = (rawProgress * 100).toStringAsFixed(1);
    
    String statusMessage = 'Concatenating: $currentTimeStr / $totalTimeStr ($progressPercent%)';
    
    if (speed.isNotEmpty && speed != '0.0x') {
      statusMessage += ' @ $speed';
    }
    
    if (eta != null && eta.inSeconds > 0) {
      statusMessage += ' • ETA: ${_formatDuration(eta)}';
    }
    
    if (frameCount != null) {
      _frameCount = frameCount;
      statusMessage += ' • Frame: $frameCount';
    }
    
    onProgress!(statusMessage, mappedProgress);
    
    // Log significant progress milestones
    if (rawProgress > 0 && (rawProgress * 100) % 20 < 2) {
      Logger.log('Concatenation milestone: $progressPercent% complete');
      Logger.log('- Current: $currentTimeStr / $totalTimeStr');
      Logger.log('- Speed: $speed, Elapsed: ${_formatDuration(elapsed)}');
      if (eta != null) Logger.log('- ETA: ${_formatDuration(eta)}');
    }
  }
  
  Duration? _parseTimeString(String timeStr) {
    try {
      // Parse format like "00:01:23.45" or "01:23.45"
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hours = 0;
        int minutes = 0;
        double seconds = 0;
        
        if (parts.length == 3) {
          // HH:MM:SS.ss format
          hours = int.parse(parts[0]);
          minutes = int.parse(parts[1]);
          seconds = double.parse(parts[2]);
        } else if (parts.length == 2) {
          // MM:SS.ss format
          minutes = int.parse(parts[0]);
          seconds = double.parse(parts[1]);
        }
        
        return Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds.floor(),
          milliseconds: ((seconds - seconds.floor()) * 1000).round(),
        );
      }
    } catch (e) {
      Logger.debug('Error parsing time string "$timeStr": $e');
    }
    return null;
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}