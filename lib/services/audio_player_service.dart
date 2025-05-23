// lib/services/audio_player_service.dart
import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/storage/audiobook_storage_manager.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// Service for playing audiobooks with improved Windows compatibility
class AudioPlayerService {
  // Player instance
  AudioPlayer? _player;
  bool _isWindowsPlatform = false;
  bool _isPlayerInitialized = false;
  
  // Currently playing file
  AudiobookFile? _currentFile;
  
  // Storage manager for saving playback state
  final AudiobookStorageManager _storageManager;
  
  // Timer for periodic state saving
  Timer? _saveProgressTimer;
  
  // Sleep timer
  Timer? _sleepTimer;
  Duration? _sleepTimerDuration;
  
  // Status streams
  final _playerStateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _speedController = StreamController<double>.broadcast();
  
  // Add file change controller to notify UI when file changes
  final _fileChangeController = StreamController<AudiobookFile?>.broadcast();
  
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  Stream<double> get speedStream => _speedController.stream;
  Stream<AudiobookFile?> get fileChangeStream => _fileChangeController.stream;
  
  // Sleep timer controller
  final _sleepTimerController = StreamController<Duration?>.broadcast();
  Stream<Duration?> get sleepTimerStream => _sleepTimerController.stream;
  
  // Default values
  Duration _currentPosition = Duration.zero;
  Duration? _totalDuration;
  bool _playing = false;
  double _speed = 1.0;
  double _volume = 1.0;
  
  // Periodic position update timer
  Timer? _positionUpdateTimer;
  DateTime? _lastMetadataUpdate;
  static const Duration _metadataUpdateThrottle = Duration(seconds: 5);
  
  // Constructor
  AudioPlayerService({required AudiobookStorageManager storageManager})
      : _storageManager = storageManager {
    _initPlayer();
  }
  
  // Initialize player
  void _initPlayer() {
    try {
      _isWindowsPlatform = Platform.isWindows;
      Logger.log('Initializing audio player (Platform: ${Platform.operatingSystem}, Windows: $_isWindowsPlatform)');
      
      // Create player instance with catch for Windows
      try {
        _player = AudioPlayer();
        Logger.debug('AudioPlayer instance created successfully');
      } catch (e) {
        Logger.error('Error creating AudioPlayer instance', e);
        // We'll continue with null player and handle it in play/pause methods
      }
      
      if (!_isWindowsPlatform && _player != null) {
        // For non-Windows platforms, set up standard stream forwarding
        _setupStreamForwarding();
        Logger.log('Standard audio streams forwarded successfully');
      } else {
        // For Windows, set up periodic position updates
        _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
          if (_player != null && _isPlayerInitialized && _playing) {
            _updatePositionState();
          }
        });
        Logger.log('Windows-specific position update timer initialized');
      }
      
      // FIXED: Reduced frequency of progress saving
      _saveProgressTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
        _savePlaybackState();
      });
      
      _isPlayerInitialized = true;
      Logger.log('Audio player initialized successfully');
    } catch (e, stackTrace) {
      Logger.error('Error initializing audio player', e, stackTrace);
      // Create a fallback implementation for streams if initialization failed
      _createFallbackStreams();
    }
  }
  
  // Set up standard stream forwarding
  void _setupStreamForwarding() {
    if (_player == null) return;
    
    Logger.debug('Setting up stream forwarding for audio player');
    
    // Forward player streams to our controllers
    _player!.playerStateStream.listen((state) {
      _playing = state.playing;
      _playerStateController.add(state);
      Logger.debug('Player state changed: playing=${state.playing}, state=${state.processingState}');
    }, onError: (e) => Logger.error('Error in playerStateStream', e));
    
    // FIXED: Add throttling to position stream
    _player!.positionStream.listen((position) {
      if (position.inMilliseconds < 0 || !position.inMilliseconds.isFinite) {
        Logger.warning('Received invalid position from player: $position, ignoring');
        return;
      }
      
      _currentPosition = position;
      _positionController.add(position);
      
      // FIXED: Throttle metadata updates
      if (_currentFile != null && position.inSeconds > 0) {
        _updateFilePlaybackPositionThrottled(position);
      }
    }, onError: (e) => Logger.error('Error in positionStream', e));
    
    _player!.durationStream.listen((duration) {
      if (duration != null && (duration.inMilliseconds < 0 || !duration.inMilliseconds.isFinite)) {
        Logger.warning('Received invalid duration from player: $duration, ignoring');
        return;
      }
      
      _totalDuration = duration;
      _durationController.add(duration);
      Logger.debug('Duration updated: $duration');
    }, onError: (e) => Logger.error('Error in durationStream', e));
    
    _player!.volumeStream.listen((volume) {
      _volume = volume;
      _volumeController.add(volume);
    }, onError: (e) => Logger.error('Error in volumeStream', e));
    
    _player!.speedStream.listen((speed) {
      _speed = speed;
      _speedController.add(speed);
    }, onError: (e) => Logger.error('Error in speedStream', e));
    
    // Set up playback completion handling
    _player!.processingStateStream.listen((state) {
      Logger.debug('Processing state changed: $state');
      if (state == ProcessingState.completed && _currentFile != null) {
        Logger.log('Playback completed for file: ${_currentFile!.path}');
        // Mark as completed
        _storageManager.updateUserData(
          _currentFile!.path,
          playbackPosition: Duration.zero,
          lastPlayedPosition: DateTime.now(),
        );
      }
    }, onError: (e) => Logger.error('Error in processingStateStream', e));
  }
  
  // Update position manually (for Windows)
  void _updatePositionState() {
    if (_player == null) return;
    
    try {
      // Get current position safely
      Duration position;
      try {
        position = _player!.position;
        // Guard against invalid position values - improved validation
        if (position.inMilliseconds < 0 || 
            !position.inMilliseconds.isFinite ||
            position.inMilliseconds.isNaN ||
            position.inMilliseconds.isInfinite) {
          Logger.warning('Invalid position detected: $position, using previous position instead');
          position = _currentPosition; // Use previous valid position
        }
      } catch (e) {
        Logger.warning('Error getting player position', e);
        position = _currentPosition; // Use previous valid position
      }
      
      _currentPosition = position;
      _positionController.add(_currentPosition);
      
      // FIXED: Throttle metadata updates
      if (_currentFile != null && _currentPosition.inSeconds > 0) {
        _updateFilePlaybackPositionThrottled(_currentPosition);
      }
      
      // Get duration safely
      Duration? duration;
      try {
        duration = _player!.duration;
        // Guard against invalid duration values - improved validation
        if (duration != null && 
            (duration.inMilliseconds < 0 || 
             !duration.inMilliseconds.isFinite ||
             duration.inMilliseconds.isNaN || 
             duration.inMilliseconds.isInfinite)) {
          Logger.warning('Invalid duration detected: $duration, using previous duration instead');
          duration = _totalDuration; // Use previous valid duration
        }
      } catch (e) {
        Logger.warning('Error getting player duration', e);
        duration = _totalDuration; // Use previous valid duration
      }
      
      if (duration != null) {
        _totalDuration = duration;
        _durationController.add(duration);
      }
      
      // Check for playback completion
      if (_totalDuration != null && _currentPosition.inMilliseconds > 0 &&
          _currentPosition.inMilliseconds >= _totalDuration!.inMilliseconds - 500) {
        Logger.log('Playback completed (detected manually) for file: ${_currentFile?.path}');
        // Mark as completed
        if (_currentFile != null) {
          _storageManager.updateUserData(
            _currentFile!.path,
            playbackPosition: Duration.zero,
            lastPlayedPosition: DateTime.now(),
          );
        }
        
        // Update state (FIXED: Correct order - playing first, then processingState)
        _playing = false;
        final currentProcessingState = _player!.processingState;
        _playerStateController.add(PlayerState(false, currentProcessingState));
      }
    } catch (e) {
      Logger.error('Error updating position state', e);
    }
  }
  
  // Create fallback streams if player initialization fails
  void _createFallbackStreams() {
    Logger.warning('Creating fallback stream implementations');
    // We'll just create controllers that never emit anything
    // but at least they won't crash
  }
  
  // Save current playback state
  Future<void> _savePlaybackState() async {
    if (_currentFile == null || !_playing) return;
    
    final position = _currentPosition;
    await _updateFilePlaybackPosition(position);
  }
  
  // FIXED: Add throttled version of position update
  void _updateFilePlaybackPositionThrottled(Duration position) {
    final now = DateTime.now();
    
    // Check if enough time has passed since last update
    if (_lastMetadataUpdate != null && 
        now.difference(_lastMetadataUpdate!) < _metadataUpdateThrottle) {
      return; // Skip this update
    }
    
    _lastMetadataUpdate = now;
    _updateFilePlaybackPosition(position);
  }
  
  // Update file playback position
  Future<void> _updateFilePlaybackPosition(Duration position) async {
    if (_currentFile == null) return;
    
    // Guard against invalid positions - improved validation
    if (!position.inMilliseconds.isFinite || 
        position.inMilliseconds.isNaN || 
        position.inMilliseconds.isInfinite || 
        position.inMilliseconds < 0) {
      Logger.warning('Invalid position detected during save: $position, skipping update');
      return;
    }
    
    // FIXED: Only save significant changes (more than 10 seconds instead of 2)
    final currentMetadata = _currentFile!.metadata;
    if (currentMetadata != null) {
      final currentPosition = currentMetadata.playbackPosition;
      if (currentPosition != null && 
          (position - currentPosition).abs().inSeconds < 10) {
        return;
      }
    }
    
    try {
      await _storageManager.updateUserData(
        _currentFile!.path,
        playbackPosition: position,
        lastPlayedPosition: DateTime.now(),
      );
      Logger.debug('Updated playback position: ${position.inSeconds}s');
    } catch (e) {
      Logger.error('Error updating playback position', e);
    }
  }
  
  // FIXED: Enhanced audio loading with better error handling for Windows
  Future<bool> play(AudiobookFile file) async {
    try {
      Logger.log('Playing audiobook: ${file.path}');
      
      // Save current state before stopping if we have a different file
      if (_currentFile != null && _currentFile!.path != file.path) {
        await _savePlaybackState();
      }
      
      // Reset state variables first to avoid UI showing incorrect info
      _currentPosition = Duration.zero;
      _totalDuration = null;
      
      // Stop any current playback
      await stop();
      
      // Check if file exists
      if (!await File(file.path).exists()) {
        Logger.error('File does not exist: ${file.path}');
        return false;
      }
      
      // FIXED: Validate file is actually an audio file
      if (!_isValidAudioFile(file.path)) {
        Logger.error('File is not a valid audio file: ${file.path}');
        return false;
      }
      
      if (_player == null) {
        Logger.log('Audio player is null, attempting to recreate');
        try {
          _player = AudioPlayer();
          _isPlayerInitialized = true;
          // Set up forwarding even for Windows in this case
          _setupStreamForwarding();
        } catch (e) {
          Logger.error('Failed to recreate AudioPlayer', e);
          return false;
        }
      }
      
      // Windows-specific handling
      String safePath = file.path;
      if (_isWindowsPlatform) {
        // Ensure the path is properly formatted for Windows
        safePath = safePath.replaceAll('\\', '/');
        Logger.debug('Windows path formatted to: $safePath');
      }
      
      // FIXED: Enhanced file loading with better error recovery
      bool loadSuccess = false;
      Exception? lastError;
      
      // Try multiple methods to load the file
      try {
        Logger.debug('Attempting to load audio via setFilePath');
        await _player!.setFilePath(safePath);
        Logger.log('Loaded audio file with setFilePath');
        loadSuccess = true;
      } catch (e) {
        lastError = e as Exception;
        Logger.warning('Failed to load audio with setFilePath', e);
        
        try {
          Logger.debug('Attempting to load audio via AudioSource.file');
          await _player!.setAudioSource(AudioSource.file(safePath));
          Logger.log('Loaded audio file with AudioSource.file');
          loadSuccess = true;
        } catch (e) {
          lastError = e as Exception;
          Logger.warning('Failed to load audio with AudioSource.file', e);
          
          // Try one final method for Windows
          if (_isWindowsPlatform) {
            try {
              Logger.debug('Attempting to load audio via Uri parsing (Windows)');
              final uri = Uri.file(safePath);
              await _player!.setUrl(uri.toString());
              Logger.log('Loaded audio file with setUrl');
              loadSuccess = true;
            } catch (e) {
              lastError = e as Exception;
              Logger.error('All loading methods failed', e);
            }
          }
        }
      }
      
      if (!loadSuccess) {
        Logger.error('Failed to load audio file after all attempts', lastError);
        return false;
      }
      
      // Set current file and notify listeners BEFORE continuing with setup
      _currentFile = file;
      _fileChangeController.add(file);
      
      // Get metadata to restore position
      final metadata = file.metadata;
      
      // Resume from last position if available
      if (metadata?.playbackPosition != null) {
        try {
          // Validate the position before seeking
          final position = metadata!.playbackPosition!;
          if (position.inMilliseconds > 0 && 
              position.inMilliseconds.isFinite) {
            
            // Add a small delay to ensure the audio is properly loaded before seeking
            await Future.delayed(const Duration(milliseconds: 500)); // Increased delay
            await _player!.seek(position);
            _currentPosition = position;
            _positionController.add(position);
            Logger.log('Resumed from position: $position');
          } else {
            Logger.warning('Invalid saved position: $position, starting from beginning');
          }
        } catch (e) {
          Logger.error('Error seeking to saved position', e);
          // Continue playing even if seeking fails
        }
      }
      
      // Get total duration (might be async)
      _player!.durationStream.first.then((duration) {
        if (duration != null && duration.inMilliseconds > 0 && duration.inMilliseconds.isFinite) {
          _totalDuration = duration;
          _durationController.add(duration);
          Logger.debug('Total duration detected: $duration');
        }
      }).catchError((e) {
        Logger.error('Error getting duration', e);
        return null;
      });
      
      // Start playback
      await _player!.play();
      _playing = true;
      
      // FIXED: Correct order - playing first, then processingState
      _playerStateController.add(PlayerState(true, _player!.processingState));
      
      Logger.log('Playback started successfully for: ${file.filename}');
      
      return true;
    } catch (e, stackTrace) {
      Logger.error('Error playing audiobook: ${file.path}', e, stackTrace);
      return false;
    }
  }
  
  // FIXED: Add file validation
  bool _isValidAudioFile(String filePath) {
    const validExtensions = ['.mp3', '.m4a', '.m4b', '.aac', '.ogg', '.wma', '.flac', '.opus'];
    final extension = filePath.toLowerCase().substring(filePath.lastIndexOf('.'));
    
    if (!validExtensions.contains(extension)) {
      return false;
    }
    
    // Additional check for file size (should be > 1KB for valid audio)
    try {
      final file = File(filePath);
      final size = file.lengthSync();
      return size > 1024; // Must be larger than 1KB
    } catch (e) {
      Logger.error('Error checking file size: $filePath', e);
      return false;
    }
  }
  
  // ... (rest of the methods remain the same as in your original code)
  
  // Pause playback
  Future<void> pause() async {
    try {
      Logger.debug('Pausing playback');
      if (_player != null && _isPlayerInitialized) {
        await _player!.pause();
        _playing = false;
        
        // FIXED: Correct order - playing first, then processingState
        _playerStateController.add(PlayerState(false, _player!.processingState));
      }
      
      // Save current position
      await _savePlaybackState();
      Logger.debug('Playback paused, state saved');
    } catch (e) {
      Logger.error('Error pausing playback', e);
    }
  }
  
  // Resume playback
  Future<void> resume() async {
    try {
      Logger.debug('Resuming playback');
      if (_player != null && _isPlayerInitialized) {
        await _player!.play();
        _playing = true;
        
        // FIXED: Correct order - playing first, then processingState
        _playerStateController.add(PlayerState(true, _player!.processingState));
      }
      Logger.debug('Playback resumed');
    } catch (e) {
      Logger.error('Error resuming playback', e);
    }
  }
  
  // Stop playback
  Future<void> stop() async {
    try {
      Logger.debug('Stopping playback');
      
      // Save final position
      await _savePlaybackState();
      
      if (_player != null && _isPlayerInitialized) {
        await _player!.stop();
        _playing = false;
        
        // FIXED: Correct order - playing first, then processingState
        _playerStateController.add(PlayerState(false, _player!.processingState));
      }
      
      // Clear the current file and notify listeners
      AudiobookFile? oldFile = _currentFile;
      _currentFile = null;
      if (oldFile != null) {
        _fileChangeController.add(null);
      }
      
      // Cancel sleep timer
      cancelSleepTimer();
      Logger.debug('Playback stopped completely');
    } catch (e) {
      Logger.error('Error stopping playback', e);
    }
  }
  
  // Seek to position
  Future<void> seekTo(Duration position) async {
    try {
      // Improved validation
      if (!position.inMilliseconds.isFinite || 
          position.inMilliseconds.isNaN || 
          position.inMilliseconds.isInfinite || 
          position.inMilliseconds < 0) {
        Logger.warning('Attempt to seek to invalid position: $position, ignoring');
        return;
      }
      
      Logger.debug('Seeking to position: $position');
      if (_player != null && _isPlayerInitialized) {
        // For Windows, add a small delay to ensure the audio is properly loaded
        if (_isWindowsPlatform) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        await _player!.seek(position);
        _currentPosition = position;
        _positionController.add(position);
        
        // Force save position after seeking
        await _updateFilePlaybackPosition(position);
      }
    } catch (e) {
      Logger.error('Error seeking to position', e);
    }
  }
  
  // Skip forward
  Future<void> skipForward({Duration duration = const Duration(seconds: 30)}) async {
    try {
      Logger.debug('Skipping forward by $duration');
      final newPosition = _currentPosition + duration;
      await seekTo(newPosition);
    } catch (e) {
      Logger.error('Error skipping forward', e);
    }
  }
  
  // Skip backward
  Future<void> skipBackward({Duration duration = const Duration(seconds: 10)}) async {
    try {
      Logger.debug('Skipping backward by $duration');
      final newPosition = _currentPosition - duration;
      await seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
    } catch (e) {
      Logger.error('Error skipping backward', e);
    }
  }
  
  // Set playback speed
  Future<void> setSpeed(double speed) async {
    try {
      // Improved validation
      if (!speed.isFinite || speed <= 0) {
        Logger.warning('Invalid speed value: $speed, using 1.0 instead');
        speed = 1.0;
      }
      
      Logger.debug('Setting playback speed to $speed');
      if (_player != null && _isPlayerInitialized) {
        await _player!.setSpeed(speed);
        _speed = speed;
        _speedController.add(speed);
      }
    } catch (e) {
      Logger.error('Error setting playback speed', e);
    }
  }
  
  // Set volume
  Future<void> setVolume(double volume) async {
    try {
      // Improved validation
      if (!volume.isFinite || volume < 0 || volume > 1) {
        Logger.warning('Invalid volume value: $volume, clamping to valid range');
        volume = volume.clamp(0.0, 1.0);
      }
      
      Logger.debug('Setting volume to $volume');
      if (_player != null && _isPlayerInitialized) {
        await _player!.setVolume(volume);
        _volume = volume;
        _volumeController.add(volume);
      }
    } catch (e) {
      Logger.error('Error setting volume', e);
    }
  }
  
  // Set sleep timer
  void setSleepTimer(Duration duration) {
    // Cancel existing timer if any
    if (_sleepTimer != null) {
      _sleepTimer!.cancel();
      _sleepTimer = null;
    }
    
    // Set new timer
    _sleepTimerDuration = duration;
    _sleepTimer = Timer(duration, () {
      pause();
      _sleepTimerDuration = null;
      _sleepTimerController.add(null);
    });
    
    // Notify listeners
    _sleepTimerController.add(duration);
    
    Logger.log('Sleep timer set for ${duration.inMinutes} minutes');
  }
  
  // Cancel sleep timer
  void cancelSleepTimer() {
    if (_sleepTimer != null) {
      _sleepTimer!.cancel();
      _sleepTimer = null;
      _sleepTimerDuration = null;
      _sleepTimerController.add(null);
      Logger.log('Sleep timer cancelled');
    }
  }
  
  // Get remaining sleep timer duration
  Duration? getRemainingTimerDuration() {
    if (_sleepTimer == null || _sleepTimerDuration == null) {
      return null;
    }
    
    final elapsed = _sleepTimerDuration! - Duration(milliseconds: _sleepTimer!.tick);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }
  
  // Add bookmark at current position
  Future<AudiobookBookmark?> addBookmark(String title, {String? note}) async {
    if (_currentFile == null) return null;
    
    try {
      final position = _currentPosition;
      final bookmarkId = const Uuid().v4();
      
      final bookmark = AudiobookBookmark(
        id: bookmarkId,
        title: title,
        position: position,
        createdAt: DateTime.now(),
        note: note,
      );
      
      final success = await _storageManager.addBookmark(_currentFile!.path, bookmark);
      
      if (success) {
        // Reload metadata
        _currentFile!.metadata = await _storageManager.getMetadataForFile(_currentFile!.path);
        Logger.log('Added bookmark at ${position.toString()} with title: $title');
        return bookmark;
      } else {
        Logger.error('Failed to add bookmark');
        return null;
      }
    } catch (e) {
      Logger.error('Error adding bookmark', e);
      return null;
    }
  }
  
  // Remove a bookmark
  Future<bool> removeBookmark(String bookmarkId) async {
    if (_currentFile == null) return false;
    
    try {
      final success = await _storageManager.removeBookmark(_currentFile!.path, bookmarkId);
      
      if (success) {
        // Reload metadata
        _currentFile!.metadata = await _storageManager.getMetadataForFile(_currentFile!.path);
        Logger.log('Removed bookmark: $bookmarkId');
        return true;
      } else {
        Logger.error('Failed to remove bookmark');
        return false;
      }
    } catch (e) {
      Logger.error('Error removing bookmark', e);
      return false;
    }
  }
  
  // Jump to bookmark
  Future<bool> jumpToBookmark(AudiobookBookmark bookmark) async {
    try {
      await seekTo(bookmark.position);
      Logger.log('Jumped to bookmark: ${bookmark.title} at ${bookmark.position}');
      return true;
    } catch (e) {
      Logger.error('Error jumping to bookmark', e);
      return false;
    }
  }
  
  // Check if currently playing
  bool get isPlaying => _playing;
  
  // Get current position
  Duration get currentPosition => _currentPosition;
  
  // Get total duration
  Duration? get totalDuration => _totalDuration;
  
  // Get current speed
  double get currentSpeed => _speed;
  
  // Get current volume
  double get currentVolume => _volume;
  
  // Get current file
  AudiobookFile? get currentFile => _currentFile;
  
  // Get sleep timer status
  bool get isSleepTimerActive => _sleepTimer != null;
  
  // Dispose resources
  void dispose() {
    Logger.log('Disposing AudioPlayerService');
    
    _saveProgressTimer?.cancel();
    _sleepTimer?.cancel();
    _positionUpdateTimer?.cancel();
    
    _savePlaybackState();
    
    // Close all controllers
    _playerStateController.close();
    _positionController.close();
    _durationController.close();
    _volumeController.close();
    _speedController.close();
    _sleepTimerController.close();
    _fileChangeController.close();
    
    // Safely dispose player
    try {
      if (_player != null && _isPlayerInitialized) {
        _player!.dispose();
        Logger.log('Audio player disposed successfully');
      }
    } catch (e) {
      Logger.error('Error disposing audio player', e);
    }
    
    _player = null;
    _isPlayerInitialized = false;
  }
}