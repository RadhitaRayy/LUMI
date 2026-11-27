import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';

/// Extra room kept below a focused field so the button under it stays above the keyboard.
const fieldScrollPadding = EdgeInsets.fromLTRB(20, 20, 20, 160);

/// True while the on-screen keyboard is up.
bool keyboardOpen(BuildContext context) => MediaQuery.viewInsetsOf(context).bottom > 80;

/// Page for the sign-in flow.
///
/// The form scrolls; the footer (e.g. "No account yet?") sits pinned at the bottom and slides away
/// while the keyboard is open, so the fields and the main button keep the room. Tapping outside a
/// field closes the keyboard.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.children, this.onBack, this.footer, this.header});

  final List<Widget> children;
  final VoidCallback? onBack;
  final Widget? footer;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final typing = keyboardOpen(context);
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onBack != null || header != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 24, 0),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (onBack != null)
                          IconButton(
                            tooltip: context.l10n.back,
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          )
                        else
                          const SizedBox(width: 12),
                        if (header != null) Expanded(child: header!),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
              if (footer != null)
                AnimatedSize(
                  duration: Motion.of(context, const Duration(milliseconds: 200)),
                  curve: Motion.ease,
                  child: typing
                      ? const SizedBox(width: double.infinity)
                      : Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 12), child: footer),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthTitle extends StatelessWidget {
  const AuthTitle({super.key, required this.title, required this.subtitle, this.step = 0});

  final String title;
  final String subtitle;
  final int step;

  @override
  Widget build(BuildContext context) {
    final typing = keyboardOpen(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn.step(
          step,
          child: AnimatedDefaultTextStyle(
            duration: Motion.of(context, const Duration(milliseconds: 220)),
            curve: Motion.ease,
            style: AppText.heading(typing ? 24 : 30),
            child: Text(title),
          ),
        ),
        // The explanation steps aside while typing; the title is enough to stay oriented.
        AnimatedSize(
          duration: Motion.of(context, const Duration(milliseconds: 220)),
          curve: Motion.ease,
          child: typing
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FadeSlideIn.step(
                    step + 1,
                    child: Text(subtitle, style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.muted)),
                  ),
                ),
        ),
      ],
    );
  }
}

/// A rounded icon tile that gently sways (mail on the code screen, key on the reset screen).
/// It folds away while the keyboard is open.
class SwayingIcon extends StatefulWidget {
  const SwayingIcon({super.key, required this.icon});

  final IconData icon;

  @override
  State<SwayingIcon> createState() => _SwayingIconState();
}

class _SwayingIconState extends State<SwayingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && !_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tile = AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -6 * t),
          child: Transform.rotate(angle: (-4 + 8 * t) * 0.0174533, child: child),
        );
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(widget.icon, color: AppColors.accent, size: 30),
      ),
    );
    return AnimatedSize(
      duration: Motion.of(context, const Duration(milliseconds: 220)),
      curve: Motion.ease,
      alignment: Alignment.topLeft,
      child: keyboardOpen(context)
          ? const SizedBox(width: double.infinity)
          : Padding(padding: const EdgeInsets.only(bottom: 24), child: Align(alignment: Alignment.centerLeft, child: tile)),
    );
  }
}

/// Shows a coral error line that fades in.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(message!, style: const TextStyle(fontSize: 13, color: AppColors.danger, height: 1.4)),
              ),
            ),
    );
  }
}

String? requiredText(BuildContext context, String? value) =>
    (value == null || value.trim().isEmpty) ? context.l10n.fieldRequired : null;

String? emailText(BuildContext context, String? value) {
  final empty = requiredText(context, value);
  if (empty != null) return empty;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim()) ? null : context.l10n.emailInvalid;
}
