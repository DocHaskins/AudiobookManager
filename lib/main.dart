// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/directory_scanner.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/collection_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/services/providers/google_books_provider.dart';
import 'package:audiobook_organizer/services/providers/open_library_provider.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/storage/audiobook_storage_manager.dart';
import 'package:audiobook_organizer/ui/screens/library_screen.dart';
import 'package:audiobook_organizer/utils/logger.dart';
import 'package:audiobook_organizer/ui/widgets/mini_player.dart';

// Entry point
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize MetadataGod early
  try {
    await MetadataGod.initialize();
    Logger.log('MetadataGod initialized successfully');
  } catch (e) {
    Logger.error('Error initializing MetadataGod:', e);
    // Continue anyway - we'll handle extraction failures gracefully
  }
  
  // Initialize logger with higher detail level
  await Logger.initialize(
    logLevel: Logger.LEVEL_DEBUG,  // Set to DEBUG for more detailed logs
    logToFile: true,
  );
  
  Logger.log('Starting Audiobook Organizer on platform: ${Platform.operatingSystem}');
  Logger.logDeviceInfo();
  
  // Check for platform-specific initialization requirements
  bool audioInitialized = false;
  
  try {
    Logger.log('Initializing audioplayers for platform: ${Platform.operatingSystem}');
    
    // For Windows, we need to be more careful with initialization
    if (Platform.isWindows) {
      Logger.log('Windows platform detected - initializing with minimal configuration');
      
      // On Windows, don't try to set global audio context immediately
      // Let individual AudioPlayer instances handle their own initialization
      audioInitialized = true;
      Logger.log('Windows audioplayers setup completed');
      
    } else if (Platform.isAndroid) {
      // For Android, configure audio focus and session
      AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            audioMode: AndroidAudioMode.normal,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      audioInitialized = true;
      Logger.log('Android audio context configured');
      
    } else if (Platform.isIOS) {
      // For iOS, configure audio session
      AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      audioInitialized = true;
      Logger.log('iOS audio context configured');
    }
    
    Logger.log('Audioplayers initialization completed successfully');
  } catch (e, stack) {
    Logger.error('Error initializing audio services', e, stack);
    // Continue anyway - individual players will try to initialize themselves
    audioInitialized = true;
    Logger.warning('Audio initialization had issues but continuing');
  }
  
  // Install global error handler for better debugging
  FlutterError.onError = (FlutterErrorDetails details) {
    Logger.error('Flutter Error', details.exception, details.stack);
    
    // Check for plugin exceptions that we want to handle gracefully
    if (details.exception.toString().contains('MissingPluginException')) {
      Logger.warning('Caught plugin exception - this may be expected: ${details.exception}');
      return; // Don't propagate plugin errors that we can handle
    }
    
    // Let Flutter handle other errors normally
    FlutterError.presentError(details);
  };
  
  if (!audioInitialized) {
    Logger.warning('Audio initialization had issues - some features may be limited');
  }
  
  // Start the app
  runApp(const AudiobookOrganizerApp());
}

class AudiobookOrganizerApp extends StatefulWidget {
  const AudiobookOrganizerApp({super.key});

  @override
  _AudiobookOrganizerAppState createState() => _AudiobookOrganizerAppState();
}

class _AudiobookOrganizerAppState extends State<AudiobookOrganizerApp> {
  // Services
  late DirectoryScanner _directoryScanner;
  late MetadataCache _metadataCache;
  late AudiobookStorageManager _storageManager;
  late List<MetadataProvider> _metadataProviders;
  late MetadataMatcher _metadataMatcher;
  late LibraryManager _libraryManager;
  late CollectionManager _collectionManager;
  late AudioPlayerService _playerService;
  late MetadataService _metadataService;
  
  // Initialization status
  bool _initialized = false;
  String _initStatus = 'Initializing...';
  String? _initError;
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  // Initialize all services
  Future<void> _initializeServices() async {
    try {
      Logger.log('Starting application services initialization');
      
      // Update status
      setState(() {
        _initStatus = 'Initializing core services...';
      });
      
      // Initialize metadata service first
      setState(() {
        _initStatus = 'Initializing metadata service...';
      });
      _metadataService = MetadataService();
      await _metadataService.initialize();
      Logger.debug('MetadataService initialized');
      
      // Initialize directory scanner
      _directoryScanner = DirectoryScanner();
      Logger.debug('DirectoryScanner created');
      
      // Initialize metadata cache
      setState(() {
        _initStatus = 'Initializing metadata cache...';
      });
      _metadataCache = MetadataCache();
      await _metadataCache.initialize();
      Logger.debug('MetadataCache initialized');
      
      // Initialize storage manager
      setState(() {
        _initStatus = 'Initializing storage manager...';
      });
      _storageManager = AudiobookStorageManager();
      await _storageManager.initialize();
      Logger.debug('StorageManager initialized');
      
      // Initialize metadata providers
      setState(() {
        _initStatus = 'Setting up metadata providers...';
      });
      _metadataProviders = [
        GoogleBooksProvider(apiKey: ''), // Add your API key here if available
        OpenLibraryProvider(),
      ];
      Logger.debug('Metadata providers created');
      
      // Initialize metadata matcher
      _metadataMatcher = MetadataMatcher(
        providers: _metadataProviders,
        cache: _metadataCache,
        storageManager: _storageManager,
      );
      await _metadataMatcher.initialize();
      Logger.debug('MetadataMatcher initialized');
      
      // Initialize library manager
      setState(() {
        _initStatus = 'Loading library...';
      });
      _libraryManager = LibraryManager(
        scanner: _directoryScanner,
        metadataMatcher: _metadataMatcher,
        storageManager: _storageManager,
        cache: _metadataCache,
      );
      await _libraryManager.initialize();
      Logger.debug('LibraryManager initialized');
      
      // Initialize collection manager
      setState(() {
        _initStatus = 'Initializing collections...';
      });
      _collectionManager = CollectionManager(libraryManager: _libraryManager);
      await _collectionManager.initialize();
      
      // Set collection manager reference in library manager
      _libraryManager.collectionManager = _collectionManager;
      Logger.debug('CollectionManager initialized');
      
      // Initialize audio player service
      setState(() {
        _initStatus = 'Initializing audio player...';
      });
      _playerService = AudioPlayerService(
        storageManager: _storageManager,
      );
      Logger.debug('AudioPlayerService initialized');
      
      // Update status
      setState(() {
        _initialized = true;
        _initStatus = 'Initialization complete';
      });
      
      Logger.log('Application services initialized successfully');
    } catch (e, stack) {
      Logger.error('Error initializing services', e, stack);
      setState(() {
        _initStatus = 'Initialization failed';
        _initError = e.toString();
        // Still mark as initialized so we can show the error
        _initialized = true;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Show loading screen until initialization is complete
    if (!_initialized) {
      return MaterialApp(
        title: 'Audiobook Organizer',
        theme: _buildTheme(),
        home: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                ),
                const SizedBox(height: 24),
                Text(
                  _initStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Show error screen if initialization failed
    if (_initError != null) {
      return MaterialApp(
        title: 'Audiobook Organizer',
        theme: _buildTheme(),
        home: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline, 
                  color: Colors.red, 
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Initialization Error', 
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  margin: const EdgeInsets.symmetric(horizontal: 32.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _initError!, 
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _initialized = false;
                      _initError = null;
                      _initStatus = 'Reinitializing...';
                    });
                    _initializeServices();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return MultiProvider(
      providers: [
        Provider<DirectoryScanner>.value(value: _directoryScanner),
        Provider<MetadataCache>.value(value: _metadataCache),
        Provider<AudiobookStorageManager>.value(value: _storageManager),
        Provider<MetadataMatcher>.value(value: _metadataMatcher),
        Provider<LibraryManager>.value(value: _libraryManager),
        Provider<CollectionManager>.value(value: _collectionManager),
        Provider<AudioPlayerService>.value(value: _playerService),
        Provider<MetadataService>.value(value: _metadataService),

        StreamProvider<List<AudiobookFile>>(
          create: (_) => _libraryManager.libraryChanged,
          initialData: _libraryManager.files,
        ),
      ],
      child: MaterialApp(
        title: 'Audiobook Organizer',
        theme: _buildTheme(),
        home: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Column(
            children: [
              // Main content area
              Expanded(
                child: LibraryScreen(
                  libraryManager: _libraryManager,
                  collectionManager: _collectionManager,
                ),
              ),
              
              // Mini Player at the bottom
              const MiniPlayer(),
            ],
          ),
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
  
  ThemeData _buildTheme() {
    return ThemeData(
      primarySwatch: Colors.indigo,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark().copyWith(
        primary: Colors.indigo,
        secondary: Colors.amberAccent,
        surface: const Color(0xFF1A1A1A),
        background: const Color(0xFF121212),
      ),
      fontFamily: GoogleFonts.roboto().fontFamily,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      
      // Custom theme elements for the Spotify-like interface
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      
      // Input decoration theme for search bars
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: Colors.grey[600]),
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A2A),
        thickness: 1,
      ),
    );
  }
  
  @override
  void dispose() {
    // Dispose services
    Logger.log('Disposing application services');
    
    try {
      _collectionManager.dispose();
    } catch (e) {
      Logger.error('Error disposing CollectionManager', e);
    }
    
    try {
      _libraryManager.dispose();
    } catch (e) {
      Logger.error('Error disposing LibraryManager', e);
    }
    
    try {
      _playerService.dispose();
    } catch (e) {
      Logger.error('Error disposing AudioPlayerService', e);
    }
    
    Logger.log('Application services disposed');
    super.dispose();
  }
}