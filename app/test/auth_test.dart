import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/core/api_client.dart';
import 'package:lumi/features/auth/login_screen.dart';
import 'package:lumi/features/auth/register_screen.dart';
import 'package:lumi/features/auth/verify_screen.dart';
import 'package:lumi/features/chat/chat_screen.dart';
import 'package:lumi/state/session_controller.dart';
import 'package:lumi/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  group('Sign-in & errors', () {
    testWidgets('valid credentials save session and route to ChatScreen', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedLocale: 'en');
      api.on('POST', 'auth/login', (call) {
        expect(call.body?['email'], 'radhita@example.com');
        expect(call.body?['password'], 'secret123');
        expect(call.body?['device_name'], 'Galaxy A56');
        return {
          'token': 'tok-123',
          'token_id': 7,
          'user': userJson(verified: true),
        };
      });

      await tester.pumpWidget(wrapFullApp(api: api, storage: storage, deviceName: 'Galaxy A56'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'radhita@example.com');
      await tester.enterText(fields.at(1), 'secret123');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(storage.savedToken, 'tok-123');
      expect(storage.savedTokenId, 7);
      expect(api.token, 'tok-123');
    });

    testWidgets('shows invalid_credentials and account_blocked errors', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedLocale: 'en');
      var blocked = false;
      api.on('POST', 'auth/login', (_) {
        if (blocked) {
          throw ApiException(status: 403, code: 'account_blocked');
        }
        throw ApiException(status: 401, code: 'invalid_credentials');
      });

      await tester.pumpWidget(wrapTestApp(child: const LoginScreen(), api: api, storage: storage));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'user@example.com');
      await tester.enterText(fields.at(1), 'wrongpass');
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.text('Wrong email or password.'), findsOneWidget);

      blocked = true;
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.text('Your account is blocked. Contact the Lumi admin.'), findsOneWidget);
    });

    testWidgets('shows 422 field validation errors inline', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedLocale: 'en');
      api.on('POST', 'auth/login', (_) {
        throw ApiException(
          status: 422,
          code: 'validation_error',
          fieldErrors: {
            'email': ['Email format is rejected by server.'],
          },
        );
      });

      await tester.pumpWidget(wrapTestApp(child: const LoginScreen(), api: api, storage: storage));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'user@example.com');
      await tester.enterText(fields.at(1), 'password123');
      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.text('Email format is rejected by server.'), findsOneWidget);
    });

    testWidgets('registration_closed shows dedicated message on RegisterScreen', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedLocale: 'en');
      api.on('POST', 'auth/register', (_) {
        throw ApiException(status: 403, code: 'registration_closed');
      });

      await tester.pumpWidget(wrapTestApp(child: const RegisterScreen(), api: api, storage: storage));
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Radhita');
      await tester.enterText(fields.at(1), 'radhita@example.com');
      await tester.enterText(fields.at(2), 'StrongPass123!');
      await tester.tap(find.text('Sign up and send code'));
      await tester.pump();

      expect(find.text('Sign-ups are closed right now. Try again later.'), findsOneWidget);
    });
  });

  group('Email verification', () {
    testWidgets('wrong code shows attempts left; valid code verifies and opens ChatScreen', (tester) async {
      setPhoneViewport(tester);
      final api = FakeApiClient();
      final storage = MemoryStorage(savedToken: 'tok-unv', savedTokenId: 11, savedLocale: 'en');
      api.on('GET', 'me', (_) => {'user': userJson(verified: false)});
      api.on('POST', 'auth/email/verify', (call) {
        if (call.body?['code'] == '111111') {
          throw ApiException(
            status: 422,
            code: 'code_invalid',
            body: {'attempts_left': 3},
          );
        }
        return {'user': userJson(verified: true)};
      });

      await tester.pumpWidget(wrapFullApp(api: api, storage: storage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(VerifyScreen), findsOneWidget);
      expect(find.text('Check your email'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '111111');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Wrong code. 3 attempts left.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '654321');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Email verified'), findsOneWidget);
      await tester.tap(find.text('Start chatting'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(containerOf(tester).read(sessionProvider).status, SessionStatus.signedIn);
    });
  });
}
