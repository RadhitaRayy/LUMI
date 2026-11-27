import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/features/settings/ai_key_screen.dart';
import 'package:lumi/features/settings/devices_screen.dart';
import 'package:lumi/features/settings/settings_screen.dart';
import 'package:lumi/state/session_controller.dart';
import 'package:lumi/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  group('Settings, AI key & active devices', () {
    testWidgets('switching language updates locale, storage and Core', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 1, savedLocale: 'en');
      api.on('GET', 'me', (_) => {'user': userJson(locale: 'en')});
      api.on('GET', 'me/ai-key', (_) => {'ai_key': null});
      api.on('GET', 'devices', (_) => {
        'devices': [
          {'id': 1, 'name': 'Galaxy A56', 'is_current': true},
        ],
      });
      api.on('PATCH', 'me', (call) {
        expect(call.body?['locale'], 'id');
        return {'user': userJson(locale: 'id')};
      });

      await tester.pumpWidget(wrapFullApp(api: api, storage: storage));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CircleAvatar));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bahasa Indonesia'));
      await tester.pumpAndSettle();

      expect(storage.savedLocale, 'id');
      expect(api.locale, 'id');
      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.text('Kunci AI saya'), findsOneWidget);
      expect(api.calls.any((c) => c.method == 'PATCH' && c.path == 'me'), isTrue);
    });

    testWidgets('My AI key saves, displays only last 4 chars, and toggles on/off', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 1, savedLocale: 'en');
      var active = true;
      Map<String, dynamic>? savedKey;

      api.on('GET', 'me', (_) => {'user': userJson(aiKeySource: (savedKey != null && active) ? 'user' : 'platform')});
      api.on('GET', 'me/ai-key', (_) => {'ai_key': savedKey});
      api.on('PUT', 'me/ai-key', (call) {
        expect(call.body?['driver'], 'openrouter');
        expect(call.body?['api_key'], 'sk-or-v1-secret9876');
        expect(call.body?['model_id'], 'nvidia/nemotron:free');
        savedKey = {
          'driver': 'openrouter',
          'base_url': null,
          'model_id': 'nvidia/nemotron:free',
          'key_last4': '9876',
          'is_active': true,
          'last_validated_at': DateTime.now().toUtc().toIso8601String(),
          'last_error': null,
        };
        return {'ai_key': savedKey};
      });
      api.on('PATCH', 'me/ai-key', (call) {
        active = call.body?['is_active'] as bool;
        savedKey = {...savedKey!, 'is_active': active};
        return {'ai_key': savedKey};
      });

      await tester.pumpWidget(wrapTestApp(child: const AiKeyScreen(), api: api, storage: storage));
      await containerOf(tester).read(sessionProvider.notifier).restore();
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'sk-or-v1-secret9876');
      await tester.enterText(fields.at(1), 'nvidia/nemotron:free');
      await tester.tap(find.text('Test and save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('••••9876'), findsOneWidget);
      expect(find.text('sk-or-v1-secret9876'), findsNothing);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.text("Off · using Lumi's key"), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Active devices signs out another device after confirmation', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 1, savedLocale: 'en');
      final devices = [
        {'id': 1, 'name': 'Galaxy A56', 'is_current': true},
        {'id': 2, 'name': 'Poco X3 NFC', 'is_current': false},
      ];

      api.on('GET', 'me', (_) => {'user': userJson()});
      api.on('GET', 'devices', (_) => {'devices': devices});
      api.on('DELETE', 'devices/2', (_) {
        devices.removeWhere((d) => d['id'] == 2);
        return {};
      });

      await tester.pumpWidget(wrapTestApp(child: const DevicesScreen(), api: api, storage: storage));
      await containerOf(tester).read(sessionProvider.notifier).restore();
      await tester.pumpAndSettle();

      expect(find.text('Galaxy A56'), findsOneWidget);
      expect(find.text('Poco X3 NFC'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out Poco X3 NFC?'), findsOneWidget);
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();

      expect(find.text('Poco X3 NFC'), findsNothing);
      expect(find.text('Only this device is signed in. All good.'), findsOneWidget);
      expect(api.calls.any((c) => c.method == 'DELETE' && c.path == 'devices/2'), isTrue);

      await tester.pump(const Duration(seconds: 3));
    });
  });
}
