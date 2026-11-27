import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../core/reverb_client.dart';
import '../data/models.dart';
import 'chat_controller.dart';
import 'conversations_controller.dart';
import 'core_providers.dart';
import 'persona_controller.dart';
import 'session_controller.dart';

/// Connects to Reverb while signed in and routes events from other devices into the app state.
class RealtimeController extends Notifier<bool> {
  ReverbClient? _client;

  @override
  bool build() {
    ref.onDispose(() => _client?.disconnect());
    ref.listen(sessionProvider, (previous, next) {
      final userId = next.status == SessionStatus.signedIn ? next.user?.id : null;
      final previousId = previous?.status == SessionStatus.signedIn ? previous?.user?.id : null;
      if (userId != previousId) {
        _client?.disconnect();
        _client = null;
        if (userId != null) _connect(userId);
      }
    }, fireImmediately: true);
    return false;
  }

  /// Reconnect after the app comes back to the foreground.
  void resume() {
    final session = ref.read(sessionProvider);
    if (session.status != SessionStatus.signedIn || session.user == null) return;
    _client?.disconnect();
    _connect(session.user!.id);
  }

  void _connect(int userId) {
    if (!AppConfig.realtimeEnabled) return;
    _client = ReverbClient(
      api: ref.read(apiClientProvider),
      host: AppConfig.reverbHost,
      port: AppConfig.reverbPort,
      key: AppConfig.reverbKey,
      secure: AppConfig.reverbScheme == 'https',
      onEvent: _onEvent,
    )..connect('private-user.$userId');
  }

  @visibleForTesting
  void handleEvent(String event, Map<String, dynamic> data) => _onEvent(event, data);

  void _onEvent(String event, Map<String, dynamic> data) {
    final conversations = ref.read(conversationsProvider.notifier);
    final chat = ref.read(chatProvider.notifier);

    switch (event) {
      case 'conversation.created' || 'conversation.updated':
        final raw = data['conversation'];
        if (raw is! Map<String, dynamic>) return;
        final conversation = Conversation.fromJson(raw);
        final openHere = ref.read(chatProvider).conversationId == conversation.id;
        conversations.upsert(conversation, fresh: !openHere);
        chat.remoteRenamed(conversation.id, conversation.title);
      case 'conversation.deleted':
        final id = data['id'] as String?;
        if (id == null) return;
        conversations.remove(id);
        chat.remoteDeleted(id);
      case 'message.created':
        final id = data['conversation_id'] as String?;
        final raw = data['message'];
        if (id == null || raw is! Map<String, dynamic>) return;
        chat.remoteMessage(id, ChatMessage.fromJson(raw));
      case 'persona.updated':
        final raw = data['persona'];
        if (raw is! Map<String, dynamic>) return;
        ref.read(personaProvider.notifier).applyRemote(raw);
      case 'session.revoked':
        final ids = (data['token_ids'] as List? ?? const []).whereType<int>();
        final mine = ref.read(sessionProvider).tokenId;
        if (mine != null && ids.contains(mine)) {
          ref.read(sessionProvider.notifier).revoked();
        } else {
          ref.read(sessionProvider.notifier).refreshUser();
        }
    }
  }
}

final realtimeProvider = NotifierProvider<RealtimeController, bool>(RealtimeController.new);
