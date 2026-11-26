import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../data/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/chat_controller.dart';
import '../../state/conversations_controller.dart';
import '../../state/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';
import '../settings/settings_screen.dart';

/// Slides in from the left: search, conversations grouped by day, delete with a confirm sheet.
class HistoryDrawer extends ConsumerStatefulWidget {
  const HistoryDrawer({super.key});

  @override
  ConsumerState<HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends ConsumerState<HistoryDrawer> {
  late final _search = TextEditingController(text: ref.read(conversationsProvider).query);
  final _scroll = ScrollController();
  final _removing = <String>{};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final state = ref.read(conversationsProvider);
    // Refresh every time the drawer opens; the list may have changed on another device.
    Future.microtask(() => ref.read(conversationsProvider.notifier).load(query: state.query));
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 200) ref.read(conversationsProvider.notifier).loadMore();
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
      ref.read(conversationsProvider.notifier).load(query: value.trim());
    });
  }

  void _open(Conversation conversation) {
    Navigator.of(context).pop();
    ref.read(chatProvider.notifier).open(conversation).catchError((Object e) {
      if (mounted) showToast(context, apiErrorText(context.l10n, e), success: false);
    });
  }

  Future<void> _delete(Conversation conversation, String title) async {
    final l = context.l10n;
    final ok = await confirmSheet(
      context,
      title: l.deleteChatTitle,
      body: l.deleteChatBody(title),
      confirmLabel: l.delete,
    );
    if (!ok || !mounted) return;
    setState(() => _removing.add(conversation.id));
    try {
      await Future.wait([
        ref.read(conversationsProvider.notifier).delete(conversation.id),
        Future<void>.delayed(Motion.of(context, const Duration(milliseconds: 280))),
      ]);
      if (ref.read(chatProvider).conversationId == conversation.id) {
        ref.read(chatProvider.notifier).startNew();
      }
      if (mounted) showToast(context, l.chatDeleted);
    } on ApiException catch (e) {
      if (mounted) showToast(context, apiErrorText(l, e), success: false);
    } finally {
      if (mounted) setState(() => _removing.remove(conversation.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(conversationsProvider);
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final groups = _group(l, state.items);

    return Drawer(
      width: 330,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(child: Text(l.historyTitle, style: AppText.heading(22))),
                  Pressable(
                    onTap: () {},
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        ref.read(chatProvider.notifier).startNew();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(l.newChatShort),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l.searchChats,
                  fillColor: AppColors.bg,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.accent,
                onRefresh: () => ref.read(conversationsProvider.notifier).load(),
                child: _body(l, state, groups),
              ),
            ),
            if (user != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.border,
                      child: Text(user.initial, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            user.usesOwnKey ? l.usingOwnKey : l.quotaLeft(user.quota.remaining),
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l.openSettings,
                      color: AppColors.muted,
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(lumiRoute<void>(const SettingsScreen()));
                      },
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l, ConversationsState state, List<_Group> groups) {
    if (!state.loaded && state.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (state.items.isEmpty) {
      final searching = state.query.isNotEmpty;
      return ListView(
        children: [
          FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Column(
                children: [
                  Icon(searching ? Icons.search_off_rounded : Icons.forum_outlined, size: 40, color: AppColors.lamp),
                  const SizedBox(height: 10),
                  Text(searching ? l.noResultsTitle : l.noChatsTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(
                    state.error != null ? apiErrorText(l, state.error!) : (searching ? l.noResultsBody : l.noChatsBody),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    var index = 0;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: Text(group.label.toUpperCase(), style: AppText.sectionLabel.copyWith(color: AppColors.faint)),
          ),
          for (final conversation in group.items)
            FadeSlideIn(
              key: ValueKey(conversation.id),
              delay: Duration(milliseconds: 80 + 40 * (index++).clamp(0, 10)),
              offset: const Offset(-14, 0),
              child: _Row(
                conversation: conversation,
                removing: _removing.contains(conversation.id),
                untitled: l.newChatTitle,
                onOpen: () => _open(conversation),
                onDelete: (title) => _delete(conversation, title),
              ),
            ),
        ],
        if (state.loading && state.loaded)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
      ],
    );
  }

  List<_Group> _group(AppLocalizations l, List<Conversation> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String labelFor(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      final diff = today.difference(day).inDays;
      if (diff <= 0) return l.groupToday;
      if (diff == 1) return l.groupYesterday;
      if (diff < 7) return l.groupLast7;
      return l.groupOlder;
    }

    final groups = <_Group>[];
    for (final c in items) {
      final label = labelFor(c.sortKey);
      if (groups.isEmpty || groups.last.label != label) groups.add(_Group(label, []));
      groups.last.items.add(c);
    }
    return groups;
  }
}

class _Group {
  _Group(this.label, this.items);

  final String label;
  final List<Conversation> items;
}

class _Row extends StatelessWidget {
  const _Row({
    required this.conversation,
    required this.removing,
    required this.untitled,
    required this.onOpen,
    required this.onDelete,
  });

  final Conversation conversation;
  final bool removing;
  final String untitled;
  final VoidCallback onOpen;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = (conversation.title?.isNotEmpty ?? false) ? conversation.title! : untitled;
    final duration = Motion.of(context, const Duration(milliseconds: 260));

    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOut,
      child: removing
          ? const SizedBox(width: double.infinity)
          : AnimatedOpacity(
              duration: duration,
              opacity: removing ? 0 : 1,
              child: _FreshGlow(
                fresh: conversation.fresh,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onOpen,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ),
                              if (conversation.fresh) ...[
                                const SizedBox(width: 8),
                                Semantics(label: l.newFromOtherDevice, child: const PulsingDot()),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.deleteChatA11y(title),
                      color: AppColors.faint,
                      onPressed: () => onDelete(title),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// A soft lime wash that pulses twice on conversations that just arrived from another device.
class _FreshGlow extends StatefulWidget {
  const _FreshGlow({required this.fresh, required this.child});

  final bool fresh;
  final Widget child;

  @override
  State<_FreshGlow> createState() => _FreshGlowState();
}

class _FreshGlowState extends State<_FreshGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.fresh && !Motion.reduced(context) && !_c.isAnimating && _c.value == 0) {
      _c.repeat(reverse: true, count: 4);
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
    builder: (_, child) => DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12 * _c.value),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    ),
    child: widget.child,
  );
}
