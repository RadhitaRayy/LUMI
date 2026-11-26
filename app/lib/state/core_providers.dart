import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../core/api_client.dart';
import '../core/storage.dart';

final storageProvider = Provider<AppStorage>((ref) => AppStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: AppConfig.apiBaseUrl),
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
