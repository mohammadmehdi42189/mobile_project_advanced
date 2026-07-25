import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/media.dart';
import '../models/user_data.dart';
import '../services/local_store.dart';
import '../services/omdb_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.store, this.api);

  final LocalStore store;
  final OmdbService api;
  LocalUser? user;
  bool guestMode = false;
  bool initialized = false;
  bool busy = false;
  String? error;
  List<MediaSummary> searchResults = [];
  int searchTotal = 0;
  final Map<String, MediaSummary> savedMedia = {};
  final Map<String, WatchState> watchStates = {};
  final Map<String, int> watchedEpisodes = {};
  final Map<String, double> ratings = {};
  final List<Review> reviews = [];
  final Map<String, Set<String>> customLists = {};
  Timer? _searchTimer;

  Future<void> initialize() async {
    final users = await store.users();
    final sessionId = await store.session();
    user = users.where((item) => item.id == sessionId).firstOrNull;
    if (user != null) await _loadData();
    initialized = true;
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    final users = await store.users();
    final normalized = email.trim().toLowerCase();
    if (users.any((item) => item.email == normalized)) {
      throw StateError('این ایمیل قبلاً ثبت شده است.');
    }
    user = LocalUser(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      email: normalized,
      passwordHash: store.hashPassword(password),
    );
    await store.saveUsers([...users, user!]);
    await store.saveSession(user!.id);
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

  Future<void> login(String email, String password) async {
    final users = await store.users();
    final hash = store.hashPassword(password);
    user = users
        .where((item) => item.email == email.trim().toLowerCase() && item.passwordHash == hash)
        .firstOrNull;
    if (user == null) throw StateError('ایمیل یا رمز عبور نادرست است.');
    await store.saveSession(user!.id);
    await _loadData();
    notifyListeners();
  }

  Future<void> logout() async {
    await store.saveSession(null);
    user = null;
    guestMode = false;
    _clearData();
    notifyListeners();
  }

  Future<void> resetPassword(String email, String newPassword) async {
    final users = await store.users();
    final normalized = email.trim().toLowerCase();
    if (!users.any((item) => item.email == normalized)) {
      throw StateError('حسابی با این ایمیل وجود ندارد.');
    }
    await store.saveUsers([
      for (final item in users)
        if (item.email == normalized)
          LocalUser(
            id: item.id,
            name: item.name,
            email: item.email,
            passwordHash: store.hashPassword(newPassword),
            bio: item.bio,
            avatarPath: item.avatarPath,
          )
        else
          item,
    ]);
  }

  Future<void> updateProfile(String name, String bio) async {
    final users = await store.users();
    user = user!.copyWith(name: name.trim(), bio: bio.trim());
    await store.saveUsers([
      for (final item in users) if (item.id == user!.id) user! else item,
    ]);
    notifyListeners();
  }

  void debouncedSearch(String query) {
    _searchTimer?.cancel();
    if (query.trim().length < 2) {
      searchResults = [];
      notifyListeners();
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 450), () => search(query));
  }

  Future<void> search(String query, {int page = 1}) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.search(query.trim(), page: page);
      searchResults = result.items;
      searchTotal = result.total;
      await store.cacheSearch(query, result.items);
    } on MovieServiceException catch (exception) {
      final cached = await store.cachedSearch(query);
      searchResults = cached;
      error = cached.isEmpty ? exception.message : 'نتایج ذخیره‌شده نمایش داده می‌شوند.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> setWatchState(MediaSummary media, WatchState state) async {
    savedMedia[media.id] = media;
    watchStates[media.id] = state;
    await _saveData();
    notifyListeners();
  }

  Future<void> toggleEpisode(MediaSummary media, int episode) async {
    savedMedia[media.id] = media;
    watchedEpisodes[media.id] =
        watchedEpisodes[media.id] == episode ? episode - 1 : episode;
    watchStates[media.id] = WatchState.watching;
    await _saveData();
    notifyListeners();
  }

  Future<void> rate(MediaSummary media, double value) async {
    savedMedia[media.id] = media;
    ratings[media.id] = value;
    await _saveData();
    notifyListeners();
  }

  Future<void> addReview(String mediaId, String text, bool spoiler) async {
    reviews.add(Review(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      mediaId: mediaId,
      text: text.trim(),
      spoiler: spoiler,
      createdAt: DateTime.now(),
    ));
    await _saveData();
    notifyListeners();
  }

  Future<void> createList(String name) async {
    customLists.putIfAbsent(name.trim(), () => <String>{});
    await _saveData();
    notifyListeners();
  }

  Future<void> addToList(String name, MediaSummary media) async {
    savedMedia[media.id] = media;
    customLists.putIfAbsent(name, () => <String>{}).add(media.id);
    await _saveData();
    notifyListeners();
  }

  int get completedMovies => watchStates.entries
      .where((entry) =>
          entry.value == WatchState.completed && savedMedia[entry.key]?.type == 'movie')
      .length;

  int get completedSeries => watchStates.entries
      .where((entry) =>
          entry.value == WatchState.completed && savedMedia[entry.key]?.type == 'series')
      .length;

  double get averageRating => ratings.isEmpty
      ? 0
      : ratings.values.reduce((a, b) => a + b) / ratings.length;

  String? get favoriteGenre => null;

  Future<void> _loadData() async {
    final data = await store.userData(user!.id);
    final media = (data['media'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(MediaSummary.fromJson);
    savedMedia.addEntries(media.map((item) => MapEntry(item.id, item)));
    (data['states'] as Map<String, dynamic>? ?? {}).forEach((id, value) {
      watchStates[id] = WatchState.values.byName(value as String);
    });
    (data['episodes'] as Map<String, dynamic>? ?? {})
        .forEach((id, value) => watchedEpisodes[id] = value as int);
    (data['ratings'] as Map<String, dynamic>? ?? {})
        .forEach((id, value) => ratings[id] = (value as num).toDouble());
    reviews.addAll((data['reviews'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Review.fromJson));
    (data['lists'] as Map<String, dynamic>? ?? {}).forEach((name, value) {
      customLists[name] = (value as List<dynamic>).cast<String>().toSet();
    });
  }

  Future<void> _saveData() async {
    if (user == null) return;
    await store.saveUserData(user!.id, {
      'media': savedMedia.values.map((item) => item.toJson()).toList(),
      'states': watchStates.map((id, state) => MapEntry(id, state.name)),
      'episodes': watchedEpisodes,
      'ratings': ratings,
      'reviews': reviews.map((item) => item.toJson()).toList(),
      'lists': customLists.map((name, ids) => MapEntry(name, ids.toList())),
    });
  }

  void _clearData() {
    savedMedia.clear();
    watchStates.clear();
    watchedEpisodes.clear();
    ratings.clear();
    reviews.clear();
    customLists.clear();
  }
}
