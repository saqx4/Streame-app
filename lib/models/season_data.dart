/// A cast/crew member from TMDB credits.
class CastMember {
  final String name;
  final String character;
  final String profilePath;

  const CastMember({
    required this.name,
    this.character = '',
    this.profilePath = '',
  });

  factory CastMember.fromTmdbMap(Map<String, dynamic> json) {
    return CastMember(
      name: (json['name'] ?? '').toString(),
      character: (json['character'] ?? '').toString(),
      profilePath: (json['profile_path'] ?? '').toString(),
    );
  }

  /// Backwards-compatible map representation (used by existing UI widgets).
  Map<String, String> toMap() => {
    'name': name,
    'character': character,
    'profilePath': profilePath,
  };
}

/// A single episode within a TV season.
class Episode {
  final int id;
  final String name;
  final String overview;
  final String stillPath;
  final int episodeNumber;
  final String airDate;
  final double voteAverage;

  const Episode({
    required this.id,
    this.name = '',
    this.overview = '',
    this.stillPath = '',
    required this.episodeNumber,
    this.airDate = '',
    this.voteAverage = 0.0,
  });

  factory Episode.fromTmdbMap(Map<String, dynamic> json) {
    return Episode(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      overview: json['overview'] ?? '',
      stillPath: json['still_path'] ?? '',
      episodeNumber: json['episode_number'] ?? 0,
      airDate: json['air_date'] ?? '',
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// A TV season with its episodes.
/// Supports both TMDB format (flat episode list) and custom-ID/Stremio format
/// (episodes grouped by season number).
class SeasonData {
  /// Available season numbers (for custom-ID format).
  final List<int>? seasons;

  /// Flat episode list (TMDB format).
  final List<Episode>? episodes;

  /// Episodes keyed by season number (custom-ID format).
  final Map<int, List<Episode>>? episodesBySeason;

  const SeasonData({
    this.seasons,
    this.episodes,
    this.episodesBySeason,
  });

  /// Construct from TMDB season-details response.
  factory SeasonData.fromTmdbResponse(Map<String, dynamic> json) {
    final epList = (json['episodes'] as List?)
            ?.map((e) => Episode.fromTmdbMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    return SeasonData(episodes: epList);
  }

  /// Construct from custom-ID/Stremio format.
  factory SeasonData.fromCustomIdFormat(
    List<int> seasonNumbers,
    Map<int, List<Map<String, dynamic>>> rawEpisodesBySeason,
  ) {
    final bySeason = <int, List<Episode>>{};
    for (final entry in rawEpisodesBySeason.entries) {
      bySeason[entry.key] =
          entry.value.map((e) => Episode.fromTmdbMap(e)).toList();
    }
    return SeasonData(
      seasons: seasonNumbers..sort(),
      episodesBySeason: bySeason,
    );
  }

  /// Get episodes for a given season number.
  List<Episode> episodesForSeason(int seasonNumber) {
    if (episodes != null) return episodes!;
    if (episodesBySeason != null) {
      return episodesBySeason![seasonNumber] ?? [];
    }
    return [];
  }

  /// Get total season count.
  int get seasonCount {
    if (seasons != null) return seasons!.length;
    if (episodesBySeason != null) return episodesBySeason!.length;
    return 1;
  }

  /// Whether this uses the custom-ID format (episodesBySeason).
  bool get isCustomIdFormat => episodesBySeason != null;
}
