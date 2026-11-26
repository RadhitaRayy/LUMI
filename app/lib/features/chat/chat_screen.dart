import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../state/chat_controller.dart';
import '../../state/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/lumi_cat.dart';
import '../../widgets/ui.dart';
import '../history/history_drawer.dart';
import '../session_ended_dialog.dart';
import '../settings/ai_key_screen.dart';
import '../settings/settings_screen.dart';
import 'chat_widgets.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final content = (text ?? _input.text).trim();
    if (content.isEmpty) return;
    _input.clear();
    try {
      await ref.read(chatProvider.notifier).send(content);
    } on ApiException catch (e) {
      if (!mounted) return;
      _input.text = content;
      if (e.code == 'quota_exceeded') {
        if (await showQuotaDialog(context) && mounted) {
          Navigator.of(context).push(lumiRoute<void>(const AiKeyScreen()));
        }
      } else {
        showToast(context, apiErrorText(context.l10n, e), success: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chat = ref.watch(chatProvider);
    final user = ref.watch(sessionProvider.select((s) => s.user));

    ref.listen(chatProvider.select((s) => s.gone), (_, gone) {
      if (gone) {
        showToast(context, l.chatGone, success: false);
        ref.read(chatProvider.notifier).startNew();
      }
    });

    final empty = chat.messages.isEmpty && !chat.loading;
    final canSend = _input.text.trim().isNotEmpty;

    return Scaffold(
      key: _scaffold,
      drawer: const HistoryDrawer(),
      drawerScrimColor: const Color(0x99050608),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              title: chat.title ?? l.newChatTitle,
              subtitle: user == null
                  ? ''
                  : user.usesOwnKey
                  ? l.usingOwnKey
                  : l.quotaLeft(user.quota.remaining),
              initial: user?.initial ?? '?',
              onMenu: () => _scaffold.currentState?.openDrawer(),
              onSettings: () => Navigator.of(context).push(lumiRoute<void>(const SettingsScreen())),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.of(context, const Duration(milliseconds: 250)),
                child: chat.loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                    : empty
                    ? _EmptyChat(key: const ValueKey('empty'), name: user?.name ?? '')
                    : _Messages(key: ValueKey(chat.conversationId ?? 'new'), state: chat),
              ),
            ),
            if (empty)
              _Suggestions(
                onPick: (prompt) => _send(prompt),
                items: [
                  (l.suggestionTrip, l.suggestionTripPrompt),
                  (l.suggestionEmail, l.suggestionEmailPrompt),
                  (l.suggestionExplain, l.suggestionExplainPrompt),
                ],
              ),
            _Composer(
              controller: _input,
              busy: chat.streaming,
              canSend: canSend,
              onSend: () => _send(),
              onStop: () => ref.read(chatProvider.notifier).stop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.onMenu,
    required this.onSettings,
  });

  final String title;
  final String subtitle;
  final String initial;
  final VoidCallback onMenu;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          IconButton(tooltip: l.openHistory, onPressed: onMenu, icon: const Icon(Icons.notes_rounded)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: Motion.of(context, const Duration(milliseconds: 220)),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.heading(16),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: l.openSettings,
            child: Pressable(
              onTap: onSettings,
              scale: 0.92,
              child: InkResponse(
                onTap: onSettings,
                radius: 24,
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.border,
                      child: Text(
                        initial,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Messages extends StatelessWidget {
  const _Messages({super.key, required this.state});

  final ChatState state;

  @override
  Widget build(BuildContext context) {
    final messages = state.messages;
    // Reversed so the newest message stays at the bottom while answers stream in.
    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final position = messages.length - 1 - index;
        return FadeSlideIn(
          key: ValueKey('m$position'),
          duration: Motion.message,
          offset: const Offset(0, 14),
          child: MessageView(message: messages[position]),
        );
      },
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeSlideIn(
              offset: const Offset(0, 30),
              child: LumiCat(size: 150, semanticLabel: l.catWaving),
            ),
            const SizedBox(height: 16),
            FadeSlideIn.step(
              2,
              child: Text(
                l.emptyChatTitle(name),
                textAlign: TextAlign.center,
                style: AppText.heading(22),
              ),
            ),
            const SizedBox(height: 8),
            FadeSlideIn.step(
              3,
              child: Text(
                l.emptyChatBody,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.items, required this.onPick});

  final List<(String, String)> items;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => FadeSlideIn(
          delay: Motion.stagger * (i + 4),
          offset: const Offset(16, 0),
          child: Pressable(
            onTap: () => onPick(items[i].$2),
            child: ActionChip(
              onPressed: () => onPick(items[i].$2),
              label: Text(items[i].$1),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              labelStyle: const TextStyle(fontSize: 13, color: AppColors.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.canSend,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool busy;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: l.messageHint,
                  semanticCounterText: l.messageFieldLabel,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: Motion.of(context, const Duration(milliseconds: 220)),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(parent: animation, curve: Motion.pop),
                child: RotationTransition(
                  turns: Tween(begin: -0.25, end: 0.0).animate(animation),
                  child: child,
                ),
              ),
              child: busy
                  ? _RoundButton(
                      key: const ValueKey('stop'),
                      tooltip: l.stopAnswer,
                      color: AppColors.text,
                      onTap: onStop,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(3)),
                      ),
                    )
                  : _RoundButton(
                      key: const ValueKey('send'),
                      tooltip: l.send,
                      color: canSend ? AppColors.accent : AppColors.lamp,
                      onTap: canSend ? onSend : null,
                      child: const Icon(Icons.arrow_upward_rounded, color: AppColors.bg, size: 22),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.tooltip, required this.color, required this.onTap, required this.child});

  final String tooltip;
  final Color color;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(dimension: 44, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}
