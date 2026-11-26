/// Where the app finds Lumi Core. Set with `--dart-define`, for example:
///
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
///     --dart-define=REVERB_KEY=... --dart-define=REVERB_PORT=8090
///
/// In development the phone reaches the laptop through `adb reverse tcp:8000 tcp:8000`
/// (and `tcp:8090` for Reverb), so 127.0.0.1 works on a USB-connected phone.
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Reverb (Pusher protocol). Realtime stays off when the key is empty.
  static const reverbKey = String.fromEnvironment('REVERB_KEY');
  static const _reverbHost = String.fromEnvironment('REVERB_HOST');
  static const reverbPort = int.fromEnvironment('REVERB_PORT', defaultValue: 8090);
  static const reverbScheme = String.fromEnvironment(
    'REVERB_SCHEME',
    defaultValue: 'http',
  );

  static String get reverbHost =>
      _reverbHost.isNotEmpty ? _reverbHost : Uri.parse(apiBaseUrl).host;

  static bool get realtimeEnabled => reverbKey.isNotEmpty;

  static const appVersion = '0.1';
}
