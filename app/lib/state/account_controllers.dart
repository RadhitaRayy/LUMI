import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../data/models.dart';
import 'core_providers.dart';
import 'session_controller.dart';

/// "My AI key": the saved key (never the secret itself) and the actions on it.
class AiKeyController extends AsyncNotifier<AiKey?> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<AiKey?> build() async {
    ref.watch(sessionProvider.select((s) => s.user?.id));
    final body = await _api.get('me/ai-key');
    final raw = body['ai_key'];
    return raw is Map<String, dynamic> ? AiKey.fromJson(raw) : null;
  }

  Future<void> save({
    required AiProvider provider,
    required String apiKey,
    required String modelId,
    String? baseUrl,
  }) async {
    final body = await _api.put('me/ai-key', {
      'driver': provider.driver,
      'base_url': provider.fixedBaseUrl ?? (provider == AiProvider.other ? baseUrl?.trim() : null),
      'api_key': apiKey.trim(),
      'model_id': modelId.trim(),
    });
    _apply(body);
  }

  Future<void> test() async => _apply(await _api.post('me/ai-key/test'));

  Future<void> setActive(bool active) async => _apply(await _api.patch('me/ai-key', {'is_active': active}));

  Future<void> remove() async {
    await _api.delete('me/ai-key');
    state = const AsyncData(null);
    await ref.read(sessionProvider.notifier).refreshUser();
  }

  void _apply(Map<String, dynamic> body) {
    final raw = body['ai_key'];
    state = AsyncData(raw is Map<String, dynamic> ? AiKey.fromJson(raw) : null);
    ref.read(sessionProvider.notifier).refreshUser();
  }
}

final aiKeyProvider = AsyncNotifierProvider<AiKeyController, AiKey?>(AiKeyController.new);

/// Devices signed in to this account (one Sanctum token each).
class DevicesController extends AsyncNotifier<List<Device>> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<List<Device>> build() async {
    ref.watch(sessionProvider.select((s) => s.user?.id));
    final body = await _api.get('devices');
    return [
      for (final d in (body['devices'] as List? ?? const [])) Device.fromJson(d as Map<String, dynamic>),
    ];
  }

  Future<void> signOut(List<int> ids) async {
    for (final id in ids) {
      await _api.delete('devices/$id');
    }
    final current = state.value ?? const [];
    state = AsyncData(current.where((d) => !ids.contains(d.id)).toList());
  }
}

final devicesProvider = AsyncNotifierProvider<DevicesController, List<Device>>(DevicesController.new);
