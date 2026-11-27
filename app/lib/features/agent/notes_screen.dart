import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/notes_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';

/// Lists, searches, creates, edits, and deletes personal notes synced with Core.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notesProvider.notifier).load(query: ''));
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 200) ref.read(notesProvider.notifier).loadMore();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(notesProvider.notifier).load(query: value.trim());
    });
  }

  Future<void> _openEditor([UserNote? existing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: const AnimationStyle(duration: Motion.sheet),
      builder: (_) => _NoteSheet(existing: existing),
    );
    if (saved == true && mounted) {
      showToast(context, context.l10n.noteSaved);
    }
  }

  Future<void> _delete(UserNote note) async {
    final l = context.l10n;
    final ok = await confirmSheet(
      context,
      title: l.noteDeleteTitle,
      body: l.noteDeleteBody(note.title),
      confirmLabel: l.delete,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(notesProvider.notifier).delete(note.id);
      if (mounted) showToast(context, l.noteDeleted);
    } on ApiException catch (e) {
      if (mounted) showToast(context, apiErrorText(l, e), success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.agentNotes), shape: const Border()),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bg,
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.noteAdd),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.notesSearchHint,
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () => ref.read(notesProvider.notifier).load(),
              child: _body(l, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l, NotesState state) {
    if (!state.loaded && state.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (state.items.isEmpty) {
      final searching = state.query.isNotEmpty;
      return ListView(
        padding: const EdgeInsets.fromLTRB(28, 60, 28, 32),
        children: [
          Icon(searching ? Icons.search_off_rounded : Icons.sticky_note_2_outlined, size: 42, color: AppColors.lamp),
          const SizedBox(height: 12),
          Text(
            searching ? l.noResultsTitle : l.notesEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            state.error != null ? apiErrorText(l, state.error!) : (searching ? l.noResultsBody : l.notesEmptyBody),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: state.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final note = state.items[i];
        return Panel(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _openEditor(note),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        note.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted),
                      ),
                      if (note.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final tag in note.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('#$tag', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: l.delete,
                color: AppColors.faint,
                onPressed: () => _delete(note),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoteSheet extends ConsumerStatefulWidget {
  const _NoteSheet({this.existing});

  final UserNote? existing;

  @override
  ConsumerState<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends ConsumerState<_NoteSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _content = TextEditingController(text: widget.existing?.content ?? '');
  late final _tags = TextEditingController(text: (widget.existing?.tags ?? const []).join(', '));
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _error = context.l10n.fieldRequired);
      return;
    }
    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ctrl = ref.read(notesProvider.notifier);
      if (widget.existing == null) {
        await ctrl.create(title: title, content: content, tags: tags);
      } else {
        await ctrl.update(widget.existing!.id, title: title, content: content, tags: tags);
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? l.noteAdd : l.noteEdit, style: AppText.heading(20)),
            const SizedBox(height: 14),
            LabeledField(
              label: l.noteTitleLabel,
              child: TextField(
                controller: _title,
                maxLength: 120,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l.noteTitleHint,
                  fillColor: AppColors.bg,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: l.noteContentLabel,
              child: TextField(
                controller: _content,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: l.noteContentHint,
                  fillColor: AppColors.bg,
                ),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: l.noteTagsLabel,
              child: TextField(
                controller: _tags,
                decoration: InputDecoration(
                  hintText: l.noteTagsHint,
                  fillColor: AppColors.bg,
                ),
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
      ),
    );
  }
}
