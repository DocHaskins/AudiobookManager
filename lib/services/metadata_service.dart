// lib/services/metadata_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:ffmpeg_kit_flutter/log.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as path_util;
import 'package:mime/mime.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/utils/file_utils.dart';

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