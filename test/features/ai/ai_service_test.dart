import 'dart:convert';

import 'package:fl_clash/features/ai/ai_service.dart';
import 'package:fl_clash/models/ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiApiService', () {
    test('normalizes compatible API endpoints', () {
      expect(
        AiApiService.endpoint('https://example.com/v1///', '/models'),
        'https://example.com/v1/models',
      );
      expect(
        AiApiService.endpoint('https://example.com/openai/v1', 'chat/completions'),
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
  });

  test('AiConfig round trips through json', () {
    const config = AiConfig(
      baseUrl: 'https://example.com/v1',
      apiKey: 'secret',
      model: 'model-a',
    );

    expect(AiConfig.fromJson(config.toJson()).toJson(), config.toJson());
  });
}
