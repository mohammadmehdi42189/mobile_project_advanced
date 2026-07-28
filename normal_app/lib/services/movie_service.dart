import '../models/media.dart';

class MovieServiceException implements Exception {
  const MovieServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SearchResult {
  const SearchResult(this.items, this.total);
  final List<MediaSummary> items;
  final int total;
}

abstract interface class MovieService {
  Future<SearchResult> search(
    String query, {
    int page = 1,
    String? type,
    int? year,
  });
  Future<MediaDetails> details(String id);
  Future<List<Episode>> season(String id, int season);
}
