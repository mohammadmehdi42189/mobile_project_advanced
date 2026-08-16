import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/media.dart';
import '../models/user_data.dart';
import '../services/backend_service.dart';
import '../services/local_store.dart';
import '../services/movie_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.store, this.api);

  final LocalStore store;
  final MovieService api;
  LocalUser? user;
  bool guestMode = false;
  bool initialized = false;
  bool busy = false;
  String? error;
  List<MediaSummary> searchResults = [];
  int searchTotal = 0;
  final Map<String, MediaSummary> savedMedia = {};
  final Map<String, WatchState> watchStates = {};
  final Map<String, Set<String>> watchedEpisodes = {};
  final Map<String, double> ratings = {};
  final List<Review> reviews = [];
  final Map<String, List<Review>> publicReviews = {};
  final Map<String, Set<String>> customLists = {};
  final Map<String, String> remoteListIds = {};
  Timer? _searchTimer;
  int _searchRequestId = 0;

  BackendService? get backend =>
      api is BackendService ? api as BackendService : null;

  Future<void> initialize() async {
    if (backend != null) {
      try {
        if (await backend!.restoreSession()) user = await backend!.profile();
      } catch (_) {
        await backend!.logout();
      }
    } else {
      final users = await store.users();
      final sessionId = await store.session();
      user = users.where((item) => item.id == sessionId).firstOrNull;
    }
    if (user != null) await _loadData();
    initialized = true;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String bio = '',
    String? avatarPath,
    int sessionDays = 30,
  }) async {
    if (backend != null) {
      user = await backend!.register(
        name.trim(),
        username.trim(),
        email.trim(),
        password,
        bio: bio.trim(),
        avatarUrl: avatarPath?.trim().isEmpty ?? true ? null : avatarPath!.trim(),
        sessionDays: sessionDays,
      );
    } else {
      final users = await store.users();
      final normalized = email.trim().toLowerCase();
      final normalizedUsername = username.trim().toLowerCase();
      if (!RegExp(r'^[a-zA-Z0-9_.]{3,30}$').hasMatch(username.trim())) {
        throw StateError('نام کاربری باید ۳ تا ۳۰ نویسه و شامل حروف انگلیسی، عدد، . یا _ باشد.');
      }
      if (users.any((item) => item.email == normalized)) {
        throw StateError('این ایمیل قبلاً ثبت شده است.');
      }
      if (users.any((item) => item.username.toLowerCase() == normalizedUsername)) {
        throw StateError('این نام کاربری قبلاً ثبت شده است.');
      }
      user = LocalUser(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        username: normalizedUsername,
        email: normalized,
        passwordHash: store.hashPassword(password),
        bio: bio.trim(),
        avatarPath: avatarPath?.trim().isEmpty ?? true ? null : avatarPath!.trim(),
      );
      await store.saveUsers([...users, user!]);
      await store.saveSession(user!.id, days: sessionDays);
    }
    notifyListeners();
  }

  void continueAsGuest() {
    guestMode = true;
    notifyListeners();
  }

  void exitGuest() {
    guestMode = false;
    notifyListeners();
  }

  Future<void> login(
    String email,
    String password, {
    int sessionDays = 30,
  }) async {
    if (backend != null) {
      user = await backend!.login(
        email.trim(),
        password,
        sessionDays: sessionDays,
      );
    } else {
      final users = await store.users();
      user = users
          .where(
            (item) =>
                item.email == email.trim().toLowerCase() &&
                store.verifyPassword(password, item.passwordHash),
          )
          .firstOrNull;
      if (user == null) throw StateError('ایمیل یا رمز عبور نادرست است.');
      if (store.needsPasswordUpgrade(user!.passwordHash)) {
        user = user!.copyWith(passwordHash: store.hashPassword(password));
        await store.saveUsers([
          for (final item in users)
            if (item.id == user!.id) user! else item,
        ]);
      }
      await store.saveSession(user!.id, days: sessionDays);
    }
    await _loadData();
    notifyListeners();
  }

  Future<void> logout() async {
    if (backend != null) {
      await backend!.logout();
    } else {
      await store.saveSession(null);
    }
    user = null;
    guestMode = false;
    _clearData();
    notifyListeners();
  }

  Future<void> requestPasswordReset(String email) async {
    if (backend == null) {
      throw StateError(
        'بازیابی امن رمز عبور فقط در حالت پیشرفته و از طریق ایمیل در دسترس است.',
      );
    }
    await backend!.requestPasswordReset(email.trim());
  }

  Future<void> resetPassword(
    String email,
    String newPassword, {
    String? token,
  }) async {
    if (backend != null) {
      if (token == null || token.length != 8) {
        throw StateError('کد بازیابی هشت‌نویسه‌ای را وارد کنید.');
      }
      await backend!.confirmPasswordReset(email.trim(), token, newPassword);
      return;
    }
    throw StateError(
      'بازیابی امن رمز عبور در حالت عادی بدون سرویس ایمیل قابل انجام نیست.',
    );
  }

  Future<void> updateProfile(String name, String bio) async {
    if (backend != null) {
      await backend!.updateProfile(name.trim(), bio.trim());
    }
    final users = await store.users();
    user = user!.copyWith(name: name.trim(), bio: bio.trim());
    if (backend == null) {
      await store.saveUsers([
        for (final item in users)
          if (item.id == user!.id) user! else item,
      ]);
    }
    notifyListeners();
  }

  void debouncedSearch(String query) {
    _searchTimer?.cancel();
    if (query.trim().length < 2) {
      _searchRequestId++;
      searchResults = [];
      searchTotal = 0;
      busy = false;
      notifyListeners();
      return;
    }
    _searchTimer = Timer(
      const Duration(milliseconds: 450),
      () => search(query),
    );
  }

  Future<void> search(String query, {int page = 1}) async {
    final requestId = ++_searchRequestId;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.search(query.trim(), page: page);
      if (requestId != _searchRequestId) return;
      searchResults = result.items;
      searchTotal = result.total;
      await store.cacheSearch(query, result.items);
    } on MovieServiceException catch (exception) {
      final cached = await store.cachedSearch(query);
      if (requestId != _searchRequestId) return;
      searchResults = cached;
      searchTotal = cached.length;
      error = cached.isEmpty
          ? exception.message
          : 'نتایج ذخیره‌شده نمایش داده می‌شوند.';
    } finally {
      if (requestId == _searchRequestId) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> setWatchState(MediaSummary media, WatchState state) async {
    await backend?.setWatchState(media.id, state);
    savedMedia[media.id] = media;
    watchStates[media.id] = state;
    await _saveData();
    notifyListeners();
  }

  bool isEpisodeWatched(String mediaId, int season, int episode) =>
      watchedEpisodes[mediaId]?.contains('$season:$episode') ?? false;

  int seasonWatchedCount(String mediaId, int season) =>
      watchedEpisodes[mediaId]
          ?.where((value) => value.startsWith('$season:'))
          .length ??
      0;

  Future<void> toggleEpisode(
    MediaSummary media,
    int season,
    int episode,
  ) async {
    final key = '$season:$episode';
    final watched = !(watchedEpisodes[media.id]?.contains(key) ?? false);
    await backend?.setEpisode(media.id, season, episode, watched);
    savedMedia[media.id] = media;
    final episodes = watchedEpisodes.putIfAbsent(media.id, () => <String>{});
    if (watched) {
      episodes.add(key);
    } else {
      episodes.remove(key);
    }
    watchStates[media.id] = WatchState.watching;
    await _saveData();
    notifyListeners();
  }

  Future<void> rate(MediaSummary media, double value) async {
    await backend?.rate(media.id, value);
    savedMedia[media.id] = media;
    ratings[media.id] = value;
    await _saveData();
    notifyListeners();
  }

  Future<Map<int, double>> ratingDistribution(String mediaId) =>
      backend?.ratingDistribution(mediaId) ?? store.ratingDistribution(mediaId);

  Future<void> addReview(String mediaId, String text, bool spoiler) async {
    final remoteId = await backend?.addComment(mediaId, text.trim(), spoiler);
    reviews.add(
      Review(
        id: remoteId ?? DateTime.now().microsecondsSinceEpoch.toString(),
        mediaId: mediaId,
        text: text.trim(),
        spoiler: spoiler,
        createdAt: DateTime.now(),
        userName: user?.name,
        userAvatar: user?.avatarPath,
      ),
    );
    await _saveData();
    await loadReviews(mediaId);
    notifyListeners();
  }

  Future<void> deleteReview(String id) async {
    await backend?.deleteComment(id);
    reviews.removeWhere((review) => review.id == id);
    for (final items in publicReviews.values) {
      items.removeWhere((review) => review.id == id);
    }
    await _saveData();
    notifyListeners();
  }

  List<Review> reviewsFor(String mediaId) =>
      publicReviews[mediaId] ??
      reviews.where((review) => review.mediaId == mediaId).toList();

  Future<void> loadReviews(String mediaId) async {
    publicReviews[mediaId] = backend != null
        ? await backend!.mediaComments(mediaId)
        : await store.reviewsForMedia(mediaId);
    notifyListeners();
  }

  Future<void> createList(String name) async {
    final normalized = name.trim();
    final remoteId = await backend?.createList(normalized);
    customLists.putIfAbsent(normalized, () => <String>{});
    if (remoteId != null) remoteListIds[normalized] = remoteId;
    await _saveData();
    notifyListeners();
  }

  Future<void> deleteList(String name) async {
    final remoteId = remoteListIds[name];
    if (remoteId != null) await backend?.deleteList(remoteId);
    customLists.remove(name);
    remoteListIds.remove(name);
    await _saveData();
    notifyListeners();
  }

  Future<void> addToList(String name, MediaSummary media) async {
    final remoteId = remoteListIds[name];
    if (remoteId != null) await backend?.addToList(remoteId, media.id);
    savedMedia[media.id] = media;
    customLists.putIfAbsent(name, () => <String>{}).add(media.id);
    await _saveData();
    notifyListeners();
  }

  Future<void> removeFromList(String name, String mediaId) async {
    final remoteId = remoteListIds[name];
    if (remoteId != null) await backend?.removeFromList(remoteId, mediaId);
    customLists[name]?.remove(mediaId);
    await _saveData();
    notifyListeners();
  }

  int get completedMovies => watchStates.entries
      .where(
        (entry) =>
            entry.value == WatchState.completed &&
            savedMedia[entry.key]?.type == 'movie',
      )
      .length;

  int get completedSeries => watchStates.entries
      .where(
        (entry) =>
            entry.value == WatchState.completed &&
            savedMedia[entry.key]?.type == 'series',
      )
      .length;

  int get totalWatchedEpisodes => watchedEpisodes.values.fold<int>(
    0,
    (total, episodes) => total + episodes.length,
  );

  int get totalWatchMinutes {
    final movieMinutes = watchStates.entries
        .where(
          (entry) =>
              entry.value == WatchState.completed &&
              savedMedia[entry.key]?.type == 'movie',
        )
        .fold<int>(
          0,
          (total, entry) =>
              total + (savedMedia[entry.key]?.runtimeMinutes ?? 0),
        );
    return movieMinutes + totalWatchedEpisodes * 45;
  }

  double get averageRating => ratings.isEmpty
      ? 0
      : ratings.values.reduce((a, b) => a + b) / ratings.length;

  String get favoriteGenre {
    final counts = <String, int>{};
    for (final entry in watchStates.entries) {
      if (entry.value != WatchState.completed &&
          entry.value != WatchState.favorite) {
        continue;
      }
      for (final genre
          in savedMedia[entry.key]?.genre?.split(',') ?? const <String>[]) {
        final normalized = genre.trim();
        if (normalized.isNotEmpty) {
          counts[normalized] = (counts[normalized] ?? 0) + 1;
        }
      }
    }
    if (counts.isEmpty) return 'نامشخص';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Future<void> _loadData() async {
    final data = await store.userData(user!.id);
    final media = (data['media'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(MediaSummary.fromJson);
    savedMedia.addEntries(media.map((item) => MapEntry(item.id, item)));
    (data['states'] as Map<String, dynamic>? ?? {}).forEach((id, value) {
      watchStates[id] = WatchState.values.byName(value as String);
    });
    (data['episodes'] as Map<String, dynamic>? ?? {}).forEach((id, value) {
      if (value is List<dynamic>) {
        watchedEpisodes[id] = value.cast<String>().toSet();
      } else if (value is int) {
        watchedEpisodes[id] = {
          for (var episode = 1; episode <= value; episode++) '1:$episode',
        };
      }
    });
    (data['ratings'] as Map<String, dynamic>? ?? {}).forEach((id, value) {
      final raw = (value as num).toDouble();
      if (raw >= 1) ratings[id] = raw.round().clamp(1, 5).toDouble();
    });
    reviews.addAll(
      (data['reviews'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Review.fromJson),
    );
    (data['lists'] as Map<String, dynamic>? ?? {}).forEach((name, value) {
      customLists[name] = (value as List<dynamic>).cast<String>().toSet();
    });
    (data['remoteListIds'] as Map<String, dynamic>? ?? {}).forEach(
      (name, value) => remoteListIds[name] = value as String,
    );
    if (backend != null) await _loadRemoteData();
  }

  Future<void> _loadRemoteData() async {
    final data = await backend!.personalData();
    for (final item in (data['watchlist'] as List<dynamic>? ?? [])) {
      final row = item as Map<String, dynamic>;
      final media = MediaSummary.fromJson(row['media'] as Map<String, dynamic>);
      savedMedia[media.id] = media;
      watchStates[media.id] = switch (row['status'] as String) {
        'WATCHING' => WatchState.watching,
        'COMPLETED' => WatchState.completed,
        'PAUSED' => WatchState.paused,
        'DROPPED' => WatchState.dropped,
        'FAVORITE' => WatchState.favorite,
        _ => WatchState.planned,
      };
      watchedEpisodes.remove(media.id);
    }
    for (final item in (data['ratings'] as List<dynamic>? ?? [])) {
      final row = item as Map<String, dynamic>;
      final media = MediaSummary.fromJson(row['media'] as Map<String, dynamic>);
      savedMedia[media.id] = media;
      ratings[media.id] = (row['value'] as num).toDouble();
    }
    final existingReviewIds = reviews.map((review) => review.id).toSet();
    for (final item in (data['comments'] as List<dynamic>? ?? [])) {
      final row = item as Map<String, dynamic>;
      if (existingReviewIds.add(row['id'] as String)) {
        reviews.add(
          Review(
            id: row['id'] as String,
            mediaId: row['mediaId'] as String,
            text: row['text'] as String,
            spoiler: row['spoiler'] as bool? ?? false,
            createdAt: DateTime.parse(row['createdAt'] as String),
            userName: user?.name,
            userAvatar: user?.avatarPath,
          ),
        );
      }
    }
    for (final item in (data['lists'] as List<dynamic>? ?? [])) {
      final row = item as Map<String, dynamic>;
      final name = row['name'] as String;
      remoteListIds[name] = row['id'] as String;
      customLists[name] = {
        for (final listItem in (row['items'] as List<dynamic>? ?? []))
          (listItem as Map<String, dynamic>)['mediaId'] as String,
      };
      for (final listItem in (row['items'] as List<dynamic>? ?? [])) {
        final itemMap = listItem as Map<String, dynamic>;
        final media = MediaSummary.fromJson(
          itemMap['media'] as Map<String, dynamic>,
        );
        savedMedia[media.id] = media;
      }
    }
    for (final item in (data['episodes'] as List<dynamic>? ?? [])) {
      final row = item as Map<String, dynamic>;
      final mediaId = row['mediaId'] as String;
      watchedEpisodes
          .putIfAbsent(mediaId, () => <String>{})
          .add('${row['season']}:${row['episode']}');
    }
  }

  Future<void> _saveData() async {
    if (user == null) return;
    await store.saveUserData(user!.id, {
      'media': savedMedia.values.map((item) => item.toJson()).toList(),
      'states': watchStates.map((id, state) => MapEntry(id, state.name)),
      'episodes': watchedEpisodes.map(
        (id, values) => MapEntry(id, values.toList()),
      ),
      'ratings': ratings,
      'reviews': reviews.map((item) => item.toJson()).toList(),
      'lists': customLists.map((name, ids) => MapEntry(name, ids.toList())),
      'remoteListIds': remoteListIds,
      'mode': AppConfig.advancedMode ? 'advanced' : 'normal',
    });
  }

  void _clearData() {
    savedMedia.clear();
    watchStates.clear();
    watchedEpisodes.clear();
    ratings.clear();
    reviews.clear();
    publicReviews.clear();
    customLists.clear();
    remoteListIds.clear();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
