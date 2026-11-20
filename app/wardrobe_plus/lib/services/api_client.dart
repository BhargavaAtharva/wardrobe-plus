import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

/// A problem talking to the backend, with a message that is safe to show users.
class ApiException implements Exception {
  final String message;
  final bool serverUnreachable;
  final bool unauthorized;
  ApiException(this.message, {this.serverUnreachable = false, this.unauthorized = false});
  @override
  String toString() => message;
}

class ApiClient {
  /// Sign-in token sent with every request (set by UserProfile).
  static String? token;

  /// Called when the server says the token is no longer valid (e.g. signed
  /// out elsewhere or the account was removed). main.dart sends the user to sign in.
  static void Function()? onUnauthorized;

  static Map<String, String> _headers({bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static String _unreachable() =>
      'Can\'t reach the Wardrobe+ server at ${AppConfig.baseUrl}. Make sure backend/start.sh '
      'is running and the phone is on the same Wi-Fi, or change the address in Profile → Server address.';

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('The server took too long to answer. Try again.', serverUnreachable: true);
    } on SocketException {
      throw ApiException(_unreachable(), serverUnreachable: true);
    } on http.ClientException {
      throw ApiException(_unreachable(), serverUnreachable: true);
    } on FormatException {
      throw ApiException('The server sent back something unexpected. Is the address correct?');
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final body = json.decode(response.body);
    if (body is! Map<String, dynamic>) throw const FormatException();
    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException(body['message'] as String? ?? 'Please sign in again.', unauthorized: true);
    }
    if (response.statusCode >= 400 && response.statusCode != 422) {
      throw ApiException(body['message'] as String? ?? 'Server error (${response.statusCode}).');
    }
    return body;
  }

  // ---------------- Accounts ----------------

  static Future<Map<String, dynamic>> _authPost(String path, Map<String, dynamic> body) => _guard(() async {
        final response = await http
            .post(Uri.parse('${AppConfig.baseUrl}$path'), headers: _headers(json: true), body: json.encode(body))
            .timeout(const Duration(seconds: 15));
        final decoded = json.decode(response.body);
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        if (response.statusCode >= 400) {
          throw ApiException(decoded['message'] as String? ?? 'Sign-in failed (${response.statusCode}).');
        }
        return decoded;
      });

  /// Returns {token, user: {id, email, name, created_at}}.
  static Future<Map<String, dynamic>> login(String email, String password) =>
      _authPost('/auth/login', {'email': email, 'password': password});

  static Future<Map<String, dynamic>> register(String name, String email, String password) =>
      _authPost('/auth/register', {'name': name, 'email': email, 'password': password});

  static Future<void> logout() async {
    try {
      await _authPost('/auth/logout', {});
    } on ApiException {
      // Signing out locally still works if the server can't be reached.
    }
  }

  /// Checks the server; returns the model's class names.
  static Future<List<String>> health({String? baseUrl}) => _guard(() async {
        final response = await http
            .get(Uri.parse('${baseUrl ?? AppConfig.baseUrl}/health'))
            .timeout(const Duration(seconds: 6));
        final body = _decode(response);
        return List<String>.from(body['classes'] as List? ?? const []);
      });

  /// Background removal + type + colour for one photo.
  /// First call after the server starts can be slow; busy backgrounds use a
  /// slower but more accurate cut-out model (~15s).
  static Future<Map<String, dynamic>> classify(File image) => _guard(() async {
        final request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/classify'))
          ..headers.addAll(_headers())
          ..files.add(await http.MultipartFile.fromPath('image', image.path));
        final streamed = await request.send().timeout(const Duration(seconds: 90));
        return _decode(await http.Response.fromStream(streamed));
      });

  /// Ranks the pants that go with a top (or the tops that go with pants).
  /// Returns 'matches' or a map with 'error' and 'message'.
  static Future<Map<String, dynamic>> match({
    required int anchorId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> history,
    String? occasion,
  }) =>
      _guard(() async {
        final response = await http
            .post(
              Uri.parse('${AppConfig.baseUrl}/match'),
              headers: _headers(json: true),
              body: json.encode({'anchor_id': anchorId, 'items': items, 'history': history, 'occasion': occasion}),
            )
            .timeout(const Duration(seconds: 20));
        return _decode(response);
      });

  /// Best outfit for the occasion. Returns either a suggestion or a map with
  /// 'error' and 'message' (e.g. closet is missing pants).
  static Future<Map<String, dynamic>> suggest({
    required List<Map<String, dynamic>> items,
    required String occasion,
    required List<Map<String, dynamic>> history,
    required List<String> excludeKeys,
  }) =>
      _guard(() async {
        final response = await http
            .post(
              Uri.parse('${AppConfig.baseUrl}/suggest'),
              headers: _headers(json: true),
              body: json.encode({
                'items': items,
                'occasion': occasion,
                'history': history,
                'exclude_keys': excludeKeys,
              }),
            )
            .timeout(const Duration(seconds: 20));
        return _decode(response);
      });
}
