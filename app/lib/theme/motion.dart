import 'package:material_ui/material_ui.dart';

/// Lumi's motion values (see the "Gerak Lumi" note on the design canvas).
abstract final class Motion {
  static const enter = Duration(milliseconds: 320);
  static const stagger = Duration(milliseconds: 60);
  static const press = Duration(milliseconds: 120);
  static const sheet = Duration(milliseconds: 280);
  static const dialog = Duration(milliseconds: 200);
  static const message = Duration(milliseconds: 220);
  static const toast = Duration(milliseconds: 2500);

  static const ease = Curves.easeOutCubic;
  static const pop = Cubic(0.3, 1.4, 0.5, 1);

  /// True when the phone asks for less motion; animations then jump to their end.
  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);

  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Page transition: the new screen fades in while rising a little.
Route<T> lumiRoute<T>(Widget page, {bool fadeOnly = false}) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 340),
  reverseTransitionDuration: const Duration(milliseconds: 260),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (context, animation, secondary, child) {
    if (Motion.reduced(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: Motion.ease);
    return FadeTransition(
      opacity: curved,
      child: fadeOnly
          ? child
          : SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
              child: child,
            ),
    );
  },
);
