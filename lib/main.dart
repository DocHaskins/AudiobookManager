// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:audiobook_organizer/models/audiobook_file.dart';
import 'package:audiobook_organizer/services/directory_scanner.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/services/library_manager.dart';
import 'package:audiobook_organizer/services/audio_player_service.dart';
import 'package:audiobook_organizer/services/providers/google_books_provider.dart';
import 'package:audiobook_organizer/services/providers/open_library_provider.dart';
import 'package:audiobook_organizer/services/providers/metadata_provider.dart';
import 'package:audiobook_organizer/services/metadata_service.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/storage/audiobook_storage_manager.dart';
import 'package:audiobook_organizer/ui/screens/main_container.dart';
import 'package:audiobook_organizer/utils/logger.dart';

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
  bool backgroundAudioInitialized = false;
  
  if (Platform.isWindows) {
    Logger.log('Windows platform detected - preparing platform-specific audio handling');
    
    // Skip background audio initialization for Windows
    backgroundAudioInitialized = true;

    // Install error handler for plugin errors
    FlutterError.onError = (FlutterErrorDetails details) {
      Logger.error('Flutter Error', details.exception, details.stack);
      
      // Check for plugin exceptions that we want to handle gracefully
      if (details.exception.toString().contains('MissingPluginException') &&
          details.exception.toString().contains('just_audio')) {
        Logger.warning('Caught just_audio plugin exception - this is expected on Windows and will be handled');
        return; // Don't propagate this specific error
      }
      
      // Let Flutter handle other errors normally
      FlutterError.presentError(details);
    };
    
    Logger.log('Windows-specific error handlers installed');
  } else {
    // Initialize background audio on supported platforms
    try {
      Logger.log('Initializing JustAudioBackground on non-Windows platform');
      
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.yourcompany.audiobook_organizer.audio',
        androidNotificationChannelName: 'Audiobook playback',
        androidNotificationOngoing: true,
        fastForwardInterval: const Duration(seconds: 30),
        rewindInterval: const Duration(seconds: 10),
        notificationColor: const Color(0xFF2196F3),
      );
      
      backgroundAudioInitialized = true;
      Logger.log('JustAudioBackground initialized successfully');
    } catch (e, stack) {
      Logger.error('Error initializing background audio services', e, stack);
      // Continue without background audio
    }
  }
  
  if (!backgroundAudioInitialized) {
    Logger.warning('Background audio initialization failed or skipped - some features may be limited');
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
  late AudioPlayerService _playerService;
  late MetadataService _metadataService; // Add this
  
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
      
      // Initialize audio player service with platform check
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
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_initStatus),
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
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Initialization Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(_initError!, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _initialized = false;
                      _initError = null;
                      _initStatus = 'Reinitializing...';
                    });
                    _initializeServices();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Main app with providers - MODIFIED to use MainContainer instead of HomeScreen
    return MultiProvider(
      providers: [
        // Provide all services to the app
        Provider<DirectoryScanner>.value(value: _directoryScanner),
        Provider<MetadataCache>.value(value: _metadataCache),
        Provider<AudiobookStorageManager>.value(value: _storageManager),
        Provider<MetadataMatcher>.value(value: _metadataMatcher),
        Provider<LibraryManager>.value(value: _libraryManager),
        Provider<AudioPlayerService>.value(value: _playerService),
        Provider<MetadataService>.value(value: _metadataService), // Add this
        
        // Stream of audiobook files
        StreamProvider<List<AudiobookFile>>(
          create: (_) => _libraryManager.libraryChanged,
          initialData: _libraryManager.files,
        ),
      ],
      child: MaterialApp(
        title: 'Audiobook Organizer',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark().copyWith(
            primary: Colors.indigo,
            secondary: Colors.amberAccent,
          ),
          fontFamily: GoogleFonts.roboto().fontFamily,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MainContainer(), // Use MainContainer instead of HomeScreen
      ),
    );
  }
  
  @override
  void dispose() {
    // Dispose services
    Logger.log('Disposing application services');
    
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