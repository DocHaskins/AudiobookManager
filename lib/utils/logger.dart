// File: lib/utils/logger.dart
import 'package:logging/logging.dart' as logging;

/// Log levels supported by the application
enum LogLevel { debug, info, warning, error }

/// A logging utility class that standardizes log messages across the application
/// Uses the 'logging' package rather than print statements for production code
class Logger {
  static final _logger = logging.Logger('AudiobookOrganizer');
  static bool _initialized = false;
  
  /// Initialize the logger with appropriate handlers and level
  static void initialize({LogLevel minimumLevel = LogLevel.info, bool includeTimestamp = true}) {
    if (_initialized) return;
    
    // Set up the logging level
    logging.hierarchicalLoggingEnabled = true;
    
    // Set minimum level based on input
    switch (minimumLevel) {
      case LogLevel.debug:
        _logger.level = logging.Level.FINE;
        break;
      case LogLevel.info:
        _logger.level = logging.Level.INFO;
        break;
      case LogLevel.warning:
        _logger.level = logging.Level.WARNING;
        break;
      case LogLevel.error:
        _logger.level = logging.Level.SEVERE;
        break;
    }
    
    // Add console handler
    logging.Logger.root.onRecord.listen((record) {
      final message = includeTimestamp 
          ? '${record.time}: ${record.message}'
          : record.message;
          
      if (record.error != null) {
        // ignore: avoid_print
        print('${record.level.name}: $message - ${record.error}\n${record.stackTrace ?? ""}');
      } else {
        // ignore: avoid_print
        print('${record.level.name}: $message');
      }
    });
    
    _initialized = true;
  }
  
  /// Ensure logger is initialized before use
  static void _ensureInitialized() {
    if (!_initialized) {
      initialize();
    }
  }
  
  /// Log a debug message 
  static void debug(String message) {
    _ensureInitialized();
    _logger.fine(message);
  }
  
  /// Log an informational message
  static void log(String message) {
    _ensureInitialized();
    _logger.info(message);
  }
  
  /// Log a warning message
  static void warning(String message) {
    _ensureInitialized();
    _logger.warning(message);
  }
  
  /// Log an error message with optional error object
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.severe(message, error, stackTrace);
  }
}