import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';
import '../models/media.dart';
import '../models/user_data.dart';
import 'movie_service.dart';

class BackendService implements MovieService {
  BackendService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.backendBaseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'Accept': 'application/json'},
        ),
      ) {
    final uri = Uri.parse(AppConfig.backendBaseUrl);
    if (uri.scheme != 'https' &&
        uri.host != 'localhost' &&
        uri.host != '10.0.2.2') {
      throw StateError('The advanced backend must use HTTPS.');
    }
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: HttpClient.new,
      validateCertificate: (certificate, _, __) {
        final expected = AppConfig.backendCertificateSha256
            .replaceAll(':', '')
            .toLowerCase();
        if (expected.isEmpty) return true;
        final actual = sha256.convert(certificate?.der ?? []).toString();
        return actual == expected;
      },
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _token;

  Future<bool> restoreSession() async {
    _token = await _secureStorage.read(key: 'backend_token');
    return _token != null;
  }

  Future<LocalUser> register(String name, String email, String password) async {
    final response = await _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
    return _saveIdentity(response);
  }

  Future<LocalUser> login(String email, String password) async {
    final response = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    return _saveIdentity(response);
  }

  Future<LocalUser> profile() async {
    final response = await _get('/profile');
    return _userFromJson(response);
  }

  Future<void> logout() async {
    _token = null;
    await _secureStorage.delete(key: 'backend_token');
  }

  Future<void> requestPasswordReset(String email) async {
    await _post('/auth/password-reset/request', {'email': email});
  }

  Future<void> confirmPasswordReset(
    String email,
    String token,
    String password,
  ) async {
    await _post('/auth/password-reset/confirm', {
      'email': email,
      'token': token,
      'password': password,
    });
  }

  Future<void> updateProfile(String name, String bio) async {
    await _patch('/profile', {'name': name, 'bio': bio});
  }

  Future<void> setWatchState(
    String mediaId,
    WatchState state,
    int watchedEpisodes,
  ) async {
    await _put('/watchlist/$mediaId', {
      'status': switch (state) {
        WatchState.planned => 'PLANNED',
        WatchState.watching => 'WATCHING',
        WatchState.completed => 'COMPLETED',
        WatchState.paused || WatchState.dropped => 'DROPPED',
        WatchState.favorite => 'FAVORITE',
      },
      'watchedEpisodes': watchedEpisodes,
    });
  }

  Future<void> setEpisode(
    String mediaId,
    int season,
    int episode,
    bool watched,
  ) async {
    final path = '/episodes/$mediaId/$season/$episode';
    if (watched) {
      await _put(path, const {});
    } else {
      await _delete(path);
    }
  }

  Future<void> rate(String mediaId, double value) async {
    await _put('/ratings/$mediaId', {'value': (value * 2).round()});
  }

  Future<Map<int, double>> ratingDistribution(String mediaId) async {
    final response = await _get('/media/$mediaId/ratings');
    final distribution =
        response['distribution'] as Map<String, dynamic>? ?? {};
    return {
      for (var value = 1; value <= 10; value++)
        value: (distribution['$value'] as num?)?.toDouble() ?? 0,
    };
  }

  Future<String?> addComment(String mediaId, String text, bool spoiler) async {
    final response = await _post('/comments/$mediaId', {
      'text': text,
      'spoiler': spoiler,
    });
    return response['id'] as String?;
  }

  Future<void> deleteComment(String id) async {
    await _delete('/comments/$id');
  }

  Future<List<Review>> mediaComments(String mediaId) async {
    try {
      final response = await _dio.get<dynamic>('/media/$mediaId/comments');
      return (response.data as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) {
            final author = row['user'] as Map<String, dynamic>? ?? const {};
            return Review(
              id: row['id'] as String,
              mediaId: row['mediaId'] as String,
              text: row['text'] as String,
              spoiler: row['spoiler'] as bool? ?? false,
              createdAt: DateTime.parse(row['createdAt'] as String),
              userName: author['name'] as String?,
              userAvatar: author['avatarUrl'] as String?,
            );
          })
          .toList(growable: false);
    } on DioException catch (exception) {
      throw MovieServiceException(_message(exception));
    }
  }

  Future<String?> createList(String name) async {
    final response = await _post('/lists', {'name': name});
    return response['id'] as String?;
  }

  Future<void> deleteList(String id) => _delete('/lists/$id');

  Future<void> addToList(String listId, String mediaId) =>
      _put('/lists/$listId/items/$mediaId', const {});

  Future<void> removeFromList(String listId, String mediaId) =>
      _delete('/lists/$listId/items/$mediaId');

  Future<Map<String, dynamic>> personalData() async {
    try {
      final responses = await Future.wait([
        _dio.get<dynamic>('/watchlist'),
        _dio.get<dynamic>('/ratings'),
        _dio.get<dynamic>('/comments'),
        _dio.get<dynamic>('/lists'),
        _dio.get<dynamic>('/episodes/progress'),
      ]);
      return {
        'watchlist': responses[0].data,
        'ratings': responses[1].data,
        'comments': responses[2].data,
        'lists': responses[3].data,
        'episodes': responses[4].data,
      };
    } on DioException catch (exception) {
      throw MovieServiceException(_message(exception));
    }
  }

  @override
  Future<SearchResult> search(
    String query, {
    int page = 1,
    String? type,
    int? year,
  }) async {
    final data = await _get(
      '/media/search',
      query: {
        'q': query,
        'page': page,
        if (type != null) 'type': type,
        if (year != null) 'year': year,
      },
    );
    final items = (data['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(MediaSummary.fromJson)
        .toList(growable: false);
    return SearchResult(items, data['total'] as int? ?? items.length);
  }

  @override
  Future<MediaDetails> details(String id) async {
    return MediaDetails.fromJson(await _get('/media/$id'));
  }

  @override
  Future<List<Episode>> season(String id, int season) async {
    final data = await _get('/media/$id/seasons/$season');
    return (data['episodes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Episode.fromJson)
        .toList(growable: false);
  }

  Future<LocalUser> _saveIdentity(Map<String, dynamic> data) async {
    _token = data['token'] as String;
    await _secureStorage.write(key: 'backend_token', value: _token);
    return _userFromJson(data['user'] as Map<String, dynamic>);
  }

  LocalUser _userFromJson(Map<String, dynamic> data) => LocalUser(
    id: data['id'] as String,
    name: data['name'] as String,
    email: data['email'] as String,
    passwordHash: '',
    bio: data['bio'] as String? ?? '',
    avatarPath: data['avatarUrl'] as String?,
  );

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<dynamic>(path, queryParameters: query);
      return response.data as Map<String, dynamic>;
    } on DioException catch (exception) {
      throw MovieServiceException(_message(exception));
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<dynamic>(path, data: body);
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};
    } on DioException catch (exception) {
      throw MovieServiceException(_message(exception));
    }
  }

  Future<void> _put(String path, Map<String, dynamic> body) async {
    try {
      await _dio.put<dynamic>(path, data: body);
    } on DioException catch (exception) {
      throw MovieServiceException(_message(exception));
    }
  }

  Future<void> _patch(String path, Map<String, dynamic> body) async {
    try {
      await _dio.patch<dynamic>(path, data: body);
    } on DioException catch (exception) {
      throw MovieServiceException(_message(exception));
    }
  }

  Future<void> _delete(String path) async {
    try {
      await _dio.delete<dynamic>(path);
    } on DioException catch (exception) {
      throw MovieServiceException(_message(exception));
    }
  }

  String _message(DioException exception) {
    final data = exception.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        return error['message'] as String;
      }
    }
    return 'ارتباط با سرور برقرار نشد.';
  }
}
