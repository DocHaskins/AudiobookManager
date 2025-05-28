// lib/models/chapter_info.dart
import 'package:audiobook_organizer/models/audiobook_metadata.dart';

class ChapterInfo {
  final String filePath;
  final String title;
  final Duration startTime;
  final Duration duration;
  final AudiobookMetadata? metadata;
  final int order;

  ChapterInfo({
    required this.filePath,
    required this.title,
    required this.startTime,
    required this.duration,
    this.metadata,
    required this.order,
  });

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  ChapterInfo copyWith({
    String? filePath,
    String? title,
    Duration? startTime,
    Duration? duration,
    AudiobookMetadata? metadata,
    int? order,
  }) {
    return ChapterInfo(
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      metadata: metadata ?? this.metadata,
      order: order ?? this.order,
    );
  }

  @override
  String toString() {
    return 'ChapterInfo(title: $title, duration: $formattedDuration, order: $order)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChapterInfo &&
        other.filePath == filePath &&
        other.title == title &&
        other.startTime == startTime &&
        other.duration == duration &&
        other.order == order;
  }

  @override
  int get hashCode {
    return Object.hash(filePath, title, startTime, duration, order);
  }
}