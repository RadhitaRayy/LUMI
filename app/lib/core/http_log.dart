import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A single captured HTTP or SSE exchange shown in Lumi's built-in Network Inspector.
class HttpLogEntry {
  const HttpLogEntry({
    required this.id,
    required this.startedAt,
    required this.method,
    required this.url,
    required this.isSse,
    required this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.durationMs,
    this.responseHeaders = const {},
    this.responseBody,
    this.sseEvents = const [],
    this.error,
    this.completed = false,
  });

  final int id;
  final DateTime startedAt;
  final String method;
  final String url;
  final bool isSse;
  final Map<String, String> requestHeaders;
  final String? requestBody;
  final int? statusCode;
  final int? durationMs;
  final Map<String, String> responseHeaders;
  final String? responseBody;
  final List<String> sseEvents;
  final String? error;
  final bool completed;

  bool get isError => error != null || (statusCode != null && statusCode! >= 400);

  String get path {
    final parsed = Uri.tryParse(url);
    if (parsed == null) return url;
    final query = parsed.hasQuery ? '?${parsed.query}' : '';
    return '${parsed.path}$query';
  }

  HttpLogEntry copyWith({
    int? statusCode,
    int? durationMs,
    Map<String, String>? responseHeaders,
    String? responseBody,
    List<String>? sseEvents,
    String? error,
    bool? completed,
  }) => HttpLogEntry(
    id: id,
    startedAt: startedAt,
    method: method,
    url: url,
    isSse: isSse,
    requestHeaders: requestHeaders,
    requestBody: requestBody,
    statusCode: statusCode ?? this.statusCode,
    durationMs: durationMs ?? this.durationMs,
    responseHeaders: responseHeaders ?? this.responseHeaders,
    responseBody: responseBody ?? this.responseBody,
    sseEvents: sseEvents ?? this.sseEvents,
    error: error ?? this.error,
    completed: completed ?? this.completed,
  );

  /// Formats a copyable cURL command with sensitive headers/fields already redacted.
  String toCurl() {
    final buf = StringBuffer('curl -X $method ${_shellQuote(url)}');
    for (final entry in requestHeaders.entries) {
      buf.write(' \\\n  -H ${_shellQuote('${entry.key}: ${entry.value}')}');
    }
    if (requestBody != null && requestBody!.isNotEmpty) {
      buf.write(' \\\n  -d ${_shellQuote(requestBody!)}');
    }
    return buf.toString();
  }

  static String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";
}

/// In-memory ring buffer (max 100 entries) capturing Lumi's REST & SSE traffic with automatic secret redaction.
class HttpLogStore extends ChangeNotifier {
  HttpLogStore({this.maxEntries = 100});

  final int maxEntries;
  final List<HttpLogEntry> _entries = [];
  var _nextId = 1;

  List<HttpLogEntry> get entries => List.unmodifiable(_entries);

  int get count => _entries.length;

  int get errorCount => _entries.where((e) => e.isError).length;

  int start({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    String? body,
    bool isSse = false,
  }) {
    final id = _nextId++;
    final entry = HttpLogEntry(
      id: id,
      startedAt: DateTime.now(),
      method: method.toUpperCase(),
      url: url.toString(),
      isSse: isSse,
      requestHeaders: redactHeaders(headers),
      requestBody: body == null ? null : redactBody(body),
    );
    _entries.insert(0, entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    notifyListeners();
    return id;
  }

  void finish(
    int id, {
    required int statusCode,
    required int durationMs,
    Map<String, String> responseHeaders = const {},
    String? responseBody,
    bool completed = true,
  }) {
    _update(
      id,
      (e) => e.copyWith(
        statusCode: statusCode,
        durationMs: durationMs,
        responseHeaders: redactHeaders(responseHeaders),
        responseBody: responseBody == null ? e.responseBody : redactBody(responseBody),
        completed: completed,
      ),
    );
  }

  void appendSse(int id, String line, {int? durationMs, bool completed = false}) {
    _update(
      id,
      (e) => e.copyWith(
        sseEvents: [...e.sseEvents, line],
        durationMs: durationMs ?? e.durationMs,
        completed: completed || e.completed,
      ),
    );
  }

  void fail(int id, {required int durationMs, required String error, int? statusCode, String? responseBody}) {
    _update(
      id,
      (e) => e.copyWith(
        statusCode: statusCode ?? e.statusCode,
        durationMs: durationMs,
        responseBody: responseBody == null ? e.responseBody : redactBody(responseBody),
        error: error,
        completed: true,
      ),
    );
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }

  void _update(int id, HttpLogEntry Function(HttpLogEntry) transform) {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _entries[idx] = transform(_entries[idx]);
    notifyListeners();
  }

  static const _sensitiveHeaderKeys = {'authorization', 'cookie', 'set-cookie', 'x-api-key'};
  static const _sensitiveBodyKeys = {
    'password',
    'current_password',
    'password_confirmation',
    'api_key',
    'token',
    'access_token',
    'secret',
    'web_search_api_key',
  };

  static Map<String, String> redactHeaders(Map<String, String> headers) => {
    for (final entry in headers.entries)
      entry.key: _sensitiveHeaderKeys.contains(entry.key.toLowerCase()) ? '••• (redacted)' : entry.value,
  };

  static String redactBody(String raw) {
    if (raw.trim().isEmpty) return raw;
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(_redactValue(decoded));
    } catch (_) {
      return raw.length > 8000 ? '${raw.substring(0, 8000)}\n…(truncated)' : raw;
    }
  }

  static Object? _redactValue(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          '${entry.key}': _sensitiveBodyKeys.contains('${entry.key}'.toLowerCase())
              ? '•••'
              : _redactValue(entry.value),
      };
    }
    if (value is List) {
      return [for (final item in value) _redactValue(item)];
    }
    return value;
  }
}
