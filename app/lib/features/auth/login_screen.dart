import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../state/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/lumi_cat.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';
import 'forgot_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  var _shown = false;
  var _busy = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    // The cat covers its eyes while the password is typed.
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
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
      await ref.read(sessionProvider.notifier).login(_email.text, _password.text);
      // The router moves on to the chat (or the email code) from here.
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final peeking = _passwordFocus.hasFocus && !_shown;
    // While typing, the header shrinks so both fields and the button fit above the keyboard.
    final typing = keyboardOpen(context);
    final quick = Motion.of(context, const Duration(milliseconds: 240));

    return AuthScaffold(
      footer: FadeSlideIn.step(
        6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l.noAccount, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
            TextButton(
              onPressed: () => Navigator.of(context).push(lumiRoute<void>(const RegisterScreen())),
              child: Text(l.signUpFree),
            ),
          ],
        ),
      ),
      children: [
        AnimatedContainer(duration: quick, curve: Motion.ease, height: typing ? 4 : 40),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSize(
                      duration: quick,
                      curve: Motion.ease,
                      child: typing
                          ? const SizedBox(width: double.infinity)
                          : const Padding(
                              padding: EdgeInsets.only(bottom: 18),
                              child: FadeSlideIn(child: LumiWordmark(size: 34)),
                            ),
                    ),
                    FadeSlideIn.step(
                      1,
                      child: AnimatedDefaultTextStyle(
                        duration: quick,
                        curve: Motion.ease,
                        style: AppText.heading(typing ? 24 : 30),
                        child: Text(l.loginGreeting),
                      ),
                    ),
                    AnimatedSize(
                      duration: quick,
                      curve: Motion.ease,
                      child: typing
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: FadeSlideIn.step(
                                2,
                                child: Text(
                                  l.loginSubtitle,
                                  style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.muted),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              offset: const Offset(0, 40),
              duration: const Duration(milliseconds: 650),
              child: Transform.translate(
                offset: const Offset(0, 18),
                // The cat stays (and still covers its eyes) but gets smaller while typing.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: typing ? 84 : 124),
                  duration: quick,
                  curve: Motion.ease,
                  builder: (context, size, _) =>
                      LumiCat(size: size, eyesClosed: peeking, semanticLabel: l.catWaving),
                ),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line),
          ),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn.step(
                    3,
                    child: LabeledField(
                      label: l.emailLabel,
                      child: TextFormField(
                        controller: _email,
                        scrollPadding: fieldScrollPadding,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: l.emailHint,
                          fillColor: AppColors.bg,
                          errorText: _fieldErrors['email']?.first,
                        ),
                        validator: (v) => emailText(context, v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn.step(
                    4,
                    child: LabeledField(
                      label: l.passwordLabel,
                      trailing: TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 32)),
                        onPressed: () => Navigator.of(context).push(
                          lumiRoute<void>(ForgotScreen(email: _email.text.trim())),
                        ),
                        child: Text(l.forgotPasswordLink, style: const TextStyle(fontSize: 13)),
                      ),
                      child: TextFormField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        scrollPadding: fieldScrollPadding,
                        obscureText: !_shown,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: l.passwordHint,
                          fillColor: AppColors.bg,
                          errorText: _fieldErrors['password']?.first,
                          suffixIcon: IconButton(
                            tooltip: _shown ? l.hidePassword : l.showPassword,
                            onPressed: () => setState(() => _shown = !_shown),
                            icon: Icon(
                              _shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.muted,
                              size: 20,
                            ),
                          ),
                        ),
                        validator: (v) => requiredText(context, v),
                      ),
                    ),
                  ),
                  FormError(_error),
                  const SizedBox(height: 18),
                  FadeSlideIn.step(
                    5,
                    child: PrimaryButton(
                      label: l.signIn,
                      icon: Icons.arrow_forward_rounded,
                      loading: _busy,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
