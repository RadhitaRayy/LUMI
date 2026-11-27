import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_log.dart';

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
  ApiClient({required String baseUrl, http.Client? client, this.logger})
    : _base = _parseBase(baseUrl),
      _client = client ?? http.Client();

  Uri _base;
  final http.Client _client;
  final HttpLogStore? logger;

  static Uri _parseBase(String url) => Uri.parse(url.endsWith('/') ? url : '$url/');

  String get baseUrl => _base.toString().replaceFirst(RegExp(r'/$'), '');

  void setBaseUrl(String url) => _base = _parseBase(url);

  /// Checks whether [url] hosts a reachable Lumi Core instance (`/api/v1/health`).
  Future<void> probeHealth(String url) async {
    final target = _parseBase(url).resolve('api/v1/health');
    const reqHeaders = {'Accept': 'application/json'};
    final sw = Stopwatch()..start();
    final logId = logger?.start(method: 'GET', url: target, headers: reqHeaders);
    final http.Response response;
    try {
      response = await _client.get(target, headers: reqHeaders).timeout(const Duration(seconds: 10));
    } catch (e) {
      if (logId != null) logger?.fail(logId, durationMs: sw.elapsedMilliseconds, error: '$e');
      throw ApiException(status: 0, code: 'network');
    }
    final text = utf8.decode(response.bodyBytes);
    if (logId != null) {
      logger?.finish(
        logId,
        statusCode: response.statusCode,
        durationMs: sw.elapsedMilliseconds,
        responseHeaders: response.headers,
        responseBody: text,
      );
    }
    if (response.statusCode != 200) {
      throw ApiException(status: response.statusCode, code: 'server_invalid');
    }
    try {
      final decoded = jsonDecode(text);
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

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) {
    final target = uri(path, query);
    final reqHeaders = headers(json: false);
    return _send(
      method: 'GET',
      url: target,
      reqHeaders: reqHeaders,
      call: () => _client.get(target, headers: reqHeaders),
    );
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) {
    final target = uri(path);
    final reqHeaders = headers();
    final encoded = jsonEncode(body ?? {});
    return _send(
      method: 'POST',
      url: target,
      reqHeaders: reqHeaders,
      reqBody: encoded,
      call: () => _client.post(target, headers: reqHeaders, body: encoded),
    );
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) {
    final target = uri(path);
    final reqHeaders = headers();
    final encoded = jsonEncode(body);
    return _send(
      method: 'PUT',
      url: target,
      reqHeaders: reqHeaders,
      reqBody: encoded,
      call: () => _client.put(target, headers: reqHeaders, body: encoded),
    );
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) {
    final target = uri(path);
    final reqHeaders = headers();
    final encoded = jsonEncode(body);
    return _send(
      method: 'PATCH',
      url: target,
      reqHeaders: reqHeaders,
      reqBody: encoded,
      call: () => _client.patch(target, headers: reqHeaders, body: encoded),
    );
  }

  Future<Map<String, dynamic>> delete(String path) {
    final target = uri(path);
    final reqHeaders = headers(json: false);
    return _send(
      method: 'DELETE',
      url: target,
      reqHeaders: reqHeaders,
      call: () => _client.delete(target, headers: reqHeaders),
    );
  }

  /// Opens a streamed POST (SSE). The caller owns [client] and closes it to stop the stream.
  Future<http.StreamedResponse> openStream(
    http.Client client,
    String path,
    Map<String, dynamic> body,
  ) async {
    final target = uri(path);
    final reqHeaders = headers(accept: 'text/event-stream');
    final encoded = jsonEncode(body);
    final sw = Stopwatch()..start();
    final logId = logger?.start(
      method: 'POST',
      url: target,
      headers: reqHeaders,
      body: encoded,
      isSse: true,
    );

    final request = http.Request('POST', target)
      ..headers.addAll(reqHeaders)
      ..body = encoded;
    final http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(_timeout);
    } on ApiException {
      rethrow;
    } catch (e) {
      if (logId != null) logger?.fail(logId, durationMs: sw.elapsedMilliseconds, error: '$e');
      throw ApiException(status: 0, code: 'network');
    }
    if (response.statusCode >= 400) {
      final text = await response.stream.bytesToString();
      if (logId != null) {
        logger?.fail(
          logId,
          durationMs: sw.elapsedMilliseconds,
          statusCode: response.statusCode,
          responseBody: text,
          error: 'HTTP ${response.statusCode}',
        );
      }
      throw _error(response.statusCode, text);
    }

    if (logId == null || logger == null) return response;

    logger!.finish(
      logId,
      statusCode: response.statusCode,
      durationMs: sw.elapsedMilliseconds,
      responseHeaders: response.headers,
      completed: false,
    );

    final tapped = _tapSseStream(response.stream, logId: logId, stopwatch: sw);
    return http.StreamedResponse(
      tapped,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  http.ByteStream _tapSseStream(
    http.ByteStream source, {
    required int logId,
    required Stopwatch stopwatch,
  }) {
    final controller = StreamController<List<int>>();
    var buffer = '';
    var pendingEvent = '';
    var deltaChars = 0;

    void flushDeltas() {
      if (deltaChars > 0) {
        logger?.appendSse(logId, '[delta] $deltaChars chars streamed', durationMs: stopwatch.elapsedMilliseconds);
        deltaChars = 0;
      }
    }

    void processChunk(List<int> chunk) {
      buffer += utf8.decode(chunk, allowMalformed: true);
      var idx = buffer.indexOf('\n');
      while (idx != -1) {
        final line = buffer.substring(0, idx).replaceAll('\r', '');
        buffer = buffer.substring(idx + 1);
        if (line.startsWith('event:')) {
          pendingEvent = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final rawData = line.substring(5).trim();
          if (pendingEvent == 'delta') {
            try {
              final decoded = jsonDecode(rawData);
              if (decoded is Map && decoded['text'] is String) {
                deltaChars += (decoded['text'] as String).length;
              }
            } catch (_) {}
          } else if (pendingEvent.isNotEmpty) {
            flushDeltas();
            final compact = rawData.length > 260 ? '${rawData.substring(0, 260)}…' : rawData;
            logger?.appendSse(logId, '[$pendingEvent] $compact', durationMs: stopwatch.elapsedMilliseconds);
          }
        } else if (line.isEmpty) {
          pendingEvent = '';
        }
        idx = buffer.indexOf('\n');
      }
    }

    source.listen(
      (chunk) {
        processChunk(chunk);
        if (!controller.isClosed) controller.add(chunk);
      },
      onError: (Object error, StackTrace stack) {
        flushDeltas();
        logger?.fail(logId, durationMs: stopwatch.elapsedMilliseconds, error: '$error');
        if (!controller.isClosed) controller.addError(error, stack);
      },
      onDone: () {
        flushDeltas();
        logger?.appendSse(
          logId,
          '[stream closed]',
          durationMs: stopwatch.elapsedMilliseconds,
          completed: true,
        );
        if (!controller.isClosed) controller.close();
      },
      cancelOnError: false,
    );

    return http.ByteStream(controller.stream);
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required Uri url,
    required Map<String, String> reqHeaders,
    String? reqBody,
    required Future<http.Response> Function() call,
  }) async {
    final sw = Stopwatch()..start();
    final logId = logger?.start(method: method, url: url, headers: reqHeaders, body: reqBody);
    final http.Response response;
    try {
      response = await call().timeout(_timeout);
    } catch (e) {
      if (logId != null) logger?.fail(logId, durationMs: sw.elapsedMilliseconds, error: '$e');
      throw ApiException(status: 0, code: 'network');
    }
    final text = response.bodyBytes.isEmpty ? '' : utf8.decode(response.bodyBytes);
    if (logId != null) {
      logger?.finish(
        logId,
        statusCode: response.statusCode,
        durationMs: sw.elapsedMilliseconds,
        responseHeaders: response.headers,
        responseBody: text,
      );
    }
    if (response.statusCode >= 400) {
      throw _error(response.statusCode, text);
    }
    if (text.isEmpty) return const {};
    final decoded = jsonDecode(text);
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
