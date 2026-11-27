import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/lumi_cat.dart';
import '../../widgets/markdown_view.dart';
import '../../widgets/ui.dart';

/// One chat message. User messages sit right in a bubble; Lumi's answers sit left with the cat.
class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: const BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: SelectableText(message.content, style: const TextStyle(fontSize: 15, height: 1.45)),
          ),
        ),
      );
    }

    final streaming = message.status == MessageStatus.streaming;
    final waiting = streaming && message.content.isEmpty;
    final failed = message.status == MessageStatus.error;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Hop(active: streaming, child: const LumiCatIcon(size: 30)),
        const SizedBox(width: 8),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (waiting || message.content.isNotEmpty)
                  // Lumi's answer in a bubble; the corner by the cat is the small one.
                  AnimatedSize(
                    duration: Motion.of(context, const Duration(milliseconds: 160)),
                    alignment: Alignment.topLeft,
                    child: Container(
                      padding: waiting
                          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 6)
                          : const EdgeInsets.fromLTRB(15, 11, 15, 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        border: Border.all(color: AppColors.line),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: waiting
                          ? Semantics(label: l.typing, child: const TypingDots())
                          : SelectionArea(
                              child: MarkdownView(
                                data: message.content,
                                trailing: streaming ? const _Caret() : null,
                              ),
                            ),
                    ),
                  ),
                if (message.status == MessageStatus.cancelled) ...[
                  const SizedBox(height: 6),
                  Text(l.stopped, style: const TextStyle(fontSize: 12, color: AppColors.warn)),
                ],
                if (failed) ...[
                  if (message.content.isNotEmpty) const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      (message.errorText?.isNotEmpty ?? false) ? message.errorText! : l.answerFailed,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.danger),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Opacity(
      opacity: Motion.reduced(context) || _c.value < 0.5 ? 1 : 0,
      child: Container(
        width: 7,
        height: 16,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(1)),
      ),
    ),
  );
}

/// Three dots bouncing one after another.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Builder(
                builder: (_) {
                  final t = (_c.value - i * 0.14) % 1;
                  final up = t < 0.3 ? math.sin(t / 0.3 * math.pi) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Transform.translate(
                      offset: Offset(0, -5 * up),
                      child: Opacity(
                        opacity: 0.35 + 0.65 * up,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Small bounce for the cat avatar while Lumi answers.
class _Hop extends StatefulWidget {
  const _Hop({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Hop> createState() => _HopState();
}

class _HopState extends State<_Hop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(_Hop old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    if (widget.active && !Motion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else if (_c.isAnimating) {
      _c.animateTo(0, duration: const Duration(milliseconds: 150));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform.translate(
      offset: Offset(0, -3 * math.sin(_c.value * math.pi)),
      child: child,
    ),
    child: widget.child,
  );
}
