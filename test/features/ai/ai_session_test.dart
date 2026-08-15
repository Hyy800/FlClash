import 'package:fl_clash/features/ai/ai_service.dart';
import 'package:fl_clash/models/ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session store round trips and keeps the active session', () {
    final first = AiSession(
      title: 'First',
      messages: [AiChatMessage(role: 'user', content: 'hello')],
    );
    final second = AiSession(title: 'Second');
    final store = AiSessionStore(
      activeSessionId: second.id,
      sessions: [first, second],
    );

    final restored = AiSessionStore.fromJson(store.toJson());
    expect(restored.activeSessionId, second.id);
    expect(restored.activeSession.title, 'Second');
    expect(restored.sessions.first.messages.single.content, 'hello');
  });

  test('chat attachments persist and build multimodal API content', () {
    final message = AiChatMessage(
      role: 'user',
      content: 'Repair this configuration',
      attachments: const [
        AiAttachment(
          name: 'broken.yaml',
          mimeType: 'text/plain',
          text: 'proxies: [',
        ),
        AiAttachment(
          name: 'screen.png',
          mimeType: 'image/png',
          data: 'aGVsbG8=',
        ),
      ],
    );

    final restored = AiChatMessage.fromJson(message.toJson());
    expect(restored.attachments, hasLength(2));
    final api = restored.toApiJson();
    expect(api['content'], isA<List<dynamic>>());
    final content = api['content'] as List<dynamic>;
    expect(content.first.toString(), contains('broken.yaml'));
    expect(content.last.toString(), contains('data:image/png;base64'));
  });

  test('assistant reasoning persists but is excluded from API history', () {
    final message = AiChatMessage(
      role: 'assistant',
      content: 'Final answer',
      reasoning: 'Internal reasoning',
    );

    final restored = AiChatMessage.fromJson(message.toJson());
    expect(restored.reasoning, 'Internal reasoning');
    expect(restored.toApiJson(), {
      'role': 'assistant',
      'content': 'Final answer',
    });
  });

  test('text-only attachments use the attached file envelope', () {
    final message = AiChatMessage(
      role: 'user',
      content: '',
      attachments: const [
        AiAttachment(
          name: 'profile.yaml',
          mimeType: 'text/plain',
          text: 'mixed-port: 7890',
        ),
      ],
    );

    final api = message.toApiJson();
    expect(api['content'], contains('<attached_file name="profile.yaml">'));
    expect(api['content'], contains('mixed-port: 7890'));
  });

  test('session store falls back from an invalid active id', () {
    final session = AiSession(title: 'Available');
    final restored = AiSessionStore.fromJson({
      'activeSessionId': 'missing',
      'sessions': [session.toJson()],
    });
    expect(restored.activeSessionId, session.id);
  });

  test('only an untouched active session can be reused', () {
    final empty = AiSession();
    expect(
      AiSessionStore(
        activeSessionId: empty.id,
        sessions: [empty],
      ).canReuseActiveSession,
      isTrue,
    );
    final started = AiSession(
      messages: [AiChatMessage(role: 'user', content: 'hello')],
    );
    expect(
      AiSessionStore(
        activeSessionId: started.id,
        sessions: [started],
      ).canReuseActiveSession,
      isFalse,
    );
  });

  test('AI Skill infers names, persists, and enters the system prompt', () {
    const content = '''---
name: Routing helper
---
Always inspect routing state first.''';
    final skill = AiSkill(name: AiSkill.inferName(content), content: content);
    final restored = AiSkill.fromJson(skill.toJson());
    expect(restored.name, 'Routing helper');
    expect(restored.content, content);
    expect(buildAiSkillPrompt([restored]), contains(content));
    expect(buildAiSkillPrompt([restored.copyWith(enabled: false)]), isEmpty);
  });

  test('context compressor threshold covers count and character limits', () {
    const compressor = AiContextCompressor();
    final many = AiSession(
      messages: List.generate(
        AiContextCompressor.maxMessages + 1,
        (index) => AiChatMessage(role: 'user', content: '$index'),
      ),
    );
    final long = AiSession(
      messages: [
        AiChatMessage(
          role: 'user',
          content: List.filled(
            AiContextCompressor.maxCharacters + 1,
            'x',
          ).join(),
        ),
      ],
    );
    expect(compressor.shouldCompress(many), isTrue);
    expect(compressor.shouldCompress(long), isTrue);
    expect(compressor.shouldCompress(AiSession()), isFalse);
  });
}
