import 'dart:math';

import '../../data/mock_data.dart';
import '../../data/models.dart';

/// Agent palsu untuk versi demo: membalas berdasarkan kata kunci.
/// Nanti diganti dengan koneksi ke model AI + agent di laptop.
class DemoAgent {
  DemoAgent({this.latency = const Duration(milliseconds: 700)});

  final Duration latency;
  final _rng = Random();

  Future<List<ChatItem>> reply(String text) async {
    await Future<void>.delayed(latency);
    final t = text.toLowerCase();

    if (t.contains('restart')) {
      final target = t.contains('tele') ? 'tele-bot' : 'bot-discord';
      final action = PendingAction(
        tool: 'restart_bot',
        target: target,
        command: 'pm2 restart $target',
        host: '${MockData.hostName} · via Tailscale',
        reason: 'Kamu minta restart',
        impact: 'Bot offline beberapa detik',
      );
      if (MockData.toolByName('restart_bot')?.mode == PermissionMode.auto) {
        action.status = ActionStatus.approved;
        return [
          const AgentMessage('Siap, restart_bot sudah kamu izinkan otomatis.'),
          ...await execute(action),
        ];
      }
      return [
        const AgentMessage(
          'Oke. Restart mengubah kondisi sistem, jadi aku minta izin dulu ya.',
        ),
        action,
      ];
    }

    if (t.contains('log') || t.contains('error')) {
      return [
        ToolCall(
          tool: 'baca_log',
          took: _took(),
          rows: const [
            ('bot-discord', '2 warning · 0 error'),
            ('tele-bot', '0 warning · 0 error'),
          ],
        ),
        const AgentMessage(
          'Log 12 jam terakhir bersih. Ada 2 warning rate-limit di bot Discord '
          'sekitar jam 08.50, sudah pulih sendiri.',
        ),
      ];
    }

    if (t.contains('status') || t.contains('jalan') || t.contains('bot')) {
      return [
        ToolCall(
          tool: 'cek_status_bot',
          took: _took(),
          rows: const [
            ('tele-bot', 'online · 3j 20m'),
            ('bot-discord', 'online · 1j 12m'),
          ],
        ),
        const AgentMessage('Semua bot online dan sehat.'),
      ];
    }

    if (t.contains('catat')) {
      return [
        ToolCall(tool: 'catatan', took: _took(), rows: const []),
        const AgentMessage('Catatan baru siap. Mau aku isi apa?'),
      ];
    }

    return const [
      AgentMessage(
        'Ini masih versi demo, jadi aku baru paham soal status bot, log, '
        'restart, dan catatan. Nanti aku disambungkan ke model AI sungguhan.',
      ),
    ];
  }

  Future<List<ChatItem>> execute(PendingAction action) async {
    await Future<void>.delayed(latency * 1.5);
    return [
      ToolCall(
        tool: action.tool,
        took: const Duration(milliseconds: 2400),
        rows: [(action.target, 'online · baru saja')],
      ),
      AgentMessage(
        'Beres. ${action.target} sudah jalan lagi. Kabari kalau masih lemot.',
      ),
    ];
  }

  Duration _took() => Duration(milliseconds: 400 + _rng.nextInt(900));
}
