import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../state/persona_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/lumi_cat.dart';
import '../../widgets/ui.dart';
import 'persona_screen.dart';

/// Dedicated Agent hub: Persona, Memory, Notes, and Tools — cleanly separate from account Settings.
class AgentScreen extends ConsumerWidget {
  const AgentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final personaAsync = ref.watch(personaProvider);
    final personaValue = personaAsync.when(
      data: (bundle) {
        if (!bundle.persona.isActive) return l.statusOff;
        return bundle.activePreset?.name ?? bundle.persona.preset;
      },
      loading: () => '',
      error: (_, _) => '',
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.agentMenu), shape: const Border()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          FadeSlideIn(
            child: Panel(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const LumiCatIcon(size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lumi ${l.agentMenu}', style: AppText.heading(18)),
                        const SizedBox(height: 4),
                        Text(
                          l.agentSubtitle,
                          style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn.step(
            1,
            child: Panel(
              child: Column(
                children: [
                  _AgentRow(
                    icon: Icons.auto_awesome_rounded,
                    color: AppColors.accent,
                    label: l.agentPersona,
                    value: personaValue,
                    onTap: () => Navigator.of(context).push(lumiRoute<void>(const PersonaScreen())),
                  ),
                  _AgentRow(
                    icon: Icons.psychology_alt_rounded,
                    color: AppColors.info,
                    label: l.agentMemory,
                    badge: l.comingSoon,
                    divider: true,
                  ),
                  _AgentRow(
                    icon: Icons.sticky_note_2_outlined,
                    color: AppColors.warn,
                    label: l.agentNotes,
                    badge: l.comingSoon,
                    divider: true,
                  ),
                  _AgentRow(
                    icon: Icons.handyman_rounded,
                    color: const Color(0xFFC9A7FF),
                    label: l.agentTools,
                    badge: l.comingSoon,
                    divider: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({
    required this.icon,
    required this.color,
    required this.label,
    this.value,
    this.badge,
    this.onTap,
    this.divider = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final String? badge;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? const Border(top: BorderSide(color: AppColors.divider)) : null,
      ),
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.62,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 62),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  TintIcon(icon: icon, color: color),
                  const SizedBox(width: 14),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(badge!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    )
                  else if (value != null && value!.isNotEmpty)
                    Text(value!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  if (enabled) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
