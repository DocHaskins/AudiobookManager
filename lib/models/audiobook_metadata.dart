// lib/models/audiobook_metadata.dart

class AudiobookBookmark {
  final String id;
  final String title;
  final Duration position;
  final DateTime createdAt;
  final String? note;

  AudiobookBookmark({
    required this.id,
    required this.title,
    required this.position,
    required this.createdAt,
    this.note,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'position': position.inSeconds,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
    };
  }

  // Create from JSON
  factory AudiobookBookmark.fromJson(Map<String, dynamic> json) {
    return AudiobookBookmark(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      position: Duration(seconds: json['position'] ?? 0),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      note: json['note'],
    );
  }
}

class AudiobookNote {
  final String id;
  final String content;
  final DateTime createdAt;
  final Duration? position; // Optional - note could be general or position-specific
  final String? chapter;

  AudiobookNote({
    required this.id,
    required this.content,
    required this.createdAt,
    this.position,
    this.chapter,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'position': position?.inSeconds,
      'chapter': chapter,
    };
  }

  // Create from JSON
  factory AudiobookNote.fromJson(Map<String, dynamic> json) {
    return AudiobookNote(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      position: json['position'] != null 
          ? Duration(seconds: json['position']) 
          : null,
      chapter: json['chapter'],
    );
  }
}

class AudiobookMetadata {
  final String id;
  final String title;
  final List<String> authors;
  final String description;
  final String publisher;
  final String publishedDate;
  final List<String> categories;
  final double averageRating;
  final int ratingsCount;
  final String thumbnailUrl;
  final String language;
  final String series;
  final String seriesPosition;
  final Duration? audioDuration;
  final int? bitrate;
  final int? channels;
  final int? sampleRate;
  final String fileFormat;
  final String provider;
  
  // User-specific fields
  final int userRating;
  final DateTime? lastPlayedPosition;
  final Duration? playbackPosition;
  final List<String> userTags;
  final bool isFavorite;
  final List<AudiobookBookmark> bookmarks;
  final List<AudiobookNote> notes;
  
  AudiobookMetadata({
    required this.id,
    required this.title,
    required this.authors,
    this.description = '',
    this.publisher = '',
    this.publishedDate = '',
    this.categories = const [],
    this.averageRating = 0.0,
    this.ratingsCount = 0,
    this.thumbnailUrl = '',
    this.language = '',
    this.series = '',
    this.seriesPosition = '',
    this.audioDuration,
    this.bitrate,
    this.channels,
    this.sampleRate,
    this.fileFormat = '',
    this.provider = '',
    this.userRating = 0,
    this.lastPlayedPosition,
    this.playbackPosition,
    this.userTags = const [],
    this.isFavorite = false,
    this.bookmarks = const [],
    this.notes = const [],
  });
  
  // Get formatted authors string
  String get authorsFormatted => authors.isEmpty ? 'Unknown' : authors.join(', ');
  
  // Get formatted duration string
  String get durationFormatted {
    if (audioDuration == null) return 'Unknown';
    
    final hours = audioDuration!.inHours;
    final minutes = audioDuration!.inMinutes.remainder(60);
    final seconds = audioDuration!.inSeconds.remainder(60);
    
    return hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  // Create a copy with updated fields
  AudiobookMetadata copyWith({
    String? id,
    String? title,
    List<String>? authors,
    String? description,
    String? publisher,
    String? publishedDate,
    List<String>? categories,
    double? averageRating,
    int? ratingsCount,
    String? thumbnailUrl,
    String? language,
    String? series,
    String? seriesPosition,
    Duration? audioDuration,
    int? bitrate,
    int? channels,
    int? sampleRate,
    String? fileFormat,
    String? provider,
    int? userRating,
    DateTime? lastPlayedPosition,
    Duration? playbackPosition,
    List<String>? userTags,
    bool? isFavorite,
    List<AudiobookBookmark>? bookmarks,
    List<AudiobookNote>? notes,
  }) {
    return AudiobookMetadata(
      id: id ?? this.id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      description: description ?? this.description,
      publisher: publisher ?? this.publisher,
      publishedDate: publishedDate ?? this.publishedDate,
      categories: categories ?? this.categories,
      averageRating: averageRating ?? this.averageRating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      language: language ?? this.language,
      series: series ?? this.series,
      seriesPosition: seriesPosition ?? this.seriesPosition,
      audioDuration: audioDuration ?? this.audioDuration,
      bitrate: bitrate ?? this.bitrate,
      channels: channels ?? this.channels,
      sampleRate: sampleRate ?? this.sampleRate,
      fileFormat: fileFormat ?? this.fileFormat,
      provider: provider ?? this.provider,
      userRating: userRating ?? this.userRating,
      lastPlayedPosition: lastPlayedPosition ?? this.lastPlayedPosition,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      userTags: userTags ?? this.userTags,
      isFavorite: isFavorite ?? this.isFavorite,
      bookmarks: bookmarks ?? this.bookmarks,
      notes: notes ?? this.notes,
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'authors': authors,
      'description': description,
      'publisher': publisher,
      'publishedDate': publishedDate,
      'categories': categories,
      'averageRating': averageRating,
      'ratingsCount': ratingsCount,
      'thumbnailUrl': thumbnailUrl,
      'language': language,
      'series': series,
      'seriesPosition': seriesPosition,
      'audioDuration': audioDuration?.inSeconds,
      'bitrate': bitrate,
      'channels': channels,
      'sampleRate': sampleRate,
      'fileFormat': fileFormat,
      'provider': provider,
      'userRating': userRating,
      'lastPlayedPosition': lastPlayedPosition?.toIso8601String(),
      'playbackPosition': playbackPosition?.inSeconds,
      'userTags': userTags,
      'isFavorite': isFavorite,
      'bookmarks': bookmarks.map((bookmark) => bookmark.toJson()).toList(),
      'notes': notes.map((note) => note.toJson()).toList(),
    };
  }
  
  // Create from JSON
  factory AudiobookMetadata.fromJson(Map<String, dynamic> json) {
    List<AudiobookBookmark> bookmarks = [];
    if (json['bookmarks'] != null) {
      bookmarks = (json['bookmarks'] as List)
          .map((item) => AudiobookBookmark.fromJson(item))
          .toList();
    }
    
    List<AudiobookNote> notes = [];
    if (json['notes'] != null) {
      notes = (json['notes'] as List)
          .map((item) => AudiobookNote.fromJson(item))
          .toList();
    }
    
    return AudiobookMetadata(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      authors: List<String>.from(json['authors'] ?? []),
      description: json['description'] ?? '',
      publisher: json['publisher'] ?? '',
      publishedDate: json['publishedDate'] ?? '',
      categories: List<String>.from(json['categories'] ?? []),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingsCount: json['ratingsCount'] ?? 0,
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      language: json['language'] ?? '',
      series: json['series'] ?? '',
      seriesPosition: json['seriesPosition'] ?? '',
      audioDuration: json['audioDuration'] != null 
          ? Duration(seconds: json['audioDuration']) 
          : null,
      bitrate: json['bitrate'],
      channels: json['channels'],
      sampleRate: json['sampleRate'],
      fileFormat: json['fileFormat'] ?? '',
      provider: json['provider'] ?? '',
      userRating: json['userRating'] ?? 0,
      lastPlayedPosition: json['lastPlayedPosition'] != null 
          ? DateTime.parse(json['lastPlayedPosition']) 
          : null,
      playbackPosition: json['playbackPosition'] != null 
          ? Duration(seconds: json['playbackPosition']) 
          : null,
      userTags: List<String>.from(json['userTags'] ?? []),
      isFavorite: json['isFavorite'] ?? false,
      bookmarks: bookmarks,
      notes: notes,
    );
  }
  
  // String representation
  @override
  String toString() {
    return 'AudiobookMetadata: $title by $authorsFormatted (Series: $series #$seriesPosition)';
  }
  
  // Merge with another metadata object (useful for combining online and local data)
  AudiobookMetadata enhance(AudiobookMetadata enhancement) {
    return copyWith(
      // Only use enhancement's values if current values are empty/default
      title: title.isNotEmpty ? title : enhancement.title,
      authors: authors.isNotEmpty ? authors : enhancement.authors,
      description: description.isNotEmpty ? description : enhancement.description,
      publisher: publisher.isNotEmpty ? publisher : enhancement.publisher,
      publishedDate: publishedDate.isNotEmpty ? publishedDate : enhancement.publishedDate,
      categories: categories.isNotEmpty ? categories : enhancement.categories,
      averageRating: averageRating > 0.0 ? averageRating : enhancement.averageRating,
      ratingsCount: ratingsCount > 0 ? ratingsCount : enhancement.ratingsCount,
      thumbnailUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : enhancement.thumbnailUrl,
      language: language.isNotEmpty ? language : enhancement.language,
      series: series.isNotEmpty ? series : enhancement.series,
      seriesPosition: seriesPosition.isNotEmpty ? seriesPosition : enhancement.seriesPosition,
      audioDuration: audioDuration ?? enhancement.audioDuration,
      bitrate: bitrate ?? enhancement.bitrate,
      channels: channels ?? enhancement.channels,
      sampleRate: sampleRate ?? enhancement.sampleRate,
      fileFormat: fileFormat.isNotEmpty ? fileFormat : enhancement.fileFormat,
      provider: provider.isNotEmpty ? provider : enhancement.provider,
      // Preserve ALL user data
      userRating: userRating,
      lastPlayedPosition: lastPlayedPosition,
      playbackPosition: playbackPosition,
      userTags: userTags,
      isFavorite: isFavorite,
      bookmarks: bookmarks,
      notes: notes,
    );
  }
  
  // 2. UPDATE: Replace metadata while keeping user data (same book, better info)
  AudiobookMetadata updateVersion(AudiobookMetadata newVersion) {
    return AudiobookMetadata(
      // Use all values from the new version
      id: id, // Keep original file-based ID
      title: newVersion.title,
      authors: newVersion.authors,
      description: newVersion.description,
      publisher: newVersion.publisher,
      publishedDate: newVersion.publishedDate,
      categories: newVersion.categories,
      averageRating: newVersion.averageRating,
      ratingsCount: newVersion.ratingsCount,
      thumbnailUrl: newVersion.thumbnailUrl,
      language: newVersion.language,
      series: newVersion.series,
      seriesPosition: newVersion.seriesPosition,
      audioDuration: newVersion.audioDuration,
      bitrate: newVersion.bitrate,
      channels: newVersion.channels,
      sampleRate: newVersion.sampleRate,
      fileFormat: newVersion.fileFormat,
      provider: newVersion.provider,
      // PRESERVE user data - same book, just better metadata
      userRating: userRating,
      lastPlayedPosition: lastPlayedPosition,
      playbackPosition: playbackPosition,
      userTags: userTags,
      isFavorite: isFavorite,
      bookmarks: bookmarks,
      notes: notes,
    );
  }
  
  // 3. REPLACE: Completely different book - reset everything
  AudiobookMetadata replaceBook(AudiobookMetadata newBook) {
    return AudiobookMetadata(
      // Use all values from the new book
      id: id, // Keep original file-based ID (same file, different book)
      title: newBook.title,
      authors: newBook.authors,
      description: newBook.description,
      publisher: newBook.publisher,
      publishedDate: newBook.publishedDate,
      categories: newBook.categories,
      averageRating: newBook.averageRating,
      ratingsCount: newBook.ratingsCount,
      thumbnailUrl: newBook.thumbnailUrl,
      language: newBook.language,
      series: newBook.series,
      seriesPosition: newBook.seriesPosition,
      audioDuration: newBook.audioDuration,
      bitrate: newBook.bitrate,
      channels: newBook.channels,
      sampleRate: newBook.sampleRate,
      fileFormat: newBook.fileFormat,
      provider: newBook.provider,
      // RESET user data - this is a different book entirely
      userRating: 0,
      lastPlayedPosition: null,
      playbackPosition: null,
      userTags: const [],
      isFavorite: false,
      bookmarks: const [],
      notes: const [],
    );
  }
}