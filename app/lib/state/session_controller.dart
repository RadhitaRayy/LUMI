import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../data/models.dart';
import 'core_providers.dart';
import 'locale_controller.dart';

enum SessionStatus {
  /// Still reading the saved token (splash).
  unknown,

  /// A token is saved but Core could not be reached; the splash offers "Try again".
  unreachable,
  signedOut,
  unverified,
  signedIn,
}

/// Why the user is signed out, so the app can explain a revoked session.
enum SignOutReason { none, manual, revoked }

class SessionState {
  const SessionState({
    this.status = SessionStatus.unknown,
    this.user,
    this.tokenId,
    this.reason = SignOutReason.none,
  });

  final SessionStatus status;
  final User? user;

  /// This device's token id; a `session.revoked` event naming it signs this device out.
  final int? tokenId;
  final SignOutReason reason;

  bool get hasAccount => status == SessionStatus.signedIn || status == SessionStatus.unverified;

  SessionState copyWith({SessionStatus? status, User? user, int? tokenId, SignOutReason? reason}) =>
      SessionState(
        status: status ?? this.status,
        user: user ?? this.user,
        tokenId: tokenId ?? this.tokenId,
        reason: reason ?? this.reason,
      );
}

class SessionController extends Notifier<SessionState> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  SessionState build() {
    _api.onUnauthenticated = () {
      if (state.hasAccount) revoked();
    };
    // Keep Core's copy of the language in step, so emails follow the app.
    ref.listen(localeProvider.select((s) => s.code), (_, code) => _syncLocale(code));
    return const SessionState();
  }

  Future<void> restore() async {
    final saved = await ref.read(storageProvider).readSession();
    if (saved == null) {
      state = const SessionState(status: SessionStatus.signedOut);
      return;
    }
    _api.token = saved.token;
    try {
      final user = User.fromJson((await _api.get('me'))['user'] as Map<String, dynamic>);
      _signedIn(user, saved.tokenId);
    } on ApiException catch (e) {
      if (e.isNetwork || e.status >= 500) {
        state = SessionState(status: SessionStatus.unreachable, tokenId: saved.tokenId);
      } else {
        await _forget();
        state = const SessionState(status: SessionStatus.signedOut);
      }
    }
  }

  Future<void> login(String email, String password) async {
    final body = await _api.post('auth/login', {
      'email': email.trim(),
      'password': password,
      'device_name': await ref.read(deviceNameProvider.future),
    });
    await _accept(body);
  }

  Future<void> register(String name, String email, String password) async {
    final body = await _api.post('auth/register', {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'device_name': await ref.read(deviceNameProvider.future),
      'locale': ref.read(localeProvider).code,
    });
    await _accept(body);
  }

  /// Checks the code; the screen shows its success popup before [finishVerification].
  Future<User> verify(String code) async {
    final body = await _api.post('auth/email/verify', {'code': code});
    return User.fromJson(body['user'] as Map<String, dynamic>);
  }

  void finishVerification(User user) => _signedIn(user, state.tokenId);

  Future<void> resendCode() => _api.post('auth/email/resend');

  Future<void> refreshUser() async {
    if (!state.hasAccount) return;
    try {
      final user = User.fromJson((await _api.get('me'))['user'] as Map<String, dynamic>);
      state = state.copyWith(user: user);
    } on ApiException {
      // Keep the last known user; a revoked token is handled by onUnauthenticated.
    }
  }

  void updateUser(User user) => state = state.copyWith(user: user);

  Future<void> logout() async {
    try {
      await _api.post('auth/logout');
    } on ApiException {
      // Signing out locally still works offline.
    }
    await _forget();
    state = const SessionState(status: SessionStatus.signedOut, reason: SignOutReason.manual);
  }

  /// This device's token was revoked (another device, a password change, or a 401).
  Future<void> revoked() async {
    if (!state.hasAccount) return;
    await _forget();
    state = const SessionState(status: SessionStatus.signedOut, reason: SignOutReason.revoked);
  }

  /// Back on the sign-in screen after a password reset: nothing to remember.
  void acknowledgeSignOut() {
    if (state.reason != SignOutReason.none) {
      state = const SessionState(status: SessionStatus.signedOut);
    }
  }

  Future<void> _accept(Map<String, dynamic> body) async {
    final token = body['token'] as String;
    final tokenId = body['token_id'] as int;
    await ref.read(storageProvider).saveSession(token, tokenId);
    _api.token = token;
    _signedIn(User.fromJson(body['user'] as Map<String, dynamic>), tokenId);
    await _syncLocale(ref.read(localeProvider).code);
  }

  void _signedIn(User user, int? tokenId) {
    state = SessionState(
      status: user.emailVerified ? SessionStatus.signedIn : SessionStatus.unverified,
      user: user,
      tokenId: tokenId,
    );
  }

  Future<void> _forget() async {
    _api.token = null;
    _api.socketId = null;
    await ref.read(storageProvider).clearSession();
  }

  Future<void> _syncLocale(String code) async {
    final user = state.user;
    if (!state.hasAccount || user == null || user.locale == code) return;
    try {
      final body = await _api.patch('me', {'locale': code});
      state = state.copyWith(user: User.fromJson(body['user'] as Map<String, dynamic>));
    } on ApiException {
      // Tried again on the next sign-in or language change.
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);
