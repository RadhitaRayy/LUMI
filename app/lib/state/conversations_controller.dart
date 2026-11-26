import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../data/models.dart';
import 'core_providers.dart';
import 'session_controller.dart';

class ConversationsState {
  const ConversationsState({
    this.items = const [],
    this.loading = false,
    this.loaded = false,
    this.error,
    this.query = '',
    this.page = 1,
    this.hasMore = false,
  });

  final List<Conversation> items;
  final bool loading;
  final bool loaded;
  final ApiException? error;
  final String query;
  final int page;
  final bool hasMore;

  ConversationsState copyWith({
    List<Conversation>? items,
    bool? loading,
    bool? loaded,
    ApiException? error,
    bool clearError = false,
    String? query,
    int? page,
    bool? hasMore,
  }) => ConversationsState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    error: clearError ? null : (error ?? this.error),
    query: query ?? this.query,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
  );
}

/// The history list. Kept in sync by realtime events from other devices.
class ConversationsController extends Notifier<ConversationsState> {
  ApiClient get _api => ref.read(apiClientProvider);
  int _requestId = 0;

  @override
  ConversationsState build() {
    ref.listen(sessionProvider.select((s) => s.status), (previous, status) {
      if (status != SessionStatus.signedIn) state = const ConversationsState();
    });
    return const ConversationsState();
  }

  Future<void> load({String? query}) async {
    final q = query ?? state.query;
    final id = ++_requestId;
    state = state.copyWith(loading: true, query: q, clearError: true);
    try {
      final body = await _api.get('conversations', query: {if (q.isNotEmpty) 'q': q, 'page': '1'});
      if (id != _requestId) return;
      state = state.copyWith(
        items: _parse(body),
        loading: false,
        loaded: true,
        page: 1,
        hasMore: _hasMore(body),
      );
    } on ApiException catch (e) {
      if (id != _requestId) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    final id = ++_requestId;
    final next = state.page + 1;
    state = state.copyWith(loading: true);
    try {
      final body = await _api.get('conversations', query: {
        if (state.query.isNotEmpty) 'q': state.query,
        'page': '$next',
      });
      if (id != _requestId) return;
      final known = state.items.map((c) => c.id).toSet();
      state = state.copyWith(
        items: [...state.items, ..._parse(body).where((c) => !known.contains(c.id))],
        loading: false,
        page: next,
        hasMore: _hasMore(body),
      );
    } on ApiException catch (e) {
      if (id != _requestId) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// A conversation was created or changed (here or on another device).
  void upsert(Conversation conversation, {bool fresh = false}) {
    final existing = state.items.where((c) => c.id == conversation.id).firstOrNull;
    final merged = conversation.copyWith(fresh: fresh || (existing?.fresh ?? false));
    final items = [merged, ...state.items.where((c) => c.id != conversation.id)]
      ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    state = state.copyWith(items: items);
  }

  void remove(String id) =>
      state = state.copyWith(items: state.items.where((c) => c.id != id).toList());

  void markSeen(String id) {
    if (!state.items.any((c) => c.id == id && c.fresh)) return;
    state = state.copyWith(
      items: [for (final c in state.items) c.id == id ? c.copyWith(fresh: false) : c],
    );
  }

  Future<void> delete(String id) async {
    await _api.delete('conversations/$id');
    remove(id);
  }

  List<Conversation> _parse(Map<String, dynamic> body) => [
    for (final item in (body['data'] as List? ?? const []))
      Conversation.fromJson(item as Map<String, dynamic>),
  ];

  bool _hasMore(Map<String, dynamic> body) {
    final meta = body['meta'];
    if (meta is! Map) return false;
    final current = meta['current_page'] as int? ?? 1;
    final last = meta['last_page'] as int? ?? 1;
    return current < last;
  }
}

final conversationsProvider = NotifierProvider<ConversationsController, ConversationsState>(
  ConversationsController.new,
);
