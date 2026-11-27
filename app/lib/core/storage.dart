import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The device token lives in the platform keystore; the language choice in plain preferences.
class AppStorage {
  AppStorage({FlutterSecureStorage? secure, SharedPreferencesAsync? prefs})
    : _secureOverride = secure,
      _prefsOverride = prefs;

  final FlutterSecureStorage? _secureOverride;
  final SharedPreferencesAsync? _prefsOverride;

  // Created on first use, so tests can subclass this without platform plugins.
  late final FlutterSecureStorage _secure = _secureOverride ?? const FlutterSecureStorage();
  late final SharedPreferencesAsync _prefs = _prefsOverride ?? SharedPreferencesAsync();

  static const _tokenKey = 'lumi.token';
  static const _tokenIdKey = 'lumi.token_id';
  static const _localeKey = 'lumi.locale';
  static const _serverUrlKey = 'lumi.server_url';
  static const _inspectorOverlayKey = 'lumi.inspector_overlay';

  Future<({String token, int tokenId})?> readSession() async {
    final token = await _secure.read(key: _tokenKey);
    final tokenId = int.tryParse(await _secure.read(key: _tokenIdKey) ?? '');
    if (token == null || tokenId == null) return null;
    return (token: token, tokenId: tokenId);
  }

  Future<void> saveSession(String token, int tokenId) async {
    await _secure.write(key: _tokenKey, value: token);
    await _secure.write(key: _tokenIdKey, value: '$tokenId');
  }

  Future<void> clearSession() async {
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _tokenIdKey);
  }

  /// `null` means "follow the phone".
  Future<String?> readLocale() => _prefs.getString(_localeKey);

  Future<void> saveLocale(String? code) =>
      code == null ? _prefs.remove(_localeKey) : _prefs.setString(_localeKey, code);

  /// `null` means "use AppConfig.apiBaseUrl".
  Future<String?> readServerUrl() => _prefs.getString(_serverUrlKey);

  Future<void> saveServerUrl(String? url) =>
      url == null ? _prefs.remove(_serverUrlKey) : _prefs.setString(_serverUrlKey, url);

  Future<bool> readInspectorOverlay() async => (await _prefs.getBool(_inspectorOverlayKey)) ?? false;

  Future<void> saveInspectorOverlay(bool enabled) => _prefs.setBool(_inspectorOverlayKey, enabled);
}
