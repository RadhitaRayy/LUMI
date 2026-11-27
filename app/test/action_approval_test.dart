import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lumi/features/chat/chat_widgets.dart';
import 'package:lumi/state/realtime_controller.dart';
import 'package:lumi/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  testWidgets('ChatScreen pauses on action.pending, opens ConfirmActionSheet, approves and streams resumed answer', (
    tester,
  ) async {
    setPhoneViewport(tester);
    final api = FakeApiClient();
    final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 1, savedLocale: 'en');
    api.on('GET', 'me', (_) => {'user': userJson(verified: true)});
    api.on('POST', 'conversations', (_) => {'data': conversationJson(id: 'conv-act')});

    final pauseSse = StreamController<List<int>>();
    final resumeSse = StreamController<List<int>>();
    final streamPaths = <String>[];

    api.onStream = (path, _) {
      streamPaths.add(path);
      return http.StreamedResponse(
        path.endsWith('/approve') ? resumeSse.stream : pauseSse.stream,
        200,
      );
    };

    await tester.pumpWidget(wrapFullApp(api: api, storage: storage));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Delete my Draft note');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    pauseSse.add(sseChunk('message.start', {'message_id': 'm-bot', 'user_message_id': 'm-user'}));
    pauseSse.add(
      sseChunk('action.pending', {
        'id': 'act-1',
        'conversation_id': 'conv-act',
        'message_id': 'm-bot',
        'tool': 'delete_note',
        'title': 'Delete note',
        'summary': 'Delete note "Draft"',
        'status': 'pending',
        'expires_at': DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
      }),
    );
    await pauseSse.close();
    await tester.pumpAndSettle();

    expect(find.byType(PendingActionCard), findsOneWidget);
    expect(find.text('Approval required'), findsOneWidget);
    expect(find.text('Delete note "Draft"'), findsOneWidget);

    // Tapping the card opens the ConfirmActionSheet bottom sheet; approving streams the resumed turn.
    await tester.tap(find.text('Delete note "Draft"'));
    await tester.pumpAndSettle();
    expect(find.text('Tool: delete_note'), findsOneWidget);

    await tester.tap(find.text('Approve').last);
    await tester.pump();

    expect(streamPaths, contains('actions/act-1/approve'));

    resumeSse.add(sseChunk('message.start', {'message_id': 'm-bot'}));
    resumeSse.add(sseChunk('tool.start', {'tool_call_id': 'tc-1', 'tool': 'delete_note', 'label': 'Delete note'}));
    resumeSse.add(
      sseChunk('tool.end', {
        'tool_call_id': 'tc-1',
        'tool': 'delete_note',
        'status': 'ok',
        'summary': 'Deleted "Draft"',
      }),
    );
    resumeSse.add(sseChunk('delta', {'text': 'Done, Draft has been deleted.'}));
    resumeSse.add(sseChunk('message.end', {'message_id': 'm-bot', 'input_tokens': 25, 'output_tokens': 10}));
    await resumeSse.close();
    await tester.pumpAndSettle();

    expect(find.byType(PendingActionCard), findsNothing);
    expect(find.byType(ToolCallCard), findsOneWidget);
    expect(find.textContaining('Done, Draft has been deleted.'), findsOneWidget);
  });

  testWidgets('Realtime action.resolved clears PendingActionCard on another device', (tester) async {
    setPhoneViewport(tester);
    final api = FakeApiClient();
    final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 1, savedLocale: 'en');
    api.on('GET', 'me', (_) => {'user': userJson(verified: true)});
    api.on('POST', 'conversations', (_) => {'data': conversationJson(id: 'conv-sync')});

    final pauseSse = StreamController<List<int>>();
    api.onStream = (_, _) => http.StreamedResponse(pauseSse.stream, 200);

    await tester.pumpWidget(wrapFullApp(api: api, storage: storage));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Forget my old memory');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    pauseSse.add(sseChunk('message.start', {'message_id': 'm-bot-2', 'user_message_id': 'm-user-2'}));
    pauseSse.add(
      sseChunk('action.pending', {
        'id': 'act-sync',
        'conversation_id': 'conv-sync',
        'message_id': 'm-bot-2',
        'tool': 'forget_memory',
        'title': 'Forget memory',
        'summary': 'Forget memory "Likes coffee"',
        'status': 'pending',
        'expires_at': DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
      }),
    );
    await pauseSse.close();
    await tester.pumpAndSettle();

    expect(find.byType(PendingActionCard), findsOneWidget);

    containerOf(tester).read(realtimeProvider.notifier).handleEvent('action.resolved', {
      'action_id': 'act-sync',
      'conversation_id': 'conv-sync',
      'message_id': 'm-bot-2',
      'status': 'rejected',
    });
    await tester.pump();

    expect(find.byType(PendingActionCard), findsNothing);
  });
}
