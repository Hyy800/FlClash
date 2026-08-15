int _lastAiId = 0;

String _newAiId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  _lastAiId = now > _lastAiId ? now : _lastAiId + 1;
  return _lastAiId.toString();
}

enum AiApiProtocol {
  auto,
  openAiChat,
  openAiResponses,
  anthropic;

  String get label => switch (this) {
    auto => 'Auto',
    openAiChat => 'Chat Completions',
    openAiResponses => 'Responses',
    anthropic => 'Anthropic Messages',
  };

  static AiApiProtocol parse(String? value) {
    return AiApiProtocol.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AiApiProtocol.auto,
    );
  }
}

class AiSkill {
  static const maxContentLength = 32768;

  final String id;
  final String name;
  final String content;
  final bool enabled;
  final DateTime importedAt;

  AiSkill({
    String? id,
    required this.name,
    required this.content,
    this.enabled = true,
    DateTime? importedAt,
  }) : id = id ?? _newAiId(),
       importedAt = importedAt ?? DateTime.now() {
    if (name.trim().isEmpty) {
      throw const FormatException('Skill name cannot be empty.');
    }
    if (content.trim().isEmpty) {
      throw const FormatException('Skill content cannot be empty.');
    }
    if (content.length > maxContentLength) {
      throw const FormatException('Skill content is too large.');
    }
  }

  static String inferName(String content, {String fallback = 'Skill'}) {
    final frontMatterName = RegExp(
      r'''^---\s*[\r\n]+[\s\S]*?^name:\s*["']?([^\r\n"']+)''',
      multiLine: true,
    ).firstMatch(content)?.group(1)?.trim();
    if (frontMatterName?.isNotEmpty == true) return frontMatterName!;
    final heading = RegExp(
      r'^#{1,3}\s+(.+)$',
      multiLine: true,
    ).firstMatch(content)?.group(1)?.trim();
    return heading?.isNotEmpty == true ? heading! : fallback.trim();
  }

  AiSkill copyWith({String? name, String? content, bool? enabled}) {
    return AiSkill(
      id: id,
      name: name ?? this.name,
      content: content ?? this.content,
      enabled: enabled ?? this.enabled,
      importedAt: importedAt,
    );
  }

  factory AiSkill.fromJson(Map<String, dynamic> json) {
    return AiSkill(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Skill',
      content: json['content'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        json['importedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'content': content,
    'enabled': enabled,
    'importedAt': importedAt.millisecondsSinceEpoch,
  };
}

class AiConfig {
  final String baseUrl;
  final String apiKey;
  final String model;
  final AiApiProtocol protocol;
  final List<String> cachedModels;

  const AiConfig({
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.model = '',
    this.protocol = AiApiProtocol.auto,
    this.cachedModels = const [],
  });

  bool get isReady =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  AiApiProtocol get resolvedProtocol {
    if (protocol != AiApiProtocol.auto) {
      return protocol;
    }
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
    return host.contains('anthropic.com')
        ? AiApiProtocol.anthropic
        : AiApiProtocol.openAiChat;
  }

  AiConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    AiApiProtocol? protocol,
    List<String>? cachedModels,
  }) {
    return AiConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      protocol: protocol ?? this.protocol,
      cachedModels: cachedModels ?? this.cachedModels,
    );
  }

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    return AiConfig(
      baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com/v1',
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? '',
      protocol: AiApiProtocol.parse(json['protocol'] as String?),
      cachedModels: (json['cachedModels'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
    'protocol': protocol.name,
    'cachedModels': cachedModels,
  };
}

class AiAttachment {
  final String name;
  final String mimeType;
  final String data;
  final String text;

  const AiAttachment({
    required this.name,
    required this.mimeType,
    this.data = '',
    this.text = '',
  });

  bool get isImage => mimeType.startsWith('image/') && data.isNotEmpty;

  factory AiAttachment.fromJson(Map<String, dynamic> json) {
    return AiAttachment(
      name: json['name'] as String? ?? 'attachment',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      data: json['data'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'mimeType': mimeType,
    if (data.isNotEmpty) 'data': data,
    if (text.isNotEmpty) 'text': text,
  };
}

class AiChatMessage {
  final String id;
  final String role;
  final String content;
  final String reasoning;
  final List<AiAttachment> attachments;
  final DateTime createdAt;

  AiChatMessage({
    String? id,
    required this.role,
    required this.content,
    this.reasoning = '',
    this.attachments = const [],
    DateTime? createdAt,
  }) : id = id ?? _newAiId(),
       createdAt = createdAt ?? DateTime.now();

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      id: json['id'] as String?,
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      reasoning: json['reasoning'] as String? ?? '',
      attachments: (json['attachments'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => AiAttachment.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    if (reasoning.isNotEmpty) 'reasoning': reasoning,
    if (attachments.isNotEmpty)
      'attachments': attachments.map((item) => item.toJson()).toList(),
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  Map<String, dynamic> toApiJson() {
    final fileSections = attachments
        .where((item) => item.text.isNotEmpty)
        .map(
          (item) =>
              '<attached_file name="${item.name}">\n${item.text}\n</attached_file>',
        )
        .join('\n\n');
    final textContent = [
      if (content.trim().isNotEmpty) content,
      if (fileSections.isNotEmpty) fileSections,
    ].join('\n\n');
    final images = attachments.where((item) => item.isImage).toList();
    if (images.isEmpty) return {'role': role, 'content': textContent};
    return {
      'role': role,
      'content': [
        if (textContent.isNotEmpty) {'type': 'text', 'text': textContent},
        for (final image in images)
          {
            'type': 'image_url',
            'image_url': {'url': 'data:${image.mimeType};base64,${image.data}'},
          },
      ],
    };
  }
}

class AiSession {
  final String id;
  final String title;
  final String summary;
  final List<AiChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiSession({
    String? id,
    this.title = 'New chat',
    this.summary = '',
    this.messages = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? _newAiId(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  AiSession copyWith({
    String? title,
    String? summary,
    List<AiChatMessage>? messages,
    DateTime? updatedAt,
  }) {
    return AiSession(
      id: id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AiSession.fromJson(Map<String, dynamic> json) {
    return AiSession(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'New chat',
      summary: json['summary'] as String? ?? '',
      messages: (json['messages'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => AiChatMessage.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['updatedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'messages': messages.map((message) => message.toJson()).toList(),
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
}

class AiSessionStore {
  final String activeSessionId;
  final List<AiSession> sessions;

  AiSessionStore({required this.activeSessionId, required this.sessions});

  factory AiSessionStore.initial() {
    final session = AiSession();
    return AiSessionStore(activeSessionId: session.id, sessions: [session]);
  }

  AiSession get activeSession {
    return sessions.firstWhere(
      (session) => session.id == activeSessionId,
      orElse: () => sessions.first,
    );
  }

  bool get canReuseActiveSession =>
      activeSession.messages.isEmpty && activeSession.summary.trim().isEmpty;

  factory AiSessionStore.fromJson(Map<String, dynamic> json) {
    final sessions = (json['sessions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => AiSession.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    if (sessions.isEmpty) {
      return AiSessionStore.initial();
    }
    final requestedId = json['activeSessionId'] as String?;
    final activeId = sessions.any((session) => session.id == requestedId)
        ? requestedId!
        : sessions.first.id;
    return AiSessionStore(activeSessionId: activeId, sessions: sessions);
  }

  Map<String, dynamic> toJson() => {
    'activeSessionId': activeSessionId,
    'sessions': sessions.map((session) => session.toJson()).toList(),
  };
}
