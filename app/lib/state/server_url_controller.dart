import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../core/api_client.dart';
import 'core_providers.dart';

class ServerUrlState {
  const ServerUrlState({this.customUrl});

  final String? customUrl;

  String get defaultUrl => AppConfig.apiBaseUrl;
  String get effectiveUrl => customUrl ?? defaultUrl;
  bool get isCustom => customUrl != null;
}

/// Manages an optional custom Lumi Core URL (e.g. Cloudflare Tunnel or self-hosted VPS) without rebuilding the APK.
class ServerUrlController extends Notifier<ServerUrlState> {
  @override
  ServerUrlState build() => const ServerUrlState();

  /// Validates and strips trailing slashes. Returns `null` if [raw] is not a valid http/https URL.
  static String? normalize(String raw) {
    final trimmed = raw.trim().replaceFirst(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return trimmed;
  }

  Future<void> load() async {
    final saved = await ref.read(storageProvider).readServerUrl();
    final normalized = saved == null ? null : normalize(saved);
    state = ServerUrlState(customUrl: normalized);
    ref.read(apiClientProvider).setBaseUrl(state.effectiveUrl);
  }

  /// Probes `/api/v1/health` on [rawUrl], then persists and activates it.
  Future<void> testAndSave(String rawUrl) async {
    final normalized = normalize(rawUrl);
    if (normalized == null) {
      throw ApiException(status: 422, code: 'server_url_invalid');
    }
    final api = ref.read(apiClientProvider);
    await api.probeHealth(normalized);
    final isDefault = normalized == normalize(AppConfig.apiBaseUrl);
    final toStore = isDefault ? null : normalized;
    await ref.read(storageProvider).saveServerUrl(toStore);
    state = ServerUrlState(customUrl: toStore);
    api.setBaseUrl(state.effectiveUrl);
  }

  Future<void> reset() async {
    await ref.read(storageProvider).saveServerUrl(null);
    state = const ServerUrlState();
    ref.read(apiClientProvider).setBaseUrl(state.effectiveUrl);
  }
}

final serverUrlProvider = NotifierProvider<ServerUrlController, ServerUrlState>(ServerUrlController.new);
