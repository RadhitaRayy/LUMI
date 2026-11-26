import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../state/core_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';

/// Three steps that slide sideways: email → code and new password → done.
class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key, this.email = ''});

  final String email;

  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  var _step = 1;
  var _forward = true;
  var _busy = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _go(int step) => setState(() {
    _forward = step > _step;
    _step = step;
    _error = null;
    _fieldErrors = const {};
  });

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? apiErrorText(context.l10n, e) : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _sendCode() {
    if (!_emailForm.currentState!.validate()) return;
    _run(() async {
      await ref.read(apiClientProvider).post('auth/password/forgot', {'email': _email.text.trim()});
      _go(2);
    });
  }

  void _save() {
    if (!_resetForm.currentState!.validate()) return;
    _run(() async {
      await ref.read(apiClientProvider).post('auth/password/reset', {
        'email': _email.text.trim(),
        'code': _code.text.trim(),
        'password': _password.text,
      });
      _go(3);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return AuthScaffold(
      onBack: _step == 2 ? () => _go(1) : () => Navigator.of(context).pop(),
      header: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 6,
                color: AppColors.line,
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: Motion.of(context, const Duration(milliseconds: 450)),
                  curve: Motion.ease,
                  widthFactor: _step / 3,
                  child: Container(color: AppColors.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(l.stepOf(_step, 3), style: AppText.mono(12, color: AppColors.muted)),
        ],
      ),
      children: [
        AnimatedSwitcher(
          duration: Motion.of(context, const Duration(milliseconds: 380)),
          switchInCurve: Motion.ease,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(_step);
            final from = incoming == _forward ? 0.25 : -0.25;
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: Offset(from, 0), end: Offset.zero).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(key: ValueKey(_step), child: _stepBody()),
        ),
      ],
    );
  }

  Widget _stepBody() {
    final t = context.l10n;
    switch (_step) {
      case 1:
        return Form(
          key: _emailForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: SwayingIcon(icon: Icons.key_rounded)),
              const SizedBox(height: 24),
              AuthTitle(title: t.forgotTitle, subtitle: t.forgotBody),
              const SizedBox(height: 24),
              LabeledField(
                label: t.emailLabel,
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) => _sendCode(),
                  decoration: InputDecoration(hintText: t.emailHint, errorText: _fieldErrors['email']?.first),
                  validator: (v) => emailText(context, v),
                ),
              ),
              FormError(_error),
              const SizedBox(height: 22),
              PrimaryButton(label: _busy ? t.sending : t.sendCode, loading: _busy, onPressed: _sendCode),
            ],
          ),
        );
      case 2:
        return Form(
          key: _resetForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              AuthTitle(title: t.resetTitle, subtitle: t.resetBody),
              const SizedBox(height: 22),
              LabeledField(
                label: t.codeLabel,
                child: TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppText.mono(18).copyWith(letterSpacing: 6),
                  decoration: InputDecoration(hintText: '000000', counterText: '', errorText: _fieldErrors['code']?.first),
                  validator: (v) => (v ?? '').length == 6 ? null : t.codeLabel,
                ),
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: t.newPasswordLabel,
                child: TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(hintText: t.passwordHint, errorText: _fieldErrors['password']?.first),
                  validator: (v) => (v ?? '').length < 8 ? t.passwordTooShort : null,
                ),
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: t.repeatPasswordLabel,
                child: TextFormField(
                  controller: _repeat,
                  obscureText: true,
                  onFieldSubmitted: (_) => _save(),
                  decoration: InputDecoration(hintText: t.repeatPasswordHint),
                  validator: (v) => v == _password.text ? null : t.passwordsDontMatch,
                ),
              ),
              FormError(_error),
              const SizedBox(height: 22),
              PrimaryButton(label: t.savePassword, loading: _busy, onPressed: _save),
            ],
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(top: 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: Motion.of(context, const Duration(milliseconds: 450)),
                  curve: Motion.pop,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(26)),
                    child: const Icon(Icons.lock_reset_rounded, size: 38, color: AppColors.bg),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(t.passwordChangedTitle, textAlign: TextAlign.center, style: AppText.heading(26)),
              const SizedBox(height: 8),
              Text(
                t.passwordChangedBody,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: t.goToSignIn, onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        );
    }
  }
}
