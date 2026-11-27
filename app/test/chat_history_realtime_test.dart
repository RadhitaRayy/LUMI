import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lumi/core/api_client.dart';
import 'package:lumi/data/models.dart';
import 'package:lumi/features/auth/login_screen.dart';
import 'package:lumi/features/chat/chat_screen.dart';
import 'package:lumi/features/chat/chat_widgets.dart';
import 'package:lumi/features/history/history_drawer.dart';
import 'package:lumi/state/chat_controller.dart';
import 'package:lumi/state/conversations_controller.dart';
import 'package:lumi/state/realtime_controller.dart';
import 'package:lumi/state/session_controller.dart';
import 'package:lumi/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  group('Streaming chat', () {
    testWidgets('streams SSE deltas live and updates quota after completion', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 5, savedLocale: 'en');
      var remaining = 28;
      api.on('GET', 'me', (_) => {'user': userJson(verified: true, remaining: remaining)});
      api.on('POST', 'conversations', (_) => {'data': conversationJson(id: 'conv-1')});

      final sse = StreamController<List<int>>();
      api.onStream = (path, body) {
        expect(path, 'conversations/conv-1/messages');
        expect(body['content'], 'Hello Lumi');
        return http.StreamedResponse(sse.stream, 200);
      };

      await tester.pumpWidget(wrapFullApp(api: api, storage: storage));
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('28 messages left today'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hello Lumi');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      // User message and typing indicator appear while waiting for the first delta.
      expect(find.text('Hello Lumi'), findsWidgets);
      expect(find.byType(TypingDots), findsOneWidget);

      sse.add(sseChunk('message.start', {
        'message_id': 'msg-bot-1',
        'user_message_id': 'msg-user-1',
        'model': 'nvidia/nemotron',
        'key_source': 'platform',
      }));
      sse.add(sseChunk('delta', {'text': 'Halo '}));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Halo'), findsOneWidget);

      sse.add(sseChunk('delta', {'text': 'dunia!'}));
      remaining = 27;
      sse.add(sseChunk('message.end', {'message_id': 'msg-bot-1', 'input_tokens': 10, 'output_tokens': 5}));
      await sse.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Halo dunia!'), findsOneWidget);
      expect(find.text('27 messages left today'), findsOneWidget);
      expect(containerOf(tester).read(chatProvider).streaming, isFalse);
    });

    testWidgets('shows quota dialog when Core returns 429 quota_exceeded', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 5, savedLocale: 'en');
      api.on('GET', 'me', (_) => {'user': userJson(verified: true, remaining: 0)});
      api.on('POST', 'conversations', (_) => {'data': conversationJson(id: 'conv-q')});
      api.onStream = (_, _) => throw ApiException(status: 429, code: 'quota_exceeded');

      await tester.pumpWidget(wrapFullApp(api: api, storage: storage));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'One more question');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      expect(find.text("Today's quota is used up"), findsOneWidget);
      expect(find.text('Set up AI key'), findsOneWidget);
      // Composer keeps the unsent text so the user does not lose it.
      final composer = tester.widget<TextField>(find.byType(TextField));
      expect(composer.controller?.text, 'One more question');

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
    });

    testWidgets('shows stream error event inside the assistant message', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 5, savedLocale: 'en');
      api.on('GET', 'me', (_) => {'user': userJson(verified: true)});
      api.on('POST', 'conversations', (_) => {'data': conversationJson(id: 'conv-e')});
      api.onStream = (_, _) {
        final stream = Stream<List<int>>.fromIterable([
          sseChunk('message.start', {'message_id': 'm2', 'user_message_id': 'm1'}),
          sseChunk('error', {'code': 'provider_error', 'message': 'Provider timed out.'}),
        ]);
        return http.StreamedResponse(stream, 200);
      };

      await tester.pumpWidget(wrapFullApp(api: api, storage: storage));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ping');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      expect(find.text('Provider timed out.'), findsOneWidget);
    });
  });

  group('History drawer', () {
    testWidgets('lists, searches, opens and deletes conversations', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 5, savedLocale: 'en');
      final conversations = [
        conversationJson(id: 'c1', title: 'Trip to Bandung'),
        conversationJson(id: 'c2', title: 'Laravel Reverb Notes'),
      ];

      api.on('GET', 'me', (_) => {'user': userJson(verified: true)});
      api.on('GET', 'conversations', (call) {
        final q = (call.query?['q'] ?? '').toLowerCase();
        final filtered = q.isEmpty
            ? conversations
            : conversations.where((c) => '${c['title']}'.toLowerCase().contains(q)).toList();
        return {
          'data': filtered,
          'meta': {'current_page': 1, 'last_page': 1},
        };
      });
      api.on('GET', 'conversations/c1', (_) => {
        'data': {
          'id': 'c1',
          'title': 'Trip to Bandung',
          'messages': [
            messageJson(id: 'u1', role: 'user', content: 'Plan Bandung trip'),
            messageJson(id: 'a1', role: 'assistant', content: 'Day 1: Braga & Lembang.'),
          ],
        },
      });
      api.on('DELETE', 'conversations/c2', (_) {
        conversations.removeWhere((c) => c['id'] == 'c2');
        return {};
      });

      await tester.pumpWidget(wrapFullApp(api: api, storage: storage));
      await tester.pumpAndSettle();

      // Open drawer and see both conversations.
      await tester.tap(find.byTooltip('Chat history'));
      await tester.pumpAndSettle();

      expect(find.text('Trip to Bandung'), findsOneWidget);
      expect(find.text('Laravel Reverb Notes'), findsOneWidget);

      // Search filters via API (?q=Reverb).
      final searchField = find.descendant(of: find.byType(HistoryDrawer), matching: find.byType(TextField));
      await tester.enterText(searchField, 'Reverb');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Laravel Reverb Notes'), findsOneWidget);
      expect(find.text('Trip to Bandung'), findsNothing);

      // Delete "Laravel Reverb Notes".
      await tester.tap(find.byTooltip('Delete Laravel Reverb Notes'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this chat?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Laravel Reverb Notes'), findsNothing);

      // Clear search and open "Trip to Bandung".
      await tester.enterText(searchField, '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trip to Bandung'));
      await tester.pumpAndSettle();

      expect(find.text('Plan Bandung trip'), findsOneWidget);
      expect(find.text('Day 1: Braga & Lembang.'), findsOneWidget);

      // Drain toast timer so no pending timers remain at teardown.
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Realtime events', () {
    testWidgets('routes conversation, message and session.revoked events into UI', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 42, savedLocale: 'en');
      api.on('GET', 'me', (_) => {'user': userJson(verified: true)});
      api.on('GET', 'conversations/c-open', (_) => {
        'data': {
          'id': 'c-open',
          'title': 'Synced chat',
          'messages': [
            messageJson(id: 'm-1', role: 'user', content: 'From phone A'),
            messageJson(id: 'm-2', role: 'assistant', content: '', status: 'streaming'),
          ],
        },
      });

      await tester.pumpWidget(wrapFullApp(api: api, storage: storage));
      await tester.pumpAndSettle();

      final container = containerOf(tester);
      final realtime = container.read(realtimeProvider.notifier);

      // Open a conversation that had an in-progress answer from another device.
      await container.read(chatProvider.notifier).open(
        const Conversation(id: 'c-open', title: 'Synced chat'),
      );
      await tester.pump();
      expect(find.text('From phone A'), findsOneWidget);
      expect(find.byType(TypingDots), findsOneWidget);

      // Another device finishes the answer: message.created replaces the streaming placeholder.
      realtime.handleEvent('message.created', {
        'conversation_id': 'c-open',
        'message': messageJson(id: 'm-2', role: 'assistant', content: 'Finished from phone A.'),
      });
      await tester.pump();
      expect(find.text('Finished from phone A.'), findsOneWidget);
      expect(find.byType(TypingDots), findsNothing);

      // A brand-new conversation created elsewhere appears in history marked fresh.
      realtime.handleEvent('conversation.created', {
        'conversation': conversationJson(id: 'c-other', title: 'Started on Poco'),
      });
      await tester.pump();
      final list = container.read(conversationsProvider).items;
      expect(list.any((c) => c.id == 'c-other' && c.fresh), isTrue);

      // Deleting the currently open conversation elsewhere resets chat and shows a toast.
      realtime.handleEvent('conversation.deleted', {'id': 'c-open'});
      await tester.pump();
      expect(container.read(chatProvider).conversationId, isNull);
      expect(find.text('This chat was deleted on another device.'), findsOneWidget);

      // Drain toast timer before triggering session revocation.
      await tester.pump(const Duration(seconds: 3));

      // session.revoked with this device's token_id signs out and shows Session ended dialog.
      realtime.handleEvent('session.revoked', {
        'token_ids': [42],
      });
      await tester.pumpAndSettle();

      expect(find.text('Session ended'), findsOneWidget);
      expect(storage.savedToken, isNull);
      expect(container.read(sessionProvider).status, SessionStatus.signedOut);

      await tester.tap(find.text('Sign in again'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
