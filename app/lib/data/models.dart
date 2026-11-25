/// Model data untuk versi demo. Nanti diganti data asli dari agent di laptop.
library;

enum PermissionMode { auto, ask }

extension PermissionModeLabel on PermissionMode {
  String get label => switch (this) {
    PermissionMode.auto => 'Otomatis',
    PermissionMode.ask => 'Minta izin',
  };
}

class AgentTool {
  AgentTool({
    required this.name,
    required this.description,
    required this.mode,
  });

  final String name;
  final String description;
  PermissionMode mode;
}

/// Satu item di layar chat.
sealed class ChatItem {
  const ChatItem();
}

class UserMessage extends ChatItem {
  const UserMessage(this.text);
  final String text;
}

class AgentMessage extends ChatItem {
  const AgentMessage(this.text);
  final String text;
}

/// Hasil pemanggilan tool yang sudah selesai.
class ToolCall extends ChatItem {
  const ToolCall({required this.tool, required this.took, required this.rows});

  final String tool;
  final Duration took;

  /// Baris hasil: (nama, keterangan).
  final List<(String, String)> rows;
}

enum ActionStatus { waiting, approved, rejected }

/// Aksi yang mengubah sistem dan menunggu izin pengguna.
class PendingAction extends ChatItem {
  PendingAction({
    required this.tool,
    required this.target,
    required this.command,
    required this.host,
    required this.reason,
    required this.impact,
    this.status = ActionStatus.waiting,
  });

  final String tool;
  final String target;
  final String command;
  final String host;
  final String reason;
  final String impact;
  ActionStatus status;
}

class ChatSummary {
  const ChatSummary({
    required this.title,
    required this.time,
    required this.snippet,
    required this.tools,
  });

  final String title;
  final String time;
  final String snippet;
  final List<String> tools;
}

class ChatGroup {
  const ChatGroup(this.label, this.items);
  final String label;
  final List<ChatSummary> items;
}
