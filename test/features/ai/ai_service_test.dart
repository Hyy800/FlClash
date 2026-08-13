import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/ai/ai_service.dart';
import 'package:fl_clash/features/ai/ai_tools.dart';
import 'package:fl_clash/models/ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiApiService', () {
    test('emits SSE events while the transport is still open', () async {
      final controller = StreamController<Uint8List>();
      final events = <Map<String, dynamic>>[];
      final completion = AiApiService.readSseForTest(
        controller.stream,
        onEvent: events.add,
      );

      controller.add(
        Uint8List.fromList(
          utf8.encode('data: {"type":"delta","delta":"hello"}\n\n'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events.single['delta'], 'hello');
      controller.add(Uint8List.fromList(utf8.encode('data: [DONE]\n\n')));
      await controller.close();
      expect(await completion, hasLength(1));
    });

    test('normalizes compatible API endpoints', () {
      expect(
        AiApiService.endpoint('https://example.com/v1///', '/models'),
        'https://example.com/v1/models',
      );
      expect(
        AiApiService.endpoint(
          'https://example.com/openai/v1',
          'chat/completions',
        ),
        'https://example.com/openai/v1/chat/completions',
      );
    });

    test('parses and sorts model ids', () {
      expect(
        AiApiService.parseModelIds({
          'data': [
            {'id': 'model-b'},
            {'id': 'model-a'},
            {'id': 'model-a'},
          ],
        }),
        ['model-a', 'model-b'],
      );
      expect(
        AiApiService.parseModelIds({
          'models': [
            {'name': 'claude-b'},
            {'id': 'claude-a'},
          ],
        }),
        ['claude-a', 'claude-b'],
      );
    });

    test('parses tool call arguments', () {
      final call = AiToolCall.fromJson({
        'id': 'call_1',
        'function': {
          'name': 'switch_profile',
          'arguments': jsonEncode({'profile_id': 42}),
        },
      });

      expect(call.id, 'call_1');
      expect(call.name, 'switch_profile');
      expect(call.arguments, {'profile_id': 42});
    });

    test('extracts text from compatible content shapes', () {
      expect(
        AiApiService.extractText([
          {'type': 'text', 'text': 'hello'},
          {'type': 'output_text', 'text': ' world'},
        ]),
        'hello world',
      );
      final result = AiApiService.parseChatCompletion({
        'choices': [
          {
            'message': {'role': 'assistant', 'reasoning_content': 'reasoning'},
          },
        ],
      });
      expect(result.content, 'reasoning');
    });

    test('merges streamed tool call arguments', () {
      final result = AiApiService.parseChatStream([
        {
          'choices': [
            {
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'id': 'call_1',
                    'function': {'name': 'switch_', 'arguments': '{"profile_'},
                  },
                ],
              },
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'function': {'name': 'profile', 'arguments': 'id":42}'},
                  },
                ],
              },
            },
          ],
        },
      ]);
      expect(result.toolCalls.single.name, 'switch_profile');
      expect(result.toolCalls.single.arguments, {'profile_id': 42});
    });

    test('parses legacy function_call', () {
      final result = AiApiService.parseChatCompletion({
        'choices': [
          {
            'message': {
              'function_call': {'name': 'get_app_state', 'arguments': '{}'},
            },
          },
        ],
      });
      expect(result.toolCalls.single.name, 'get_app_state');
    });

    test('parses Responses streaming events', () {
      final deltas = <String>[];
      final result = AiApiService.parseResponsesStream([
        {'type': 'response.output_text.delta', 'delta': 'hello'},
        {
          'type': 'response.output_item.added',
          'item': {
            'type': 'function_call',
            'call_id': 'call_2',
            'name': 'get_app_state',
            'arguments': '',
          },
        },
        {
          'type': 'response.function_call_arguments.delta',
          'call_id': 'call_2',
          'delta': '{}',
        },
      ], onDelta: deltas.add);
      expect(result.content, 'hello');
      expect(deltas, ['hello']);
      expect(result.toolCalls.single.name, 'get_app_state');
    });

    test('parses Anthropic streaming events', () {
      final result = AiApiService.parseAnthropicStream([
        {
          'type': 'content_block_start',
          'index': 0,
          'content_block': {
            'type': 'tool_use',
            'id': 'tool_1',
            'name': 'switch_profile',
          },
        },
        {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {
            'type': 'input_json_delta',
            'partial_json': '{"profile_id":7}',
          },
        },
      ]);
      expect(result.toolCalls.single.id, 'tool_1');
      expect(result.toolCalls.single.arguments, {'profile_id': 7});
    });
  });

  test('AiConfig round trips through json', () {
    const config = AiConfig(
      baseUrl: 'https://example.com/v1',
      apiKey: 'secret',
      model: 'model-a',
      protocol: AiApiProtocol.openAiResponses,
      cachedModels: ['model-a', 'model-b'],
    );

    expect(AiConfig.fromJson(config.toJson()).toJson(), config.toJson());
  });

  test('agent exposes delay testing and persistence guidance', () {
    final toolNames = aiToolDefinitions
        .map((tool) => tool['function'] as Map<String, dynamic>)
        .map((function) => function['name'])
        .toSet();
    expect(toolNames, contains('test_proxy_delays'));
    expect(toolNames, contains('add_routing_rule'));
    expect(toolNames, contains('list_ai_skills'));
    expect(toolNames, contains('import_ai_skill'));
    expect(aiSystemPrompt, contains('Persist until'));
  });

  test(
    'agent forwards transport deltas without duplicating the reply',
    () async {
      final deltas = <String>[];
      final reply = await AiAgent(_StreamingAiApiService()).run(
        config: const AiConfig(
          baseUrl: 'https://example.com/v1',
          apiKey: 'secret',
          model: 'model-a',
        ),
        history: const [],
        toolHandler: (_) async => const {},
        onDelta: deltas.add,
      );

      expect(deltas, ['he', 'llo']);
      expect(reply, 'hello');
    },
  );

  group('AI routing rule detection', () {
    test('detects domains and wildcard suffixes', () {
      expect(parseAiRoutingRuleSource('Example.COM'), (
        action: RuleAction.DOMAIN,
        content: 'example.com',
      ));
      expect(parseAiRoutingRuleSource('*.Example.COM'), (
        action: RuleAction.DOMAIN_SUFFIX,
        content: 'example.com',
      ));
      expect(parseAiRoutingRuleSource('https://example.com/path'), (
        action: RuleAction.DOMAIN,
        content: 'example.com',
      ));
    });

    test('detects IPv4, IPv6, and CIDR values', () {
      expect(parseAiRoutingRuleSource('192.0.2.8'), (
        action: RuleAction.IP_CIDR,
        content: '192.0.2.8/32',
      ));
      expect(parseAiRoutingRuleSource('2001:db8::8'), (
        action: RuleAction.IP_CIDR6,
        content: '2001:db8::8/128',
      ));
      expect(parseAiRoutingRuleSource('192.0.2.0/24'), (
        action: RuleAction.IP_CIDR,
        content: '192.0.2.0/24',
      ));
    });

    test('rejects invalid values', () {
      expect(
        () => parseAiRoutingRuleSource('not a domain'),
        throwsFormatException,
      );
      expect(
        () => parseAiRoutingRuleSource('192.0.2.0/99'),
        throwsFormatException,
      );
    });
  });
}

class _StreamingAiApiService extends AiApiService {
  @override
  Future<AiCompletion> createCompletion(
    AiConfig config,
    List<Map<String, dynamic>> messages, {
    List<Map<String, dynamic>> tools = const [],
    AiStreamCallback? onDelta,
  }) async {
    onDelta?.call('he');
    await Future<void>.delayed(Duration.zero);
    onDelta?.call('llo');
    return const AiCompletion(
      message: {'role': 'assistant', 'content': 'hello'},
      toolCalls: [],
    );
  }
}
