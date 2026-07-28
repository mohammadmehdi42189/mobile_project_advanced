class MediaSummary {
  const MediaSummary({
    required this.id,
    required this.title,
    required this.type,
    this.year,
    this.poster,
  });

  final String id;
  final String title;
  final String type;
  final String? year;
  final String? poster;

  factory MediaSummary.fromJson(Map<String, dynamic> json) => MediaSummary(
        id: json['imdbID'] as String,
        title: json['Title'] as String? ?? '',
        type: json['Type'] as String? ?? 'movie',
        year: json['Year'] as String?,
        poster: _nullable(json['Poster']),
      );

  Map<String, dynamic> toJson() => {
        'imdbID': id,
        'Title': title,
        'Type': type,
        'Year': year,
        'Poster': poster,
      };
}

class MediaDetails extends MediaSummary {
  const MediaDetails({
    required super.id,
    required super.title,
    required super.type,
    super.year,
    super.poster,
    this.plot,
    this.genre,
    this.director,
    this.actors,
    this.runtime,
    this.country,
    this.imdbRating,
    this.totalSeasons,
  });

  final String? plot;
  final String? genre;
  final String? director;
  final String? actors;
  final String? runtime;
  final String? country;
  final String? imdbRating;
  final int? totalSeasons;

  factory MediaDetails.fromJson(Map<String, dynamic> json) => MediaDetails(
        id: json['imdbID'] as String,
        title: json['Title'] as String? ?? '',
        type: json['Type'] as String? ?? 'movie',
        year: json['Year'] as String?,
        poster: _nullable(json['Poster']),
        plot: _nullable(json['Plot']),
        genre: _nullable(json['Genre']),
        director: _nullable(json['Director']),
        actors: _nullable(json['Actors']),
        runtime: _nullable(json['Runtime']),
        country: _nullable(json['Country']),
        imdbRating: _nullable(json['imdbRating']),
        totalSeasons: int.tryParse(json['totalSeasons']?.toString() ?? ''),
      );
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
        id: json['imdbID'] as String? ?? '',
        title: json['Title'] as String? ?? '',
        episode: int.tryParse(json['Episode']?.toString() ?? '') ?? 0,
        released: _nullable(json['Released']),
        rating: _nullable(json['imdbRating']),
      );
}

String? _nullable(dynamic value) {
  final text = value?.toString();
  return text == null || text == 'N/A' || text.isEmpty ? null : text;
}
