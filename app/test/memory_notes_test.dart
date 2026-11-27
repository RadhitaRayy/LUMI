import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/features/agent/memory_screen.dart';
import 'package:lumi/features/agent/notes_screen.dart';
import 'package:lumi/state/realtime_controller.dart';
import 'package:lumi/state/session_controller.dart';
import 'package:lumi/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  group('Memory screen', () {
    testWidgets('lists, adds, deletes memories and syncs memory.changed realtime events', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 1, savedLocale: 'en');
      final items = <Map<String, dynamic>>[
        {'id': 'm1', 'category': 'preference', 'content': 'Drinks black coffee', 'source': 'agent'},
      ];

      api.on('GET', 'me', (_) => {'user': userJson()});
      api.on('GET', 'memories', (_) => {'data': items, 'count': items.length, 'limit': 50});
      api.on('POST', 'memories', (call) {
        final created = {
          'id': 'm2',
          'category': call.body?['category'] ?? 'fact',
          'content': call.body?['content'],
          'source': 'user',
        };
        items.insert(0, created);
        return {'data': created};
      });
      api.on('DELETE', 'memories/m1', (_) {
        items.removeWhere((m) => m['id'] == 'm1');
        return {};
      });

      await tester.pumpWidget(wrapTestApp(child: const MemoryScreen(), api: api, storage: storage));
      await containerOf(tester).read(sessionProvider.notifier).restore();
      await tester.pumpAndSettle();

      expect(find.text('Drinks black coffee'), findsOneWidget);
      expect(find.text('1/50'), findsOneWidget);

      // Add a memory manually.
      await tester.tap(find.text('Add memory'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Uses Laravel and Flutter');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Uses Laravel and Flutter'), findsOneWidget);
      expect(find.text('2/50'), findsOneWidget);

      // Realtime memory.changed from another device adds a new memory.
      containerOf(tester).read(realtimeProvider.notifier).handleEvent('memory.changed', {
        'action': 'created',
        'memory': {'id': 'm3', 'category': 'context', 'content': 'Lives in Indonesia', 'source': 'agent'},
      });
      await tester.pump();
      expect(find.text('Lives in Indonesia'), findsOneWidget);

      // Delete original memory.
      await tester.tap(find.byTooltip('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Drinks black coffee'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Notes screen', () {
    testWidgets('lists, searches, creates and deletes notes', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 1, savedLocale: 'en');
      final notes = <Map<String, dynamic>>[
        {'id': 'n1', 'title': 'VPS Checklist', 'content': 'Install Caddy and Postgres', 'tags': ['devops']},
      ];

      api.on('GET', 'me', (_) => {'user': userJson()});
      api.on('GET', 'notes', (call) {
        final q = (call.query?['q'] ?? '').toLowerCase();
        final filtered = q.isEmpty
            ? notes
            : notes.where((n) => '${n['title']} ${n['content']}'.toLowerCase().contains(q)).toList();
        return {
          'data': filtered,
          'meta': {'current_page': 1, 'last_page': 1, 'total': filtered.length},
        };
      });
      api.on('POST', 'notes', (call) {
        final created = {
          'id': 'n2',
          'title': call.body?['title'],
          'content': call.body?['content'],
          'tags': call.body?['tags'] ?? const <String>[],
        };
        notes.insert(0, created);
        return {'data': created};
      });
      api.on('DELETE', 'notes/n1', (_) {
        notes.removeWhere((n) => n['id'] == 'n1');
        return {};
      });

      await tester.pumpWidget(wrapTestApp(child: const NotesScreen(), api: api, storage: storage));
      await containerOf(tester).read(sessionProvider.notifier).restore();
      await tester.pumpAndSettle();

      expect(find.text('VPS Checklist'), findsOneWidget);
      expect(find.text('#devops'), findsOneWidget);

      // Create a note with tags.
      await tester.tap(find.text('New note'));
      await tester.pumpAndSettle();
      final sheetFields = find.byType(TextField);
      await tester.enterText(sheetFields.at(1), 'Grocery list');
      await tester.enterText(sheetFields.at(2), 'Coffee beans, milk');
      await tester.enterText(sheetFields.at(3), 'home, shop');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Grocery list'), findsOneWidget);
      expect(find.text('#home'), findsOneWidget);

      // Search filters via API.
      await tester.enterText(find.byType(TextField).first, 'Caddy');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('VPS Checklist'), findsOneWidget);
      expect(find.text('Grocery list'), findsNothing);

      // Delete VPS Checklist.
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('VPS Checklist'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
