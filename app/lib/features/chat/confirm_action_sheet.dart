import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../theme/app_theme.dart';

class ConfirmResult {
  const ConfirmResult({required this.approved, required this.alwaysAllow});

  final bool approved;
  final bool alwaysAllow;
}

Future<ConfirmResult?> showConfirmActionSheet(
  BuildContext context,
  PendingAction action,
) {
  return showModalBottomSheet<ConfirmResult>(
    context: context,
    isScrollControlled: true,
    barrierColor: const Color(0xB8050608),
    builder: (_) => ConfirmActionSheet(action: action),
  );
}

class ConfirmActionSheet extends StatefulWidget {
  const ConfirmActionSheet({super.key, required this.action});

  final PendingAction action;

  @override
  State<ConfirmActionSheet> createState() => _ConfirmActionSheetState();
}

class _ConfirmActionSheetState extends State<ConfirmActionSheet> {
  bool _alwaysAllow = false;

  void _close(bool approved) {
    Navigator.of(context).pop(
      ConfirmResult(approved: approved, alwaysAllow: approved && _alwaysAllow),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.warn.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.warn,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Izinkan aksi ini?', style: AppText.heading(21)),
                      const SizedBox(height: 4),
                      const Text(
                        'Lumi ingin menjalankan perintah di laptopmu.',
                        style: TextStyle(fontSize: 14, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Tool',
                    child: Text(a.tool, style: AppText.mono(13)),
                  ),
                  _DetailRow(
                    label: 'Perintah',
                    stacked: true,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        a.command,
                        style: AppText.mono(13, color: AppColors.accent),
                      ),
                    ),
                  ),
                  _DetailRow(label: 'Target', child: Text(a.host)),
                  _DetailRow(label: 'Alasan', child: Text(a.reason)),
                  _DetailRow(
                    label: 'Dampak',
                    last: true,
                    child: Text(
                      a.impact,
                      style: const TextStyle(color: AppColors.warn),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: _alwaysAllow,
              onChanged: (v) => setState(() => _alwaysAllow = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 14),
                  children: [
                    const TextSpan(text: 'Selalu izinkan '),
                    TextSpan(text: a.tool, style: AppText.mono(13)),
                    const TextSpan(text: ' tanpa bertanya'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _close(false),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.surfaceHigh,
                    ),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _close(true),
                    child: const Text('Izinkan sekali'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Semua aksi tercatat di Riwayat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.child,
    this.stacked = false,
    this.last = false,
  });

  final String label;
  final Widget child;
  final bool stacked;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: const TextStyle(fontSize: 13, color: AppColors.muted),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 13),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [labelText, const SizedBox(height: 8), child],
              )
            : Row(
                children: [
                  labelText,
                  const SizedBox(width: 16),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: child,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
