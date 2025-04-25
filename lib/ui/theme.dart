// File: lib/ui/theme.dart (updated with dark theme)
import 'package:flutter/material.dart';

// Light Theme
final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(
    elevation: 1,
    centerTitle: false,
  ),
  cardTheme: CardTheme(
    clipBehavior: Clip.antiAlias,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
);

// Dark Theme
final appDarkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(
    elevation: 1,
    centerTitle: false,
  ),
  cardTheme: CardTheme(
    clipBehavior: Clip.antiAlias,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
);

// Custom theme extensions
extension ThemeExtensions on ThemeData {
  // Get the appropriate color for audiobook cards
  Color get audiobookCardColor => brightness == Brightness.light
      ? Colors.grey.shade50
      : Colors.grey.shade900;
  
  // Get the appropriate color for pending badges
  Color get pendingBadgeColor => brightness == Brightness.light
      ? Colors.orange.shade100
      : Colors.orange.shade900;
  
  // Get the appropriate text color for pending badges
  Color get pendingBadgeTextColor => brightness == Brightness.light
      ? Colors.orange.shade900
      : Colors.orange.shade100;
}