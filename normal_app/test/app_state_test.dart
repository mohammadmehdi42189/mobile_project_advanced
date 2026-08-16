import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movie_tracker/models/media.dart';
import 'package:movie_tracker/services/local_store.dart';
import 'package:movie_tracker/services/movie_service.dart';
import 'package:movie_tracker/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedMovieService implements MovieService {
  final Map<String, Completer<SearchResult>> pending = {};

  @override
  Future<SearchResult> search(
    String query, {
    int page = 1,
    String? type,
    int? year,
  }) => pending.putIfAbsent(query, Completer<SearchResult>.new).future;

  @override
  Future<MediaDetails> details(String id) => throw UnimplementedError();

  @override
  Future<List<Episode>> season(String id, int season) =>
      throw UnimplementedError();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('older search response cannot overwrite a newer query', () async {
    final service = _DelayedMovieService();
    final state = AppState(LocalStore(), service);

    final first = state.search('matrix');
    final second = state.search('arrival');

    service.pending['arrival']!.complete(const SearchResult([
      MediaSummary(id: 'tt2543164', title: 'Arrival', type: 'movie'),
    ], 1));
    await second;

    service.pending['matrix']!.complete(const SearchResult([
      MediaSummary(id: 'tt0133093', title: 'The Matrix', type: 'movie'),
    ], 1));
    await first;

    expect(state.searchResults.single.title, 'Arrival');
    expect(state.searchTotal, 1);
    expect(state.busy, isFalse);
  });
}
