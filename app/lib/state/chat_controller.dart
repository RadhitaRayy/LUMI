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
    this.notice,
  });

  /// `null` for a new chat that has not been sent yet.
  final String? conversationId;
  final String? title;
  final List<ChatMessage> messages;
  final bool loading;
  final bool streaming;

  /// The open conversation was deleted on another device.
  final bool gone;

  /// Transient server notice (e.g. tools unsupported fallback).
  final String? notice;

  ChatState copyWith({
    String? conversationId,
    String? title,
    List<ChatMessage>? messages,
    bool? loading,
    bool? streaming,
    bool? gone,
    String? notice,
    bool clearNotice = false,
  }) => ChatState(
    conversationId: conversationId ?? this.conversationId,
    title: title ?? this.title,
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    streaming: streaming ?? this.streaming,
    gone: gone ?? this.gone,
    notice: clearNotice ? null : (notice ?? this.notice),
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
      clearNotice: true,
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

  /// Approves or rejects a paused `ask`-mode action and streams the resumed orchestrator turn.
  Future<void> resolveAction(PendingActionItem action, {required bool approve}) async {
    if (state.streaming) return;

    final targetMessageId = action.messageId;
    final previousMessages = state.messages;

    state = state.copyWith(streaming: true, clearNotice: true);
    _replace(
      targetMessageId,
      (m) => m.copyWith(status: MessageStatus.streaming, clearPendingAction: true),
    );

    final client = http.Client();
    _stream = client;
    _stopped = false;
    _botId = targetMessageId;

    try {
      final verb = approve ? 'approve' : 'reject';
      final response = await _api.openStream(client, 'actions/${action.id}/$verb', const {});
      await for (final event in parseSse(response.stream)) {
        _apply(event, userTemp: '', botTemp: targetMessageId);
      }
      _finishBot(targetMessageId, _stopped ? MessageStatus.cancelled : null);
    } on ApiException catch (e) {
      if (_stopped) {
        _finishBot(targetMessageId, MessageStatus.cancelled);
      } else if (e.status == 409 || e.status == 410 || e.status == 404) {
        // Already handled elsewhere or expired: keep the pending card cleared and let the screen notify.
        _replace(
          targetMessageId,
          (m) => m.copyWith(
            status: m.content.isNotEmpty ? MessageStatus.complete : MessageStatus.cancelled,
            clearPendingAction: true,
          ),
        );
        rethrow;
      } else if (_isBefore(e)) {
        // Restore the pending card so the user can retry.
        state = state.copyWith(messages: previousMessages, streaming: false);
        rethrow;
      } else {
        _finishBot(targetMessageId, MessageStatus.error, error: e.message);
      }
    } catch (_) {
      _finishBot(targetMessageId, _stopped ? MessageStatus.cancelled : MessageStatus.error);
    } finally {
      if (identical(_stream, client)) _stream = null;
      client.close();
      state = state.copyWith(streaming: false);
      unawaited(ref.read(sessionProvider.notifier).refreshUser());
    }
  }

  /// A pending approval arrived on another device (`action.pending`).
  void remoteActionPending(PendingActionItem action) {
    if (state.conversationId != action.conversationId || state.streaming) return;
    _replace(
      action.messageId,
      (m) => m.copyWith(status: MessageStatus.awaitingApproval, pendingAction: action),
    );
  }

  /// A pending approval was approved/rejected on another device (`action.resolved`).
  void remoteActionResolved({
    required String actionId,
    required String conversationId,
    required String messageId,
  }) {
    if (state.conversationId != conversationId || state.streaming) return;
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == messageId || m.pendingAction?.id == actionId)
            m.copyWith(
              clearPendingAction: true,
              status: m.status == MessageStatus.awaitingApproval ? MessageStatus.streaming : m.status,
            )
          else
            m,
      ],
    );
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

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }

  bool _isBefore(ApiException e) => e.status >= 400 && e.status != 0;

  void _apply(SseEvent event, {required String userTemp, required String botTemp}) {
    switch (event.event) {
      case 'message.start':
        final rawUserId = event.data['user_message_id'];
        final botId = '${event.data['message_id']}';
        if (userTemp.isNotEmpty && rawUserId != null) {
          _replace(userTemp, (m) => m.copyWith(id: '$rawUserId'));
        }
        _replace(botTemp, (m) => m.copyWith(id: botId));
        _botId = botId;
      case 'notice':
        final msg = event.data['message'] as String?;
        if (msg != null && msg.isNotEmpty) state = state.copyWith(notice: msg);
      case 'action.pending':
        final action = PendingActionItem.fromJson(event.data);
        final targetId = action.messageId.isNotEmpty ? action.messageId : (_botId ?? botTemp);
        _replace(
          targetId,
          (m) => m.copyWith(
            status: MessageStatus.awaitingApproval,
            pendingAction: action,
          ),
        );
      case 'tool.start':
        final item = ToolCallItem(
          id: '${event.data['tool_call_id'] ?? event.data['tool']}',
          toolName: event.data['tool'] as String? ?? '',
          label: event.data['label'] as String? ?? (event.data['tool'] as String? ?? ''),
          status: 'running',
        );
        _replace(_botId ?? botTemp, (m) => m.copyWith(toolCalls: [...m.toolCalls, item]));
      case 'tool.end':
        final callId = '${event.data['tool_call_id'] ?? event.data['tool']}';
        final toolStatus = event.data['status'] as String? ?? 'ok';
        final summary = event.data['summary'] as String? ?? '';
        _replace(_botId ?? botTemp, (m) {
          final updated = [
            for (final tc in m.toolCalls)
              tc.id == callId ? tc.copyWith(status: toolStatus, summary: summary) : tc,
          ];
          return m.copyWith(toolCalls: updated);
        });
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
