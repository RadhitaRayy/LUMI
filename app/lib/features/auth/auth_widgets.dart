import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

/// Scrollable page for the sign-in flow, with an optional back button.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.children, this.onBack, this.footer, this.header});

  final List<Widget> children;
  final VoidCallback? onBack;
  final Widget? footer;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (onBack != null || header != null)
                      SizedBox(
                        height: 56,
                        child: Row(
                          children: [
                            if (onBack != null)
                              Transform.translate(
                                offset: const Offset(-12, 0),
                                child: IconButton(
                                  tooltip: context.l10n.back,
                                  onPressed: onBack,
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                                ),
                              ),
                            if (header != null) Expanded(child: header!),
                          ],
                        ),
                      ),
                    ...children,
                    const Spacer(),
                    if (footer != null) ...[const SizedBox(height: 24), footer!],
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

class AuthTitle extends StatelessWidget {
  const AuthTitle({super.key, required this.title, required this.subtitle, this.step = 0});

  final String title;
  final String subtitle;
  final int step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn.step(step, child: Text(title, style: AppText.heading(30))),
        const SizedBox(height: 8),
        FadeSlideIn.step(
          step + 1,
          child: Text(subtitle, style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.muted)),
        ),
      ],
    );
  }
}

/// A rounded icon tile that gently sways (mail on the code screen, key on the reset screen).
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
    if (!MediaQuery.disableAnimationsOf(context) && !_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
