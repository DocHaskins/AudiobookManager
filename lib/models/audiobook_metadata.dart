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

class AudiobookIdentifier {
  final String type; // ISBN_10, ISBN_13, ISSN, ASIN, etc.
  final String identifier;

  AudiobookIdentifier({
    required this.type,
    required this.identifier,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'identifier': identifier,
    };
  }

  factory AudiobookIdentifier.fromJson(Map<String, dynamic> json) {
    return AudiobookIdentifier(
      type: json['type'] ?? '',
      identifier: json['identifier'] ?? '',
    );
  }

  @override
  String toString() => '$type: $identifier';
}

class AudiobookMetadata {
  final String id;
  final String title;
  final String subtitle;
  final List<String> authors;
  final String narrator;
  final String description;
  final String publisher;
  final String publishedDate;
  final List<String> categories;
  final String mainCategory;
  final double averageRating;
  final int ratingsCount;
  final String thumbnailUrl;
  final String language;
  final String series;
  final String seriesPosition;
  final Duration? audioDuration;
  final String fileFormat;
  final String provider;
  
  final List<AudiobookIdentifier> identifiers; // ISBN, ASIN, etc.
  final int pageCount; // Original book page count
  final String printType; // BOOK, MAGAZINE, etc.
  final String maturityRating; // Content rating
  final String contentVersion; // Version tracking
  final Map<String, bool> readingModes; // Available reading modes
  final String previewLink; // Google Books preview URL
  final String infoLink; // Google Books info URL
  final Map<String, String> physicalDimensions; // height, width, thickness
  
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
    this.subtitle = '',
    required this.authors,
    this.narrator = '',
    this.description = '',
    this.publisher = '',
    this.publishedDate = '',
    this.categories = const [],
    this.mainCategory = '',
    this.averageRating = 0.0,
    this.ratingsCount = 0,
    this.thumbnailUrl = '',
    this.language = '',
    this.series = '',
    this.seriesPosition = '',
    this.audioDuration,
    this.fileFormat = '',
    this.provider = '',
    this.identifiers = const [],
    this.pageCount = 0,
    this.printType = '',
    this.maturityRating = '',
    this.contentVersion = '',
    this.readingModes = const {},
    this.previewLink = '',
    this.infoLink = '',
    this.physicalDimensions = const {},
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
  
  // Get formatted full title (including subtitle if present)
  String get fullTitle {
    if (subtitle.isEmpty) return title;
    return '$title: $subtitle';
  }
  
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
  
  // Get primary ISBN (prefer ISBN-13, fallback to ISBN-10)
  String get isbn {
    final isbn13 = identifiers.firstWhere(
      (id) => id.type == 'ISBN_13',
      orElse: () => AudiobookIdentifier(type: '', identifier: ''),
    ).identifier;
    
    if (isbn13.isNotEmpty) return isbn13;
    
    return identifiers.firstWhere(
      (id) => id.type == 'ISBN_10',
      orElse: () => AudiobookIdentifier(type: '', identifier: ''),
    ).identifier;
  }
  
  // Get specific identifier by type
  String getIdentifier(String type) {
    return identifiers.firstWhere(
      (id) => id.type == type,
      orElse: () => AudiobookIdentifier(type: '', identifier: ''),
    ).identifier;
  }
  
  // Check if this metadata has essential information
  bool get hasEssentialInfo {
    return title.isNotEmpty && 
           authors.isNotEmpty && 
           audioDuration != null;
  }
  
  // Check if this is from file extraction vs online source
  bool get isFromFile => provider == 'metadata_god';
  
  // Get completion percentage for metadata (updated with new fields)
  double get completionPercentage {
    int totalFields = 10; // title, authors, duration, series, description, categories, year, narrator, isbn, publisher
    int completedFields = 0;
    
    if (title.isNotEmpty) completedFields++;
    if (authors.isNotEmpty) completedFields++;
    if (audioDuration != null) completedFields++;
    if (series.isNotEmpty) completedFields++;
    if (description.isNotEmpty) completedFields++;
    if (categories.isNotEmpty) completedFields++;
    if (publishedDate.isNotEmpty) completedFields++;
    if (narrator.isNotEmpty) completedFields++;
    if (isbn.isNotEmpty) completedFields++;
    if (publisher.isNotEmpty) completedFields++;
    
    return (completedFields / totalFields) * 100;
  }
  
  // Check if audiobook has mature content
  bool get isMatureContent {
    return maturityRating.toUpperCase().contains('MATURE') ||
           maturityRating.toUpperCase().contains('ADULT');
  }
  
  // Get estimated reading time based on page count (rough estimate)
  Duration? get estimatedReadingTime {
    if (pageCount <= 0) return null;
    // Rough estimate: 250 words per page, 200 words per minute reading speed
    final estimatedMinutes = (pageCount * 250 / 200).round();
    return Duration(minutes: estimatedMinutes);
  }
  
  // Create a copy with updated fields
  AudiobookMetadata copyWith({
    String? id,
    String? title,
    String? subtitle,
    List<String>? authors,
    String? narrator,
    String? description,
    String? publisher,
    String? publishedDate,
    List<String>? categories,
    String? mainCategory,
    double? averageRating,
    int? ratingsCount,
    String? thumbnailUrl,
    String? language,
    String? series,
    String? seriesPosition,
    Duration? audioDuration,
    String? fileFormat,
    String? provider,
    List<AudiobookIdentifier>? identifiers,
    int? pageCount,
    String? printType,
    String? maturityRating,
    String? contentVersion,
    Map<String, bool>? readingModes,
    String? previewLink,
    String? infoLink,
    Map<String, String>? physicalDimensions,
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
      subtitle: subtitle ?? this.subtitle,
      authors: authors ?? this.authors,
      narrator: narrator ?? this.narrator,
      description: description ?? this.description,
      publisher: publisher ?? this.publisher,
      publishedDate: publishedDate ?? this.publishedDate,
      categories: categories ?? this.categories,
      mainCategory: mainCategory ?? this.mainCategory,
      averageRating: averageRating ?? this.averageRating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      language: language ?? this.language,
      series: series ?? this.series,
      seriesPosition: seriesPosition ?? this.seriesPosition,
      audioDuration: audioDuration ?? this.audioDuration,
      fileFormat: fileFormat ?? this.fileFormat,
      provider: provider ?? this.provider,
      identifiers: identifiers ?? this.identifiers,
      pageCount: pageCount ?? this.pageCount,
      printType: printType ?? this.printType,
      maturityRating: maturityRating ?? this.maturityRating,
      contentVersion: contentVersion ?? this.contentVersion,
      readingModes: readingModes ?? this.readingModes,
      previewLink: previewLink ?? this.previewLink,
      infoLink: infoLink ?? this.infoLink,
      physicalDimensions: physicalDimensions ?? this.physicalDimensions,
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
      'subtitle': subtitle,
      'authors': authors,
      'narrator': narrator,
      'description': description,
      'publisher': publisher,
      'publishedDate': publishedDate,
      'categories': categories,
      'mainCategory': mainCategory,
      'averageRating': averageRating,
      'ratingsCount': ratingsCount,
      'thumbnailUrl': thumbnailUrl,
      'language': language,
      'series': series,
      'seriesPosition': seriesPosition,
      'audioDuration': audioDuration?.inSeconds,
      'fileFormat': fileFormat,
      'provider': provider,
      'identifiers': identifiers.map((id) => id.toJson()).toList(),
      'pageCount': pageCount,
      'printType': printType,
      'maturityRating': maturityRating,
      'contentVersion': contentVersion,
      'readingModes': readingModes,
      'previewLink': previewLink,
      'infoLink': infoLink,
      'physicalDimensions': physicalDimensions,
      'userRating': userRating,
      'lastPlayedPosition': lastPlayedPosition?.toIso8601String(),
      'playbackPosition': playbackPosition?.inSeconds,
      'userTags': userTags,
      'isFavorite': isFavorite,
      'bookmarks': bookmarks.map((bookmark) => bookmark.toJson()).toList(),
      'notes': notes.map((note) => note.toJson()).toList(),
    };
  }
  
  // Create from JSON (backward compatible with old format)
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
    
    List<AudiobookIdentifier> identifiers = [];
    if (json['identifiers'] != null) {
      identifiers = (json['identifiers'] as List)
          .map((item) => AudiobookIdentifier.fromJson(item))
          .toList();
    }
    
    return AudiobookMetadata(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      authors: List<String>.from(json['authors'] ?? []),
      narrator: json['narrator'] ?? '',
      description: json['description'] ?? '',
      publisher: json['publisher'] ?? '',
      publishedDate: json['publishedDate'] ?? '',
      categories: List<String>.from(json['categories'] ?? []),
      mainCategory: json['mainCategory'] ?? '',
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingsCount: json['ratingsCount'] ?? 0,
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      language: json['language'] ?? '',
      series: json['series'] ?? '',
      seriesPosition: json['seriesPosition'] ?? '',
      audioDuration: json['audioDuration'] != null 
          ? Duration(seconds: json['audioDuration']) 
          : null,
      fileFormat: json['fileFormat'] ?? '',
      provider: json['provider'] ?? '',
      identifiers: identifiers,
      pageCount: json['pageCount'] ?? 0,
      printType: json['printType'] ?? '',
      maturityRating: json['maturityRating'] ?? '',
      contentVersion: json['contentVersion'] ?? '',
      readingModes: Map<String, bool>.from(json['readingModes'] ?? {}),
      previewLink: json['previewLink'] ?? '',
      infoLink: json['infoLink'] ?? '',
      physicalDimensions: Map<String, String>.from(json['physicalDimensions'] ?? {}),
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
    // Note: bitrate, channels, sampleRate are ignored if present in old JSON for backward compatibility
  }
  
  // String representation
  @override
  String toString() {
    return 'AudiobookMetadata: $fullTitle by $authorsFormatted${narrator.isNotEmpty ? " (Narrated by: $narrator)" : ""} (Series: $series #$seriesPosition)${audioDuration != null ? " - $durationFormatted" : ""}';
  }
  
  // Merge with another metadata object (useful for combining online and local data)
  AudiobookMetadata enhance(AudiobookMetadata enhancement) {
    return copyWith(
      // Only use enhancement's values if current values are empty/default
      title: title.isNotEmpty ? title : enhancement.title,
      subtitle: subtitle.isNotEmpty ? subtitle : enhancement.subtitle,
      authors: authors.isNotEmpty ? authors : enhancement.authors,
      narrator: narrator.isNotEmpty ? narrator : enhancement.narrator,
      description: description.isNotEmpty ? description : enhancement.description,
      publisher: publisher.isNotEmpty ? publisher : enhancement.publisher,
      publishedDate: publishedDate.isNotEmpty ? publishedDate : enhancement.publishedDate,
      categories: categories.isNotEmpty ? categories : enhancement.categories,
      mainCategory: mainCategory.isNotEmpty ? mainCategory : enhancement.mainCategory,
      averageRating: averageRating > 0.0 ? averageRating : enhancement.averageRating,
      ratingsCount: ratingsCount > 0 ? ratingsCount : enhancement.ratingsCount,
      thumbnailUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : enhancement.thumbnailUrl,
      language: language.isNotEmpty ? language : enhancement.language,
      series: series.isNotEmpty ? series : enhancement.series,
      seriesPosition: seriesPosition.isNotEmpty ? seriesPosition : enhancement.seriesPosition,
      audioDuration: audioDuration ?? enhancement.audioDuration,
      fileFormat: fileFormat.isNotEmpty ? fileFormat : enhancement.fileFormat,
      provider: provider.isNotEmpty ? provider : enhancement.provider,
      identifiers: identifiers.isNotEmpty ? identifiers : enhancement.identifiers,
      pageCount: pageCount > 0 ? pageCount : enhancement.pageCount,
      printType: printType.isNotEmpty ? printType : enhancement.printType,
      maturityRating: maturityRating.isNotEmpty ? maturityRating : enhancement.maturityRating,
      contentVersion: contentVersion.isNotEmpty ? contentVersion : enhancement.contentVersion,
      readingModes: readingModes.isNotEmpty ? readingModes : enhancement.readingModes,
      previewLink: previewLink.isNotEmpty ? previewLink : enhancement.previewLink,
      infoLink: infoLink.isNotEmpty ? infoLink : enhancement.infoLink,
      physicalDimensions: physicalDimensions.isNotEmpty ? physicalDimensions : enhancement.physicalDimensions,
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
  
  // UPDATE: Replace metadata while keeping user data (same book, better info)
  AudiobookMetadata updateVersion(AudiobookMetadata newVersion) {
    return AudiobookMetadata(
      // Use all values from the new version
      id: id, // Keep original file-based ID
      title: newVersion.title,
      subtitle: newVersion.subtitle,
      authors: newVersion.authors,
      narrator: newVersion.narrator,
      description: newVersion.description,
      publisher: newVersion.publisher,
      publishedDate: newVersion.publishedDate,
      categories: newVersion.categories,
      mainCategory: newVersion.mainCategory,
      averageRating: newVersion.averageRating,
      ratingsCount: newVersion.ratingsCount,
      thumbnailUrl: newVersion.thumbnailUrl,
      language: newVersion.language,
      series: newVersion.series,
      seriesPosition: newVersion.seriesPosition,
      audioDuration: newVersion.audioDuration,
      fileFormat: newVersion.fileFormat,
      provider: newVersion.provider,
      identifiers: newVersion.identifiers,
      pageCount: newVersion.pageCount,
      printType: newVersion.printType,
      maturityRating: newVersion.maturityRating,
      contentVersion: newVersion.contentVersion,
      readingModes: newVersion.readingModes,
      previewLink: newVersion.previewLink,
      infoLink: newVersion.infoLink,
      physicalDimensions: newVersion.physicalDimensions,
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
  
  // REPLACE: Completely different book - reset everything
  AudiobookMetadata replaceBook(AudiobookMetadata newBook) {
    return AudiobookMetadata(
      // Use all values from the new book
      id: id, // Keep original file-based ID (same file, different book)
      title: newBook.title,
      subtitle: newBook.subtitle,
      authors: newBook.authors,
      narrator: newBook.narrator,
      description: newBook.description,
      publisher: newBook.publisher,
      publishedDate: newBook.publishedDate,
      categories: newBook.categories,
      mainCategory: newBook.mainCategory,
      averageRating: newBook.averageRating,
      ratingsCount: newBook.ratingsCount,
      thumbnailUrl: newBook.thumbnailUrl,
      language: newBook.language,
      series: newBook.series,
      seriesPosition: newBook.seriesPosition,
      audioDuration: newBook.audioDuration,
      fileFormat: newBook.fileFormat,
      provider: newBook.provider,
      identifiers: newBook.identifiers,
      pageCount: newBook.pageCount,
      printType: newBook.printType,
      maturityRating: newBook.maturityRating,
      contentVersion: newBook.contentVersion,
      readingModes: newBook.readingModes,
      previewLink: newBook.previewLink,
      infoLink: newBook.infoLink,
      physicalDimensions: newBook.physicalDimensions,
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