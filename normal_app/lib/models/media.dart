class MediaSummary {
  const MediaSummary({
    required this.id,
    required this.title,
    required this.type,
    this.year,
    this.poster,
    this.genre,
    this.runtimeMinutes,
  });

  final String id;
  final String title;
  final String type;
  final String? year;
  final String? poster;
  final String? genre;
  final int? runtimeMinutes;

  factory MediaSummary.fromJson(Map<String, dynamic> json) => MediaSummary(
    id: (json['imdbID'] ?? json['id']) as String,
    title: (json['Title'] ?? json['title']) as String? ?? '',
    type: (json['Type'] ?? json['type']) as String? ?? 'movie',
    year: (json['Year'] ?? json['year'])?.toString(),
    poster: nullableText(json['Poster'] ?? json['posterUrl']),
    genre: nullableText(json['Genre'] ?? json['genres']),
    runtimeMinutes: parseRuntime(json),
  );

  Map<String, dynamic> toJson() => {
    'imdbID': id,
    'Title': title,
    'Type': type,
    'Year': year,
    'Poster': poster,
    'Genre': genre,
    'runtimeMinutes': runtimeMinutes,
  };
}

class MediaDetails extends MediaSummary {
  const MediaDetails({
    required super.id,
    required super.title,
    required super.type,
    super.year,
    super.poster,
    super.genre,
    super.runtimeMinutes,
    this.plot,
    this.director,
    this.actors,
    this.runtime,
    this.country,
    this.imdbRating,
    this.totalSeasons,
  });

  final String? plot;
  final String? director;
  final String? actors;
  final String? runtime;
  final String? country;
  final String? imdbRating;
  final int? totalSeasons;

  factory MediaDetails.fromJson(Map<String, dynamic> json) => MediaDetails(
    id: (json['imdbID'] ?? json['id']) as String,
    title: (json['Title'] ?? json['title']) as String? ?? '',
    type: (json['Type'] ?? json['type']) as String? ?? 'movie',
    year: (json['Year'] ?? json['year'])?.toString(),
    poster: nullableText(json['Poster'] ?? json['posterUrl']),
    plot: nullableText(json['Plot'] ?? json['plot']),
    genre: nullableText(json['Genre'] ?? json['genres']),
    director: nullableText(json['Director'] ?? json['director']),
    actors: nullableText(json['Actors'] ?? json['cast']),
    runtime: nullableText(
      json['Runtime'] ??
          (json['runtimeMinutes'] == null
              ? null
              : '${json['runtimeMinutes']} min'),
    ),
    runtimeMinutes: parseRuntime(json),
    country: nullableText(json['Country'] ?? json['country']),
    imdbRating: nullableText(json['imdbRating']),
    totalSeasons: int.tryParse(json['totalSeasons']?.toString() ?? ''),
  );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'Plot': plot,
    'Director': director,
    'Actors': actors,
    'Runtime': runtime,
    'Country': country,
    'imdbRating': imdbRating,
    'totalSeasons': totalSeasons,
  };
}

class Episode {
  const Episode({
    required this.id,
    required this.title,
    required this.episode,
    this.released,
    this.rating,
  });

  final String id;
  final String title;
  final int episode;
  final String? released;
  final String? rating;

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    id: (json['imdbID'] ?? json['id']) as String? ?? '',
    title: (json['Title'] ?? json['title']) as String? ?? '',
    episode:
        int.tryParse((json['Episode'] ?? json['episode'])?.toString() ?? '') ??
        0,
    released: nullableText(json['Released'] ?? json['released']),
    rating: nullableText(json['imdbRating'] ?? json['rating']),
  );
}

String? nullableText(dynamic value) {
  final text = value?.toString();
  return text == null || text == 'N/A' || text.isEmpty ? null : text;
}

int? parseRuntime(Map<String, dynamic> json) {
  final raw =
      json['runtimeMinutes'] ?? json['Runtime']?.toString().split(' ').first;
  return int.tryParse(raw?.toString() ?? '');
}
