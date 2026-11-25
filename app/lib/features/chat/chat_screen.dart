import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'chat_widgets.dart';
import 'confirm_action_sheet.dart';
import 'demo_agent.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatItem> _items = MockData.initialChat();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _agent = DemoAgent();
  bool _thinking = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _items.add(UserMessage(text));
      _thinking = true;
    });
    _scrollToEnd();

    final reply = await _agent.reply(text);
    if (!mounted) return;
    setState(() {
      _items.addAll(reply);
      _thinking = false;
    });
    _scrollToEnd();
  }

  Future<void> _review(PendingAction action) async {
    final result = await showConfirmActionSheet(context, action);
    if (result == null || !mounted) return;

    if (result.alwaysAllow) {
      MockData.toolByName(action.tool)?.mode = PermissionMode.auto;
    }
    setState(() {
      action.status = result.approved
          ? ActionStatus.approved
          : ActionStatus.rejected;
      if (!result.approved) {
        _items.add(
          const AgentMessage(
            'Oke, aku batalkan. Bot tetap jalan seperti sekarang.',
          ),
        );
      } else {
        _thinking = true;
      }
    });
    _scrollToEnd();
    if (!result.approved) return;

    final done = await _agent.execute(action);
    if (!mounted) return;
    setState(() {
      _items.addAll(done);
      _thinking = false;
    });
    _scrollToEnd();
  }

  Future<void> _openVoice() async {
    final transcript = await Navigator.of(context)
        .pushNamed<String>(Routes.voice);
    if (transcript != null && transcript.isNotEmpty) {
      unawaited(_send(transcript));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Riwayat percakapan',
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Navigator.of(context).pushNamed(Routes.history),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lumi', style: AppText.heading(17)),
            const SizedBox(height: 2),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusDot(),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Terhubung ke ${MockData.hostName}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tools dan koneksi',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).pushNamed(Routes.tools),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                itemCount: _items.length + 2,
                separatorBuilder: (context, i) =>
                    SizedBox(height: _gapAfter(i)),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return const Center(
                      child: Text(
                        'Hari ini · 09.41',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    );
                  }
                  if (i == _items.length + 1) {
                    return _thinking
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: TypingIndicator(),
                          )
                        : const SizedBox.shrink();
                  }
                  return _buildItem(_items[i - 1]);
                },
              ),
            ),
            _QuickPrompts(onTap: _send),
            _Composer(controller: _input, onSend: _send, onVoice: _openVoice),
          ],
        ),
      ),
    );
  }

  /// Item agent yang berurutan dirapatkan (10), antar giliran dilonggarkan (18).
  double _gapAfter(int i) {
    if (i == 0 || i >= _items.length) return 18;
    final current = _items[i - 1];
    final next = _items[i];
    final sameTurn = current is! UserMessage && next is! UserMessage;
    return sameTurn ? 10 : 18;
  }

  Widget _buildItem(ChatItem item) => switch (item) {
    UserMessage(:final text) => UserBubble(text),
    AgentMessage(:final text) => AgentText(text),
    ToolCall() => ToolCallCard(item),
    PendingAction() => PendingActionCard(
      action: item,
      onReview: () => _review(item),
    ),
  };
}

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: MockData.quickPrompts.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = MockData.quickPrompts[i];
          return OutlinedButton(
            onPressed: () => onTap(label),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            child: Text(label),
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onVoice,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Lampirkan file',
              color: AppColors.muted,
              icon: const Icon(Icons.add_rounded),
              onPressed: () => showDemoSnack(
                context,
                'Lampiran belum tersedia di versi demo.',
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Tanya atau suruh Lumi…',
                  filled: false,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mode suara',
              icon: const Icon(Icons.mic_none_rounded),
              onPressed: onVoice,
            ),
            IconButton.filled(
              tooltip: 'Kirim',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.bg,
              ),
              icon: const Icon(Icons.arrow_upward_rounded),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}
