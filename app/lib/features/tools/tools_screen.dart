import 'package:material_ui/material_ui.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _memory = true;

  Future<void> _editPermission(AgentTool tool) async {
    final picked = await showModalBottomSheet<PermissionMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tool.name, style: AppText.mono(16, weight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                tool.description,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              for (final mode in PermissionMode.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(mode.label),
                  subtitle: Text(
                    mode == PermissionMode.auto
                        ? 'Lumi langsung menjalankan tanpa bertanya'
                        : 'Lumi minta persetujuanmu setiap kali',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  trailing: tool.mode == mode
                      ? const Icon(Icons.check_rounded, color: AppColors.accent)
                      : null,
                  onTap: () => Navigator.of(context).pop(mode),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => tool.mode = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 0,
        title: const Text('Tools & koneksi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionLabel('Koneksi'),
          const SizedBox(height: 10),
          OutlinedCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.laptop_rounded),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MockData.hostName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Tailscale · agent v0.1 · 42 ms',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusDot(),
                        SizedBox(width: 6),
                        Text(
                          'Online',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('Tools'),
                    SizedBox(height: 4),
                    Text(
                      'Aksi yang mengubah sistem selalu minta izin.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => showDemoSnack(
                  context,
                  'Tambah tool belum tersedia di versi demo.',
                ),
                child: const Text('+ Tambah'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedCard(
            child: Column(
              children: [
                for (final (i, tool) in MockData.tools.indexed) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    minTileHeight: 56,
                    contentPadding: const EdgeInsets.only(left: 14, right: 10),
                    title: Text(tool.name, style: AppText.mono(13.5)),
                    subtitle: Text(
                      tool.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PermissionBadge(tool.mode),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                    onTap: () => _editPermission(tool),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Model AI'),
          const SizedBox(height: 10),
          OutlinedCard(
            child: Column(
              children: [
                ListTile(
                  minTileHeight: 54,
                  contentPadding: const EdgeInsets.only(left: 14, right: 10),
                  title: const Text(
                    'Penyedia & model',
                    style: TextStyle(fontSize: 14),
                  ),
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Belum dipilih',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    ],
                  ),
                  onTap: () => showDemoSnack(
                    context,
                    'Pilih model akan tersedia setelah integrasi AI.',
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 14, right: 10),
                  value: _memory,
                  onChanged: (v) => setState(() => _memory = v),
                  title: const Text(
                    'Memori jangka panjang',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Disimpan lokal di perangkat',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
