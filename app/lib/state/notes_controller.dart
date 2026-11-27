import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../data/models.dart';
import 'core_providers.dart';
import 'session_controller.dart';

class NotesState {
  const NotesState({
    this.items = const [],
    this.total = 0,
    this.loading = false,
    this.loaded = false,
    this.query = '',
    this.page = 1,
    this.hasMore = false,
    this.error,
  });

  final List<UserNote> items;
  final int total;
  final bool loading;
  final bool loaded;
  final String query;
  final int page;
  final bool hasMore;
  final ApiException? error;

  NotesState copyWith({
    List<UserNote>? items,
    int? total,
    bool? loading,
    bool? loaded,
    String? query,
    int? page,
    bool? hasMore,
    ApiException? error,
    bool clearError = false,
  }) => NotesState(
    items: items ?? this.items,
    total: total ?? this.total,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    query: query ?? this.query,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
  );
}

class NotesController extends Notifier<NotesState> {
  ApiClient get _api => ref.read(apiClientProvider);
  var _requestId = 0;

  @override
  NotesState build() {
    ref.listen(sessionProvider.select((s) => s.status), (_, status) {
      if (status != SessionStatus.signedIn) state = const NotesState();
    });
    return const NotesState();
  }

  Future<void> load({String? query}) async {
    final q = query ?? state.query;
    final id = ++_requestId;
    state = state.copyWith(loading: true, query: q, clearError: true);
    try {
      final body = await _api.get('notes', query: {if (q.isNotEmpty) 'q': q, 'page': '1'});
      if (id != _requestId) return;
      final items = _parse(body);
      final meta = body['meta'] as Map? ?? const {};
      final current = meta['current_page'] as int? ?? 1;
      final last = meta['last_page'] as int? ?? 1;
      state = state.copyWith(
        items: items,
        total: meta['total'] as int? ?? items.length,
        loading: false,
        loaded: true,
        page: 1,
        hasMore: current < last,
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
      final body = await _api.get('notes', query: {
        if (state.query.isNotEmpty) 'q': state.query,
        'page': '$next',
      });
      if (id != _requestId) return;
      final known = state.items.map((n) => n.id).toSet();
      final meta = body['meta'] as Map? ?? const {};
      final current = meta['current_page'] as int? ?? next;
      final last = meta['last_page'] as int? ?? next;
      state = state.copyWith(
        items: [...state.items, ..._parse(body).where((n) => !known.contains(n.id))],
        loading: false,
        page: next,
        hasMore: current < last,
      );
    } on ApiException catch (e) {
      if (id != _requestId) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> create({required String title, required String content, List<String> tags = const []}) async {
    final body = await _api.post('notes', {
      'title': title.trim(),
      'content': content.trim(),
      'tags': tags,
    });
    final created = UserNote.fromJson(body['data'] as Map<String, dynamic>);
    state = state.copyWith(
      items: [created, ...state.items.where((n) => n.id != created.id)],
      total: state.total + 1,
      loaded: true,
    );
  }

  Future<void> update(String id, {required String title, required String content, List<String> tags = const []}) async {
    final body = await _api.patch('notes/$id', {
      'title': title.trim(),
      'content': content.trim(),
      'tags': tags,
    });
    final updated = UserNote.fromJson(body['data'] as Map<String, dynamic>);
    state = state.copyWith(
      items: [updated, ...state.items.where((n) => n.id != updated.id)],
    );
  }

  Future<void> delete(String id) async {
    await _api.delete('notes/$id');
    final existed = state.items.any((n) => n.id == id);
    state = state.copyWith(
      items: state.items.where((n) => n.id != id).toList(),
      total: existed && state.total > 0 ? state.total - 1 : state.total,
    );
  }

  void applyRemote(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    if (action == 'deleted') {
      final id = data['id'] as String?;
      if (id == null) return;
      final existed = state.items.any((n) => n.id == id);
      state = state.copyWith(
        items: state.items.where((n) => n.id != id).toList(),
        total: existed && state.total > 0 ? state.total - 1 : state.total,
      );
      return;
    }
    final raw = data['note'];
    if (raw is! Map<String, dynamic>) return;
    final note = UserNote.fromJson(raw);
    final existed = state.items.any((n) => n.id == note.id);
    state = state.copyWith(
      items: [note, ...state.items.where((n) => n.id != note.id)],
      total: existed ? state.total : state.total + 1,
    );
  }

  List<UserNote> _parse(Map<String, dynamic> body) => [
    for (final item in (body['data'] as List? ?? const []))
      UserNote.fromJson(item as Map<String, dynamic>),
  ];
}

final notesProvider = NotifierProvider<NotesController, NotesState>(NotesController.new);
