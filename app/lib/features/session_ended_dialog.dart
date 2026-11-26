import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../widgets/lumi_cat.dart';
import '../widgets/ui.dart';

/// "Session ended": this device was signed out elsewhere. A sleeping cat with floating z's.
Future<void> showSessionEnded(BuildContext context) {
  final l = context.l10n;
  return showLumiDialog<void>(
    context,
    dismissible: false,
    child: _CatDialog(
      sleepy: true,
      title: l.sessionEndedTitle,
      body: l.sessionEndedBody,
      actions: [PrimaryButton(label: l.signInAgain, onPressed: () => Navigator.of(context).pop())],
    ),
  );
}

/// "Today's quota is used up". Resolves to true when the user wants to set up their own key.
Future<bool> showQuotaDialog(BuildContext context) async {
  final l = context.l10n;
  final result = await showLumiDialog<bool>(
    context,
    child: Builder(
      builder: (context) => _CatDialog(
        sleepy: false,
        title: l.quotaTitle,
        body: l.quotaBody,
        actions: [
          PrimaryButton(label: l.setUpAiKey, onPressed: () => Navigator.of(context).pop(true)),
          const SizedBox(height: 4),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.text, minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.later),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

class _CatDialog extends StatelessWidget {
  const _CatDialog({required this.sleepy, required this.title, required this.body, required this.actions});

  final bool sleepy;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 150,
            height: 140,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                LumiCat(
                  size: 140,
                  sleepy: true,
                  waving: false,
                  lampLit: sleepy ? 0 : 0.25,
                  semanticLabel: context.l10n.catSleeping,
                ),
                if (sleepy) const Positioned(right: 4, top: 8, child: _Zzz()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: AppText.heading(22)),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        ...actions,
      ],
    );
  }
}

class _Zzz extends StatefulWidget {
  const _Zzz();

  @override
  State<_Zzz> createState() => _ZzzState();
}

class _ZzzState extends State<_Zzz> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

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
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => SizedBox(
          width: 40,
          height: 50,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (i, size) in [(0, 18.0), (1, 14.0), (2, 12.0)])
                Builder(
                  builder: (_) {
                    final t = (_c.value + i / 3) % 1;
                    return Positioned(
                      left: 18 * t,
                      top: 30 - 34 * t,
                      child: Opacity(
                        opacity: t < 0.3 ? t / 0.3 : (1 - t) / 0.7,
                        child: Text('z', style: AppText.heading(size).copyWith(color: AppColors.muted)),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
