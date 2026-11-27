import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumi/core/api_client.dart';
import 'package:lumi/core/http_log.dart';
import 'package:lumi/features/settings/network_log_screen.dart';
import 'package:lumi/state/core_providers.dart';
import 'package:lumi/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  test('HttpLogStore captures requests and automatically redacts tokens, passwords and API keys', () async {
    final store = HttpLogStore();
    final mockHttp = MockClient((request) async {
      return http.Response(
        jsonEncode({'token': 'secret-bearer-value', 'user': {'name': 'Radhita'}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = ApiClient(baseUrl: 'https://api.lumi.test', client: mockHttp, logger: store)
      ..token = 'live-sanctum-token';

    await client.post('auth/login', {
      'email': 'radhita@example.com',
      'password': 'super-secret-password',
      'api_key': 'sk-or-v1-secret',
    });

    expect(store.count, 1);
    final entry = store.entries.first;
    expect(entry.method, 'POST');
    expect(entry.statusCode, 200);
    expect(entry.requestHeaders['Authorization'], '••• (redacted)');
    expect(entry.requestBody, isNot(contains('super-secret-password')));
    expect(entry.requestBody, isNot(contains('sk-or-v1-secret')));
    expect(entry.responseBody, isNot(contains('secret-bearer-value')));
    expect(entry.toCurl(), isNot(contains('live-sanctum-token')));
  });

  testWidgets('NetworkLogScreen lists captured REST & SSE entries, filters and opens detail tabs', (tester) async {
    setPhoneViewport(tester);
    final api = FakeApiClient();
    final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 1, savedLocale: 'en');

    await tester.pumpWidget(wrapTestApp(child: const NetworkLogScreen(), api: api, storage: storage));
    final store = containerOf(tester).read(httpLogStoreProvider);

    final id1 = store.start(
      method: 'GET',
      url: Uri.parse('https://api.lumi.test/api/v1/health'),
      headers: const {'Accept': 'application/json'},
    );
    store.finish(id1, statusCode: 200, durationMs: 42, responseBody: '{"status":"ok"}');

    final id2 = store.start(
      method: 'POST',
      url: Uri.parse('https://api.lumi.test/api/v1/conversations/c1/messages'),
      headers: const {'Authorization': 'Bearer secret-token'},
      body: '{"content":"Hi Lumi"}',
      isSse: true,
    );
    store.finish(id2, statusCode: 200, durationMs: 120, completed: false);
    store.appendSse(id2, '[tool.start] {"tool":"get_time"}', durationMs: 180);
    store.appendSse(id2, '[delta] 24 chars streamed', durationMs: 260, completed: true);

    await tester.pumpAndSettle();

    expect(find.text('/api/v1/health'), findsOneWidget);
    expect(find.text('/api/v1/conversations/c1/messages'), findsOneWidget);
    expect(find.text('SSE'), findsWidgets);

    // Filter by SSE hides the REST entry.
    await tester.tap(find.widgetWithText(ChoiceChip, 'SSE'));
    await tester.pumpAndSettle();
    expect(find.text('/api/v1/health'), findsNothing);
    expect(find.text('/api/v1/conversations/c1/messages'), findsOneWidget);

    // Open detail view and inspect Response SSE events.
    await tester.tap(find.text('/api/v1/conversations/c1/messages'));
    await tester.pumpAndSettle();
    expect(find.text('Copy cURL'), findsOneWidget);

    await tester.tap(find.text('Response'));
    await tester.pumpAndSettle();
    expect(find.textContaining('[tool.start]'), findsOneWidget);
  });
}
