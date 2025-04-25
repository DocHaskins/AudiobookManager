// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audiobook_organizer/services/audiobook_scanner.dart';
import 'package:audiobook_organizer/services/metadata_matcher.dart';
import 'package:audiobook_organizer/services/providers/google_books_provider.dart';
import 'package:audiobook_organizer/services/providers/open_library_provider.dart';
import 'package:audiobook_organizer/storage/metadata_cache.dart';
import 'package:audiobook_organizer/storage/user_preferences.dart';
import 'package:audiobook_organizer/storage/library_storage.dart';
import 'package:audiobook_organizer/ui/screens/library_screen.dart';
import 'package:audiobook_organizer/ui/screens/settings_screen.dart';
import 'package:audiobook_organizer/ui/theme.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final metadataCache = MetadataCache();
  await metadataCache.initialize();
  
  final userPreferences = UserPreferences();
  final apiKey = await userPreferences.getApiKey();
  
  // Initialize providers
  final googleBooksProvider = GoogleBooksProvider(apiKey: apiKey ?? '');
  final openLibraryProvider = OpenLibraryProvider();
  
  // Check for dark mode preference
  final useDarkMode = await userPreferences.getUseDarkMode();
  
  runApp(
    MultiProvider(
      providers: [
        Provider<MetadataCache>.value(value: metadataCache),
        Provider<UserPreferences>.value(value: userPreferences),
        Provider<GoogleBooksProvider>.value(value: googleBooksProvider),
        Provider<OpenLibraryProvider>.value(value: openLibraryProvider),
        Provider<LibraryStorage>.value(value: LibraryStorage()),
        Provider<MetadataMatcher>(
          create: (context) => MetadataMatcher(
            providers: [googleBooksProvider, openLibraryProvider],
            cache: metadataCache,
          ),
        ),
        Provider<AudiobookScanner>(
          create: (context) => AudiobookScanner(
            userPreferences: userPreferences,
            metadataMatcher: Provider.of<MetadataMatcher>(context, listen: false),
          ),
        ),
        // Theme mode provider
        ChangeNotifierProvider(
          create: (_) => ThemeModeProvider(
            initialMode: useDarkMode == true 
                ? ThemeMode.dark 
                : (useDarkMode == false ? ThemeMode.light : ThemeMode.system)
          ),
        ),
      ],
      child: const AudiobookOrganizerApp(),
    ),
  );
}

class ThemeModeProvider extends ChangeNotifier {
  ThemeMode _themeMode;
  
  ThemeModeProvider({ThemeMode initialMode = ThemeMode.system})
      : _themeMode = initialMode;
  
  ThemeMode get themeMode => _themeMode;
  
  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
  }
}

class AudiobookOrganizerApp extends StatelessWidget {
  const AudiobookOrganizerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeModeProvider>(context);
    
    return MaterialApp(
      title: 'Audiobook Organizer',
      theme: appTheme,
      darkTheme: appDarkTheme,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LibraryScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}