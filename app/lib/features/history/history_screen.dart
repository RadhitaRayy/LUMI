import 'package:material_ui/material_ui.dart';

import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

enum _Tab { chats, memory }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Tab _tab = _Tab.chats;
  String _query = '';

  bool _matches(String text) =>
      _query.isEmpty || text.toLowerCase().contains(_query.toLowerCase());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 0,
        title: const Text('Riwayat'),
        actions: [
          IconButton(
            tooltip: 'Percakapan baru',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: _tab == _Tab.chats
                        ? 'Cari percakapan'
                        : 'Cari memori',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.muted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_Tab>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _Tab.chats,
                        label: Text('Percakapan'),
                      ),
                      ButtonSegment(value: _Tab.memory, label: Text('Memori')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: AppColors.border),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.selected)
                            ? AppColors.border
                            : AppColors.surface,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.selected)
                            ? AppColors.text
                            : AppColors.muted,
                      ),
                      textStyle: const WidgetStatePropertyAll(
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (_tab) {
              _Tab.chats => _buildChats(),
              _Tab.memory => _buildMemory(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChats() {
    final groups = [
      for (final g in MockData.chatGroups)
        ChatGroup(
          g.label,
          g.items.where((c) => _matches('${c.title} ${c.snippet}')).toList(),
        ),
    ].where((g) => g.items.isNotEmpty).toList();

    if (groups.isEmpty) {
      return const _Empty('Tidak ada percakapan yang cocok.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        for (final g in groups) ...[
          SectionLabel(g.label),
          const SizedBox(height: 8),
          for (final c in g.items) ...[_ChatTile(c), const SizedBox(height: 6)],
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildMemory() {
    final items = MockData.memories.where(_matches).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.07),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 20,
                color: AppColors.accent,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hal yang Lumi ingat dipakai untuk menjawab lebih tepat. '
                  'Semuanya tersimpan di HP dan bisa kamu hapus kapan saja.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const _Empty('Tidak ada memori yang cocok.')
        else
          OutlinedCard(
            child: Column(
              children: [
                for (final (i, m) in items.indexed) ...[
                  if (i > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            m,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus memori ini',
                          color: AppColors.muted,
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () =>
                              setState(() => MockData.memories.remove(m)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile(this.chat);

  final ChatSummary chat;

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      color: AppColors.card,
      radius: 14,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chat.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    chat.time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                chat.snippet,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 5),
              Text(
                chat.tools.join(' · '),
                style: AppText.mono(11.5, color: AppColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(text, style: const TextStyle(color: AppColors.muted)),
      ),
    );
  }
}
