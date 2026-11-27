import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../../state/account_controllers.dart';
import '../../state/core_providers.dart';
import '../../state/locale_controller.dart';
import '../../state/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';
import 'ai_key_screen.dart';
import 'devices_screen.dart';
import 'network_log_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final aiKey = ref.watch(aiKeyProvider);
    final devices = ref.watch(devicesProvider);
    final locale = ref.watch(localeProvider);
    if (user == null) return const Scaffold();

    final keyStatus = aiKey.when(
      data: (key) => key == null ? l.notSet : (key.isActive ? l.statusOn : l.statusOff),
      loading: () => '',
      error: (_, _) => '',
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle), shape: const Border()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          FadeSlideIn(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.border,
                  child: Text(user.initial, style: AppText.heading(24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(user.name, overflow: TextOverflow.ellipsis, style: AppText.heading(20))),
                          const SizedBox(width: 6),
                          const _WavingHand(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(user.email, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                          if (user.emailVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_rounded, size: 11, color: AppColors.accent),
                                  const SizedBox(width: 3),
                                  Text(
                                    l.verified,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn.step(1, child: _QuotaCard(usesOwnKey: user.usesOwnKey, used: user.quota.usedToday, limit: user.quota.dailyLimit)),
          const SizedBox(height: 16),
          FadeSlideIn.step(
            2,
            child: Panel(
              child: Column(
                children: [
                  _Row(
                    icon: Icons.key_rounded,
                    color: AppColors.accent,
                    label: l.myAiKey,
                    value: keyStatus,
                    onTap: () => Navigator.of(context).push(lumiRoute<void>(const AiKeyScreen())),
                  ),
                  _Row(
                    icon: Icons.smartphone_rounded,
                    color: AppColors.info,
                    label: l.activeDevices,
                    value: devices.value == null ? '' : '${devices.value!.length}',
                    onTap: () => Navigator.of(context).push(lumiRoute<void>(const DevicesScreen())),
                  ),
                  _Row(
                    icon: Icons.translate_rounded,
                    color: const Color(0xFFC9A7FF),
                    label: l.language,
                    value: locale.choice == null ? l.languageFollowPhone : supportedLanguages[locale.choice]!,
                    onTap: () => _pickLanguage(context, ref),
                  ),
                  _Row(
                    icon: Icons.lock_outline_rounded,
                    color: AppColors.warn,
                    label: l.changePassword,
                    onTap: () => _changePassword(context, ref),
                  ),
                  ListenableBuilder(
                    listenable: ref.watch(httpLogStoreProvider),
                    builder: (context, _) {
                      final count = ref.read(httpLogStoreProvider).count;
                      return _Row(
                        icon: Icons.bug_report_outlined,
                        color: AppColors.info,
                        label: l.networkInspectorTitle,
                        value: count == 0 ? '' : '$count',
                        onTap: () => Navigator.of(context).push(lumiRoute<void>(const NetworkLogScreen())),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn.step(
            3,
            child: Pressable(
              onTap: () => _signOut(context, ref),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () => _signOut(context, ref),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(l.signOut),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn.step(
            4,
            child: Text(
              l.appVersionLine(AppConfig.appVersion),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.faint),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final current = ref.read(localeProvider).choice;
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: const AnimationStyle(duration: Motion.sheet),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.language, style: AppText.heading(20)),
            const SizedBox(height: 6),
            Text(l.languageNote, style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5)),
            const SizedBox(height: 12),
            for (final (code, label) in [
              ('system', l.languageFollowPhone),
              ...supportedLanguages.entries.map((e) => (e.key, e.value)),
            ])
              _LanguageOption(
                label: label,
                selected: (current ?? 'system') == code,
                onTap: () => Navigator.of(context).pop(code),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(localeProvider.notifier).choose(picked == 'system' ? null : picked);
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: const AnimationStyle(duration: Motion.sheet),
      builder: (context) => const _ChangePasswordSheet(),
    );
    if (changed == true && context.mounted) {
      showToast(context, context.l10n.passwordChangedToast);
      ref.invalidate(devicesProvider);
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showLumiDialog<bool>(
      context,
      child: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: TintIcon(icon: Icons.logout_rounded, color: AppColors.danger, size: 56)),
            const SizedBox(height: 14),
            Text(l.signOutTitle, textAlign: TextAlign.center, style: AppText.heading(20)),
            const SizedBox(height: 8),
            Text(
              l.signOutBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 18),
            PrimaryButton(label: l.signOut, color: AppColors.danger, onPressed: () => Navigator.of(context).pop(true)),
            const SizedBox(height: 4),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.text, minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.cancel),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await ref.read(sessionProvider.notifier).logout();
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.color, required this.label, required this.onTap, this.value});

  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              TintIcon(icon: icon, color: color),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
              if (value != null)
                AnimatedSwitcher(
                  duration: Motion.of(context, const Duration(milliseconds: 200)),
                  child: Text(value!, key: ValueKey(value), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, const Duration(milliseconds: 200)),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.1) : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.accent : AppColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: Motion.of(context, const Duration(milliseconds: 220)),
                    curve: Motion.pop,
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 22),
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

/// The daily quota as a ring that fills up when the screen opens.
class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.usesOwnKey, required this.used, required this.limit});

  final bool usesOwnKey;
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fraction = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    return Panel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          if (usesOwnKey)
            const TintIcon(icon: Icons.all_inclusive_rounded, color: AppColors.accent, size: 56)
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: Motion.of(context, const Duration(milliseconds: 1000)),
              curve: Motion.ease,
              builder: (context, value, _) => SizedBox.square(
                dimension: 68,
                child: CustomPaint(
                  painter: _RingPainter(value),
                  child: Center(child: Text('$used', style: AppText.mono(17, weight: FontWeight.w600))),
                ),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!usesOwnKey)
                  Text(l.quotaUsed(used, limit), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (!usesOwnKey) const SizedBox(height: 4),
                Text(
                  usesOwnKey ? l.ownKeyNote : l.quotaNote,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(4);
    final track = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        track
          ..color = value >= 1 ? AppColors.danger : AppColors.accent
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

class _WavingHand extends StatefulWidget {
  const _WavingHand();

  @override
  State<_WavingHand> createState() => _WavingHandState();
}

class _WavingHandState extends State<_WavingHand> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && _c.value == 0 && !_c.isAnimating) _c.repeat(count: 2);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform.rotate(
      angle: math.sin(_c.value * math.pi * 2) * 0.25,
      alignment: const Alignment(0.4, 0.6),
      child: child,
    ),
    child: const Icon(Icons.waving_hand_rounded, size: 18, color: Color(0xFFF2A65A)),
  );
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  var _busy = false;
  Map<String, List<String>> _errors = const {};
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errors = const {};
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).put('me/password', {
        'current_password': _current.text,
        'password': _next.text,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? apiErrorText(context.l10n, e) : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.changePassword, style: AppText.heading(20)),
            const SizedBox(height: 6),
            Text(l.changePasswordNote, style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5)),
            const SizedBox(height: 10),
            LabeledField(
              label: l.currentPasswordLabel,
              child: TextFormField(
                controller: _current,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(fillColor: AppColors.bg, errorText: _errors['current_password']?.first),
                validator: (v) => (v ?? '').isEmpty ? l.fieldRequired : null,
              ),
            ),
            const SizedBox(height: 10),
            LabeledField(
              label: l.newPasswordLabel,
              child: TextFormField(
                controller: _next,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  hintText: l.passwordHint,
                  fillColor: AppColors.bg,
                  errorText: _errors['password']?.first,
                ),
                validator: (v) => (v ?? '').length < 8 ? l.passwordTooShort : null,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: SecondaryButton(label: l.cancel, onPressed: () => Navigator.of(context).pop(false))),
                const SizedBox(width: 10),
                Expanded(child: PrimaryButton(label: l.save, loading: _busy, onPressed: _save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
