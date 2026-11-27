DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

class Quota {
  const Quota({required this.dailyLimit, required this.usedToday, required this.remaining});

  factory Quota.fromJson(Map<String, dynamic> json) => Quota(
    dailyLimit: json['daily_limit'] as int? ?? 0,
    usedToday: json['used_today'] as int? ?? 0,
    remaining: json['remaining'] as int? ?? 0,
  );

  final int dailyLimit;
  final int usedToday;
  final int remaining;
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.locale,
    required this.emailVerified,
    required this.usesOwnKey,
    required this.quota,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    locale: json['locale'] as String? ?? 'id',
    emailVerified: json['email_verified'] as bool? ?? false,
    usesOwnKey: json['ai_key_source'] == 'user',
    quota: Quota.fromJson(json['quota'] as Map<String, dynamic>? ?? const {}),
  );

  final int id;
  final String name;
  final String email;
  final String locale;
  final bool emailVerified;
  final bool usesOwnKey;
  final Quota quota;

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

class Conversation {
  const Conversation({
    required this.id,
    this.title,
    this.lastMessageAt,
    this.createdAt,
    this.fresh = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    title: json['title'] as String?,
    lastMessageAt: _date(json['last_message_at']),
    createdAt: _date(json['created_at']),
  );

  final String id;
  final String? title;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  /// Arrived from another device while this one was open; shown with a pulsing dot.
  final bool fresh;

  DateTime get sortKey => lastMessageAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  Conversation copyWith({String? title, DateTime? lastMessageAt, bool? fresh}) => Conversation(
    id: id,
    title: title ?? this.title,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    createdAt: createdAt,
    fresh: fresh ?? this.fresh,
  );
}

enum MessageStatus { complete, streaming, error, cancelled }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.status = MessageStatus.complete,
    this.errorText,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: '${json['id']}',
    role: json['role'] == 'user' ? Role.user : Role.assistant,
    content: json['content'] as String? ?? '',
    status: switch (json['status']) {
      'error' => MessageStatus.error,
      'cancelled' => MessageStatus.cancelled,
      'streaming' => MessageStatus.streaming,
      _ => MessageStatus.complete,
    },
  );

  final String id;
  final Role role;
  final String content;
  final MessageStatus status;

  /// Why an answer failed, already in the user's language.
  final String? errorText;

  bool get isUser => role == Role.user;

  ChatMessage copyWith({String? id, String? content, MessageStatus? status, String? errorText}) =>
      ChatMessage(
        id: id ?? this.id,
        role: role,
        content: content ?? this.content,
        status: status ?? this.status,
        errorText: errorText ?? this.errorText,
      );
}

enum Role { user, assistant }

class Device {
  const Device({
    required this.id,
    required this.name,
    required this.isCurrent,
    this.lastUsedAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    isCurrent: json['is_current'] as bool? ?? false,
    lastUsedAt: _date(json['last_used_at']) ?? _date(json['created_at']),
  );

  final int id;
  final String name;
  final bool isCurrent;
  final DateTime? lastUsedAt;

  bool get looksLikeTablet => RegExp('ipad|tab', caseSensitive: false).hasMatch(name);
}

/// The three choices in "My AI key"; NVIDIA NIM is an OpenAI-compatible endpoint with a fixed URL.
enum AiProvider {
  openRouter('openrouter', null),
  nim('openai_compatible', 'https://integrate.api.nvidia.com/v1'),
  other('openai_compatible', null);

  const AiProvider(this.driver, this.fixedBaseUrl);

  final String driver;
  final String? fixedBaseUrl;

  static AiProvider of(String driver, String? baseUrl) {
    if (driver == 'openrouter') return AiProvider.openRouter;
    if (baseUrl != null && baseUrl.contains('nvidia.com')) return AiProvider.nim;
    return AiProvider.other;
  }
}

class AiKey {
  const AiKey({
    required this.provider,
    required this.modelId,
    required this.keyLast4,
    required this.isActive,
    this.baseUrl,
    this.lastValidatedAt,
    this.lastError,
  });

  factory AiKey.fromJson(Map<String, dynamic> json) => AiKey(
    provider: AiProvider.of(json['driver'] as String? ?? '', json['base_url'] as String?),
    baseUrl: json['base_url'] as String?,
    modelId: json['model_id'] as String? ?? '',
    keyLast4: json['key_last4'] as String? ?? '',
    isActive: json['is_active'] as bool? ?? false,
    lastValidatedAt: _date(json['last_validated_at']),
    lastError: json['last_error'] as String?,
  );

  final AiProvider provider;
  final String? baseUrl;
  final String modelId;
  final String keyLast4;
  final bool isActive;
  final DateTime? lastValidatedAt;
  final String? lastError;
}

class PersonaPreset {
  const PersonaPreset({required this.id, required this.name, required this.description});

  factory PersonaPreset.fromJson(Map<String, dynamic> json) => PersonaPreset(
    id: json['id'] as String? ?? 'santai',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );

  final String id;
  final String name;
  final String description;
}

class UserPersona {
  const UserPersona({
    required this.preset,
    required this.isActive,
    this.callMe,
    this.customInstructions,
    this.updatedAt,
  });

  factory UserPersona.fromJson(Map<String, dynamic> json) => UserPersona(
    preset: json['preset'] as String? ?? 'santai',
    callMe: json['call_me'] as String?,
    customInstructions: json['custom_instructions'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    updatedAt: _date(json['updated_at']),
  );

  final String preset;
  final String? callMe;
  final String? customInstructions;
  final bool isActive;
  final DateTime? updatedAt;
}

class PersonaBundle {
  const PersonaBundle({required this.persona, required this.presets});

  factory PersonaBundle.fromJson(Map<String, dynamic> json) => PersonaBundle(
    persona: UserPersona.fromJson(json['persona'] as Map<String, dynamic>? ?? const {}),
    presets: [
      for (final p in (json['presets'] as List? ?? const []))
        PersonaPreset.fromJson(p as Map<String, dynamic>),
    ],
  );

  final UserPersona persona;
  final List<PersonaPreset> presets;

  PersonaPreset? get activePreset => presets.where((p) => p.id == persona.preset).firstOrNull;
}

class UserMemory {
  const UserMemory({
    required this.id,
    required this.category,
    required this.content,
    required this.source,
    this.createdAt,
    this.updatedAt,
  });

  factory UserMemory.fromJson(Map<String, dynamic> json) => UserMemory(
    id: '${json['id']}',
    category: json['category'] as String? ?? 'fact',
    content: json['content'] as String? ?? '',
    source: json['source'] as String? ?? 'user',
    createdAt: _date(json['created_at']),
    updatedAt: _date(json['updated_at']),
  );

  final String id;
  final String category;
  final String content;
  final String source;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get fromAgent => source == 'agent';
}

class UserNote {
  const UserNote({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory UserNote.fromJson(Map<String, dynamic> json) => UserNote(
    id: '${json['id']}',
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    tags: [for (final t in (json['tags'] as List? ?? const [])) '$t'],
    createdAt: _date(json['created_at']),
    updatedAt: _date(json['updated_at']),
  );

  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
