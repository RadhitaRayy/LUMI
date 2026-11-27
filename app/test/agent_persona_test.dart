import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/features/agent/agent_screen.dart';
import 'package:lumi/features/agent/persona_screen.dart';
import 'package:lumi/state/persona_controller.dart';
import 'package:lumi/state/realtime_controller.dart';
import 'package:lumi/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  Map<String, dynamic> personaPayload({
    String preset = 'santai',
    String? callMe,
    String? customInstructions,
    bool isActive = true,
  }) => {
    'persona': {
      'preset': preset,
      'call_me': callMe,
      'custom_instructions': customInstructions,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    },
    'presets': [
      {'id': 'santai', 'name': 'Friendly', 'description': 'Warm, casual tone.'},
      {'id': 'coding', 'name': 'Coding Partner', 'description': 'Direct, code-first answers.'},
      {'id': 'custom', 'name': 'Custom', 'description': 'Write your own rules.'},
    ],
  };

  testWidgets('Drawer opens Agent hub -> Persona, saves changes and syncs via realtime', (tester) async {
    setPhoneViewport(tester);
    final api = FakeApiClient();
    final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 1, savedLocale: 'en');
    var current = personaPayload();

    api.on('GET', 'me', (_) => {'user': userJson(verified: true)});
    api.on('GET', 'conversations', (_) => {'data': const <dynamic>[], 'meta': {'current_page': 1, 'last_page': 1}});
    api.on('GET', 'me/persona', (_) => current);
    api.on('PUT', 'me/persona', (call) {
      expect(call.body?['preset'], 'coding');
      expect(call.body?['call_me'], 'Captain');
      expect(call.body?['custom_instructions'], 'Prefer Dart examples.');
      expect(call.body?['is_active'], true);
      current = personaPayload(
        preset: 'coding',
        callMe: 'Captain',
        customInstructions: 'Prefer Dart examples.',
        isActive: true,
      );
      return current;
    });

    await tester.pumpWidget(wrapFullApp(api: api, storage: storage));
    await tester.pumpAndSettle();

    // Open left drawer -> tap Agent.
    await tester.tap(find.byTooltip('Chat history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agent'));
    await tester.pumpAndSettle();

    expect(find.byType(AgentScreen), findsOneWidget);
    expect(find.text('Friendly'), findsOneWidget);

    // Open Persona screen, switch preset to Coding Partner, fill fields and save.
    await tester.tap(find.text('Persona'));
    await tester.pumpAndSettle();

    expect(find.byType(PersonaScreen), findsOneWidget);
    await tester.tap(find.text('Coding Partner'));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Captain');
    await tester.enterText(fields.at(1), 'Prefer Dart examples.');
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Persona saved'), findsOneWidget);
    expect(api.calls.any((c) => c.method == 'PUT' && c.path == 'me/persona'), isTrue);

    // Drain toast timer and verify realtime persona.updated syncs provider state.
    await tester.pump(const Duration(seconds: 3));
    final container = containerOf(tester);
    container.read(realtimeProvider.notifier).handleEvent('persona.updated', {
      'persona': {
        'preset': 'custom',
        'call_me': 'Boss',
        'custom_instructions': 'Short replies.',
        'is_active': false,
      },
    });
    await tester.pump();

    final synced = container.read(personaProvider).value!.persona;
    expect(synced.preset, 'custom');
    expect(synced.callMe, 'Boss');
    expect(synced.isActive, isFalse);
  });
}
