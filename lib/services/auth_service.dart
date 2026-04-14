// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<SharedPreferences> get _prefs async =>
      SharedPreferences.getInstance();

  Future<String?> getToken() async {
    if (kIsWeb) {
      final prefs = await _prefs;
      return prefs.getString(StorageKeys.authToken);
    }
    return _storage.read(key: StorageKeys.authToken);
  }

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      final prefs = await _prefs;
      await prefs.setString(StorageKeys.authToken, token);
      return;
    }
    await _storage.write(key: StorageKeys.authToken, value: token);
  }

  Future<void> saveUserInfo({
    required String userId,
    required String email,
    required String firstName,
  }) async {
    if (kIsWeb) {
      final prefs = await _prefs;
      await Future.wait([
        prefs.setString(StorageKeys.userId, userId),
        prefs.setString(StorageKeys.userEmail, email),
        prefs.setString(StorageKeys.userFirstName, firstName),
      ]);
      return;
    }
    await Future.wait([
      _storage.write(key: StorageKeys.userId, value: userId),
      _storage.write(key: StorageKeys.userEmail, value: email),
      _storage.write(key: StorageKeys.userFirstName, value: firstName),
    ]);
  }

  Future<Map<String, String?>> getUserInfo() async {
    if (kIsWeb) {
      final prefs = await _prefs;
      return {
        'userId': prefs.getString(StorageKeys.userId),
        'email': prefs.getString(StorageKeys.userEmail),
        'firstName': prefs.getString(StorageKeys.userFirstName),
      };
    }
    final results = await Future.wait([
      _storage.read(key: StorageKeys.userId),
      _storage.read(key: StorageKeys.userEmail),
      _storage.read(key: StorageKeys.userFirstName),
    ]);
    return {
      'userId': results[0],
      'email': results[1],
      'firstName': results[2],
    };
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    if (kIsWeb) {
      final prefs = await _prefs;
      await prefs.remove(StorageKeys.authToken);
      await prefs.remove(StorageKeys.userId);
      await prefs.remove(StorageKeys.userEmail);
      await prefs.remove(StorageKeys.userFirstName);
      await prefs.remove(StorageKeys.fcmToken);
      return;
    }
    await _storage.deleteAll();
  }

  Future<void> saveFcmToken(String fcmToken) async {
    if (kIsWeb) {
      final prefs = await _prefs;
      await prefs.setString(StorageKeys.fcmToken, fcmToken);
      return;
    }
    await _storage.write(key: StorageKeys.fcmToken, value: fcmToken);
  }

  Future<String?> getFcmToken() async {
    if (kIsWeb) {
      final prefs = await _prefs;
      return prefs.getString(StorageKeys.fcmToken);
    }
    return _storage.read(key: StorageKeys.fcmToken);
  }
}