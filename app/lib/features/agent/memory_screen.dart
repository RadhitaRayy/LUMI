import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/memories_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';

/// Lists, searches, adds, edits, and deletes per-user memories synced with Core.
class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(memoriesProvider.notifier).load(query: ''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(memoriesProvider.notifier).load(query: value.trim());
    });
  }

  Future<void> _openEditor([UserMemory? existing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: const AnimationStyle(duration: Motion.sheet),
      builder: (_) => _MemorySheet(existing: existing),
    );
    if (saved == true && mounted) {
      showToast(context, context.l10n.memorySaved);
    }
  }

  Future<void> _delete(UserMemory memory) async {
    final l = context.l10n;
    final ok = await confirmSheet(
      context,
      title: l.memoryDeleteTitle,
      body: l.memoryDeleteBody,
      confirmLabel: l.delete,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(memoriesProvider.notifier).delete(memory.id);
      if (mounted) showToast(context, l.memoryDeleted);
    } on ApiException catch (e) {
      if (mounted) showToast(context, apiErrorText(l, e), success: false);
    }
  }

  String _categoryLabel(AppLocalizations l, String category) => switch (category) {
    'preference' => l.memoryCategoryPreference,
    'context' => l.memoryCategoryContext,
    _ => l.memoryCategoryFact,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(memoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.agentMemory),
        shape: const Border(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('${state.count}/${state.limit}', style: AppText.mono(12, color: AppColors.muted)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: state.atLimit
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bg,
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.memoryAdd),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.memorySubtitle(state.limit),
                  style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.memorySearchHint,
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () => ref.read(memoriesProvider.notifier).load(),
              child: _body(l, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l, MemoriesState state) {
    if (!state.loaded && state.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (state.items.isEmpty) {
      final searching = state.query.isNotEmpty;
      return ListView(
        padding: const EdgeInsets.fromLTRB(28, 60, 28, 32),
        children: [
          Icon(searching ? Icons.search_off_rounded : Icons.psychology_alt_rounded, size: 42, color: AppColors.lamp),
          const SizedBox(height: 12),
          Text(
            searching ? l.noResultsTitle : l.memoryEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            state.error != null ? apiErrorText(l, state.error!) : (searching ? l.noResultsBody : l.memoryEmptyBody),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: state.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final memory = state.items[i];
        return Panel(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _openEditor(memory),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(memory.content, style: const TextStyle(fontSize: 15, height: 1.45)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _TagChip(label: _categoryLabel(l, memory.category), accent: true),
                          _TagChip(label: memory.fromAgent ? l.memorySourceLumi : l.memorySourceYou),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: l.delete,
                color: AppColors.faint,
                onPressed: () => _delete(memory),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent ? AppColors.accent.withValues(alpha: 0.12) : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accent ? AppColors.accent : AppColors.muted,
        ),
      ),
    );
  }
}

class _MemorySheet extends ConsumerStatefulWidget {
  const _MemorySheet({this.existing});

  final UserMemory? existing;

  @override
  ConsumerState<_MemorySheet> createState() => _MemorySheetState();
}

class _MemorySheetState extends ConsumerState<_MemorySheet> {
  late final _content = TextEditingController(text: widget.existing?.content ?? '');
  late var _category = widget.existing?.category ?? 'fact';
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _content.text.trim();
    if (text.isEmpty) {
      setState(() => _error = context.l10n.fieldRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ctrl = ref.read(memoriesProvider.notifier);
      if (widget.existing == null) {
        await ctrl.create(content: text, category: _category);
      } else {
        await ctrl.update(widget.existing!.id, content: text, category: _category);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = apiErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final categories = [
      ('fact', l.memoryCategoryFact),
      ('preference', l.memoryCategoryPreference),
      ('context', l.memoryCategoryContext),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? l.memoryAdd : l.memoryEdit, style: AppText.heading(20)),
          const SizedBox(height: 14),
          LabeledField(
            label: l.memoryContentLabel,
            child: TextField(
              controller: _content,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l.memoryContentHint,
                fillColor: AppColors.bg,
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: l.memoryCategoryLabel,
            child: Wrap(
              spacing: 8,
              children: [
                for (final (id, label) in categories)
                  ChoiceChip(
                    label: Text(label),
                    selected: _category == id,
                    onSelected: (_) => setState(() => _category = id),
                  ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: SecondaryButton(label: l.cancel, onPressed: () => Navigator.of(context).pop(false))),
              const SizedBox(width: 10),
              Expanded(child: PrimaryButton(label: l.save, loading: _saving, onPressed: _save)),
            ],
          ),
        ],
      ),
    );
  }
}
