import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../data/models.dart';
import 'core_providers.dart';
import 'locale_controller.dart';
import 'session_controller.dart';

/// Server-side tools currently enabled for this user's role (`GET /api/v1/tools`).
class ToolsController extends AsyncNotifier<List<AgentToolInfo>> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<List<AgentToolInfo>> build() async {
    final userId = ref.watch(sessionProvider.select((s) => s.user?.id));
    ref.watch(localeProvider.select((s) => s.code));
    if (userId == null) return const [];
    final body = await _api.get('tools');
    return [
      for (final raw in (body['data'] as List? ?? const []))
        AgentToolInfo.fromJson(raw as Map<String, dynamic>),
    ];
  }
}

final toolsProvider = AsyncNotifierProvider<ToolsController, List<AgentToolInfo>>(ToolsController.new);
