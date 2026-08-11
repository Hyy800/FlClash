import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fl_clash/models/models.dart';

typedef AiToolHandler = Future<Map<String, dynamic>> Function(AiToolCall call);

class AiToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  factory AiToolCall.fromJson(Map<String, dynamic> json) {
    final function = Map<String, dynamic>.from(
      json['function'] as Map? ?? const {},
    );
    final rawArguments = function['arguments'];
    Map<String, dynamic> arguments = const {};
    try {
      arguments = rawArguments is String
          ? Map<String, dynamic>.from(jsonDecode(rawArguments) as Map)
          : Map<String, dynamic>.from(rawArguments as Map? ?? const {});
    } catch (_) {}
    return AiToolCall(
      id: json['id'] as String? ?? '',
      name: function['name'] as String? ?? '',
      arguments: arguments,
    );
  }
}

class AiCompletion {
  final Map<String, dynamic> message;
  final List<AiToolCall> toolCalls;

  const AiCompletion({required this.message, required this.toolCalls});

  String get content => message['content'] as String? ?? '';
}

class AiApiService {
  final Dio _dio;

  AiApiService({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 90),
              sendTimeout: const Duration(seconds: 30),
            ),
          );

  static String normalizeBaseUrl(String value) {
    var baseUrl = value.trim();
    while (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    return baseUrl;
  }

  static String endpoint(String baseUrl, String path) {
    final normalized = normalizeBaseUrl(baseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$normalized$normalizedPath';
  }

  static List<String> parseModelIds(dynamic data) {
    final decoded = data is String ? jsonDecode(data) : data;
    final map = Map<String, dynamic>.from(decoded as Map? ?? const {});
    final models = map['data'] as List? ?? const [];
    return models
        .whereType<Map>()
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Options _options(AiConfig config) {
    return Options(
      headers: {
        'Authorization': 'Bearer ${config.apiKey.trim()}',
        'Content-Type': 'application/json',
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
    await createCompletion(config, const [
      {'role': 'user', 'content': 'Reply with OK.'},
    ]);
  }

  Future<AiCompletion> createCompletion(
    AiConfig config,
    List<Map<String, dynamic>> messages, {
    List<Map<String, dynamic>> tools = const [],
  }) async {
    final body = <String, dynamic>{
      'model': config.model.trim(),
      'messages': messages,
      if (tools.isNotEmpty) ...{'tools': tools, 'tool_choice': 'auto'},
    };
    final response = await _dio.post<dynamic>(
      endpoint(config.baseUrl, 'chat/completions'),
      data: body,
      options: _options(config),
    );
    final decoded = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    final data = Map<String, dynamic>.from(decoded as Map? ?? const {});
    final choices = data['choices'] as List? ?? const [];
    if (choices.isEmpty) {
      throw StateError('The API returned no completion choices.');
    }
    final choice = Map<String, dynamic>.from(choices.first as Map);
    final message = Map<String, dynamic>.from(
      choice['message'] as Map? ?? const {},
    );
    final toolCalls = (message['tool_calls'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => AiToolCall.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return AiCompletion(message: message, toolCalls: toolCalls);
  }
}

class AiAgent {
  static const maxToolRounds = 6;
  final AiApiService service;

  const AiAgent(this.service);

  Future<String> run({
    required AiConfig config,
    required List<AiChatMessage> history,
    required AiToolHandler toolHandler,
  }) async {
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': _systemPrompt,
      },
      ...history.map((message) => message.toJson()),
    ];

    for (var round = 0; round < maxToolRounds; round++) {
      final completion = await service.createCompletion(
        config,
        messages,
        tools: aiToolDefinitions,
      );
      messages.add(completion.message);
      if (completion.toolCalls.isEmpty) {
        return completion.content.isEmpty
            ? 'The model returned an empty response.'
            : completion.content;
      }
      for (final call in completion.toolCalls) {
        Map<String, dynamic> result;
        try {
          result = await toolHandler(call);
        } catch (error) {
          result = {'ok': false, 'error': error.toString()};
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

const _systemPrompt = '''
You are the built-in FlClash assistant. Help the user operate this application,
inspect and repair Clash YAML, and convert proxy or subscription links into a
valid Clash configuration. Respond in the user's language.

Use tools for facts and app actions. Never claim an action succeeded until the
tool result confirms it. Validate YAML before asking to create or replace a
profile. Destructive or security-sensitive tools require an in-app user
confirmation; if confirmation is denied, explain that no change was made.
Prefer the smallest necessary change and never reveal API keys.
''';

const aiToolDefinitions = <Map<String, dynamic>>[
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
      'parameters': {
        'type': 'object',
        'properties': {
          'profile_id': {'type': 'integer'},
        },
        'required': ['profile_id'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'list_proxy_groups',
      'description': 'List proxy groups, their current nodes, and candidates.',
      'parameters': {'type': 'object', 'properties': {}},
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'switch_proxy',
      'description': 'Select a proxy node in one proxy group.',
      'parameters': {
        'type': 'object',
        'properties': {
          'group_name': {'type': 'string'},
          'proxy_name': {'type': 'string'},
        },
        'required': ['group_name', 'proxy_name'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'get_profile_yaml',
      'description': 'Read the original YAML of one profile.',
      'parameters': {
        'type': 'object',
        'properties': {
          'profile_id': {'type': 'integer'},
        },
        'required': ['profile_id'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'set_running',
      'description': 'Start or stop the FlClash proxy runtime. Requires user confirmation.',
      'parameters': {
        'type': 'object',
        'properties': {
          'running': {'type': 'boolean'},
        },
        'required': ['running'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'set_global_overwrite_profile',
      'description': 'Select a persistent global overwrite profile, or disable the selection.',
      'parameters': {
        'type': 'object',
        'properties': {
          'profile_id': {'type': 'integer'},
          'disabled': {'type': 'boolean'},
        },
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'set_profile_user_agent',
      'description': 'Set or clear the custom User-Agent for one profile.',
      'parameters': {
        'type': 'object',
        'properties': {
          'profile_id': {'type': 'integer'},
          'user_agent': {'type': 'string'},
        },
        'required': ['profile_id', 'user_agent'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'update_profile_subscription',
      'description': 'Download and validate the latest content of a URL profile.',
      'parameters': {
        'type': 'object',
        'properties': {
          'profile_id': {'type': 'integer'},
        },
        'required': ['profile_id'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'validate_yaml',
      'description': 'Validate Clash YAML without saving it.',
      'parameters': {
        'type': 'object',
        'properties': {
          'yaml': {'type': 'string'},
        },
        'required': ['yaml'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'create_profile_yaml',
      'description': 'Create a file profile from validated Clash YAML. Requires user confirmation.',
      'parameters': {
        'type': 'object',
        'properties': {
          'label': {'type': 'string'},
          'yaml': {'type': 'string'},
        },
        'required': ['label', 'yaml'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'replace_profile_yaml',
      'description': 'Replace an existing profile YAML after validation. Requires user confirmation.',
      'parameters': {
        'type': 'object',
        'properties': {
          'profile_id': {'type': 'integer'},
          'yaml': {'type': 'string'},
        },
        'required': ['profile_id', 'yaml'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'update_settings',
      'description': 'Update supported proxy and application settings. TUN changes require user confirmation.',
      'parameters': {
        'type': 'object',
        'properties': {
          'mode': {'type': 'string', 'enum': ['rule', 'global', 'direct']},
          'system_proxy': {'type': 'boolean'},
          'tun': {'type': 'boolean'},
          'allow_lan': {'type': 'boolean'},
          'ipv6': {'type': 'boolean'},
          'mixed_port': {'type': 'integer', 'minimum': 1, 'maximum': 65535},
          'global_user_agent': {'type': 'string'},
          'dns_enabled': {'type': 'boolean'},
          'dns_nameservers': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'auto_launch': {'type': 'boolean'},
          'silent_launch': {'type': 'boolean'},
          'auto_run': {'type': 'boolean'},
          'auto_check_update': {'type': 'boolean'},
          'open_logs': {'type': 'boolean'},
          'close_connections': {'type': 'boolean'},
          'animate_navigation': {'type': 'boolean'},
          'theme_mode': {
            'type': 'string',
            'enum': ['system', 'light', 'dark'],
          },
        },
      },
    },
  },
];
