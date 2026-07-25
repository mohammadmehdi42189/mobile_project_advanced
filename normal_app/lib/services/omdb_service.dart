import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/media.dart';

class MovieServiceException implements Exception {
  const MovieServiceException(this.message);
  final String message;
}

class SearchResult {
  const SearchResult(this.items, this.total);
  final List<MediaSummary> items;
  final int total;
}

class OmdbService {
  OmdbService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Map<String, dynamic>> _get(Map<String, String> parameters) async {
    if (AppConfig.omdbApiKey.isEmpty) {
      throw const MovieServiceException(
        'کلید OMDb تنظیم نشده است. برنامه را با OMDB_API_KEY اجرا کنید.',
      );
    }
    final uri = Uri.parse(AppConfig.omdbBaseUrl).replace(queryParameters: {
      'apikey': AppConfig.omdbApiKey,
      ...parameters,
    });
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw const MovieServiceException('سرویس اطلاعات در دسترس نیست.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['Response'] == 'False') {
        throw MovieServiceException(data['Error'] as String? ?? 'نتیجه‌ای پیدا نشد.');
      }
      return data;
    } on MovieServiceException {
      rethrow;
    } catch (_) {
      throw const MovieServiceException('ارتباط اینترنت را بررسی کنید.');
    }
  }

  Future<SearchResult> search(String query, {int page = 1, String? type}) async {
    final data = await _get({
      's': query,
      'page': '$page',
      if (type != null) 'type': type,
    });
    final raw = data['Search'] as List<dynamic>? ?? [];
    return SearchResult(
      raw
          .cast<Map<String, dynamic>>()
          .map(MediaSummary.fromJson)
          .toList(growable: false),
      int.tryParse(data['totalResults']?.toString() ?? '') ?? raw.length,
    );
  }

  Future<MediaDetails> details(String id) async {
    final data = await _get({'i': id, 'plot': 'full'});
    return MediaDetails.fromJson(data);
  }

  Future<List<Episode>> season(String id, int season) async {
    final data = await _get({'i': id, 'Season': '$season'});
    final raw = data['Episodes'] as List<dynamic>? ?? [];
    return raw
        .cast<Map<String, dynamic>>()
        .map(Episode.fromJson)
        .toList(growable: false);
  }
}
