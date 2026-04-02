import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, unverified }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final isLoggedIn = await AuthService.instance.isLoggedIn();
    if (isLoggedIn) {
      final info = await AuthService.instance.getUserInfo();
      _user = UserModel(
        id: info['userId'] ?? '',
        email: info['email'] ?? '',
        firstName: info['firstName'] ?? '',
        verified: true,
        createdAt: DateTime.now(),
      );
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.instance.post(
        ApiConstants.loginUser,
        body: {'email': email, 'password': password},
        requireAuth: false,
      );

      final token = response['token'] as String?;
      if (token == null) throw ApiException('No token received');

      final userData = response['user'] as Map<String, dynamic>?;
      if (userData != null) {
        _user = UserModel.fromJson(userData);
        await AuthService.instance.saveToken(token);
        await AuthService.instance.saveUserInfo(
          userId: _user!.id,
          email: _user!.email,
          firstName: _user!.firstName,
        );
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }

      throw ApiException('Invalid response from server');
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiService.instance.post(
        ApiConstants.createUser,
        body: {
          'email': email,
          'password': password,
          'firstName': firstName,
        },
        requireAuth: false,
      );

      _status = AuthStatus.unverified;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resendVerification(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiService.instance.post(
        ApiConstants.regenVerification,
        body: {'email': email},
        requireAuth: false,
      );
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await AuthService.instance.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
