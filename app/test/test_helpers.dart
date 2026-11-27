import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lumi/app.dart';
import 'package:lumi/core/api_client.dart';
import 'package:lumi/core/storage.dart';
import 'package:lumi/l10n/gen/app_localizations.dart';
import 'package:lumi/state/core_providers.dart';
import 'package:lumi/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// In-memory storage so tests never touch platform keystore or SharedPreferences.
class MemoryStorage extends AppStorage {
  MemoryStorage({this.savedToken, this.savedTokenId, this.savedLocale});

  String? savedToken;
  int? savedTokenId;
  String? savedLocale;

  @override
  Future<({String token, int tokenId})?> readSession() async {
    if (savedToken == null || savedTokenId == null) return null;
    return (token: savedToken!, tokenId: savedTokenId!);
  }

  @override
  Future<void> saveSession(String token, int tokenId) async {
    savedToken = token;
    savedTokenId = tokenId;
  }

  @override
  Future<void> clearSession() async {
    savedToken = null;
    savedTokenId = null;
  }

  @override
  Future<String?> readLocale() async => savedLocale;

  @override
  Future<void> saveLocale(String? code) async => savedLocale = code;
}

typedef ApiHandler = FutureOr<Map<String, dynamic>> Function(ApiCall call);
typedef StreamHandler = FutureOr<http.StreamedResponse> Function(String path, Map<String, dynamic> body);

class ApiCall {
  const ApiCall(this.method, this.path, {this.query, this.body});

  final String method;
  final String path;
  final Map<String, String>? query;
  final Map<String, dynamic>? body;
}

/// Configurable fake [ApiClient] for widget tests.
class FakeApiClient extends ApiClient {
  FakeApiClient() : super(baseUrl: 'http://test.local');

  final List<ApiCall> calls = [];
  final Map<String, ApiHandler> _handlers = {};
  StreamHandler? onStream;

  void on(String method, String path, ApiHandler handler) {
    _handlers['${method.toUpperCase()} $path'] = handler;
  }

  Future<Map<String, dynamic>> _dispatch(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final call = ApiCall(method, path, query: query, body: body);
    calls.add(call);
    final handler = _handlers['$method $path'];
    if (handler == null) {
      throw StateError('No fake handler registered for $method $path');
    }
    return await handler(call);
  }

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _dispatch('GET', path, query: query);

  @override
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _dispatch('POST', path, body: body);

  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _dispatch('PUT', path, body: body);

  @override
  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _dispatch('PATCH', path, body: body);

  @override
  Future<Map<String, dynamic>> delete(String path) => _dispatch('DELETE', path);

  @override
  Future<http.StreamedResponse> openStream(
    http.Client client,
    String path,
    Map<String, dynamic> body,
  ) async {
    calls.add(ApiCall('STREAM', path, body: body));
    final handler = onStream;
    if (handler == null) {
      throw StateError('No fake stream handler registered for $path');
    }
    return await handler(path, body);
  }
}

Map<String, dynamic> userJson({
  int id = 1,
  String name = 'Radhita',
  String email = 'radhita@example.com',
  String locale = 'en',
  bool verified = true,
  String aiKeySource = 'platform',
  int dailyLimit = 30,
  int usedToday = 2,
  int remaining = 28,
}) => {
  'id': id,
  'name': name,
  'email': email,
  'locale': locale,
  'email_verified': verified,
  'ai_key_source': aiKeySource,
  'quota': {
    'daily_limit': dailyLimit,
    'used_today': usedToday,
    'remaining': remaining,
  },
};

Map<String, dynamic> conversationJson({
  required String id,
  String? title,
  DateTime? lastMessageAt,
  DateTime? createdAt,
}) {
  final ts = (lastMessageAt ?? DateTime.now()).toUtc().toIso8601String();
  return {
    'id': id,
    'title': title,
    'last_message_at': ts,
    'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
  };
}

Map<String, dynamic> messageJson({
  required String id,
  required String role,
  required String content,
  String status = 'complete',
}) => {
  'id': id,
  'role': role,
  'content': content,
  'status': status,
};

List<int> sseChunk(String event, Map<String, dynamic> data) =>
    utf8.encode('event: $event\ndata: ${jsonEncode(data)}\n\n');

/// Builds a test app with animations disabled so repeating indicators don't block tests.
Widget wrapTestApp({
  required Widget child,
  required FakeApiClient api,
  required MemoryStorage storage,
  Locale locale = const Locale('en'),
  String deviceName = 'Test Phone',
}) {
  AppFonts.useGoogleFonts = false;
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      storageProvider.overrideWithValue(storage),
      deviceNameProvider.overrideWith((ref) async => deviceName),
    ],
    child: MediaQuery(
      data: const MediaQueryData(size: Size(412, 915), disableAnimations: true),
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: child,
      ),
    ),
  );
}

/// Builds the full [LumiApp] routed via [AppRouter] with test overrides and reduced motion.
Widget wrapFullApp({
  required FakeApiClient api,
  required MemoryStorage storage,
  String deviceName = 'Test Phone',
}) {
  AppFonts.useGoogleFonts = false;
  AppRouter.ready = false;
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      storageProvider.overrideWithValue(storage),
      deviceNameProvider.overrideWith((ref) async => deviceName),
    ],
    child: const MediaQuery(
      data: MediaQueryData(size: Size(412, 915), disableAnimations: true),
      child: LumiApp(),
    ),
  );
}

/// Sizes the test viewport to a portrait phone so bottom sheets and forms fit on screen.
void setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp).first));
