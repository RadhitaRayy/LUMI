import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/api_client.dart';
import '../core/sse.dart';
import '../data/models.dart';
import 'conversations_controller.dart';
import 'core_providers.dart';
import 'session_controller.dart';

class ChatState {
  const ChatState({
    this.conversationId,
    this.title,
    this.messages = const [],
    this.loading = false,
    this.streaming = false,
    this.gone = false,
  });

  /// `null` for a new chat that has not been sent yet.
  final String? conversationId;
  final String? title;
  final List<ChatMessage> messages;
  final bool loading;
  final bool streaming;

  /// The open conversation was deleted on another device.
  final bool gone;

  ChatState copyWith({
    String? conversationId,
    String? title,
    List<ChatMessage>? messages,
    bool? loading,
    bool? streaming,
    bool? gone,
  }) => ChatState(
    conversationId: conversationId ?? this.conversationId,
    title: title ?? this.title,
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    streaming: streaming ?? this.streaming,
    gone: gone ?? this.gone,
  );
}

/// The open chat: loads a conversation, sends messages and reads the streamed answer (SSE).
class ChatController extends Notifier<ChatState> {
  ApiClient get _api => ref.read(apiClientProvider);
  http.Client? _stream;
  var _stopped = false;
  var _tempId = 0;

  @override
  ChatState build() {
    ref.onDispose(() => _stream?.close());
    ref.listen(sessionProvider.select((s) => s.status), (_, status) {
      if (status != SessionStatus.signedIn) startNew();
    });
    return const ChatState();
  }

  void startNew() {
    _stream?.close();
    _stream = null;
    state = const ChatState();
  }

  Future<void> open(Conversation conversation) async {
    _stream?.close();
    _stream = null;
    state = ChatState(conversationId: conversation.id, title: conversation.title, loading: true);
    ref.read(conversationsProvider.notifier).markSeen(conversation.id);
    try {
      final body = await _api.get('conversations/${conversation.id}');
      final data = body['data'] as Map<String, dynamic>? ?? body;
      if (state.conversationId != conversation.id) return;
      state = state.copyWith(
        title: data['title'] as String?,
        loading: false,
        messages: [
          for (final m in (data['messages'] as List? ?? const []))
            ChatMessage.fromJson(m as Map<String, dynamic>),
        ],
      );
    } on ApiException catch (e) {
      if (state.conversationId != conversation.id) return;
      state = state.copyWith(loading: false, gone: e.status == 404);
      if (e.status != 404) rethrow;
    }
  }

  /// Sends [text]. Throws [ApiException] when Core refuses before streaming (e.g. quota_exceeded);
  /// a failure while streaming is shown on the answer bubble instead.
  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || state.streaming) return;

    final userTemp = 'local-${++_tempId}';
    final botTemp = 'local-${++_tempId}';
    final before = state.messages;
    state = state.copyWith(
      streaming: true,
      messages: [
        ...before,
        ChatMessage(id: userTemp, role: Role.user, content: content),
        ChatMessage(id: botTemp, role: Role.assistant, content: '', status: MessageStatus.streaming),
      ],
    );

    final client = http.Client();
    _stream = client;
    _stopped = false;
    try {
      var id = state.conversationId;
      if (id == null) {
        final created = await _api.post('conversations');
        final conversation = Conversation.fromJson(created['data'] as Map<String, dynamic>? ?? created);
        id = conversation.id;
        state = state.copyWith(conversationId: id);
      }
      final title = state.title ?? _titleFrom(content);
      state = state.copyWith(title: title);
      ref.read(conversationsProvider.notifier).upsert(
        Conversation(id: id, title: title, lastMessageAt: DateTime.now()),
      );

      final response = await _api.openStream(client, 'conversations/$id/messages', {'content': content});
      await for (final event in parseSse(response.stream)) {
        _apply(event, userTemp: userTemp, botTemp: botTemp);
      }
      _finishBot(botTemp, _stopped ? MessageStatus.cancelled : null);
    } on ApiException catch (e) {
      if (_stopped) {
        _finishBot(botTemp, MessageStatus.cancelled);
      } else if (_isBefore(e)) {
        // Nothing was stored: take both bubbles back and let the screen explain.
        state = state.copyWith(messages: before, streaming: false);
        rethrow;
      } else {
        _finishBot(botTemp, MessageStatus.error, error: e.message);
      }
    } catch (_) {
      _finishBot(botTemp, _stopped ? MessageStatus.cancelled : MessageStatus.error);
    } finally {
      if (identical(_stream, client)) _stream = null;
      client.close();
      state = state.copyWith(streaming: false);
      unawaited(ref.read(sessionProvider.notifier).refreshUser());
    }
  }

  void stop() {
    if (!state.streaming) return;
    _stopped = true;
    _stream?.close();
  }

  /// A message saved on another device (realtime `message.created`).
  void remoteMessage(String conversationId, ChatMessage message) {
    if (state.conversationId != conversationId) return;
    // While this device streams, its own answer arrives through SSE.
    if (state.streaming) return;
    if (state.messages.any((m) => m.id == message.id)) {
      // An answer that was still being written elsewhere when this chat opened is now finished.
      _replace(message.id, (_) => message);
      return;
    }
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void remoteDeleted(String conversationId) {
    if (state.conversationId == conversationId) {
      _stream?.close();
      state = state.copyWith(gone: true, streaming: false);
    }
  }

  void remoteRenamed(String conversationId, String? title) {
    if (state.conversationId == conversationId && title != null) {
      state = state.copyWith(title: title);
    }
  }

  bool _isBefore(ApiException e) => e.status >= 400 && e.status != 0;

  void _apply(SseEvent event, {required String userTemp, required String botTemp}) {
    switch (event.event) {
      case 'message.start':
        final userId = '${event.data['user_message_id']}';
        final botId = '${event.data['message_id']}';
        _replace(userTemp, (m) => m.copyWith(id: userId));
        _replace(botTemp, (m) => m.copyWith(id: botId));
        _botId = botId;
      case 'delta':
        final text = event.data['text'] as String? ?? '';
        _replace(_botId ?? botTemp, (m) => m.copyWith(content: m.content + text));
      case 'error':
        _replace(
          _botId ?? botTemp,
          (m) => m.copyWith(status: MessageStatus.error, errorText: event.data['message'] as String?),
        );
      case 'message.end':
        _replace(_botId ?? botTemp, (m) => m.copyWith(status: MessageStatus.complete));
    }
  }

  String? _botId;

  void _finishBot(String botTemp, MessageStatus? status, {String? error}) {
    final id = _botId ?? botTemp;
    _botId = null;
    _replace(id, (m) {
      if (m.status != MessageStatus.streaming) return m;
      return m.copyWith(status: status ?? MessageStatus.complete, errorText: error);
    });
  }

  void _replace(String id, ChatMessage Function(ChatMessage) change) {
    state = state.copyWith(
      messages: [for (final m in state.messages) m.id == id ? change(m) : m],
    );
  }

  /// Same rule as Core: the first message, squished and cut at 60 characters.
  static String _titleFrom(String content) {
    final squished = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return squished.length <= 60 ? squished : '${squished.substring(0, 60)}…';
  }
}

final chatProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);
