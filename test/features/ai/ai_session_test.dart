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
      AiSessionStore(activeSessionId: empty.id, sessions: [empty])
          .canReuseActiveSession,
      isTrue,
    );
    final started = AiSession(
      messages: [AiChatMessage(role: 'user', content: 'hello')],
    );
    expect(
      AiSessionStore(activeSessionId: started.id, sessions: [started])
          .canReuseActiveSession,
      isFalse,
    );
  });

  test('AI Skill infers names, persists, and enters the system prompt', () {
    const content = '''---
name: Routing helper
---
Always inspect routing state first.''';
    final skill = AiSkill(
      name: AiSkill.inferName(content),
      content: content,
    );
    final restored = AiSkill.fromJson(skill.toJson());
    expect(restored.name, 'Routing helper');
    expect(restored.content, content);
    expect(buildAiSkillPrompt([restored]), contains(content));
    expect(
      buildAiSkillPrompt([restored.copyWith(enabled: false)]),
      isEmpty,
    );
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
