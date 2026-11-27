import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/locale_controller.dart';
import '../../state/server_url_controller.dart';
import '../../state/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/lumi_cat.dart';
import '../../widgets/ui.dart';
import '../auth/server_sheet.dart';

/// The cat pops in, its lantern lights up, the wordmark rises and the i-dot drops in.
/// Meanwhile the saved session is checked; tap anywhere to skip once it is ready.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  var _restored = false;
  var _left = false;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) _maybeLeave();
    });
    unawaited(_restore());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _intro.value = 1;
      _maybeLeave();
    } else if (!_intro.isAnimating && !_intro.isCompleted) {
      _intro.forward();
      _ambient.repeat();
    }
  }

  Future<void> _restore() async {
    await ref.read(serverUrlProvider.notifier).load();
    await ref.read(localeProvider.notifier).load();
    await ref.read(sessionProvider.notifier).restore();
    if (!mounted) return;
    setState(() => _restored = true);
    _maybeLeave();
  }

  Future<void> _retry() async {
    setState(() => _restored = false);
    await ref.read(sessionProvider.notifier).restore();
    if (!mounted) return;
    setState(() => _restored = true);
    _maybeLeave(force: true);
  }

  void _maybeLeave({bool force = false}) {
    if (_left || !_restored) return;
    if (!force && !_intro.isCompleted) return;
    final status = ref.read(sessionProvider).status;
    if (status == SessionStatus.unreachable || status == SessionStatus.unknown) return;
    _left = true;
    AppRouter.ready = true;
    Navigator.of(context).pushReplacement(lumiRoute<void>(AppRouter.screenFor(status), fadeOnly: true));
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  double _phase(double begin, double end, [Curve curve = Curves.linear]) =>
      curve.transform(((_intro.value - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final unreachable = _restored && ref.watch(sessionProvider).status == SessionStatus.unreachable;

    return Scaffold(
      body: Semantics(
        button: true,
        label: l.splashSkip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _maybeLeave(force: true),
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _ambient]),
            builder: (context, _) {
              final pop = _phase(0, 0.25, Curves.easeOutBack);
              final lamp = _phase(0.22, 0.38, Curves.easeOut);
              final sparkIn = _phase(0.3, 0.42, Curves.easeOut);
              final sparkOut = _phase(0.5, 0.64);
              final word = _phase(0.4, 0.6, Motion.ease);
              final dot = _phase(0.55, 0.74, Curves.bounceOut);
              final tag = _phase(0.68, 0.86, Motion.ease);
              final loader = _phase(0.9, 1);

              return Stack(
                children: [
                  ..._fireflies(context),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: pop.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 40 * (1 - pop)),
                            child: Transform.scale(
                              scale: 0.5 + 0.5 * pop,
                              child: LumiCat(
                                size: 200,
                                lampLit: lamp,
                                sparks: sparkIn * (1 - sparkOut),
                                semanticLabel: l.catWaving,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Opacity(
                          opacity: word,
                          child: Transform.translate(
                            offset: Offset(0, 28 * (1 - word)),
                            child: LumiWordmark(size: 72, dotDrop: 70 * (1 - dot), dotOpacity: dot * 3),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Opacity(
                          opacity: tag,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - tag)),
                            child: Text(l.appTagline, style: const TextStyle(fontSize: 16, color: AppColors.muted)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 56 + MediaQuery.paddingOf(context).bottom,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: unreachable
                          ? Column(
                              key: const ValueKey('retry'),
                              children: [
                                Text(
                                  l.errorNetwork,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.muted, height: 1.5),
                                ),
                                const SizedBox(height: 12),
                                PrimaryButton(label: l.retry, onPressed: _retry),
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: () async {
                                    if (await showServerSheet(context) && mounted) _retry();
                                  },
                                  child: Text(l.serverChangeLink),
                                ),
                              ],
                            )
                          : Opacity(
                              key: const ValueKey('dots'),
                              opacity: _restored ? 0 : loader,
                              child: _LoaderDots(t: _ambient.value),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Four tiny lime squares drifting up, like fireflies around the lantern.
  List<Widget> _fireflies(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const flies = [(0.24, 0.66, 5.0, 0.1), (0.74, 0.71, 4.0, 0.38), (0.36, 0.77, 3.0, 0.65), (0.64, 0.64, 4.0, 0.82)];
    return [
      for (final (x, y, s, offset) in flies)
        Builder(
          builder: (_) {
            final t = (_ambient.value + offset) % 1;
            final opacity = t < 0.2 ? t / 0.2 * 0.9 : (1 - t) / 0.8 * 0.9;
            return Positioned(
              left: size.width * x,
              top: size.height * y - 180 * t,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0) * _phase(0.3, 0.5),
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(1)),
                ),
              ),
            );
          },
        ),
    ];
  }
}

class _LoaderDots extends StatelessWidget {
  const _LoaderDots({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Opacity(
              opacity: 0.25 + 0.75 * (0.5 + 0.5 * math.sin((t * 4 - i * 0.15) * 2 * math.pi)),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
      ],
    );
  }
}
