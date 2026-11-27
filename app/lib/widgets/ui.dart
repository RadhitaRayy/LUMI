import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/api_client.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// A user-facing message for an API error: known codes are translated in the app,
/// anything else uses Core's message (already in the user's language).
String apiErrorText(AppLocalizations l, Object error) {
  if (error is! ApiException) return l.errorUnknown;
  return switch (error.code) {
    'network' => l.errorNetwork,
    'invalid_credentials' => l.errorInvalidCredentials,
    'account_blocked' => l.errorAccountBlocked,
    'registration_closed' => l.errorRegistrationClosed,
    'code_expired' => l.errorCodeExpired,
    'code_attempts_exceeded' => l.errorCodeAttempts,
    'too_many_requests' => l.errorTooManyRequests,
    'no_model_configured' => l.errorNoModel,
    'code_invalid' when error.body['attempts_left'] is int =>
      l.wrongCodeLeft(error.body['attempts_left'] as int),
    'code_invalid' => l.errorCodeInvalid,
    _ => error.message.isNotEmpty ? error.message : l.errorUnknown,
  };
}

/// "lumi" with a lime square for the dot of the i. [dotDrop] (px) and [dotOpacity] animate the dot.
class LumiWordmark extends StatelessWidget {
  const LumiWordmark({super.key, this.size = 34, this.dotDrop = 0, this.dotOpacity = 1});

  final double size;
  final double dotDrop;
  final double dotOpacity;

  @override
  Widget build(BuildContext context) {
    final style = AppText.logo(size);
    final dot = size * 0.17;
    return Semantics(
      label: 'lumi',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('lum', style: style),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Text('ı', style: style),
              Positioned(
                top: size * 0.06 - dotDrop,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: dotOpacity.clamp(0.0, 1.0),
                    child: Container(
                      width: dot,
                      height: dot,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(size * 0.03),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shrinks a little while pressed (0.97, 120 ms), like the buttons on the canvas.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _down = false;

  void _set(bool value) {
    if (widget.onTap != null && _down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.of(context, Motion.press),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Rises and fades in once, after [delay]: the staggered entrance used on every screen.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 18),
    this.duration = Motion.enter,
  });

  /// Index-based delay helper: `FadeSlideIn.step(2, child: ...)`.
  static FadeSlideIn step(int index, {Key? key, required Widget child}) =>
      FadeSlideIn(key: key, delay: Motion.stagger * index, child: child);

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Motion.ease);
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted || _timer != null) return;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FadeTransition fades on the compositor; no rebuild of the child per frame.
    return FadeTransition(
      opacity: _t,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) => Transform.translate(offset: widget.offset * (1 - _t.value), child: child),
        child: widget.child,
      ),
    );
  }
}

/// A label above a text field, the way the canvas draws them.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
  });

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.labelText),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// Lime button with a spinner while [loading].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.color = AppColors.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: loading ? null : onPressed,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.faint,
        ),
        onPressed: loading ? () {} : onPressed,
        child: AnimatedSwitcher(
          duration: Motion.of(context, const Duration(milliseconds: 180)),
          child: Row(
            key: ValueKey(loading),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.bg),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              if (icon != null && !loading) ...[const SizedBox(width: 8), Icon(icon, size: 18)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Outlined button; [danger] paints the label coral.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.danger = false});

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: danger ? AppColors.danger : AppColors.text,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// A rounded panel (cards on Settings, Devices, AI key).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = EdgeInsets.zero, this.borderColor});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.of(context, const Duration(milliseconds: 250)),
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? AppColors.line),
      ),
      child: child,
    );
  }
}

/// A small lime dot with a ring that keeps expanding: "live" / "new".
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, this.size = 8});

  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
    );
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, child) => Transform.scale(
              scale: 1 + 1.5 * _c.value,
              child: Opacity(opacity: (1 - _c.value) * 0.8, child: child),
            ),
            child: dot,
          ),
          dot,
        ],
      ),
    );
  }
}

/// A toast that slides down from the top and leaves by itself after 2.5 s.
void showToast(BuildContext context, String message, {bool success = true}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Toast(
      message: message,
      success: success,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.success, required this.onDone});

  final String message;
  final bool success;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 220),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future<void>.delayed(Motion.toast, () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Motion.ease);
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(curved),
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: widget.success ? AppColors.accent : AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.success ? Icons.check_rounded : Icons.priority_high_rounded,
                        size: 15,
                        color: AppColors.bg,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(widget.message, style: const TextStyle(fontSize: 14, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet asking to confirm; resolves to true when confirmed.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool danger = true,
}) async {
  final l = context.l10n;
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    sheetAnimationStyle: const AnimationStyle(duration: Motion.sheet),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.heading(20)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.muted)),
          const SizedBox(height: 18),
          PrimaryButton(
            label: confirmLabel,
            color: danger ? AppColors.danger : AppColors.accent,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          SecondaryButton(label: l.cancel, onPressed: () => Navigator.of(context).pop(false)),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// A centred dialog that grows from 0.92 while fading in (200 ms).
Future<T?> showLumiDialog<T>(
  BuildContext context, {
  required Widget child,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0xA8050608),
    transitionDuration: Motion.of(context, const Duration(milliseconds: 260)),
    pageBuilder: (context, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: const Cubic(0.2, 0.8, 0.2, 1.05));
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

/// An icon on a soft tinted square (settings rows, dialogs).
class TintIcon extends StatelessWidget {
  const TintIcon({super.key, required this.icon, required this.color, this.size = 36});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// "2 hours ago" in the app's language.
String relativeTime(AppLocalizations l, DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return l.timeJustNow;
  if (diff.inHours < 1) return l.timeMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l.timeHoursAgo(diff.inHours);
  return l.timeDaysAgo(diff.inDays);
}
