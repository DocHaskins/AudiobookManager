// lib/ui/widgets/processing_status_widget.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:audiobook_organizer/services/audio_conversion_service.dart';
import 'package:audiobook_organizer/utils/audio_processors/base_audio_processor.dart';

class ProcessingStatusWidget extends StatefulWidget {
  final AudioConversionService audioConversionService;

  const ProcessingStatusWidget({
    Key? key,
    required this.audioConversionService,
  }) : super(key: key);

  @override
  State<ProcessingStatusWidget> createState() => ProcessingStatusWidgetState();
}

class ProcessingStatusWidgetState extends State<ProcessingStatusWidget> 
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _expandController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _expandAnimation;
  
  bool _isExpanded = false;
  bool _isProcessing = false;
  bool _isVisible = false;
  
  ProcessingUpdate? _currentUpdate;
  StreamSubscription<ProcessingUpdate>? _progressSubscription;
  Timer? _autoHideTimer;
  
  // Draggable position
  double _xPosition = 20;
  double _yPosition = 100;
  
  // Processing stats
  String _operationType = '';
  int _totalFiles = 0;
  int _completedFiles = 0;
  int _successCount = 0;
  int _failureCount = 0;
  String _currentFile = '';
  double _progress = 0.0;
  Duration _elapsedTime = Duration.zero;
  Duration? _estimatedTimeRemaining;
  String _speed = '';
  String _stage = '';
  
  // File-level status tracking
  final Map<String, FileProcessingStatus> _fileStatuses = {};
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _subscribeToProcessingUpdates();
  }
  
  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),  
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }
  
  void _subscribeToProcessingUpdates() {
    _progressSubscription = widget.audioConversionService.progressStream?.listen(
      _handleProgressUpdate,
      onError: (error) {
        print('Progress stream error: $error');
      },
    );
  }
  
  void _handleProgressUpdate(ProcessingUpdate update) {
    if (!mounted) return;
    
    setState(() {
      _currentUpdate = update;
      _stage = update.stage;
      _progress = update.progress;
      _totalFiles = update.totalFiles ?? 0;
      _completedFiles = update.completedFiles ?? 0;
      _elapsedTime = update.elapsedTime ?? Duration.zero;
      _estimatedTimeRemaining = update.estimatedTimeRemaining;
      _speed = update.speed ?? '';
      
      // Update current file if provided
      if (update.currentFile != null && update.currentFile!.isNotEmpty) {
        _currentFile = update.currentFile!;
        
        // Track individual file status
        _fileStatuses[_currentFile] = FileProcessingStatus(
          filename: _currentFile,
          status: _progress < 1.0 ? 'Processing' : 'Completed',
          progress: _progress,
          timestamp: DateTime.now(),
        );
      }
      
      // Update processing state
      final wasProcessing = _isProcessing;
      _isProcessing = widget.audioConversionService.isOperationInProgress;
      
      // Show widget when processing starts
      if (_isProcessing && !wasProcessing) {
        _show();
      }
      
      // Hide widget when processing completes (with delay)
      if (!_isProcessing && wasProcessing) {
        _onProcessingComplete();
      }
    });
  }
  
  void _show() {
    setState(() {
      _isVisible = true;
    });
    _slideController.forward();
    _autoHideTimer?.cancel();
  }
  
  void _hide() {
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
          _isExpanded = false;
        });
      }
    });
    _expandController.reverse();
  }
  
  void _onProcessingComplete() {
    // Update final stats
    _successCount = _fileStatuses.values.where((f) => f.status == 'Completed').length;
    _failureCount = _fileStatuses.values.where((f) => f.status == 'Failed').length;
    
    if (!_isExpanded) {
      _startAutoHideTimer();
    }
  }
  
  void _startAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 8), () {
      if (!_isProcessing && mounted) {
        _hide();
      }
    });
  }
  
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
        _autoHideTimer?.cancel(); // Don't auto-hide when expanded
      } else {
        _expandController.reverse();
        if (!_isProcessing) {
          _startAutoHideTimer();
        }
      }
    });
  }
  
  Future<void> _cancelProcessing() async {
    try {
      await widget.audioConversionService.cancelCurrentOperation();
      
      // Update all processing files to cancelled
      setState(() {
        for (final filename in _fileStatuses.keys) {
          if (_fileStatuses[filename]!.status == 'Processing') {
            _fileStatuses[filename] = _fileStatuses[filename]!.copyWith(
              status: 'Cancelled',
              timestamp: DateTime.now(),
            );
          }
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing cancelled'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling operation: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  void _dismissWidget() {
    _fileStatuses.clear();
    _hide();
  }
  
  String _getOperationDisplayName() {
    if (_stage.toLowerCase().contains('convert')) return 'Converting Files';
    if (_stage.toLowerCase().contains('merge')) return 'Merging Files';
    if (_stage.toLowerCase().contains('normalize')) return 'Normalizing Audio';
    if (_stage.toLowerCase().contains('enhance')) return 'Enhancing Audio';
    return 'Processing Files';
  }
  
  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _progressSubscription?.cancel();
    _slideController.dispose();
    _expandController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }
    
    final screenSize = MediaQuery.of(context).size;
    final percentage = (_progress * 100).toInt();
    
    return Positioned(
      left: _xPosition,
      top: _yPosition,  
      child: SlideTransition(
        position: _slideAnimation,
        child: Draggable(
          feedback: _buildWidget(context, percentage, true),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: _buildWidget(context, percentage, false),
          ),
          onDragEnd: (details) {
            setState(() {
              _xPosition = details.offset.dx.clamp(0, screenSize.width - 350);
              _yPosition = details.offset.dy.clamp(50, screenSize.height - 200);
            });
          },
          child: _buildWidget(context, percentage, false),
        ),
      ),
    );
  }
  
  Widget _buildWidget(BuildContext context, int percentage, bool isDragging) {
    return Material(
      elevation: isDragging ? 16 : 8,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 350,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, percentage),
            if (_isExpanded) ...[
              const Divider(height: 1),
              _buildExpandedContent(context),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context, int percentage) {
    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Progress indicator
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isProcessing 
                              ? const Color.fromARGB(255, 39, 176, 69)
                              : (_failureCount > 0 ? Colors.orange : Colors.green),
                        ),
                        strokeWidth: 3,
                      ),
                      Text(
                        '$percentage%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Status text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isProcessing 
                            ? _getOperationDisplayName()
                            : 'Processing Complete',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _totalFiles > 0 
                            ? '$_completedFiles/$_totalFiles files'
                            : _stage,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      if (_elapsedTime.inSeconds > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          _buildTimeString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Action buttons
                if (_isProcessing)
                  IconButton(
                    icon: const Icon(Icons.cancel, size: 20),
                    onPressed: _cancelProcessing,
                    tooltip: 'Cancel',
                    color: Colors.red,
                  ),
                
                if (!_isProcessing)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _dismissWidget,
                    tooltip: 'Dismiss',
                  ),
                
                // Expand/collapse button
                IconButton(
                  icon: AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(Icons.expand_more, size: 20),
                  ),
                  onPressed: _toggleExpanded,
                ),
              ],
            ),
            
            // Current file being processed
            if (_isProcessing && _currentFile.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.audiotrack,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentFile,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildExpandedContent(BuildContext context) {
    return SizeTransition(
      sizeFactor: _expandAnimation,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Summary stats
            if (_totalFiles > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Completed', _successCount, Colors.green),
                    _buildStatItem('Failed', _failureCount, Colors.red),
                    _buildStatItem('Remaining', _totalFiles - _completedFiles, Colors.grey),
                    if (_speed.isNotEmpty)
                      _buildStatItem('Speed', _speed, Colors.blue),
                  ],
                ),
              ),
            
            const Divider(height: 1),
            
            // File list
            if (_fileStatuses.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _fileStatuses.length,
                  itemBuilder: (context, index) {
                    final fileStatus = _fileStatuses.values.elementAt(index);
                    return _buildFileStatusItem(fileStatus);
                  },
                ),
              ),
            
            // Stage details
            if (_stage.isNotEmpty && _fileStatuses.isEmpty) 
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      _getStageIcon(),
                      size: 48,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _stage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, dynamic value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
  
  Widget _buildFileStatusItem(FileProcessingStatus fileStatus) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _getFileStatusIcon(fileStatus.status),
      title: Text(
        fileStatus.filename,
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: fileStatus.progress > 0 && fileStatus.progress < 1 
          ? LinearProgressIndicator(
              value: fileStatus.progress,
              minHeight: 2,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color.fromARGB(255, 39, 176, 69),
              ),
            )
          : null,
      trailing: fileStatus.status == 'Processing'
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              _formatTimestamp(fileStatus.timestamp),
              style: const TextStyle(fontSize: 10),
            ),
    );
  }
  
  Widget _getFileStatusIcon(String status) {
    switch (status) {
      case 'Completed':
        return const Icon(Icons.check_circle, color: Colors.green, size: 16);
      case 'Failed':
        return const Icon(Icons.error, color: Colors.red, size: 16);
      case 'Processing':
        return const Icon(Icons.sync, color: Colors.blue, size: 16);
      case 'Cancelled':
        return const Icon(Icons.cancel, color: Colors.orange, size: 16);
      default:
        return const Icon(Icons.hourglass_empty, color: Colors.grey, size: 16);
    }
  }
  
  IconData _getStageIcon() {
    if (_stage.toLowerCase().contains('convert')) return Icons.transform;
    if (_stage.toLowerCase().contains('merge')) return Icons.merge_type;
    if (_stage.toLowerCase().contains('metadata')) return Icons.info;
    if (_stage.toLowerCase().contains('chapter')) return Icons.list;
    return Icons.settings;
  }
  
  String _buildTimeString() {
    final parts = <String>[];
    
    if (_elapsedTime.inSeconds > 0) {
      parts.add('${_formatDuration(_elapsedTime)} elapsed');
    }
    
    if (_estimatedTimeRemaining != null && _isProcessing) {
      parts.add('${_formatDuration(_estimatedTimeRemaining!)} remaining');
    }
    
    if (_speed.isNotEmpty && _isProcessing) {
      parts.add(_speed);
    }
    
    return parts.join(' • ');
  }
  
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) {
      return 'now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Data class to track individual file processing status
class FileProcessingStatus {
  final String filename;
  final String status; // 'Processing', 'Completed', 'Failed', 'Cancelled'
  final double progress;
  final DateTime timestamp;
  final String? errorMessage;

  const FileProcessingStatus({
    required this.filename,
    required this.status,
    required this.progress,
    required this.timestamp,
    this.errorMessage,
  });

  FileProcessingStatus copyWith({
    String? filename,
    String? status,
    double? progress,
    DateTime? timestamp,
    String? errorMessage,
  }) {
    return FileProcessingStatus(
      filename: filename ?? this.filename,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      timestamp: timestamp ?? this.timestamp,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}