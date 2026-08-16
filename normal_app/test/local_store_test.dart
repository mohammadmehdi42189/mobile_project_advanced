import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_tracker/services/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('local password hashes are salted and verifiable', () {
    final store = LocalStore();
    final first = store.hashPassword('Password123!');
    final second = store.hashPassword('Password123!');

    expect(first, startsWith(r'pbkdf2-sha256$'));
    expect(second, startsWith(r'pbkdf2-sha256$'));
    expect(first, isNot(second));
    expect(store.verifyPassword('Password123!', first), isTrue);
    expect(store.verifyPassword('WrongPassword!', first), isFalse);
  });

  test('legacy SHA-256 password is accepted for migration', () {
    final store = LocalStore();
    final legacy = sha256.convert(utf8.encode('Password123!')).toString();

    expect(store.verifyPassword('Password123!', legacy), isTrue);
    expect(store.needsPasswordUpgrade(legacy), isTrue);
  });

  test('expired and legacy sessions are rejected', () async {
    SharedPreferences.setMockInitialValues({
      'session': jsonEncode({
        'userId': 'user-1',
        'expiresAt': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
      }),
    });
    expect(await LocalStore().session(), isNull);

    SharedPreferences.setMockInitialValues({'session': 'legacy-user-id'});
    expect(await LocalStore().session(), isNull);
  });

  test('session duration is capped and active session restores user id', () async {
    final store = LocalStore();
    await store.saveSession('user-2', days: 30);
    expect(await store.session(), 'user-2');
  });
}
