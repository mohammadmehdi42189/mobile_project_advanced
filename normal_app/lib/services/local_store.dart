import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media.dart';
import '../models/user_data.dart';

class LocalStore {
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  String hashPassword(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  Future<List<LocalUser>> users() async {
    final raw = (await _prefs).getString('users');
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(LocalUser.fromJson)
        .toList();
  }

  Future<void> saveUsers(List<LocalUser> users) async {
    await (await _prefs).setString(
      'users',
      jsonEncode(users.map((item) => item.toJson()).toList()),
    );
  }

  Future<String?> session() async => (await _prefs).getString('session');

  Future<void> saveSession(String? id) async {
    final prefs = await _prefs;
    if (id == null) {
      await prefs.remove('session');
    } else {
      await prefs.setString('session', id);
    }
  }

  Future<Map<String, dynamic>> userData(String userId) async {
    final raw = (await _prefs).getString('data_$userId');
    return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveUserData(String userId, Map<String, dynamic> data) async {
    await (await _prefs).setString('data_$userId', jsonEncode(data));
  }

  Future<List<MediaSummary>> cachedSearch(String query) async {
    final raw = (await _prefs).getString('search_${query.toLowerCase()}');
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MediaSummary.fromJson)
        .toList();
  }

  Future<void> cacheSearch(String query, List<MediaSummary> items) async {
    await (await _prefs).setString(
      'search_${query.toLowerCase()}',
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<Map<int, double>> ratingDistribution(String mediaId) async {
    final result = <int, int>{};
    for (final user in await users()) {
      final data = await userData(user.id);
      final value = (data['ratings'] as Map<String, dynamic>? ?? {})[mediaId];
      if (value is num) {
        final bucket = (value.toDouble() * 2).round().clamp(1, 10).toInt();
        result[bucket] = (result[bucket] ?? 0) + 1;
      }
    }
    final total = result.values.fold<int>(0, (sum, count) => sum + count);
    return {
      for (var value = 1; value <= 10; value++)
        value: total == 0 ? 0 : (result[value] ?? 0) * 100 / total,
    };
  }

  Future<List<Review>> reviewsForMedia(String mediaId) async {
    final result = <Review>[];
    for (final user in await users()) {
      final data = await userData(user.id);
      final reviews = (data['reviews'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Review.fromJson)
          .where((review) => review.mediaId == mediaId);
      result.addAll(
        reviews.map(
          (review) => Review(
            id: review.id,
            mediaId: review.mediaId,
            text: review.text,
            createdAt: review.createdAt,
            spoiler: review.spoiler,
            userName: user.name,
            userAvatar: user.avatarPath,
          ),
        ),
      );
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }
}
