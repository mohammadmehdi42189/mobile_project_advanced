import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media.dart';
import '../models/user_data.dart';

class LocalStore {
  static const _passwordIterations = 20000;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  String hashPassword(String password) {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final derived = _pbkdf2(password, salt, _passwordIterations);
    return 'pbkdf2-sha256\$$_passwordIterations\$${base64UrlEncode(salt)}\$${base64UrlEncode(derived)}';
  }

  bool verifyPassword(String password, String encoded) {
    if (!encoded.startsWith('pbkdf2-sha256\$')) {
      // Backward compatibility for users created by older app versions.
      return _constantTimeEquals(
        utf8.encode(sha256.convert(utf8.encode(password)).toString()),
        utf8.encode(encoded),
      );
    }
    final parts = encoded.split(r'$');
    if (parts.length != 4) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    try {
      final salt = base64Url.decode(base64Url.normalize(parts[2]));
      final expected = base64Url.decode(base64Url.normalize(parts[3]));
      final actual = _pbkdf2(password, salt, iterations);
      return _constantTimeEquals(actual, expected);
    } on FormatException {
      return false;
    }
  }

  bool needsPasswordUpgrade(String encoded) =>
      !encoded.startsWith('pbkdf2-sha256\$');

  List<int> _pbkdf2(String password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(block);
    for (var iteration = 1; iteration < iterations; iteration++) {
      block = hmac.convert(block).bytes;
      for (var index = 0; index < result.length; index++) {
        result[index] ^= block[index];
      }
    }
    return result;
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

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

  Future<String?> session() async {
    final prefs = await _prefs;
    final raw = prefs.getString('session');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(data['expiresAt'] as String);
      if (!expiresAt.isAfter(DateTime.now())) {
        await prefs.remove('session');
        return null;
      }
      return data['userId'] as String;
    } catch (_) {
      // Legacy sessions had no expiry and cannot be trusted to satisfy the
      // project's maximum one-month session lifetime.
      await prefs.remove('session');
      return null;
    }
  }

  Future<void> saveSession(String? id, {int days = 30}) async {
    final prefs = await _prefs;
    if (id == null) {
      await prefs.remove('session');
    } else {
      final safeDays = days.clamp(1, 30).toInt();
      await prefs.setString(
        'session',
        jsonEncode({
          'userId': id,
          'expiresAt': DateTime.now()
              .add(Duration(days: safeDays))
              .toIso8601String(),
        }),
      );
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
        if (value.toDouble() < 1) continue;
        final bucket = value.toDouble().round().clamp(1, 5).toInt();
        result[bucket] = (result[bucket] ?? 0) + 1;
      }
    }
    final total = result.values.fold<int>(0, (sum, count) => sum + count);
    return {
      for (var value = 1; value <= 5; value++)
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
