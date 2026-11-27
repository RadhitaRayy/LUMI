import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/tools_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

/// Read-only overview of tools currently enabled for this user's account and their auto/ask policy.
class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  IconData _iconFor(String name) => switch (name) {
    'get_time' => Icons.schedule_rounded,
    'search_notes' => Icons.manage_search_rounded,
    'save_note' => Icons.note_add_outlined,
    'delete_note' => Icons.delete_sweep_outlined,
    'remember_memory' => Icons.psychology_alt_rounded,
    'forget_memory' => Icons.delete_outline_rounded,
    'web_search' => Icons.travel_explore_rounded,
    _ => Icons.handyman_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(toolsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.agentTools), shape: const Border()),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(apiErrorText(l, err), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
          ),
        ),
        data: (tools) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            FadeSlideIn(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l.toolsSubtitle,
                  style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.muted),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (tools.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text(l.toolsEmpty, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
              )
            else
              Panel(
                child: Column(
                  children: [
                    for (final (i, tool) in tools.indexed)
                      _ToolRow(
                        tool: tool,
                        icon: _iconFor(tool.name),
                        divider: i > 0,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.tool, required this.icon, required this.divider});

  final AgentToolInfo tool;
  final IconData icon;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final accent = tool.asksApproval ? AppColors.warn : AppColors.accent;
    return Container(
      decoration: BoxDecoration(
        border: divider ? const Border(top: BorderSide(color: AppColors.divider)) : null,
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintIcon(icon: icon, color: accent, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(tool.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tool.asksApproval ? l.toolModeAsk : l.toolModeAuto,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tool.description,
                  style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
