import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../data/models.dart';
import 'core_providers.dart';
import 'session_controller.dart';

class MemoriesState {
  const MemoriesState({
    this.items = const [],
    this.count = 0,
    this.limit = 50,
    this.loading = false,
    this.loaded = false,
    this.query = '',
    this.error,
  });

  final List<UserMemory> items;
  final int count;
  final int limit;
  final bool loading;
  final bool loaded;
  final String query;
  final ApiException? error;

  bool get atLimit => count >= limit;

  MemoriesState copyWith({
    List<UserMemory>? items,
    int? count,
    int? limit,
    bool? loading,
    bool? loaded,
    String? query,
    ApiException? error,
    bool clearError = false,
  }) => MemoriesState(
    items: items ?? this.items,
    count: count ?? this.count,
    limit: limit ?? this.limit,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    query: query ?? this.query,
    error: clearError ? null : (error ?? this.error),
  );
}

class MemoriesController extends Notifier<MemoriesState> {
  ApiClient get _api => ref.read(apiClientProvider);
  var _requestId = 0;

  @override
  MemoriesState build() {
    ref.listen(sessionProvider.select((s) => s.status), (_, status) {
      if (status != SessionStatus.signedIn) state = const MemoriesState();
    });
    return const MemoriesState();
  }

  Future<void> load({String? query}) async {
    final q = query ?? state.query;
    final id = ++_requestId;
    state = state.copyWith(loading: true, query: q, clearError: true);
    try {
      final body = await _api.get('memories', query: {if (q.isNotEmpty) 'q': q});
      if (id != _requestId) return;
      final items = [
        for (final raw in (body['data'] as List? ?? const []))
          UserMemory.fromJson(raw as Map<String, dynamic>),
      ];
      state = state.copyWith(
        items: items,
        count: body['count'] as int? ?? items.length,
        limit: body['limit'] as int? ?? 50,
        loading: false,
        loaded: true,
      );
    } on ApiException catch (e) {
      if (id != _requestId) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> create({required String content, required String category}) async {
    final body = await _api.post('memories', {'content': content.trim(), 'category': category});
    final created = UserMemory.fromJson(body['data'] as Map<String, dynamic>);
    state = state.copyWith(
      items: [created, ...state.items.where((m) => m.id != created.id)],
      count: state.count + 1,
      loaded: true,
    );
  }

  Future<void> update(String id, {required String content, required String category}) async {
    final body = await _api.patch('memories/$id', {'content': content.trim(), 'category': category});
    final updated = UserMemory.fromJson(body['data'] as Map<String, dynamic>);
    state = state.copyWith(
      items: [updated, ...state.items.where((m) => m.id != updated.id)],
    );
  }

  Future<void> delete(String id) async {
    await _api.delete('memories/$id');
    final existed = state.items.any((m) => m.id == id);
    state = state.copyWith(
      items: state.items.where((m) => m.id != id).toList(),
      count: existed && state.count > 0 ? state.count - 1 : state.count,
    );
  }

  void applyRemote(Map<String, dynamic> data) {
    final action = data['action'] as String?;
    if (action == 'deleted') {
      final id = data['id'] as String?;
      if (id == null) return;
      final existed = state.items.any((m) => m.id == id);
      state = state.copyWith(
        items: state.items.where((m) => m.id != id).toList(),
        count: existed && state.count > 0 ? state.count - 1 : state.count,
      );
      return;
    }
    final raw = data['memory'];
    if (raw is! Map<String, dynamic>) return;
    final memory = UserMemory.fromJson(raw);
    final existed = state.items.any((m) => m.id == memory.id);
    state = state.copyWith(
      items: [memory, ...state.items.where((m) => m.id != memory.id)],
      count: existed ? state.count : state.count + 1,
    );
  }
}

final memoriesProvider = NotifierProvider<MemoriesController, MemoriesState>(MemoriesController.new);
