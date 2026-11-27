import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/verify_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/session_ended_dialog.dart';
import 'features/settings/network_log_screen.dart';
import 'features/splash/splash_screen.dart';
import 'l10n/gen/app_localizations.dart' show AppLocalizations;
import 'state/core_providers.dart';
import 'state/locale_controller.dart';
import 'state/realtime_controller.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';
import 'theme/motion.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Moves the whole app to the screen that fits the session (sign-in, email code, chat).
abstract final class AppRouter {
  /// False while the splash is showing; it decides the first screen itself.
  static var ready = false;

  static Widget screenFor(SessionStatus status) => switch (status) {
    SessionStatus.signedIn => const ChatScreen(),
    SessionStatus.unverified => const VerifyScreen(),
    _ => const LoginScreen(),
  };

  static void reset(SessionStatus status) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      lumiRoute<void>(screenFor(status), fadeOnly: true),
      (_) => false,
    );
  }
}

class LumiApp extends ConsumerStatefulWidget {
  const LumiApp({super.key});

  @override
  ConsumerState<LumiApp> createState() => _LumiAppState();
}

class _LumiAppState extends ConsumerState<LumiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) => ref.read(localeProvider.notifier).systemChanged();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(realtimeProvider.notifier).resume();
      ref.read(sessionProvider.notifier).refreshUser();
    }
  }

  Future<void> _onSession(SessionState? previous, SessionState next) async {
    if (!AppRouter.ready || previous == null || previous.status == next.status) return;

    if (next.status == SessionStatus.signedOut) {
      if (next.reason == SignOutReason.revoked) {
        final context = navigatorKey.currentContext;
        if (context != null) await showSessionEnded(context);
        ref.read(sessionProvider.notifier).acknowledgeSignOut();
      }
      AppRouter.reset(SessionStatus.signedOut);
    } else if (next.status == SessionStatus.unverified || next.status == SessionStatus.signedIn) {
      AppRouter.reset(next.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(realtimeProvider);
    ref.listen(sessionProvider, _onSession);
    final locale = ref.watch(localeProvider).locale;
    final showInspectorPill = ref.watch(inspectorOverlayProvider);
    final logStore = ref.watch(httpLogStoreProvider);

    return MaterialApp(
      title: 'Lumi',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      builder: (context, child) {
        if (!showInspectorPill || child == null) return child ?? const SizedBox.shrink();
        return Stack(
          children: [
            child,
            Positioned(
              right: 12,
              bottom: 88 + MediaQuery.paddingOf(context).bottom,
              child: ListenableBuilder(
                listenable: logStore,
                builder: (context, _) {
                  final hasErrors = logStore.errorCount > 0;
                  return Material(
                    color: AppColors.surfaceHigh,
                    elevation: 6,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: hasErrors ? AppColors.danger : AppColors.accent.withValues(alpha: 0.7),
                      ),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () {
                        if (NetworkLogScreen.isOpen) return;
                        navigatorKey.currentState?.push(lumiRoute<void>(const NetworkLogScreen()));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: hasErrors ? AppColors.danger : AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'HTTP · ${logStore.count}',
                              style: AppText.mono(12, weight: FontWeight.w700, color: AppColors.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      home: const SplashScreen(),
    );
  }
}
