import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// An error from Lumi Core (`{code, message, ...}`) or from the network (`code: network`).
class ApiException implements Exception {
  ApiException({
    required this.status,
    required this.code,
    this.message = '',
    this.fieldErrors = const {},
    this.body = const {},
  });

  /// HTTP status, or 0 when the server could not be reached.
  final int status;
  final String code;

  /// Already in the user's language (Core follows `Accept-Language`); a fallback for unknown codes.
  final String message;
  final Map<String, List<String>> fieldErrors;
  final Map<String, dynamic> body;

  bool get isNetwork => code == 'network';

  String? fieldError(String field) => fieldErrors[field]?.firstOrNull;

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

/// Small JSON client for `/api/v1`. Holds the device token, the language and the Reverb socket id.
class ApiClient {
  ApiClient({required String baseUrl, http.Client? client})
    : _base = _parseBase(baseUrl),
      _client = client ?? http.Client();

  Uri _base;
  final http.Client _client;

  static Uri _parseBase(String url) => Uri.parse(url.endsWith('/') ? url : '$url/');

  String get baseUrl => _base.toString().replaceFirst(RegExp(r'/$'), '');

  void setBaseUrl(String url) => _base = _parseBase(url);

  /// Checks whether [url] hosts a reachable Lumi Core instance (`/api/v1/health`).
  Future<void> probeHealth(String url) async {
    final target = _parseBase(url).resolve('api/v1/health');
    final http.Response response;
    try {
      response = await _client
          .get(target, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw ApiException(status: 0, code: 'network');
    }
    if (response.statusCode != 200) {
      throw ApiException(status: response.statusCode, code: 'server_invalid');
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['status'] != 'ok') {
        throw ApiException(status: response.statusCode, code: 'server_invalid');
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(status: response.statusCode, code: 'server_invalid');
    }
  }

  String? token;

  /// Sent as `Accept-Language` so errors, validation and emails come back in this language.
  String locale = 'en';

  /// Reverb socket id, so this device does not get its own realtime events back.
  String? socketId;

  /// Called when a signed-in request gets 401: the token was revoked somewhere else.
  void Function()? onUnauthenticated;

  static const _timeout = Duration(seconds: 30);

  Uri uri(String path, [Map<String, String>? query]) {
    final resolved = _base.resolve('api/v1/$path');
    return query == null || query.isEmpty
        ? resolved
        : resolved.replace(queryParameters: query);
  }

  Map<String, String> headers({bool json = true, String accept = 'application/json'}) => {
    'Accept': accept,
    'Accept-Language': locale,
    if (json) 'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
    'X-Socket-ID': ?socketId,
  };

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send(() => _client.get(uri(path, query), headers: headers(json: false)));

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _send(() => _client.post(uri(path), headers: headers(), body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _send(() => _client.put(uri(path), headers: headers(), body: jsonEncode(body)));

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _send(() => _client.patch(uri(path), headers: headers(), body: jsonEncode(body)));

  Future<Map<String, dynamic>> delete(String path) =>
      _send(() => _client.delete(uri(path), headers: headers(json: false)));

  /// Opens a streamed POST (SSE). The caller owns [client] and closes it to stop the stream.
  Future<http.StreamedResponse> openStream(
    http.Client client,
    String path,
    Map<String, dynamic> body,
  ) async {
    final request = http.Request('POST', uri(path))
      ..headers.addAll(headers(accept: 'text/event-stream'))
      ..body = jsonEncode(body);
    final http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(_timeout);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(status: 0, code: 'network');
    }
    if (response.statusCode >= 400) {
      final text = await response.stream.bytesToString();
      throw _error(response.statusCode, text);
    }
    return response;
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    final http.Response response;
    try {
      response = await call().timeout(_timeout);
    } catch (_) {
      throw ApiException(status: 0, code: 'network');
    }
    if (response.statusCode >= 400) {
      throw _error(response.statusCode, utf8.decode(response.bodyBytes));
    }
    if (response.bodyBytes.isEmpty) return const {};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  ApiException _error(int status, String text) {
    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    final code = body['code'] as String? ?? (status == 401 ? 'unauthenticated' : 'http_$status');
    if (code == 'unauthenticated' && token != null) onUnauthenticated?.call();

    final errors = <String, List<String>>{};
    final raw = body['errors'];
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is List) errors['$key'] = value.map((e) => '$e').toList();
      });
    }
    return ApiException(
      status: status,
      code: code,
      message: body['message'] as String? ?? '',
      fieldErrors: errors,
      body: body,
    );
  }
}
