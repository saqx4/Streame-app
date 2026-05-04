enum MediaType { movie, tv }

enum CollectionGroupKind { featured, service, genre, decade, franchise, network }

enum CollectionTileShape { landscape, poster }

class NextEpisode {
  final int id;
  final int seasonNumber;
  final int episodeNumber;
  final String name;
  final String overview;

  const NextEpisode({
    required this.id,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    this.overview = '',
  });
}

class MediaItem {
  final int id;
  final String title;
  final String subtitle;
  final String overview;
  final String year;
  final String? releaseDate;
  final String rating;
  final String duration;
  final String imdbRating;
  final String tmdbRating;
  final MediaType mediaType;
  final String image;
  final String? backdrop;
  final int progress;
  final bool isWatched;
  final int? traktId;
  final String? badge;
  final List<int> genreIds;
  final String? originalLanguage;
  final String? primaryNetworkLogo;
  final bool isOngoing;
  final int? totalEpisodes;
  final int? watchedEpisodes;
  final NextEpisode? nextEpisode;
  final String? status;
  final CollectionGroupKind? collectionGroup;
  final CollectionTileShape? collectionTileShape;
  final bool collectionHideTitle;
  final String character;
  final double popularity;
  final int addedAt;
  final int sourceOrder;
  final bool isPlaceholder;

  const MediaItem({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.overview = '',
    this.year = '',
    this.releaseDate,
    this.rating = '',
    this.duration = '',
    this.imdbRating = '',
    this.tmdbRating = '',
    this.mediaType = MediaType.movie,
    this.image = '',
    this.backdrop,
    this.progress = 0,
    this.isWatched = false,
    this.traktId,
    this.badge,
    this.genreIds = const [],
    this.originalLanguage,
    this.primaryNetworkLogo,
    this.isOngoing = false,
    this.totalEpisodes,
    this.watchedEpisodes,
    this.nextEpisode,
    this.status,
    this.collectionGroup,
    this.collectionTileShape,
    this.collectionHideTitle = false,
    this.character = '',
    this.popularity = 0,
    this.addedAt = 0,
    this.sourceOrder = 0x7FFFFFFF,
    this.isPlaceholder = false,
  });

  /// Convenience getter: poster path (same as [image])
  String? get posterPath => image.isNotEmpty ? image : null;

  /// Convenience getter: numeric TMDB rating
  double get tmdbRatingDouble => double.tryParse(tmdbRating) ?? 0.0;

  MediaItem copyWith({
    int? id,
    String? title,
    String? subtitle,
    String? overview,
    String? year,
    String? releaseDate,
    String? rating,
    String? duration,
    String? imdbRating,
    String? tmdbRating,
    MediaType? mediaType,
    String? image,
    String? backdrop,
    int? progress,
    bool? isWatched,
    int? traktId,
    String? badge,
    List<int>? genreIds,
    String? originalLanguage,
    String? primaryNetworkLogo,
    bool? isOngoing,
    int? totalEpisodes,
    int? watchedEpisodes,
    NextEpisode? nextEpisode,
    String? status,
    CollectionGroupKind? collectionGroup,
    CollectionTileShape? collectionTileShape,
    bool? collectionHideTitle,
    String? character,
    double? popularity,
    int? addedAt,
    int? sourceOrder,
    bool? isPlaceholder,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      overview: overview ?? this.overview,
      year: year ?? this.year,
      releaseDate: releaseDate ?? this.releaseDate,
      rating: rating ?? this.rating,
      duration: duration ?? this.duration,
      imdbRating: imdbRating ?? this.imdbRating,
      tmdbRating: tmdbRating ?? this.tmdbRating,
      mediaType: mediaType ?? this.mediaType,
      image: image ?? this.image,
      backdrop: backdrop ?? this.backdrop,
      progress: progress ?? this.progress,
      isWatched: isWatched ?? this.isWatched,
      traktId: traktId ?? this.traktId,
      badge: badge ?? this.badge,
      genreIds: genreIds ?? this.genreIds,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      primaryNetworkLogo: primaryNetworkLogo ?? this.primaryNetworkLogo,
      isOngoing: isOngoing ?? this.isOngoing,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      nextEpisode: nextEpisode ?? this.nextEpisode,
      status: status ?? this.status,
      collectionGroup: collectionGroup ?? this.collectionGroup,
      collectionTileShape: collectionTileShape ?? this.collectionTileShape,
      collectionHideTitle: collectionHideTitle ?? this.collectionHideTitle,
      character: character ?? this.character,
      popularity: popularity ?? this.popularity,
      addedAt: addedAt ?? this.addedAt,
      sourceOrder: sourceOrder ?? this.sourceOrder,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
    );
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final releaseDate = json['release_date'] as String? ?? json['first_air_date'] as String?;
    String year = json['year'] as String? ?? '';
    if (year.isEmpty && releaseDate != null && releaseDate.isNotEmpty) {
      year = releaseDate.substring(0, 4);
    }
    return MediaItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      year: year,
      releaseDate: releaseDate,
      rating: (json['vote_average'] as num?)?.toStringAsFixed(1) ?? '',
      duration: json['duration'] as String? ?? '',
      imdbRating: json['imdb_rating'] as String? ?? '',
      tmdbRating: (json['vote_average'] as num?)?.toStringAsFixed(1) ?? '',
      mediaType: json['media_type'] == 'tv' || json['mediaType'] == 'tv'
          ? MediaType.tv
          : MediaType.movie,
      image: json['poster_path'] as String? ?? json['image'] as String? ?? '',
      backdrop: json['backdrop_path'] as String? ?? json['backdrop'] as String?,
      progress: json['progress'] as int? ?? 0,
      isWatched: json['is_watched'] as bool? ?? json['isWatched'] as bool? ?? false,
      traktId: json['trakt_id'] as int?,
      badge: json['badge'] as String?,
      genreIds: (json['genre_ids'] as List<dynamic>?)?.cast<int>() ?? [],
      originalLanguage: json['original_language'] as String?,
      primaryNetworkLogo: json['primary_network_logo'] as String?,
      isOngoing: json['is_ongoing'] as bool? ?? false,
      totalEpisodes: json['total_episodes'] as int?,
      watchedEpisodes: json['watched_episodes'] as int?,
      status: json['status'] as String?,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0,
      addedAt: json['added_at'] as int? ?? 0,
      sourceOrder: json['source_order'] as int? ?? 0x7FFFFFFF,
      isPlaceholder: json['is_placeholder'] as bool? ?? json['isPlaceholder'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'overview': overview,
    'year': year,
    'release_date': releaseDate,
    'rating': rating,
    'duration': duration,
    'imdb_rating': imdbRating,
    'tmdb_rating': tmdbRating,
    'media_type': mediaType.name,
    'poster_path': image,
    'backdrop_path': backdrop,
    'progress': progress,
    'is_watched': isWatched,
    'trakt_id': traktId,
    'badge': badge,
    'genre_ids': genreIds,
    'original_language': originalLanguage,
    'is_ongoing': isOngoing,
    'total_episodes': totalEpisodes,
    'watched_episodes': watchedEpisodes,
    'status': status,
    'popularity': popularity,
    'added_at': addedAt,
    'source_order': sourceOrder,
    'is_placeholder': isPlaceholder,
  };
}