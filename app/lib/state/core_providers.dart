import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../core/api_client.dart';
import '../core/http_log.dart';
import '../core/storage.dart';

final storageProvider = Provider<AppStorage>((ref) => AppStorage());

final httpLogStoreProvider = Provider<HttpLogStore>((ref) {
  final store = HttpLogStore();
  ref.onDispose(store.dispose);
  return store;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: AppConfig.apiBaseUrl, logger: ref.read(httpLogStoreProvider)),
);

/// Persists whether the floating Chucker-style network inspector pill is shown over the app.
class InspectorOverlayController extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final enabled = await ref.read(storageProvider).readInspectorOverlay();
      state = enabled;
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref.read(storageProvider).saveInspectorOverlay(enabled);
  }
}

final inspectorOverlayProvider = NotifierProvider<InspectorOverlayController, bool>(
  InspectorOverlayController.new,
);

/// The name Core shows in "Active devices", e.g. "Samsung SM-A566B".
final deviceNameProvider = FutureProvider<String>((ref) async {
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      final brand = android.brand.isEmpty
          ? ''
          : '${android.brand[0].toUpperCase()}${android.brand.substring(1)} ';
      return '$brand${android.model}'.trim();
    }
    if (Platform.isIOS) {
      return (await info.iosInfo).model;
    }
  } catch (_) {}
  return 'Lumi App';
});
