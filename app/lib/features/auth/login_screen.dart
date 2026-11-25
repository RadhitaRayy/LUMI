import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    // TODO: ganti dengan Firebase Auth / Supabase Auth.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(Routes.chat);
  }

  void _unlockWithBiometric() {
    // TODO: pakai package local_auth.
    Navigator.of(context).pushReplacementNamed(Routes.chat);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: LumiLogo(),
                  ),
                  const SizedBox(height: 22),
                  Text('Selamat datang lagi', style: AppText.heading(30)),
                  const SizedBox(height: 8),
                  const Text(
                    'Masuk untuk lanjut ngobrol dengan Lumi.',
                    style: TextStyle(fontSize: 15, color: AppColors.muted),
                  ),
                  const SizedBox(height: 36),
                  LabeledField(
                    label: 'Email',
                    child: TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: Validators.email,
                      decoration: const InputDecoration(
                        hintText: 'kamu@email.com',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Password',
                    child: PasswordField(
                      controller: _password,
                      validator: Validators.password,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => showDemoSnack(
                        context,
                        'Reset password belum tersedia di versi demo.',
                      ),
                      child: const Text('Lupa password?'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.bg,
                            ),
                          )
                        : const Text('Masuk'),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'atau',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _unlockWithBiometric,
                    icon: const Icon(Icons.fingerprint, size: 24),
                    label: const Text('Buka dengan sidik jari'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                    ),
                    onPressed: () => showDemoSnack(
                      context,
                      'Login Google belum tersedia di versi demo.',
                    ),
                    child: const Text('Lanjut dengan Google'),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Belum punya akun?',
                        style: TextStyle(fontSize: 14, color: AppColors.muted),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed(Routes.register),
                        child: const Text('Daftar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
