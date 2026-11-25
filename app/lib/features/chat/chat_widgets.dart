import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class UserBubble extends StatelessWidget {
  const UserBubble(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.45)),
        ),
      ),
    );
  }
}

class AgentText extends StatelessWidget {
  const AgentText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 15, height: 1.5));
  }
}

/// Kartu hasil pemanggilan tool.
class ToolCallCard extends StatelessWidget {
  const ToolCallCard(this.call, {super.key});

  final ToolCall call;

  @override
  Widget build(BuildContext context) {
    final seconds = (call.took.inMilliseconds / 1000)
        .toStringAsFixed(1)
        .replaceAll('.', ',');
    return OutlinedCard(
      color: AppColors.card,
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  call.tool,
                  style: AppText.mono(12, weight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  '$seconds dtk',
                  style: AppText.mono(12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (call.rows.isNotEmpty) ...[
            const Divider(color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                children: [
                  for (final (i, row) in call.rows.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.$1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.mono(12.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const StatusDot(),
                        const SizedBox(width: 6),
                        Text(
                          row.$2,
                          style: AppText.mono(12.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kartu aksi yang menunggu izin (atau sudah diputuskan).
class PendingActionCard extends StatelessWidget {
  const PendingActionCard({
    super.key,
    required this.action,
    required this.onReview,
  });

  final PendingAction action;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (action.status) {
      ActionStatus.waiting => (
        AppColors.warn,
        'Menunggu izin',
        Icons.shield_outlined,
      ),
      ActionStatus.approved => (
        AppColors.accent,
        'Diizinkan',
        Icons.check_rounded,
      ),
      ActionStatus.rejected => (
        AppColors.muted,
        'Ditolak',
        Icons.block_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${action.tool} · ${action.target}',
                  style: AppText.mono(13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (action.status == ActionStatus.waiting) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onReview,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warn,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Tinjau'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Indikator "Lumi sedang mengetik".
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Lumi sedang mengetik',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Opacity(
                opacity: _dotOpacity(i),
                child: const StatusDot(color: AppColors.muted, size: 7),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _dotOpacity(int i) {
    final t = (_c.value - i * 0.2) % 1.0;
    return t < 0.5 ? 0.3 + t * 1.4 : 1.0 - (t - 0.5) * 1.4;
  }
}
