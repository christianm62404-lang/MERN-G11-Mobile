import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
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

  /// Called before the token is cleared — use this to reset other providers.
  VoidCallback? onLogout;

  AuthProvider() {
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      final token = await AuthService.instance.getToken();
      if (token != null && token.isNotEmpty && !JwtDecoder.isExpired(token)) {
        _user = _userFromToken(token);
        _status = AuthStatus.authenticated;
      } else {
        await AuthService.instance.logout();
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  UserModel _userFromToken(String token) {
    final payload = JwtDecoder.decode(token);
    return UserModel(
      id: payload['userId']?.toString() ?? '',
      email: payload['email']?.toString() ?? '',
      firstName: payload['firstName']?.toString() ?? '',
      verified: true,
      createdAt: DateTime.now(),
    );
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await ApiService.instance.post(
        ApiConstants.loginUser,
        body: {'email': email, 'password': password},
        requireAuth: false,
      ) as Map<String, dynamic>?;

      final token = data?['token'] as String?;
      if (token == null || token.isEmpty) {
        throw ApiException('No token received');
      }

      await AuthService.instance.saveToken(token);
      _user = _userFromToken(token);
      await AuthService.instance.saveUserInfo(
        userId: _user!.id,
        email: _user!.email,
        firstName: _user!.firstName,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.errorCode == 'EMAIL_NOT_VERIFIED') {
        _status = AuthStatus.unverified;
      } else {
        _status = AuthStatus.unauthenticated;
      }
      _errorMessage = e.message;
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
        body: {'email': email, 'password': password, 'firstName': firstName},
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

  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await ApiService.instance.post(
        ApiConstants.resetPasswordRequest,
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

  Future<bool> resetPassword(String token, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await ApiService.instance.post(
        ApiConstants.resetPassword,
        body: {'token': token, 'newPassword': newPassword},
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
    onLogout?.call(); // clear other providers before wiping the token
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

  void setUnverified() {
    _status = AuthStatus.unverified;
    notifyListeners();
  }
}
