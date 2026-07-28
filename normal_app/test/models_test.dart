import 'package:flutter_test/flutter_test.dart';
import 'package:movie_tracker/models/media.dart';
import 'package:movie_tracker/models/user_data.dart';

void main() {
  test('parses media summary', () {
    final media = MediaSummary.fromJson({
      'imdbID': 'tt0133093',
      'Title': 'The Matrix',
      'Type': 'movie',
      'Year': '1999',
      'Poster': 'N/A',
    });
    expect(media.id, 'tt0133093');
    expect(media.poster, isNull);
  });

  test('restores a spoiler review', () {
    final review = Review.fromJson({
      'id': '1',
      'mediaId': 'tt0133093',
      'text': 'Sample',
      'createdAt': '2026-01-01T00:00:00.000',
      'spoiler': true,
    });
    expect(review.spoiler, isTrue);
  });
}
