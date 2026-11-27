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
  const MessageView({
    super.key,
    required this.message,
    this.onApproveAction,
    this.onRejectAction,
  });

  final ChatMessage message;
  final ValueChanged<PendingActionItem>? onApproveAction;
  final ValueChanged<PendingActionItem>? onRejectAction;

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
                if (message.toolCalls.isNotEmpty) ...[
                  for (final tc in message.toolCalls)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ToolCallCard(call: tc),
                    ),
                ],
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
                if (message.pendingAction != null) ...[
                  if (message.content.isNotEmpty || message.toolCalls.isNotEmpty) const SizedBox(height: 8),
                  PendingActionCard(
                    action: message.pendingAction!,
                    onApprove: onApproveAction == null ? null : () => onApproveAction!(message.pendingAction!),
                    onReject: onRejectAction == null ? null : () => onRejectAction!(message.pendingAction!),
                  ),
                ],
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

/// Compact inline card showing an agent tool execution inside a chat message.
class ToolCallCard extends StatefulWidget {
  const ToolCallCard({super.key, required this.call});

  final ToolCallItem call;

  @override
  State<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<ToolCallCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final hasSummary = call.summary.isNotEmpty;
    final color = call.isError ? AppColors.danger : AppColors.accent;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: call.isError ? AppColors.danger.withValues(alpha: 0.35) : AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: hasSummary ? () => setState(() => _expanded = !_expanded) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (call.isRunning)
                    const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    )
                  else
                    Icon(
                      call.isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                      size: 16,
                      color: color,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      call.label,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text),
                    ),
                  ),
                  if (hasSummary) ...[
                    const SizedBox(width: 6),
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 16,
                      color: AppColors.muted,
                    ),
                  ],
                ],
              ),
              if (_expanded && hasSummary) ...[
                const SizedBox(height: 6),
                Text(
                  call.summary,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline amber approval card for paused `ask`-mode tool actions.
/// Users can approve/reject directly or tap the card to inspect full details in [ConfirmActionSheet].
class PendingActionCard extends StatelessWidget {
  const PendingActionCard({
    super.key,
    required this.action,
    this.onApprove,
    this.onReject,
  });

  static const amber = Color(0xFFF5B544);

  final PendingActionItem action;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  Future<void> _openSheet(BuildContext context) async {
    final decision = await showConfirmActionSheet(context, action: action);
    if (decision == true) {
      onApprove?.call();
    } else if (decision == false) {
      onReject?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: amber.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: amber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.shield_outlined, size: 16, color: amber),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.actionApprovalBadge,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: amber),
                        ),
                        Text(
                          action.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: amber),
                ],
              ),
              if (action.summary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  action.summary,
                  style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.text),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: AppColors.text,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onReject,
                      child: Text(l.actionReject),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        backgroundColor: amber,
                        foregroundColor: AppColors.bg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onApprove,
                      child: Text(l.actionApprove),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet displaying full approval details before approving or rejecting a paused tool call.
/// Returns `true` to approve, `false` to reject, or `null` if dismissed.
Future<bool?> showConfirmActionSheet(
  BuildContext context, {
  required PendingActionItem action,
}) {
  final l = context.l10n;
  return showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    sheetAnimationStyle: const AnimationStyle(duration: Motion.sheet),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const TintIcon(icon: Icons.shield_outlined, color: PendingActionCard.amber, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.actionApprovalBadge,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PendingActionCard.amber,
                      ),
                    ),
                    Text(action.title, style: AppText.heading(19)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.all(14),
            borderColor: PendingActionCard.amber.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.summary,
                  style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.text),
                ),
                const SizedBox(height: 8),
                Text(
                  l.actionToolMeta(action.tool),
                  style: AppText.mono(12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l.actionExpiryHint,
            style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: l.actionApprove,
            color: PendingActionCard.amber,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: l.actionReject,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ),
  );
}
