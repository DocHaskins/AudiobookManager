// lib/ui/widgets/conversion_progress_dialog.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audiobook_organizer/utils/logger.dart';

class ConversionProgressDialog extends StatefulWidget {
  final String fileName;
  final Duration? totalDuration;
  final VoidCallback onCancel;

  const ConversionProgressDialog({
    Key? key,
    required this.fileName,
    this.totalDuration,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<ConversionProgressDialog> createState() => _ConversionProgressDialogState();

  static Future<void> show({
    required BuildContext context,
    required String fileName,
    Duration? totalDuration,
    required VoidCallback onCancel,
    required Stream<ConversionProgress> progressStream,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ConversionProgressDialogWithStream(
        fileName: fileName,
        totalDuration: totalDuration,
        onCancel: onCancel,
        progressStream: progressStream,
      ),
    );
  }
}

class _ConversionProgressDialogWithStream extends StatefulWidget {
  final String fileName;
  final Duration? totalDuration;
  final VoidCallback onCancel;
  final Stream<ConversionProgress> progressStream;

  const _ConversionProgressDialogWithStream({
    required this.fileName,
    this.totalDuration,
    required this.onCancel,
    required this.progressStream,
  });

  @override
  State<_ConversionProgressDialogWithStream> createState() => _ConversionProgressDialogWithStreamState();
}

class _ConversionProgressDialogWithStreamState extends State<_ConversionProgressDialogWithStream> {
  ConversionProgress _progress = ConversionProgress.initial();
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _progressSubscription = widget.progressStream.listen(
      (progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
          });
        }
      },
      onError: (error) {
        Logger.error('Progress stream error: $error');
      },
      onDone: () {
        Logger.log('Progress stream completed');
      },
    );
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ConversionProgressDialogState.buildDialog(
      context: context,
      fileName: widget.fileName,
      totalDuration: widget.totalDuration,
      progress: _progress,
      onCancel: widget.onCancel,
    );
  }
}

class _ConversionProgressDialogState extends State<ConversionProgressDialog> {
  @override
  Widget build(BuildContext context) {
    // This is handled by the stream version above
    return const SizedBox.shrink();
  }

  static Widget buildDialog({
    required BuildContext context,
    required String fileName,
    Duration? totalDuration,
    required ConversionProgress progress,
    required VoidCallback onCancel,
  }) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            progress.isCompleted ? Icons.check_circle : Icons.transform,
            color: progress.isCompleted ? Colors.green : Colors.purple,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              progress.isCompleted ? 'Conversion Complete' : 'Converting to M4B',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Progress bar
          LinearProgressIndicator(
            value: progress.percentage,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress.isCompleted ? Colors.green : Colors.purple,
            ),
          ),
          const SizedBox(height: 8),
          
          // Progress text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress.percentage * 100).toStringAsFixed(1)}%'),
              if (progress.speed.isNotEmpty)
                Text('${progress.speed}x speed'),
            ],
          ),
          const SizedBox(height: 12),
          
          // Time information
          if (progress.currentTime != null && totalDuration != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress: ${_formatDuration(progress.currentTime!)}'),
                Text('Total: ${_formatDuration(totalDuration)}'),
              ],
            ),
            const SizedBox(height: 8),
          ],
          
          // ETA
          if (progress.eta != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Estimated time remaining:'),
                Text(_formatDuration(progress.eta!)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          
          // Current stage
          Text(
            progress.stage,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        if (!progress.isCompleted) ...[
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Cancel'),
          ),
        ] else ...[
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ],
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class ConversionProgress {
  final double percentage;
  final Duration? currentTime;
  final Duration? eta;
  final String speed;
  final String stage;
  final bool isCompleted;

  ConversionProgress({
    required this.percentage,
    this.currentTime,
    this.eta,
    this.speed = '',
    required this.stage,
    this.isCompleted = false,
  });

  factory ConversionProgress.initial() {
    return ConversionProgress(
      percentage: 0.0,
      stage: 'Preparing conversion...',
    );
  }

  factory ConversionProgress.converting({
    required double percentage,
    Duration? currentTime,
    Duration? eta,
    String speed = '',
  }) {
    return ConversionProgress(
      percentage: percentage,
      currentTime: currentTime,
      eta: eta,
      speed: speed,
      stage: 'Converting audio format...',
    );
  }

  factory ConversionProgress.embeddingMetadata() {
    return ConversionProgress(
      percentage: 0.9,
      stage: 'Embedding metadata and cover art...',
    );
  }

  factory ConversionProgress.completed() {
    return ConversionProgress(
      percentage: 1.0,
      stage: 'Conversion completed successfully!',
      isCompleted: true,
    );
  }

  factory ConversionProgress.cancelled() {
    return ConversionProgress(
      percentage: 0.0,
      stage: 'Conversion cancelled',
      isCompleted: true,
    );
  }
}