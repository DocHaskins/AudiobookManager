// File: lib/utils/string_extensions.dart

/// Extensions on string and nullable string for improved null handling
extension StringExtension on String? {
  /// Check if string is not null and not empty
  bool get isNotEmptyOrNull => this != null && this!.isNotEmpty;
  
  /// Return string or empty string if null
  String get orEmpty => this ?? '';
  
  /// Return string if not null and not empty, otherwise return provided default
  String orDefault(String defaultValue) => isNotEmptyOrNull ? this! : defaultValue;
  
  /// Safely trim a nullable string
  String? get safeTrim => this?.trim();
  
  /// Capitalize first letter of each word
  String get titleCase {
    if (this == null || this!.isEmpty) return '';
    
    return this!.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1) : '');
    }).join(' ');
  }
  
  /// Clean a string for use in filenames
  String get cleanForFilename {
    if (this == null || this!.isEmpty) return '';
    
    return this!
      .replaceAll(RegExp(r'[\\/:"*?<>|]'), '_') // Replace illegal filename chars
      .replaceAll(RegExp(r'\s+'), ' ')         // Normalize whitespace
      .trim();
  }
}
