// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_size/window_size.dart';
import 'dart:io';

import 'package:audiobook_organizer/ui/screens/library_view.dart';
import 'package:audiobook_organizer/ui/screens/settings_view.dart';
import 'package:audiobook_organizer/ui/theme.dart';
import 'package:audiobook_organizer/services/audiobook_scanner.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/services/audiobook_organizer.dart';
import 'package:audiobook_organizer/services/providers/google_books_provider.dart';
import 'package:audiobook_organizer/services/providers/open_library_provider.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/storage/user_preferences.dart';
import 'package:audiobook_organizer/storage/library_storage.dart';

Future<void> main() async {
  try {
    // Initialize Flutter bindings
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize SQLite for Windows
    if (Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    // Initialize Window size
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      setWindowTitle('AudioBook Organizer');
      setWindowMinSize(const Size(1000, 700));
      setWindowMaxSize(Size.infinite);
    }
    
    // Initialize UserPreferences for later provider usage
    final userPrefs = UserPreferences();
    
    // Initialize Metadata Cache
    final metadataCache = MetadataCache();
    await metadataCache.initialize();
    
    // Initialize Library Storage
    final libraryStorage = LibraryStorage();
    
    // Get API key if available
    String? googleApiKey;
    try {
      googleApiKey = await userPrefs.getApiKey();
    } catch (e) {
      print('Error loading API key: $e');
    }
    
    runApp(MyApp(
      userPreferences: userPrefs,
      googleApiKey: googleApiKey ?? '',
      metadataCache: metadataCache,
      libraryStorage: libraryStorage,
    ));
  } catch (e) {
    // Handle any initialization errors
    print('Error during application initialization: $e');
    
    // Run a minimal error app if initialization fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Failed to initialize application: $e'),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  final UserPreferences userPreferences;
  final String googleApiKey;
  final MetadataCache metadataCache;
  final LibraryStorage libraryStorage;
  
  const MyApp({
    Key? key, 
    required this.userPreferences,
    required this.googleApiKey,
    required this.metadataCache,
    required this.libraryStorage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Storage Services
        Provider<UserPreferences>.value(value: userPreferences),
        Provider<MetadataCache>.value(value: metadataCache),
        Provider<LibraryStorage>.value(value: libraryStorage),
        
        // API Providers
        Provider<GoogleBooksProvider>(
          create: (_) => GoogleBooksProvider(apiKey: googleApiKey),
        ),
        Provider(create: (_) => OpenLibraryProvider()),
        
        // Core Services
        Provider(
          create: (context) => MetadataMatcher(
            providers: [
              context.read<GoogleBooksProvider>(),
              context.read<OpenLibraryProvider>(),
            ],
            cache: context.read<MetadataCache>(),
          ),
        ),
        Provider(create: (_) => AudiobookScanner()),
        Provider(create: (_) => AudiobookOrganizer()),
      ],
      child: MaterialApp(
        title: 'AudioBook Organizer',
        theme: appTheme,
        darkTheme: appDarkTheme,
        themeMode: ThemeMode.system, // Respect system theme
        initialRoute: '/',
        routes: {
          '/': (context) => const LibraryView(),
          '/settings': (context) => const SettingsView(),
        },
        debugShowCheckedModeBanner: false, // Remove debug banner
        builder: (context, child) {
          // Add global error handling for the UI
          ErrorWidget.builder = (FlutterErrorDetails details) {
            return Material(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.red.withOpacity(0.1),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      const Text(
                        'An error occurred',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        details.exception.toString(),
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          };
          
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}