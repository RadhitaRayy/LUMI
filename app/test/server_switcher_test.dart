import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/config.dart';
import 'package:lumi/core/api_client.dart';
import 'package:lumi/features/auth/login_screen.dart';
import 'package:lumi/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  testWidgets('Server switcher validates URL, probes health, saves custom server, and resets', (tester) async {
    setPhoneViewport(tester);
    final api = FakeApiClient();
    final storage = MemoryStorage(savedLocale: 'en');
    String? probed;
    api.onProbeHealth = (url) {
      if (url.contains('broken')) {
        throw ApiException(status: 500, code: 'server_invalid');
      }
      probed = url;
    };

    await tester.pumpWidget(wrapTestApp(child: const LoginScreen(), api: api, storage: storage));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Server'));
    await tester.pumpAndSettle();

    expect(find.text('Server address'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);

    // Invalid URL rejected before network call.
    await tester.enterText(find.byType(TextField).last, 'not-a-url');
    await tester.tap(find.text('Test and save'));
    await tester.pump();
    expect(find.text('Enter a valid http:// or https:// address.'), findsOneWidget);

    // Failing health probe surfaces error and does not save.
    await tester.enterText(find.byType(TextField).last, 'https://broken.example.com');
    await tester.tap(find.text('Test and save'));
    await tester.pump();
    expect(find.text('That address is not a healthy Lumi Core server.'), findsOneWidget);
    expect(storage.savedServerUrl, isNull);

    // Valid healthy tunnel URL saves and updates ApiClient.
    await tester.enterText(find.byType(TextField).last, 'https://lumi-demo.trycloudflare.com/');
    await tester.tap(find.text('Test and save'));
    await tester.pumpAndSettle();

    expect(probed, 'https://lumi-demo.trycloudflare.com');
    expect(storage.savedServerUrl, 'https://lumi-demo.trycloudflare.com');
    expect(api.baseUrl, 'https://lumi-demo.trycloudflare.com');

    // Reopen sheet -> Custom badge + Reset to default restores AppConfig.apiBaseUrl.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Server'));
    await tester.pumpAndSettle();
    expect(find.text('Custom'), findsOneWidget);

    await tester.tap(find.text('Reset to default'));
    await tester.pumpAndSettle();
    expect(storage.savedServerUrl, isNull);
    expect(api.baseUrl, AppConfig.apiBaseUrl);

    await tester.pump(const Duration(seconds: 3));
  });
}
