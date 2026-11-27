import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../data/models.dart';
import '../../state/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';

/// Six boxes for the email code: each digit pops in, a wrong code shakes the row.
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> with SingleTickerProviderStateMixin {
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  Timer? _timer;
  var _seconds = 60;
  var _busy = false;
  var _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 1) t.cancel();
      if (mounted) setState(() => _seconds = math.max(0, _seconds - 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(sessionProvider.notifier).verify(_code.text);
      if (!mounted) return;
      _focus.unfocus();
      await _showSuccess(user);
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _error = apiErrorText(context.l10n, e));
      _shake.forward(from: 0);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(sessionProvider.notifier).resendCode();
      if (!mounted) return;
      _code.clear();
      setState(() => _error = null);
      _startCountdown();
      showToast(context, context.l10n.codeResent);
    } on ApiException catch (e) {
      if (mounted) showToast(context, apiErrorText(context.l10n, e), success: false);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _showSuccess(User user) {
    final l = context.l10n;
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: _CheckBadge()),
            const SizedBox(height: 18),
            Text(l.verifiedTitle, textAlign: TextAlign.center, style: AppText.heading(22)),
            const SizedBox(height: 8),
            Text(
              l.verifiedBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: l.startChatting,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                ref.read(sessionProvider.notifier).finishVerification(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final email = ref.watch(sessionProvider.select((s) => s.user?.email)) ?? '';
    final digits = _code.text;
    final full = digits.length == 6;
    final time = '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}';

    return AuthScaffold(
      footer: Column(
        children: [
          Text(l.checkSpam, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.faint)),
          const SizedBox(height: 4),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            child: Text(l.useAnotherAccount),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 24),
        const FadeSlideIn(child: SwayingIcon(icon: Icons.mail_outline_rounded)),
        AuthTitle(title: l.verifyTitle, subtitle: l.verifyBody(email), step: 1),
        const SizedBox(height: 28),
        FadeSlideIn.step(
          3,
          child: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
              offset: Offset(math.sin(_shake.value * math.pi * 4) * 10 * (1 - _shake.value), 0),
              child: child,
            ),
            child: Stack(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _DigitBox(
                          key: ValueKey('$i-${i < digits.length ? digits[i] : ''}'),
                          digit: i < digits.length ? digits[i] : '',
                          active: i == digits.length && _focus.hasFocus && _error == null,
                          error: _error != null,
                        ),
                      ),
                    ],
                  ],
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _code,
                      focusNode: _focus,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        if (_error != null) setState(() => _error = null);
                        if (value.length == 6) _verify();
                      },
                      decoration: InputDecoration(counterText: '', labelText: l.verifyCodeLabel),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        FormError(_error),
        const SizedBox(height: 28),
        FadeSlideIn.step(
          4,
          child: PrimaryButton(label: l.verifyButton, loading: _busy, onPressed: full ? _verify : null),
        ),
        const SizedBox(height: 12),
        FadeSlideIn.step(
          5,
          child: Center(
            child: AnimatedSwitcher(
              duration: Motion.of(context, const Duration(milliseconds: 200)),
              child: _seconds > 0
                  ? Padding(
                      key: const ValueKey('wait'),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l.resendIn(time), style: const TextStyle(color: AppColors.muted)),
                    )
                  : TextButton(
                      key: const ValueKey('resend'),
                      onPressed: _resending ? null : _resend,
                      child: Text(l.resendCode),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({super.key, required this.digit, required this.active, required this.error});

  final String digit;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final border = error
        ? AppColors.danger
        : active
        ? AppColors.accent
        : digit.isNotEmpty
        ? AppColors.lamp
        : AppColors.border;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: digit.isEmpty ? 1 : 0.6, end: 1),
      duration: Motion.of(context, const Duration(milliseconds: 280)),
      curve: Motion.pop,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: AnimatedContainer(
        duration: Motion.of(context, const Duration(milliseconds: 200)),
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.5),
        ),
        child: digit.isEmpty && active
            ? const _Caret()
            : Text(digit, style: AppText.mono(24, weight: FontWeight.w600)),
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Opacity(
      opacity: _c.value < 0.5 ? 1 : 0,
      child: Container(width: 2, height: 26, color: AppColors.accent),
    ),
  );
}

/// A lime circle that pops in, then a check mark that draws itself.
class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, const Duration(milliseconds: 800)),
      builder: (context, t, _) {
        final ring = Motion.pop.transform((t / 0.55).clamp(0.0, 1.0));
        final check = Curves.easeOut.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
        return Transform.scale(
          scale: 0.4 + 0.6 * ring,
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            child: CustomPaint(painter: _CheckPainter(check)),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.3, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.72, size.height * 0.38);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = AppColors.bg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}
