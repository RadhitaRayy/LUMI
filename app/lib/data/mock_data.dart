import 'models.dart';

/// Data contoh untuk versi demo (belum tersambung ke laptop / model AI).
abstract final class MockData {
  static const hostName = 'Laragon-PC';

  static final List<AgentTool> tools = [
    AgentTool(
      name: 'cek_status_bot',
      description: 'Lihat status semua bot',
      mode: PermissionMode.auto,
    ),
    AgentTool(
      name: 'baca_log',
      description: 'Baca dan cari log bot',
      mode: PermissionMode.auto,
    ),
    AgentTool(
      name: 'catatan',
      description: 'Simpan dan cari catatan',
      mode: PermissionMode.auto,
    ),
    AgentTool(
      name: 'restart_bot',
      description: 'Restart bot lewat pm2',
      mode: PermissionMode.ask,
    ),
    AgentTool(
      name: 'jalankan_script',
      description: 'Jalankan script terdaftar',
      mode: PermissionMode.ask,
    ),
    AgentTool(
      name: 'git_pull',
      description: 'Tarik update lalu deploy',
      mode: PermissionMode.ask,
    ),
  ];

  static AgentTool? toolByName(String name) {
    for (final t in tools) {
      if (t.name == name) return t;
    }
    return null;
  }

  static List<ChatItem> initialChat() => [
    const UserMessage('bot telegram masih jalan nggak?'),
    const ToolCall(
      tool: 'cek_status_bot',
      took: Duration(milliseconds: 800),
      rows: [
        ('tele-bot', 'online · 3j 12m'),
        ('bot-discord', 'online · 1j 04m'),
      ],
    ),
    const AgentMessage(
      'Dua-duanya aman. Bot Telegram online sejak 3 jam lalu tanpa error, '
      'bot Discord juga jalan. Mau aku cek log terakhirnya?',
    ),
    const UserMessage('restart bot discord deh, tadi agak lemot'),
    const AgentMessage(
      'Oke. Restart mengubah kondisi sistem, jadi aku minta izin dulu ya.',
    ),
    restartDiscord(),
  ];

  static PendingAction restartDiscord() => PendingAction(
    tool: 'restart_bot',
    target: 'bot-discord',
    command: 'pm2 restart bot-discord',
    host: '$hostName · via Tailscale',
    reason: 'Kamu bilang bot lagi lemot',
    impact: 'Bot offline beberapa detik',
  );

  static const quickPrompts = [
    'Status semua bot',
    'Log error terakhir',
    'Catatan baru',
  ];

  static const chatGroups = [
    ChatGroup('Hari ini', [
      ChatSummary(
        title: 'Restart bot Discord',
        time: '09.41',
        snippet: 'Bot dimulai ulang dan kembali online.',
        tools: ['cek_status_bot', 'restart_bot'],
      ),
      ChatSummary(
        title: 'Ringkas error semalam',
        time: '07.15',
        snippet: 'Ada 3 timeout ke API, semuanya pulih sendiri.',
        tools: ['baca_log'],
      ),
    ]),
    ChatGroup('Kemarin', [
      ChatSummary(
        title: 'Ide konten minggu ini',
        time: '21.03',
        snippet: 'Lima ide video pendek soal tips coding.',
        tools: ['catatan'],
      ),
      ChatSummary(
        title: 'Deploy update tele-bot',
        time: '16.20',
        snippet: 'Tarik commit terbaru lalu restart.',
        tools: ['git_pull', 'restart_bot'],
      ),
    ]),
  ];

  static final List<String> memories = [
    'Bot berjalan di Laragon-PC dan dikelola pakai pm2',
    'Suka jawaban singkat dengan bahasa santai',
    'Proyek web utama pakai Laravel',
    'Kalau bot error, cek log dulu sebelum restart',
    'Rutin bikin konten video pendek',
  ];
}
