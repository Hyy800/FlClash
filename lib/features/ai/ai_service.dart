import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fl_clash/models/models.dart';

typedef AiToolHandler = Future<Map<String, dynamic>> Function(AiToolCall call);
typedef AiStreamCallback = void Function(String delta);

class AiToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final String rawArguments;
  final String? argumentError;

  const AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.rawArguments = '',
    this.argumentError,
  });

  factory AiToolCall.fromJson(Map<String, dynamic> json, {int index = 0}) {
    final function = Map<String, dynamic>.from(
      json['function'] as Map? ?? const {},
    );
    final name = (function['name'] ?? json['name'] ?? '').toString();
    final raw = function['arguments'] ?? json['arguments'] ?? json['input'];
    final rawText = raw is String ? raw : jsonEncode(raw ?? const {});
    Map<String, dynamic> arguments = const {};
    String? error;
    try {
      arguments = raw is Map
          ? Map<String, dynamic>.from(raw)
          : Map<String, dynamic>.from(jsonDecode(rawText) as Map);
    } catch (exception) {
      error = exception.toString();
    }
    return AiToolCall(
      id: (json['id'] ?? json['call_id'] ?? 'call_${name}_$index').toString(),
      name: name,
      arguments: arguments,
      rawArguments: rawText,
      argumentError: error,
    );
  }
}

class AiCompletion {
  final Map<String, dynamic> message;
  final List<AiToolCall> toolCalls;

  const AiCompletion({required this.message, required this.toolCalls});

  String get content => AiApiService.extractText(message['content']).trim();
}

class AiApiService {
  final Dio _dio;

  AiApiService({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 120),
              sendTimeout: const Duration(seconds: 30),
            ),
          );

  static String normalizeBaseUrl(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  static String endpoint(String baseUrl, String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '${normalizeBaseUrl(baseUrl)}$normalizedPath';
  }

  static List<String> parseModelIds(dynamic data) {
    final decoded = data is String ? jsonDecode(data) : data;
    final map = Map<String, dynamic>.from(decoded as Map? ?? const {});
    final models = map['data'] as List? ?? map['models'] as List? ?? const [];
    return models
        .whereType<Map>()
        .map((item) => (item['id'] ?? item['name'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  static String extractText(dynamic value) {
    if (value is String) return value;
    if (value is List) {
      return value.map(extractText).where((item) => item.isNotEmpty).join();
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const [
        'text',
        'output_text',
        'content',
        'value',
        'reasoning_content',
      ]) {
        final text = extractText(map[key]);
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  Options _options(AiConfig config, {bool stream = false}) {
    final anthropic = config.resolvedProtocol == AiApiProtocol.anthropic;
    return Options(
      responseType: stream ? ResponseType.stream : ResponseType.json,
      headers: {
        if (anthropic) ...{
          'x-api-key': config.apiKey.trim(),
          'anthropic-version': '2023-06-01',
        } else
          'Authorization': 'Bearer ${config.apiKey.trim()}',
        'Content-Type': 'application/json',
        if (stream) 'Accept': 'text/event-stream',
      },
    );
  }

  Future<List<String>> fetchModels(AiConfig config) async {
    final response = await _dio.get<dynamic>(
      endpoint(config.baseUrl, 'models'),
      options: _options(config),
    );
    return parseModelIds(response.data);
  }

  Future<void> testModel(AiConfig config) async {
    final result = await createCompletion(config, const [
      {'role': 'user', 'content': 'Reply with OK.'},
    ]);
    if (result.content.isEmpty && result.toolCalls.isEmpty) {
      throw StateError('The selected model returned no usable content.');
    }
  }

  Future<AiCompletion> createCompletion(
    AiConfig config,
    List<Map<String, dynamic>> messages, {
    List<Map<String, dynamic>> tools = const [],
    AiStreamCallback? onDelta,
  }) async {
    final streamed = await _create(
      config,
      messages,
      tools: tools,
      stream: onDelta != null,
      onDelta: onDelta,
    );
    if (streamed.content.isNotEmpty || streamed.toolCalls.isNotEmpty) {
      return streamed;
    }
    if (onDelta != null) {
      final fallback = await _create(config, messages, tools: tools);
      if (fallback.content.isNotEmpty || fallback.toolCalls.isNotEmpty) {
        if (fallback.content.isNotEmpty) onDelta(fallback.content);
        return fallback;
      }
    }
    throw StateError(
      '${config.resolvedProtocol.label} returned neither text nor tool calls. '
      'Check the endpoint, protocol, model permissions, and provider logs.',
    );
  }

  Future<AiCompletion> _create(
    AiConfig config,
    List<Map<String, dynamic>> messages, {
    List<Map<String, dynamic>> tools = const [],
    bool stream = false,
    AiStreamCallback? onDelta,
  }) {
    return switch (config.resolvedProtocol) {
      AiApiProtocol.openAiResponses => _createResponses(
        config,
        messages,
        tools,
        stream,
        onDelta,
      ),
      AiApiProtocol.anthropic => _createAnthropic(
        config,
        messages,
        tools,
        stream,
        onDelta,
      ),
      AiApiProtocol.auto || AiApiProtocol.openAiChat => _createChat(
        config,
        messages,
        tools,
        stream,
        onDelta,
      ),
    };
  }

  Future<AiCompletion> _createChat(
    AiConfig config,
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
    bool stream,
    AiStreamCallback? onDelta,
  ) async {
    final response = await _dio.post<dynamic>(
      endpoint(config.baseUrl, 'chat/completions'),
      data: {
        'model': config.model.trim(),
        'messages': messages,
        if (tools.isNotEmpty) ...{'tools': tools, 'tool_choice': 'auto'},
        if (stream) 'stream': true,
      },
      options: _options(config, stream: stream),
    );
    if (!stream) return parseChatCompletion(response.data);
    final chunks = await _readSse(response.data);
    return parseChatStream(chunks, onDelta: onDelta);
  }

  Future<AiCompletion> _createResponses(
    AiConfig config,
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
    bool stream,
    AiStreamCallback? onDelta,
  ) async {
    final instructions = messages
        .where((message) => message['role'] == 'system')
        .map((message) => extractText(message['content']))
        .join('\n');
    final response = await _dio.post<dynamic>(
      endpoint(config.baseUrl, 'responses'),
      data: {
        'model': config.model.trim(),
        if (instructions.isNotEmpty) 'instructions': instructions,
        'input': _responsesInput(messages),
        if (tools.isNotEmpty) 'tools': tools.map(_flattenTool).toList(),
        if (stream) 'stream': true,
      },
      options: _options(config, stream: stream),
    );
    if (!stream) return parseResponsesCompletion(response.data);
    final chunks = await _readSse(response.data);
    return parseResponsesStream(chunks, onDelta: onDelta);
  }

  Future<AiCompletion> _createAnthropic(
    AiConfig config,
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
    bool stream,
    AiStreamCallback? onDelta,
  ) async {
    final system = messages
        .where((message) => message['role'] == 'system')
        .map((message) => extractText(message['content']))
        .join('\n');
    final response = await _dio.post<dynamic>(
      endpoint(config.baseUrl, 'messages'),
      data: {
        'model': config.model.trim(),
        'max_tokens': 4096,
        if (system.isNotEmpty) 'system': system,
        'messages': _anthropicMessages(messages),
        if (tools.isNotEmpty) 'tools': tools.map(_anthropicTool).toList(),
        if (stream) 'stream': true,
      },
      options: _options(config, stream: stream),
    );
    if (!stream) return parseAnthropicCompletion(response.data);
    final chunks = await _readSse(response.data);
    return parseAnthropicStream(chunks, onDelta: onDelta);
  }

  static Future<List<Map<String, dynamic>>> _readSse(dynamic data) async {
    if (data is! ResponseBody) {
      final decoded = data is String ? jsonDecode(data) : data;
      return [Map<String, dynamic>.from(decoded as Map? ?? const {})];
    }
    final result = <Map<String, dynamic>>[];
    await for (final line in data.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final value = line.startsWith('data:')
          ? line.substring(5).trim()
          : line.trim();
      if (value.isEmpty || value == '[DONE]' || value.startsWith('event:')) {
        continue;
      }
      try {
        result.add(Map<String, dynamic>.from(jsonDecode(value) as Map));
      } catch (_) {}
    }
    return result;
  }

  static AiCompletion parseChatCompletion(dynamic raw) {
    final data = _map(raw);
    final choices = data['choices'] as List? ?? const [];
    if (choices.isEmpty) return const AiCompletion(message: {}, toolCalls: []);
    final choice = Map<String, dynamic>.from(choices.first as Map);
    final message = Map<String, dynamic>.from(
      choice['message'] as Map? ?? choice['delta'] as Map? ?? const {},
    );
    final calls = <Map<String, dynamic>>[
      ...(message['tool_calls'] as List? ?? const []).whereType<Map>().map(
        (item) => Map<String, dynamic>.from(item),
      ),
      if (message['function_call'] is Map)
        {
          'id': 'legacy_function_call',
          'function': message['function_call'],
        },
    ];
    final content = extractText(message['content']).isNotEmpty
        ? extractText(message['content'])
        : extractText(message['reasoning_content']);
    return AiCompletion(
      message: {...message, 'role': 'assistant', 'content': content},
      toolCalls: [
        for (var index = 0; index < calls.length; index++)
          AiToolCall.fromJson(calls[index], index: index),
      ],
    );
  }

  static AiCompletion parseChatStream(
    List<Map<String, dynamic>> chunks, {
    AiStreamCallback? onDelta,
  }) {
    final text = StringBuffer();
    final calls = <int, Map<String, dynamic>>{};
    for (final chunk in chunks) {
      final choices = chunk['choices'] as List? ?? const [];
      if (choices.isEmpty) continue;
      final choice = Map<String, dynamic>.from(choices.first as Map);
      final delta = Map<String, dynamic>.from(
        choice['delta'] as Map? ?? choice['message'] as Map? ?? const {},
      );
      final part = extractText(delta['content']).isNotEmpty
          ? extractText(delta['content'])
          : extractText(delta['reasoning_content']);
      if (part.isNotEmpty) {
        text.write(part);
        onDelta?.call(part);
      }
      final toolDeltas = delta['tool_calls'] as List? ?? const [];
      for (final item in toolDeltas.whereType<Map>()) {
        final index = item['index'] as int? ?? calls.length;
        final function = Map<String, dynamic>.from(
          item['function'] as Map? ?? const {},
        );
        final current = calls.putIfAbsent(index, () => <String, dynamic>{});
        current['id'] = item['id'] ?? current['id'] ?? 'call_$index';
        current['name'] = '${current['name'] ?? ''}${function['name'] ?? ''}';
        current['arguments'] =
            '${current['arguments'] ?? ''}${function['arguments'] ?? ''}';
      }
      if (delta['function_call'] is Map) {
        final function = Map<String, dynamic>.from(
          delta['function_call'] as Map,
        );
        final current = calls.putIfAbsent(0, () => <String, dynamic>{});
        current['id'] = 'legacy_function_call';
        current['name'] = '${current['name'] ?? ''}${function['name'] ?? ''}';
        current['arguments'] =
            '${current['arguments'] ?? ''}${function['arguments'] ?? ''}';
      }
    }
    final toolCalls = calls.entries.map((entry) {
      final value = entry.value;
      return AiToolCall.fromJson({
        'id': value['id'],
        'function': {
          'name': value['name'],
          'arguments': value['arguments'],
        },
      }, index: entry.key);
    }).toList();
    return AiCompletion(
      message: {
        'role': 'assistant',
        'content': text.toString(),
        if (toolCalls.isNotEmpty)
          'tool_calls': toolCalls
              .map(
                (call) => {
                  'id': call.id,
                  'type': 'function',
                  'function': {
                    'name': call.name,
                    'arguments': call.rawArguments,
                  },
                },
              )
              .toList(),
      },
      toolCalls: toolCalls,
    );
  }

  static AiCompletion parseResponsesCompletion(dynamic raw) {
    final data = _map(raw);
    final output = data['output'] as List? ?? const [];
    final text = StringBuffer(extractText(data['output_text']));
    final calls = <AiToolCall>[];
    for (final item in output.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      if (map['type'] == 'function_call') {
        calls.add(AiToolCall.fromJson(map, index: calls.length));
      } else {
        text.write(extractText(map['content']));
      }
    }
    return AiCompletion(
      message: {
        'role': 'assistant',
        'content': text.toString(),
        if (calls.isNotEmpty) 'tool_calls': _canonicalToolCalls(calls),
      },
      toolCalls: calls,
    );
  }

  static AiCompletion parseResponsesStream(
    List<Map<String, dynamic>> chunks, {
    AiStreamCallback? onDelta,
  }) {
    final text = StringBuffer();
    final calls = <String, Map<String, dynamic>>{};
    for (final event in chunks) {
      final type = event['type']?.toString() ?? '';
      if (type == 'response.output_text.delta') {
        final delta = event['delta']?.toString() ?? '';
        text.write(delta);
        onDelta?.call(delta);
      }
      final item = event['item'];
      if (item is Map && item['type'] == 'function_call') {
        final map = Map<String, dynamic>.from(item);
        final id = (map['call_id'] ?? map['id'] ?? 'call_${calls.length}')
            .toString();
        calls[id] = map;
      }
      if (type == 'response.function_call_arguments.delta') {
        final id = (event['call_id'] ?? event['item_id'] ?? '').toString();
        final call = calls.putIfAbsent(id, () => {'call_id': id});
        call['arguments'] =
            '${call['arguments'] ?? ''}${event['delta'] ?? ''}';
      }
      if (type == 'response.completed' && text.isEmpty) {
        final completed = parseResponsesCompletion(event['response']);
        if (completed.content.isNotEmpty) {
          text.write(completed.content);
          onDelta?.call(completed.content);
        }
        for (final call in completed.toolCalls) {
          calls[call.id] = {
            'call_id': call.id,
            'name': call.name,
            'arguments': call.rawArguments,
          };
        }
      }
    }
    return AiCompletion(
      message: {
        'role': 'assistant',
        'content': text.toString(),
        if (calls.isNotEmpty)
          'tool_calls': _canonicalToolCalls(
            calls.values.map((item) => AiToolCall.fromJson(item)).toList(),
          ),
      },
      toolCalls: calls.values.map((item) => AiToolCall.fromJson(item)).toList(),
    );
  }

  static AiCompletion parseAnthropicCompletion(dynamic raw) {
    final data = _map(raw);
    final content = data['content'] as List? ?? const [];
    final text = StringBuffer();
    final calls = <AiToolCall>[];
    for (final item in content.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      if (map['type'] == 'tool_use') {
        calls.add(AiToolCall.fromJson(map, index: calls.length));
      } else {
        text.write(extractText(map));
      }
    }
    return AiCompletion(
      message: {
        'role': 'assistant',
        'content': text.toString(),
        if (calls.isNotEmpty) 'tool_calls': _canonicalToolCalls(calls),
      },
      toolCalls: calls,
    );
  }

  static AiCompletion parseAnthropicStream(
    List<Map<String, dynamic>> chunks, {
    AiStreamCallback? onDelta,
  }) {
    final text = StringBuffer();
    final calls = <int, Map<String, dynamic>>{};
    var activeIndex = 0;
    for (final event in chunks) {
      final type = event['type']?.toString();
      if (type == 'content_block_start') {
        activeIndex = event['index'] as int? ?? calls.length;
        final block = Map<String, dynamic>.from(
          event['content_block'] as Map? ?? const {},
        );
        if (block['type'] == 'tool_use') {
          calls[activeIndex] = {...block, 'input': ''};
        }
      }
      if (type == 'content_block_delta') {
        final index = event['index'] as int? ?? activeIndex;
        final delta = Map<String, dynamic>.from(
          event['delta'] as Map? ?? const {},
        );
        if (delta['type'] == 'text_delta') {
          final part = delta['text']?.toString() ?? '';
          text.write(part);
          onDelta?.call(part);
        }
        if (delta['type'] == 'input_json_delta') {
          final call = calls.putIfAbsent(index, () => <String, dynamic>{});
          call['input'] = '${call['input'] ?? ''}${delta['partial_json'] ?? ''}';
        }
      }
    }
    final toolCalls = calls.entries
        .map((entry) => AiToolCall.fromJson(entry.value, index: entry.key))
        .toList();
    return AiCompletion(
      message: {
        'role': 'assistant',
        'content': text.toString(),
        if (toolCalls.isNotEmpty) 'tool_calls': _canonicalToolCalls(toolCalls),
      },
      toolCalls: toolCalls,
    );
  }

  static List<Map<String, dynamic>> _canonicalToolCalls(
    List<AiToolCall> calls,
  ) {
    return calls
        .map(
          (call) => {
            'id': call.id,
            'type': 'function',
            'function': {
              'name': call.name,
              'arguments': call.rawArguments,
            },
          },
        )
        .toList();
  }

  static Map<String, dynamic> _map(dynamic raw) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    return Map<String, dynamic>.from(decoded as Map? ?? const {});
  }

  static Map<String, dynamic> _flattenTool(Map<String, dynamic> tool) {
    final function = Map<String, dynamic>.from(
      tool['function'] as Map? ?? const {},
    );
    return {
      'type': 'function',
      'name': function['name'],
      'description': function['description'],
      'parameters': function['parameters'],
    };
  }

  static Map<String, dynamic> _anthropicTool(Map<String, dynamic> tool) {
    final function = Map<String, dynamic>.from(
      tool['function'] as Map? ?? const {},
    );
    return {
      'name': function['name'],
      'description': function['description'],
      'input_schema': function['parameters'],
    };
  }

  static List<Map<String, dynamic>> _responsesInput(
    List<Map<String, dynamic>> messages,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final message in messages.where((item) => item['role'] != 'system')) {
      final role = message['role'];
      if (role == 'tool') {
        result.add({
          'type': 'function_call_output',
          'call_id': message['tool_call_id'],
          'output': extractText(message['content']),
        });
        continue;
      }
      result.add({'role': role, 'content': message['content']});
      for (final call in (message['tool_calls'] as List? ?? const [])) {
        if (call is! Map) continue;
        final function = Map<String, dynamic>.from(
          call['function'] as Map? ?? const {},
        );
        result.add({
          'type': 'function_call',
          'call_id': call['id'],
          'name': function['name'],
          'arguments': function['arguments'],
        });
      }
    }
    return result;
  }

  static List<Map<String, dynamic>> _anthropicMessages(
    List<Map<String, dynamic>> messages,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final message in messages.where((item) => item['role'] != 'system')) {
      if (message['role'] == 'tool') {
        result.add({
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': message['tool_call_id'],
              'content': extractText(message['content']),
            },
          ],
        });
        continue;
      }
      final content = <Map<String, dynamic>>[
        if (extractText(message['content']).isNotEmpty)
          {'type': 'text', 'text': extractText(message['content'])},
      ];
      for (final call in (message['tool_calls'] as List? ?? const [])) {
        if (call is! Map) continue;
        final parsed = AiToolCall.fromJson(Map<String, dynamic>.from(call));
        content.add({
          'type': 'tool_use',
          'id': parsed.id,
          'name': parsed.name,
          'input': parsed.arguments,
        });
      }
      if (content.isNotEmpty) {
        result.add({'role': message['role'], 'content': content});
      }
    }
    return result;
  }
}

class AiAgent {
  static const maxToolRounds = 12;
  static const maxSkillCharacters = 48000;
  final AiApiService service;

  const AiAgent(this.service);

  Future<String> run({
    required AiConfig config,
    required List<AiChatMessage> history,
    required AiToolHandler toolHandler,
    String summary = '',
    List<AiSkill> skills = const [],
    AiStreamCallback? onDelta,
  }) async {
    final skillPrompt = buildAiSkillPrompt(skills);
    final systemPrompt = [
      aiSystemPrompt,
      if (skillPrompt.isNotEmpty) skillPrompt,
      if (summary.isNotEmpty) 'Previous conversation summary:\n$summary',
    ].join('\n\n');
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': systemPrompt,
      },
      ...history.map((message) => message.toApiJson()),
    ];

    for (var round = 0; round < maxToolRounds; round++) {
      final completion = await service.createCompletion(
        config,
        messages,
        tools: aiToolDefinitions,
        onDelta: onDelta,
      );
      messages.add(completion.message);
      if (completion.toolCalls.isEmpty) return completion.content;
      for (final call in completion.toolCalls) {
        Map<String, dynamic> result;
        if (call.name.isEmpty || call.argumentError != null) {
          result = {
            'ok': false,
            'error': call.name.isEmpty
                ? 'The model omitted the tool name.'
                : 'Invalid tool arguments: ${call.argumentError}',
            'raw_arguments': call.rawArguments,
          };
        } else {
          try {
            result = await toolHandler(call);
          } catch (error) {
            result = {'ok': false, 'error': error.toString()};
          }
        }
        messages.add({
          'role': 'tool',
          'tool_call_id': call.id,
          'content': jsonEncode(result),
        });
      }
    }
    throw StateError('The agent exceeded the tool-call limit.');
  }
}

String buildAiSkillPrompt(List<AiSkill> skills) {
  final enabled = skills.where((skill) => skill.enabled);
  if (enabled.isEmpty) return '';
  final buffer = StringBuffer(
    'Installed Skills provide additional task guidance. Follow them when '
    'relevant, but they never override FlClash safety boundaries, user '
    'confirmation requirements, or registered tool limits.\n',
  );
  for (final skill in enabled) {
    final section = '\n<skill name="${skill.name}">\n${skill.content}\n</skill>\n';
    if (buffer.length + section.length > AiAgent.maxSkillCharacters) break;
    buffer.write(section);
  }
  return buffer.toString();
}

class AiContextCompressor {
  static const maxMessages = 24;
  static const maxCharacters = 16000;
  static const keepRecent = 10;

  const AiContextCompressor();

  bool shouldCompress(AiSession session) {
    return session.messages.length > maxMessages ||
        session.messages.fold<int>(
              0,
              (total, message) => total + message.content.length,
            ) >
            maxCharacters;
  }

  Future<AiSession> compress(AiSession session, AiConfig config, AiApiService service) async {
    if (!shouldCompress(session)) return session;
    final recent = session.messages.length <= keepRecent
        ? session.messages
        : session.messages.sublist(session.messages.length - keepRecent);
    final older = session.messages.sublist(0, session.messages.length - recent.length);
    try {
      final completion = await service.createCompletion(config, [
        {
          'role': 'system',
          'content': '''Summarize this FlClash assistant conversation compactly. Preserve the user's goals and preferences, completed actions, profile/proxy names and IDs, unresolved errors, configuration details, and safety confirmations. Do not invent facts.''',
        },
        {
          'role': 'user',
          'content': [
            if (session.summary.isNotEmpty) 'Earlier summary:\n${session.summary}',
            ...older.map((message) => '${message.role}: ${message.content}'),
          ].join('\n'),
        },
      ]);
      return session.copyWith(
        summary: completion.content,
        messages: recent,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      final fallback = session.messages.length > 40
          ? session.messages.sublist(session.messages.length - 40)
          : session.messages;
      return session.copyWith(messages: fallback, updatedAt: DateTime.now());
    }
  }
}

const aiSystemPrompt = '''
You are the built-in FlClash assistant. Help the user operate this application,
inspect and repair Clash YAML, and convert proxy or subscription links into a
valid Clash configuration. Respond in the user's language.

You may use every registered FlClash capability exposed in the tool list. Read
current state before changing it. Never claim an action succeeded until its
tool result confirms it. Validate YAML before creating or replacing a profile.
Destructive or security-sensitive tools require in-app confirmation; if denied,
do not retry to bypass confirmation. Never reveal API keys or request arbitrary
shell, code execution, reflection, or unrestricted file access.

Persist until the requested application task is complete. If a registered tool
can perform the next step, call it instead of asking the user to do that step in
the UI. For multi-step work, inspect state, perform every required action, and
verify the final state before replying. Pause only when a confirmation was
denied, required information is genuinely missing, or no registered capability
can perform the action. Never stop merely because a previous observation was
empty; refresh or use the relevant diagnostic tool.

When the user asks to import pasted Skill instructions, call import_ai_skill
with a concise name and the complete Skill content. Do not claim the Skill was
installed until the tool confirms persistence.
''';

const aiToolDefinitions = <Map<String, dynamic>>[
  {
    'type': 'function',
    'function': {
      'name': 'list_capabilities',
      'description': 'List every registered FlClash tool and its safety level.',
      'parameters': {'type': 'object', 'properties': {}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'get_app_state',
      'description': 'Read current FlClash runtime and important settings.',
      'parameters': {'type': 'object', 'properties': {}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'list_profiles',
      'description': 'List all profiles and identify the current profile.',
      'parameters': {'type': 'object', 'properties': {}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'switch_profile',
      'description': 'Switch the active profile and apply it.',
      'parameters': {'type': 'object', 'properties': {'profile_id': {'type': 'integer'}}, 'required': ['profile_id']},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'list_proxy_groups',
      'description': 'List proxy groups, current nodes, and candidates.',
      'parameters': {'type': 'object', 'properties': {}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'switch_proxy',
      'description': 'Select a proxy node in one proxy group.',
      'parameters': {'type': 'object', 'properties': {'group_name': {'type': 'string'}, 'proxy_name': {'type': 'string'}}, 'required': ['group_name', 'proxy_name']},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'test_proxy_delays',
      'description': 'Actively test proxy delays for a group or selected proxy names and return sorted live results.',
      'parameters': {
        'type': 'object',
        'properties': {
          'group_name': {'type': 'string'},
          'proxy_names': {'type': 'array', 'items': {'type': 'string'}},
        },
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'add_routing_rule',
      'description': 'Add and apply a routing rule. Automatically detects exact domains, wildcard domain suffixes, IPv4, IPv6, and CIDR values. Use list_proxy_groups first when the requested target is a proxy or policy group.',
      'parameters': {
        'type': 'object',
        'properties': {
          'rule_value': {
            'type': 'string',
            'description': 'Domain, wildcard domain, URL, IP address, or CIDR.',
          },
          'target': {
            'type': 'string',
            'description': 'DIRECT, REJECT, proxy group, or proxy name.',
          },
          'scope': {
            'type': 'string',
            'enum': ['global', 'current_profile', 'profile'],
          },
          'profile_id': {'type': 'integer'},
          'no_resolve': {'type': 'boolean'},
        },
        'required': ['rule_value', 'target'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'list_ai_skills',
      'description': 'List locally installed AI Skills and whether each one is enabled.',
      'parameters': {'type': 'object', 'properties': {}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'import_ai_skill',
      'description': 'Import or update a persistent AI Skill from complete instructions pasted by the user.',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'content': {'type': 'string'},
        },
        'required': ['name', 'content'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'get_profile_yaml',
      'description': 'Read the original YAML of one profile.',
      'parameters': {'type': 'object', 'properties': {'profile_id': {'type': 'integer'}}, 'required': ['profile_id']},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'set_running',
      'description': 'Start or stop FlClash. Requires confirmation.',
      'parameters': {'type': 'object', 'properties': {'running': {'type': 'boolean'}}, 'required': ['running']},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'set_global_overwrite_profile',
      'description': 'Select a persistent global overwrite profile or disable it.',
      'parameters': {'type': 'object', 'properties': {'profile_id': {'type': 'integer'}, 'disabled': {'type': 'boolean'}}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'set_profile_user_agent',
      'description': 'Set or clear custom User-Agent for one profile.',
      'parameters': {'type': 'object', 'properties': {'profile_id': {'type': 'integer'}, 'user_agent': {'type': 'string'}}, 'required': ['profile_id', 'user_agent']},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'update_profile_subscription',
      'description': 'Download and validate a URL profile.',
      'parameters': {'type': 'object', 'properties': {'profile_id': {'type': 'integer'}}, 'required': ['profile_id']},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'rename_profile',
      'description': 'Rename one profile.',
      'parameters': {'type': 'object', 'properties': {'profile_id': {'type': 'integer'}, 'label': {'type': 'string'}}, 'required': ['profile_id', 'label']},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'delete_profile',
      'description': 'Delete one profile and its local file. Requires confirmation.',
      'parameters': {'type': 'object', 'properties': {'profile_id': {'type': 'integer'}}, 'required': ['profile_id']},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'restart_core',
      'description': 'Restart the FlClash core. Requires confirmation.',
      'parameters': {'type': 'object', 'properties': {}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'close_connections',
      'description': 'Close all current network connections. Requires confirmation.',
      'parameters': {'type': 'object', 'properties': {}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'refresh_proxy_groups',
      'description': 'Refresh proxy groups and node state from the core.',
      'parameters': {'type': 'object', 'properties': {}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'update_all_profiles',
      'description': 'Update every URL subscription profile.',
      'parameters': {'type': 'object', 'properties': {}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'clear_logs_and_requests',
      'description': 'Clear in-memory logs and request records. Requires confirmation.',
      'parameters': {'type': 'object', 'properties': {}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'validate_yaml',
      'description': 'Validate Clash YAML without saving it.',
      'parameters': {'type': 'object', 'properties': {'yaml': {'type': 'string'}}, 'required': ['yaml']},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'create_profile_yaml',
      'description': 'Create a profile from validated YAML. Requires confirmation.',
      'parameters': {'type': 'object', 'properties': {'label': {'type': 'string'}, 'yaml': {'type': 'string'}}, 'required': ['label', 'yaml']},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'replace_profile_yaml',
      'description': 'Replace profile YAML after validation. Requires confirmation.',
      'parameters': {'type': 'object', 'properties': {'profile_id': {'type': 'integer'}, 'yaml': {'type': 'string'}}, 'required': ['profile_id', 'yaml']},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'update_settings',
      'description': 'Update supported proxy and application settings. Sensitive changes require confirmation.',
      'parameters': {
        'type': 'object',
        'properties': {
          'mode': {'type': 'string', 'enum': ['rule', 'global', 'direct']},
          'system_proxy': {'type': 'boolean'}, 'tun': {'type': 'boolean'},
          'allow_lan': {'type': 'boolean'}, 'ipv6': {'type': 'boolean'},
          'mixed_port': {'type': 'integer', 'minimum': 1, 'maximum': 65535},
          'global_user_agent': {'type': 'string'}, 'dns_enabled': {'type': 'boolean'},
          'dns_nameservers': {'type': 'array', 'items': {'type': 'string'}},
          'auto_launch': {'type': 'boolean'}, 'silent_launch': {'type': 'boolean'},
          'auto_run': {'type': 'boolean'}, 'auto_check_update': {'type': 'boolean'},
          'open_logs': {'type': 'boolean'}, 'close_connections': {'type': 'boolean'},
          'animate_navigation': {'type': 'boolean'},
          'theme_mode': {'type': 'string', 'enum': ['system', 'light', 'dark']}
        }
      },
    },
  },
];
