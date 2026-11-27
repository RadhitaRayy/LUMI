import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lumi/features/agent/tools_screen.dart';
import 'package:lumi/features/chat/chat_widgets.dart';
import 'package:lumi/state/session_controller.dart';
import 'package:lumi/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  testWidgets('ChatScreen renders ToolCallCard live from SSE tool.start/tool.end and expands summary', (tester) async {
    setPhoneViewport(tester);
    final api = FakeApiClient();
    final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 1, savedLocale: 'en');
    api.on('GET', 'me', (_) => {'user': userJson(verified: true)});
    api.on('POST', 'conversations', (_) => {'data': conversationJson(id: 'conv-t')});

    final sse = StreamController<List<int>>();
    api.onStream = (_, _) => http.StreamedResponse(sse.stream, 200);

    await tester.pumpWidget(wrapFullApp(api: api, storage: storage));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Save a quick note');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    sse.add(sseChunk('message.start', {'message_id': 'm-bot', 'user_message_id': 'm-user'}));
    sse.add(sseChunk('tool.start', {'tool_call_id': 'tc-1', 'tool': 'save_note', 'label': 'Save note'}));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ToolCallCard), findsOneWidget);
    expect(find.text('Save note'), findsOneWidget);

    sse.add(sseChunk('tool.end', {
      'tool_call_id': 'tc-1',
      'tool': 'save_note',
      'status': 'ok',
      'summary': 'Saved "Quick Note"',
    }));
    sse.add(sseChunk('delta', {'text': 'Done! I saved your note.'}));
    sse.add(sseChunk('message.end', {'message_id': 'm-bot', 'input_tokens': 20, 'output_tokens': 8}));
    await sse.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Done! I saved your note.'), findsOneWidget);

    // Tapping the ToolCallCard expands the summary.
    await tester.tap(find.text('Save note'));
    await tester.pump();
    expect(find.text('Saved "Quick Note"'), findsOneWidget);
  });

  testWidgets('ToolsScreen displays enabled tools with Auto and Ask approval badges', (tester) async {
    setPhoneViewport(tester);
    final api = FakeApiClient();
    final storage = MemoryStorage(savedToken: 'tok-1', savedTokenId: 1, savedLocale: 'en');
    api.on('GET', 'me', (_) => {'user': userJson(verified: true)});
    api.on('GET', 'tools', (_) => {
      'data': [
        {'name': 'save_note', 'label': 'Save note', 'description': 'Create a personal note.', 'mode': 'auto'},
        {'name': 'delete_note', 'label': 'Delete note', 'description': 'Remove a personal note.', 'mode': 'ask'},
      ],
    });

    await tester.pumpWidget(wrapTestApp(child: const ToolsScreen(), api: api, storage: storage));
    await containerOf(tester).read(sessionProvider.notifier).restore();
    await tester.pumpAndSettle();

    expect(find.text('Save note'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Delete note'), findsOneWidget);
    expect(find.text('Ask approval'), findsOneWidget);
  });
}
