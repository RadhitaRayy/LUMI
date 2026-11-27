import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../state/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).register(_name.text, _email.text, _password.text);
      // The router opens the email code screen.
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

  /// 0 = too short, 1 = okay, 2 = good, 3 = strong (same rules as the canvas).
  int _score(String pw) {
    if (pw.length < 8) return 0;
    var score = 1;
    if (RegExp('[0-9]').hasMatch(pw) && RegExp('[a-zA-Z]').hasMatch(pw)) score++;
    if (pw.length >= 12 || RegExp('[^a-zA-Z0-9]').hasMatch(pw)) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pw = _password.text;
    final score = _score(pw);
    final color = switch (score) { 3 => AppColors.accent, 2 => const Color(0xFFC9E07A), _ => AppColors.warn };
    final hint = pw.isEmpty
        ? l.pwStrengthEmpty
        : pw.length < 8
        ? l.pwStrengthShort(8 - pw.length)
        : [l.pwStrengthWeak, l.pwStrengthWeak, l.pwStrengthGood, l.pwStrengthStrong][score];

    return AuthScaffold(
      onBack: () => Navigator.of(context).pop(),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l.haveAccount, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.signIn)),
        ],
      ),
      children: [
        const SizedBox(height: 16),
        AuthTitle(title: l.registerTitle, subtitle: l.registerSubtitle),
        const SizedBox(height: 24),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn.step(
                  2,
                  child: LabeledField(
                    label: l.nameLabel,
                    child: TextFormField(
                      scrollPadding: fieldScrollPadding,
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.nickname],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(hintText: l.nameHint, errorText: _fieldErrors['name']?.first),
                      validator: (v) => requiredText(context, v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn.step(
                  3,
                  child: LabeledField(
                    label: l.emailLabel,
                    child: TextFormField(
                      scrollPadding: fieldScrollPadding,
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(hintText: l.emailHint, errorText: _fieldErrors['email']?.first),
                      validator: (v) => emailText(context, v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn.step(
                  4,
                  child: LabeledField(
                    label: l.passwordLabel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          scrollPadding: fieldScrollPadding,
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(hintText: l.passwordHint, errorText: _fieldErrors['password']?.first),
                          validator: (v) => (v ?? '').length < 8 ? l.passwordTooShort : null,
                        ),
                        const SizedBox(height: 10),
                        ExcludeSemantics(
                          child: Row(
                            children: [
                              for (var i = 0; i < 3; i++) ...[
                                if (i > 0) const SizedBox(width: 6),
                                Expanded(
                                  child: AnimatedContainer(
                                    duration: Motion.of(context, const Duration(milliseconds: 300)),
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: (i == 0 && pw.isNotEmpty) || (i > 0 && score > i) ? color : AppColors.line,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          child: AnimatedSwitcher(
                            duration: Motion.of(context, const Duration(milliseconds: 180)),
                            child: Text(
                              hint,
                              key: ValueKey(hint),
                              style: TextStyle(
                                fontSize: 12,
                                color: pw.isNotEmpty && pw.length < 8 ? AppColors.warn : AppColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FormError(_error),
                const SizedBox(height: 22),
                FadeSlideIn.step(
                  5,
                  child: PrimaryButton(label: l.registerButton, loading: _busy, onPressed: _submit),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
