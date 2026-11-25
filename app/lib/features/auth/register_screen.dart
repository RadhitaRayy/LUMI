import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _biometric = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
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
    Navigator.of(context)
        .pushNamedAndRemoveUntil(Routes.chat, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        shape: const Border(),
        leading: IconButton(
          tooltip: 'Kembali ke halaman masuk',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Buat akun', style: AppText.heading(30)),
                  const SizedBox(height: 8),
                  const Text(
                    'Cukup sekali. Setelah itu buka Lumi pakai sidik jari.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  LabeledField(
                    label: 'Nama panggilan',
                    child: TextFormField(
                      controller: _name,
                      autofillHints: const [AutofillHints.nickname],
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => Validators.required(v, 'Nama'),
                      decoration: const InputDecoration(
                        hintText: 'Biar Lumi tahu manggil kamu apa',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                      autofillHints: const [AutofillHints.newPassword],
                      validator: Validators.password,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 10),
                  PasswordStrengthMeter(password: _password.text),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _biometric,
                    onChanged: (v) => setState(() => _biometric = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Aktifkan buka dengan sidik jari / Face ID',
                      style: TextStyle(fontSize: 14),
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
                        : const Text('Buat akun'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Riwayat chat dan memori tetap tersimpan di perangkatmu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Sudah punya akun?',
                        style: TextStyle(fontSize: 14, color: AppColors.muted),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Masuk'),
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
