import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  ApiException(this.message, {this.statusCode, this.errorCode});

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requireAuth) {
      final token = await AuthService.instance.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Standard GET — appends query params to URL.
  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('${ApiConstants.baseUrl}$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final response = await http
        .get(uri, headers: await _getHeaders())
        .timeout(const Duration(seconds: 30));
    return _handleResponse(response);
  }

  /// GET with a JSON body — needed for routes that use req.body on GET.
  Future<dynamic> getWithBody(String path, {Map<String, dynamic>? body}) async {
    final request = http.Request('GET', Uri.parse('${ApiConstants.baseUrl}$path'));
    request.headers.addAll(await _getHeaders());
    if (body != null) request.body = jsonEncode(body);
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConstants.baseUrl}$path'),
          headers: await _getHeaders(requireAuth: requireAuth),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 30));
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final response = await http
        .put(
          Uri.parse('${ApiConstants.baseUrl}$path'),
          headers: await _getHeaders(),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 30));
    return _handleResponse(response);
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    final request = http.Request('DELETE', Uri.parse('${ApiConstants.baseUrl}$path'));
    request.headers.addAll(await _getHeaders());
    if (body != null) request.body = jsonEncode(body);
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  /// Parses `{ success, data, message, error }` envelope.
  /// Returns `data` on success; throws [ApiException] on failure.
  dynamic _handleResponse(http.Response response) {
    dynamic json;
    if (response.body.isNotEmpty) {
      try {
        json = jsonDecode(response.body);
      } catch (_) {
        json = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Return the inner `data` field if present, else the whole body.
      if (json is Map && json.containsKey('data')) return json['data'];
      return json;
    }

    String message = 'Request failed';
    String? errorCode;
    if (json is Map) {
      message = (json['message'] ?? json['error'] ?? message).toString();
      errorCode = json['error']?.toString();
    }
    throw ApiException(message, statusCode: response.statusCode, errorCode: errorCode);
  }
}
