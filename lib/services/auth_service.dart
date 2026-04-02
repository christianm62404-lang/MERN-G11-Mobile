import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> getToken() async {
    return await _storage.read(key: StorageKeys.authToken);
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: StorageKeys.authToken, value: token);
  }

  Future<void> saveUserInfo({
    required String userId,
    required String email,
    required String firstName,
  }) async {
    await Future.wait([
      _storage.write(key: StorageKeys.userId, value: userId),
      _storage.write(key: StorageKeys.userEmail, value: email),
      _storage.write(key: StorageKeys.userFirstName, value: firstName),
    ]);
  }

  Future<Map<String, String?>> getUserInfo() async {
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
    await _storage.deleteAll();
  }

  Future<void> saveFcmToken(String fcmToken) async {
    await _storage.write(key: StorageKeys.fcmToken, value: fcmToken);
  }

  Future<String?> getFcmToken() async {
    return await _storage.read(key: StorageKeys.fcmToken);
  }
}
