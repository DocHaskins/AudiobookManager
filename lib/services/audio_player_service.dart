// lib/services/audio_player_service.dart
import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:uuid/uuid.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/models/audiobook_metadata.dart';
import 'package:audiobook_organizer/storage/audiobook_storage_manager.dart';
import 'package:audiobook_organizer/utils/logger.dart';

/// Service for playing audiobooks with improved Windows compatibility using audioplayers
class AudioPlayerService {
  // Player instance
  audioplayers.AudioPlayer? _player;
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
      Logger.log('Initializing audio player with audioplayers (Platform: ${Platform.operatingSystem})');
      
      // Create player instance
      _player = audioplayers.AudioPlayer();
      Logger.debug('AudioPlayer instance created successfully');
      
      // Set up event listeners
      _setupEventListeners();
      
      // Set up periodic position updates (needed for all platforms with audioplayers)
      _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (_player != null && _isPlayerInitialized && _playing) {
          _updatePositionState();
        }
      });
      
      // Set up periodic progress saving (reduced frequency)
      _saveProgressTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
        _savePlaybackState();
      });
      
      _isPlayerInitialized = true;
      Logger.log('Audio player initialized successfully');
    } catch (e, stackTrace) {
      Logger.error('Error initializing audio player', e, stackTrace);
      // Create fallback - mark as initialized but player will be null
      _isPlayerInitialized = false;
    }
  }
  
  // Set up event listeners for audioplayers
  void _setupEventListeners() {
    if (_player == null) return;
    
    Logger.debug('Setting up event listeners for audioplayers');
    
    // Player state changes
    _player!.onPlayerStateChanged.listen((state) {
      _playing = state == audioplayers.PlayerState.playing;
      _playerStateController.add(_convertPlayerState(state));
      Logger.debug('Player state changed: $state');
    }, onError: (e) => Logger.error('Error in player state stream', e));
    
    // Position changes
    _player!.onPositionChanged.listen((position) {
      if (position.inMilliseconds < 0 || !position.inMilliseconds.isFinite) {
        Logger.warning('Received invalid position: $position, ignoring');
        return;
      }
      
      _currentPosition = position;
      _positionController.add(position);
      
      // Throttle metadata updates
      if (_currentFile != null && position.inSeconds > 0) {
        _updateFilePlaybackPositionThrottled(position);
      }
    }, onError: (e) => Logger.error('Error in position stream', e));
    
    // Duration changes
    _player!.onDurationChanged.listen((duration) {
      if (duration.inMilliseconds < 0 || !duration.inMilliseconds.isFinite) {
        Logger.warning('Received invalid duration: $duration, ignoring');
        return;
      }
      
      _totalDuration = duration;
      _durationController.add(duration);
      Logger.debug('Duration updated: $duration');
    }, onError: (e) => Logger.error('Error in duration stream', e));
    
    // Playback completion
    _player!.onPlayerComplete.listen((_) {
      Logger.log('Playback completed for file: ${_currentFile?.path}');
      if (_currentFile != null) {
        _storageManager.updateUserData(
          _currentFile!.path,
          playbackPosition: Duration.zero,
          lastPlayedPosition: DateTime.now(),
        );
      }
      _playing = false;
      _playerStateController.add(_convertPlayerState(audioplayers.PlayerState.completed));
    }, onError: (e) => Logger.error('Error in completion stream', e));
  }
  
  // Convert audioplayers PlayerState to your PlayerState format
  PlayerState _convertPlayerState(audioplayers.PlayerState state) {
    bool playing = state == audioplayers.PlayerState.playing;
    ProcessingState processingState;
    
    switch (state) {
      case audioplayers.PlayerState.stopped:
        processingState = ProcessingState.idle;
        break;
      case audioplayers.PlayerState.playing:
        processingState = ProcessingState.ready;
        break;
      case audioplayers.PlayerState.paused:
        processingState = ProcessingState.ready;
        break;
      case audioplayers.PlayerState.completed:
        processingState = ProcessingState.completed;
        break;
      case audioplayers.PlayerState.disposed:
        processingState = ProcessingState.idle;
        break;
    }
    
    return PlayerState(playing, processingState);
  }
  
  // Update position manually
  void _updatePositionState() {
    if (_player == null || !_playing) return;
    
    // Position updates are handled by the onPositionChanged stream
    // This method can be used for additional state management if needed
  }
  
  // Save current playback state
  Future<void> _savePlaybackState() async {
    if (_currentFile == null || !_playing) return;
    
    final position = _currentPosition;
    await _updateFilePlaybackPosition(position);
  }
  
  // Throttled version of position update
  void _updateFilePlaybackPositionThrottled(Duration position) {
    final now = DateTime.now();
    
    if (_lastMetadataUpdate != null && 
        now.difference(_lastMetadataUpdate!) < _metadataUpdateThrottle) {
      return;
    }
    
    _lastMetadataUpdate = now;
    _updateFilePlaybackPosition(position);
  }
  
  // Update file playback position
  Future<void> _updateFilePlaybackPosition(Duration position) async {
    if (_currentFile == null) return;
    
    if (!position.inMilliseconds.isFinite || 
        position.inMilliseconds.isNaN || 
        position.inMilliseconds.isInfinite || 
        position.inMilliseconds < 0) {
      Logger.warning('Invalid position detected during save: $position, skipping update');
      return;
    }
    
    // Only save significant changes (more than 10 seconds)
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
  
  Future<bool> play(AudiobookFile file) async {
    try {
      Logger.log('Playing audiobook: ${file.path}');
      
      // Save current state before stopping if we have a different file
      if (_currentFile != null && _currentFile!.path != file.path) {
        await _savePlaybackState();
      }
      
      // Reset state variables first
      _currentPosition = Duration.zero;
      _totalDuration = null;
      
      // Stop any current playback
      await stop();
      
      // Check if file exists
      if (!await File(file.path).exists()) {
        Logger.error('File does not exist: ${file.path}');
        return false;
      }
      
      // Validate file is actually an audio file
      if (!_isValidAudioFile(file.path)) {
        Logger.error('File is not a valid audio file: ${file.path}');
        return false;
      }
      
      if (_player == null) {
        Logger.log('Audio player is null, attempting to recreate');
        _player = audioplayers.AudioPlayer();
        _setupEventListeners();
        _isPlayerInitialized = true;
      }
      
      // Load audio file using audioplayers
      bool loadSuccess = false;
      
      try {
        // For Windows, try different approaches
        if (_isWindowsPlatform) {
          try {
            // Method 1: Direct file path
            await _player!.setSourceDeviceFile(file.path);
            loadSuccess = true;
            Logger.debug('Successfully loaded with setSourceDeviceFile');
          } catch (e) {
            Logger.debug('setSourceDeviceFile failed: $e');
            
            // Method 2: URL source
            try {
              final uri = Uri.file(file.path);
              await _player!.setSourceUrl(uri.toString());
              loadSuccess = true;
              Logger.debug('Successfully loaded with setSourceUrl');
            } catch (e) {
              Logger.debug('setSourceUrl failed: $e');
            }
          }
        } else {
          // For non-Windows platforms
          await _player!.setSourceDeviceFile(file.path);
          loadSuccess = true;
        }
      } catch (e) {
        Logger.error('Error loading audio file', e);
      }
      
      if (!loadSuccess) {
        Logger.error('Failed to load audio file with all methods attempted');
        return false;
      }
      
      // Set current file and notify listeners
      _currentFile = file;
      _fileChangeController.add(file);
      
      // Get metadata to restore position
      final metadata = file.metadata;
      
      // Start playback first, then seek if needed
      await _player!.resume();
      _playing = true;
      
      // Resume from last position if available
      if (metadata?.playbackPosition != null) {
        try {
          final position = metadata!.playbackPosition!;
          if (position.inMilliseconds > 0 && position.inMilliseconds.isFinite) {
            await Future.delayed(const Duration(milliseconds: 1000));
            await _player!.seek(position);
            _currentPosition = position;
            _positionController.add(position);
            Logger.log('Resumed from position: $position');
          }
        } catch (e) {
          Logger.error('Error seeking to saved position', e);
        }
      }
      
      Logger.log('Playbook started successfully for: ${file.filename}');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Error playing audiobook: ${file.path}', e, stackTrace);
      return false;
    }
  }
  
  // File validation
  bool _isValidAudioFile(String filePath) {
    const validExtensions = ['.mp3', '.m4a', '.m4b', '.aac', '.ogg', '.wma', '.flac', '.opus'];
    final extension = filePath.toLowerCase().substring(filePath.lastIndexOf('.'));
    
    if (!validExtensions.contains(extension)) {
      return false;
    }
    
    try {
      final file = File(filePath);
      final size = file.lengthSync();
      return size > 1024;
    } catch (e) {
      Logger.error('Error checking file size: $filePath', e);
      return false;
    }
  }
  
  // Pause playback
  Future<void> pause() async {
    try {
      Logger.debug('Pausing playback');
      if (_player != null && _isPlayerInitialized) {
        await _player!.pause();
        _playing = false;
      }
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
        await _player!.resume();
        _playing = true;
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
      
      await _savePlaybackState();
      
      if (_player != null && _isPlayerInitialized) {
        await _player!.stop();
        _playing = false;
      }

      _currentFile = null;
      _fileChangeController.add(null);
      
      cancelSleepTimer();
      Logger.debug('Playback stopped completely');
    } catch (e) {
      Logger.error('Error stopping playback', e);
    }
  }
  
  // Seek to position
  Future<void> seekTo(Duration position) async {
    try {
      if (!position.inMilliseconds.isFinite || 
          position.inMilliseconds.isNaN || 
          position.inMilliseconds.isInfinite || 
          position.inMilliseconds < 0) {
        Logger.warning('Attempt to seek to invalid position: $position, ignoring');
        return;
      }
      
      Logger.debug('Seeking to position: $position');
      if (_player != null && _isPlayerInitialized) {
        await _player!.seek(position);
        _currentPosition = position;
        _positionController.add(position);
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
      if (!speed.isFinite || speed <= 0) {
        Logger.warning('Invalid speed value: $speed, using 1.0 instead');
        speed = 1.0;
      }
      
      Logger.debug('Setting playback speed to $speed');
      if (_player != null && _isPlayerInitialized) {
        await _player!.setPlaybackRate(speed);
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
    if (_sleepTimer != null) {
      _sleepTimer!.cancel();
      _sleepTimer = null;
    }
    
    _sleepTimerDuration = duration;
    _sleepTimer = Timer(duration, () {
      pause();
      _sleepTimerDuration = null;
      _sleepTimerController.add(null);
    });
    
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
  
  // Getters
  bool get isPlaying => _playing;
  Duration get currentPosition => _currentPosition;
  Duration? get totalDuration => _totalDuration;
  double get currentSpeed => _speed;
  double get currentVolume => _volume;
  AudiobookFile? get currentFile => _currentFile;
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

// Helper classes to maintain compatibility
class PlayerState {
  final bool playing;
  final ProcessingState processingState;
  
  PlayerState(this.playing, this.processingState);
}

enum ProcessingState {
  idle,
  loading,
  buffering,
  ready,
  completed,
}