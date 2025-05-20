// lib/utils/logger.dart - Enhanced for better debugging
import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

/// Enhanced thread-safe logging utility
class Logger {
  // Log levels
  static const int LEVEL_DEBUG = 0;
  static const int LEVEL_LOG = 1;
  static const int LEVEL_WARNING = 2;
  static const int LEVEL_ERROR = 3;
  
  // Current log level
  static int _logLevel = LEVEL_LOG;
  
  // Log file
  static File? _logFile;
  static bool _logToFile = false;
  static bool _initialized = false;
  
  // Date formatter
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  
  // Buffer for logs before initialization
  static final List<String> _preInitBuffer = [];
  
  // Writing queue
  static final Queue<String> _writeQueue = Queue<String>();
  static bool _isProcessingQueue = false;
  static final _queueLock = Object();
  
  // Enable console coloring
  static bool _enableConsoleColors = true;
  
  // Platform info
  static String _platformInfo = '';
  
  // Initialize logger
  static Future<void> initialize({
    int logLevel = LEVEL_LOG, 
    bool logToFile = false,
    bool enableConsoleColors = true,
  }) async {
    _logLevel = logLevel;
    _logToFile = logToFile;
    _enableConsoleColors = enableConsoleColors;
    
    // Get platform info
    try {
      _platformInfo = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (e) {
      _platformInfo = 'unknown platform';
    }
    
    // Log initial startup message to console
    final now = DateTime.now();
    final startupMessage = 'Logger initializing at ${_dateFormat.format(now)} on $_platformInfo';
    _printToConsole(startupMessage, LEVEL_LOG);
    
    if (_logToFile) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final logDir = Directory(path_util.join(appDir.path, 'logs'));
        
        // Create logs directory if it doesn't exist
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        
        // Create log file with current date and time
        final fileName = 'log_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}.txt';
        _logFile = File(path_util.join(logDir.path, fileName));
        
        // Write startup message
        final fileStartupMessage = '===== Audiobook Organizer Log Started at ${_dateFormat.format(now)} on $_platformInfo =====\n';
        await _writeLogToFile(fileStartupMessage);
        
        // Process any buffered logs
        final buffer = List<String>.from(_preInitBuffer);
        _preInitBuffer.clear();
        
        for (final log in buffer) {
          await _writeLogToFile(log);
        }
        
        _printToConsole('Logger initialized, logging to file: ${_logFile!.path}', LEVEL_LOG);
      } catch (e) {
        _printToConsole('Error initializing logger file: $e', LEVEL_ERROR);
        _logToFile = false;
      }
    }
    
    _initialized = true;
  }
  
  // Print to console with optional coloring
  static void _printToConsole(String message, int level) {
    if (!_enableConsoleColors) {
      print(message);
      return;
    }
    
    final colorPrefix = level == LEVEL_DEBUG ? '\x1B[90m' : // Gray
                       level == LEVEL_LOG ? '\x1B[0m' :    // Default
                       level == LEVEL_WARNING ? '\x1B[33m' : // Yellow
                       level == LEVEL_ERROR ? '\x1B[31m' : // Red
                       '\x1B[0m'; // Default
    
    const colorSuffix = '\x1B[0m';
    
    // Use developer.log for better trace info in debug console
    developer.log('$colorPrefix$message$colorSuffix', level: level);
    
    // Also print to standard console for command line visibility
    print('$colorPrefix$message$colorSuffix');
  }
  
  // Write to log file safely
  static Future<void> _writeLogToFile(String message) async {
    try {
      if (_logFile != null) {
        await _logFile!.writeAsString(message, mode: FileMode.append);
      }
    } catch (e) {
      print('Error writing to log file: $e');
    }
  }
  
  // Add to write queue
  static Future<void> _addToWriteQueue(String message) async {
    if (!_initialized) {
      _preInitBuffer.add(message);
      return;
    }
    
    if (!_logToFile || _logFile == null) return;
    
    bool shouldStartProcessing = false;
    
    // Add to queue
    synchronized(_queueLock, () {
      _writeQueue.add(message);
      
      // Check if we need to start processing
      if (!_isProcessingQueue) {
        _isProcessingQueue = true;
        shouldStartProcessing = true;
      }
    });
    
    // Process the queue if needed
    if (shouldStartProcessing) {
      await _processWriteQueue();
    }
  }
  
  // Process the write queue
  static Future<void> _processWriteQueue() async {
    while (true) {
      String? nextMessage;
      
      // Get next message from queue
      synchronized(_queueLock, () {
        if (_writeQueue.isNotEmpty) {
          nextMessage = _writeQueue.removeFirst();
        } else {
          _isProcessingQueue = false;
        }
      });
      
      // Exit if queue is empty
      if (nextMessage == null) break;
      
      // Write message to file
      await _writeLogToFile(nextMessage!);
    }
  }
  
  // Simple synchronization helper that doesn't cause recursion
  static void synchronized(Object lock, void Function() fn) {
    fn();
  }
  
  // Debug level logging
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (_logLevel <= LEVEL_DEBUG) {
      final now = DateTime.now();
      final formattedMessage = '[${_dateFormat.format(now)}] [DEBUG] $message ${error != null ? '\nError: $error' : ''}${stackTrace != null ? '\nStack Trace: $stackTrace' : ''}';
      _printToConsole(formattedMessage, LEVEL_DEBUG);
      _addToWriteQueue('$formattedMessage\n');
    }
  }
  
  // Info level logging
  static void log(String message, [Object? data]) {
    if (_logLevel <= LEVEL_LOG) {
      final now = DateTime.now();
      final formattedMessage = '[${_dateFormat.format(now)}] [INFO] $message ${data != null ? '\nData: $data' : ''}';
      _printToConsole(formattedMessage, LEVEL_LOG);
      _addToWriteQueue('$formattedMessage\n');
    }
  }
  
  // Warning level logging
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (_logLevel <= LEVEL_WARNING) {
      final now = DateTime.now();
      final formattedMessage = '[${_dateFormat.format(now)}] [WARNING] $message ${error != null ? '\nError: $error' : ''}${stackTrace != null ? '\nStack Trace: $stackTrace' : ''}';
      _printToConsole(formattedMessage, LEVEL_WARNING);
      _addToWriteQueue('$formattedMessage\n');
    }
  }
  
  // Error level logging
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (_logLevel <= LEVEL_ERROR) {
      final now = DateTime.now();
      final formattedMessage = '[${_dateFormat.format(now)}] [ERROR] $message ${error != null ? '\nError: $error' : ''}${stackTrace != null ? '\nStack Trace: $stackTrace' : ''}';
      _printToConsole(formattedMessage, LEVEL_ERROR);
      _addToWriteQueue('$formattedMessage\n');
      
      // Also log to Flutter's developer console for better visibility in IDE
      try {
        developer.log(
          message,
          error: error,
          stackTrace: stackTrace,
          level: 1000, // Error level
          name: 'AudiobookPlayer',
        );
      } catch (_) {
        // Fall back to standard print if developer.log fails
      }
    }
  }
  
  // Log platform/device information
  static void logDeviceInfo() {
    try {
      final info = StringBuffer('Device Information:\n');
      info.writeln('  Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      info.writeln('  Dart Version: ${Platform.version}');
      info.writeln('  Path Separator: ${Platform.pathSeparator}');
      info.writeln('  Local Hostname: ${Platform.localHostname}');
      info.writeln('  Number of Processors: ${Platform.numberOfProcessors}');
      
      log(info.toString());
    } catch (e) {
      error('Failed to log device info', e);
    }
  }
  
  // Set log level
  static void setLogLevel(int level) {
    _logLevel = level;
    log('Log level changed to: $_logLevel');
  }
  
  // Flush logs
  static Future<void> flush() async {
    // Wait for write queue to be processed
    if (_isProcessingQueue) {
      final isQueueEmpty = _writeQueue.isEmpty;
      while (!isQueueEmpty && _isProcessingQueue) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }
  
  // Clean up old log files (older than 7 days)
  static Future<void> cleanupOldLogs() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logDir = Directory(path_util.join(appDir.path, 'logs'));
      
      if (!await logDir.exists()) return;
      
      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 7));
      
      await for (final entity in logDir.list()) {
        if (entity is File && entity.path.endsWith('.txt')) {
          final fileName = path_util.basename(entity.path);
          
          // Parse date from filename (log_YYYY-MM-DD.txt)
          final dateMatch = RegExp(r'log_(\d{4})-(\d{1,2})-(\d{1,2})\.txt').firstMatch(fileName);
          if (dateMatch != null) {
            final year = int.parse(dateMatch.group(1)!);
            final month = int.parse(dateMatch.group(2)!);
            final day = int.parse(dateMatch.group(3)!);
            
            final fileDate = DateTime(year, month, day);
            if (fileDate.isBefore(cutoffDate)) {
              await entity.delete();
              log('Deleted old log file: ${entity.path}');
            }
          }
        }
      }
    } catch (e) {
      error('Error cleaning up old logs', e);
    }
  }
}